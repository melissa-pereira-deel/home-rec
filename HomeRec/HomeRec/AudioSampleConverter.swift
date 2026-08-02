//
//  AudioSampleConverter.swift
//  HomeRec
//
//  Converts a ScreenCaptureKit CMSampleBuffer into a non-interleaved Float32
//  AVAudioPCMBuffer. Extracted from AudioRecorder so it can be unit-tested in
//  isolation (BL-007). Pure and `nonisolated` — it runs on the recorder's
//  processing queue, never the main actor, and touches no shared state.
//

import Foundation
import CoreMedia
import AVFoundation

enum AudioSampleConverter {

    /// Build a non-interleaved Float32 PCM buffer from a sample buffer.
    /// Returns `nil` for any unsupported/empty input (caller drops the buffer).
    nonisolated static func makePCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
        guard let streamDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else { return nil }

        let sourceChannels = AVAudioChannelCount(streamDesc.pointee.mChannelsPerFrame)
        guard sourceChannels > 0 else { return nil }

        // ⚠️ `AVAudioFormat(commonFormat:sampleRate:channels:interleaved:)`
        // returns **nil for any channel count above 2** — measured 2026-08-02:
        // 1 and 2 succeed, 3/4/6/8 all return nil. It has no layout to infer
        // beyond mono and stereo, and will not guess.
        //
        // A Focusrite Scarlett 2i2 4th Gen presents 4 input channels (two analog
        // plus two loopback), so microphone capture from it failed here even
        // after integer decoding was fixed (BL-150). Anything above stereo needs
        // an explicit layout; discrete carries no spatial claim, which is right
        // for an interface's raw inputs.
        let format: AVAudioFormat?
        if sourceChannels <= 2 {
            format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: streamDesc.pointee.mSampleRate,
                channels: sourceChannels,
                interleaved: false
            )
        } else if let layout = AVAudioChannelLayout(
            layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | sourceChannels
        ) {
            format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: streamDesc.pointee.mSampleRate,
                interleaved: false,
                channelLayout: layout
            )
        } else {
            format = nil
        }
        guard let format else { return nil }

        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frameCount > 0 else { return nil }

        guard let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            return nil
        }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        // Query the required AudioBufferList size, then fetch it (with a retained
        // block buffer that must outlive the copy below — hence the defers).
        var requiredSize = 0
        var status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &requiredSize,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: nil
        )
        guard status == noErr else { return nil }

        let audioBufferListPtr = UnsafeMutableRawPointer.allocate(
            byteCount: requiredSize,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { audioBufferListPtr.deallocate() }

        var blockBuffer: CMBlockBuffer?
        status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferListPtr.assumingMemoryBound(to: AudioBufferList.self),
            bufferListSize: requiredSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else { return nil }
        defer { blockBuffer = nil }

        let audioBufferListPointer = UnsafeMutableAudioBufferListPointer(
            audioBufferListPtr.assumingMemoryBound(to: AudioBufferList.self)
        )

        guard let floatChannelData = pcmBuffer.floatChannelData else { return nil }

        let flags = streamDesc.pointee.mFormatFlags
        let channelCount = Int(streamDesc.pointee.mChannelsPerFrame)
        let isInterleaved = (flags & kAudioFormatFlagIsNonInterleaved) == 0
        let isFloat = (flags & kAudioFormatFlagIsFloat) != 0
        let bitsPerChannel = Int(streamDesc.pointee.mBitsPerChannel)

        // ⚠️ The source is NOT always Float32 (BL-150). SCK pins the `.audio`
        // output to Float32 via the stream config, but a `.microphone` buffer
        // arrives in the *device's* native format, and real interfaces send
        // packed signed integer — a Focusrite Scarlett 2i2 4th Gen sends 4ch
        // interleaved Int16. Reading those bytes as `Float` produced nil here,
        // the caller dropped every buffer, and the take was written as a header
        // with no audio. Microphone capture had only ever worked on devices that
        // happen to deliver Float32.
        //
        // Reading one frame of one channel, whatever the source encoding is.
        // Integer samples are scaled to the ±1.0 range Float32 PCM expects.
        // Bytes per sample comes from the ASBD, never from the bit depth: 24-bit
        // audio is routinely carried in a 4-byte container. Assuming otherwise
        // is what made the first attempt at this fix wrong.
        let bytesPerSample = isInterleaved
            ? Int(streamDesc.pointee.mBytesPerFrame) / max(1, channelCount)
            : Int(streamDesc.pointee.mBytesPerFrame)
        let isAlignedHigh = (flags & kAudioFormatFlagIsAlignedHigh) != 0

        let read: (UnsafeRawPointer, Int) -> Float
        switch (isFloat, bitsPerChannel, bytesPerSample) {
        case (true, 32, _):
            read = { base, i in base.assumingMemoryBound(to: Float.self)[i] }
        case (true, 64, _):
            read = { base, i in Float(base.assumingMemoryBound(to: Double.self)[i]) }
        case (false, 16, 2):
            read = { base, i in Float(base.assumingMemoryBound(to: Int16.self)[i]) / 32_768.0 }
        case (false, 32, 4):
            read = { base, i in Float(base.assumingMemoryBound(to: Int32.self)[i]) / 2_147_483_648.0 }

        // 24-bit in a 4-byte container — what a Focusrite Scarlett 2i2 sends
        // (`24-bit flags=20` = signed integer, aligned high). Aligned high means
        // the 24 significant bits sit at the top of the word with the low byte
        // zeroed, so the container reads as a full-scale Int32 and the ordinary
        // 2^31 divisor is already correct. Aligned low keeps the value in the
        // low 24 bits, so it scales by 2^23 instead.
        case (false, 24, 4):
            let divisor: Float = isAlignedHigh ? 2_147_483_648.0 : 8_388_608.0
            read = { base, i in Float(base.assumingMemoryBound(to: Int32.self)[i]) / divisor }

        // 24-bit packed into exactly 3 bytes: assemble little-endian and
        // sign-extend by hand — there is no 24-bit integer type to load.
        case (false, 24, 3):
            read = { base, i in
                let p = base.advanced(by: i * 3).assumingMemoryBound(to: UInt8.self)
                let raw = Int32(p[0]) | (Int32(p[1]) << 8) | (Int32(p[2]) << 16)
                let signed = (raw & 0x80_0000) != 0 ? raw - 0x100_0000 : raw
                return Float(signed) / 8_388_608.0
            }

        default:
            // Anything else fails loudly at the call site rather than producing
            // noise from misread bytes. The caller logs the exact format once.
            return nil
        }

        if isInterleaved {
            guard let buffer = audioBufferListPointer.first,
                  let srcData = buffer.mData else { return nil }
            for frame in 0..<frameCount {
                for channel in 0..<channelCount {
                    floatChannelData[channel][frame] = read(srcData, frame * channelCount + channel)
                }
            }
        } else {
            for channel in 0..<min(channelCount, audioBufferListPointer.count) {
                guard let srcData = audioBufferListPointer[channel].mData else { continue }
                for frame in 0..<frameCount {
                    floatChannelData[channel][frame] = read(srcData, frame)
                }
            }
        }

        return pcmBuffer
    }
}

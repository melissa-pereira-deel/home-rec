//
//  SampleBufferFixtures.swift
//  HomeRecTests
//
//  Shared synthetic audio fixtures for BL-007 tests: Float32 PCM buffers filled
//  with known (non-zero) data, and CMSampleBuffers in both interleaved and
//  non-interleaved layouts. The non-interleaved path is built from an
//  AVAudioPCMBuffer (which guarantees a correct per-channel AudioBufferList) and
//  wrapped via CMSampleBufferSetDataBufferFromAudioBufferList.
//

import Foundation
import AVFoundation
import CoreMedia

enum SampleBufferFixtures {

    /// A Float32 PCM buffer (interleaved or not) with each sample set by `fill(channel, frame)`.
    static func makePCMBuffer(
        channels: Int,
        frames: Int,
        sampleRate: Double = 48000,
        interleaved: Bool,
        fill: (_ channel: Int, _ frame: Int) -> Float
    ) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: interleaved
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(frames, 1)))!
        buffer.frameLength = AVAudioFrameCount(frames)

        if frames > 0 {
            if interleaved {
                let abl = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
                let ptr = abl[0].mData!.assumingMemoryBound(to: Float.self)
                for frame in 0..<frames {
                    for channel in 0..<channels {
                        ptr[frame * channels + channel] = fill(channel, frame)
                    }
                }
            } else {
                let channelData = buffer.floatChannelData!
                for channel in 0..<channels {
                    for frame in 0..<frames {
                        channelData[channel][frame] = fill(channel, frame)
                    }
                }
            }
        }
        return buffer
    }

    /// Wrap a PCM buffer into a CMSampleBuffer, preserving its (non-)interleaved layout.
    static func makeSampleBuffer(from pcm: AVAudioPCMBuffer) -> CMSampleBuffer {
        var asbd = pcm.format.streamDescription.pointee
        var formatDescription: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0, layout: nil,
            magicCookieSize: 0, magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        )

        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(pcm.format.sampleRate)),
            presentationTimeStamp: CMTime(value: 0, timescale: CMTimeScale(pcm.format.sampleRate)),
            decodeTimeStamp: .invalid
        )
        CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: CMItemCount(pcm.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer!,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: pcm.audioBufferList
        )

        // The block buffer above *references* `pcm`'s memory rather than copying it,
        // so `pcm` must outlive the CMSampleBuffer. As a transient local it would
        // otherwise deallocate on return, leaving the sample buffer pointing at freed
        // memory — a use-after-free that survives by luck normally but crashes under
        // Thread Sanitizer (objc_release in the full-suite run). Pin its lifetime to
        // the sample buffer via an attachment, which retains it until the buffer dies.
        CMSetAttachment(
            sampleBuffer!,
            key: "HomeRecBackingPCMBuffer" as CFString,
            value: pcm,
            attachmentMode: kCMAttachmentMode_ShouldNotPropagate
        )
        return sampleBuffer!
    }

    /// Convenience: an interleaved CMSampleBuffer filled via `fill`.
    static func interleaved(frames: Int, channels: Int = 2, sampleRate: Double = 48000, fill: (Int, Int) -> Float) -> CMSampleBuffer {
        makeSampleBuffer(from: makePCMBuffer(channels: channels, frames: frames, sampleRate: sampleRate, interleaved: true, fill: fill))
    }

    /// Convenience: a non-interleaved CMSampleBuffer filled via `fill`.
    static func nonInterleaved(frames: Int, channels: Int = 2, sampleRate: Double = 48000, fill: (Int, Int) -> Float) -> CMSampleBuffer {
        makeSampleBuffer(from: makePCMBuffer(channels: channels, frames: frames, sampleRate: sampleRate, interleaved: false, fill: fill))
    }

    // MARK: - Integer PCM (BL-150)
    //
    // ⚠️ Everything above builds **Float32**, because `AVAudioPCMBuffer` only
    // speaks the common formats. That was a blind spot with teeth: every test
    // fed `AudioSampleConverter` exactly the format it already assumed, so the
    // fixtures encoded the same belief as the code under test and **could not
    // fail on it**. Microphone capture shipped writing header-only files on any
    // interface sending integer PCM, with 282 tests green.
    //
    // These build an `AudioStreamBasicDescription` by hand instead, so a test
    // can express what real hardware actually sends. Measured from a Focusrite
    // Scarlett 2i2 4th Gen: `4ch 48000Hz 24-bit int alignedHigh container=4B`.

    /// How a device lays its samples out on the wire.
    ///
    /// Container size is carried separately from bit depth on purpose: 24-bit
    /// audio routinely travels in a 4-byte word, and conflating the two is the
    /// mistake that produced a "reproduction" no hardware could match.
    struct IntegerLayout {
        let bitsPerChannel: UInt32
        /// Bytes per sample per channel. Defaults to `bitsPerChannel / 8`.
        let bytesPerSample: UInt32
        let isAlignedHigh: Bool
        let isInterleaved: Bool

        init(bitsPerChannel: UInt32, bytesPerSample: UInt32? = nil,
             isAlignedHigh: Bool = false, isInterleaved: Bool = true) {
            self.bitsPerChannel = bitsPerChannel
            self.bytesPerSample = bytesPerSample ?? (bitsPerChannel / 8)
            self.isAlignedHigh = isAlignedHigh
            self.isInterleaved = isInterleaved
        }

        /// 16-bit packed — the common case for consumer devices.
        static let int16 = IntegerLayout(bitsPerChannel: 16)
        /// 32-bit packed.
        static let int32 = IntegerLayout(bitsPerChannel: 32)
        /// 24-bit packed into exactly three bytes.
        static let int24Packed = IntegerLayout(bitsPerChannel: 24, bytesPerSample: 3)
        /// 24-bit in a 4-byte word, significant bits at the top — **what a
        /// Scarlett 2i2 4th Gen actually sends**, and what broke BL-150.
        static let int24AlignedHigh = IntegerLayout(bitsPerChannel: 24, bytesPerSample: 4, isAlignedHigh: true)

        var formatFlags: AudioFormatFlags {
            var f = kAudioFormatFlagIsSignedInteger
            // Packed and aligned-high are mutually exclusive claims about where
            // the significant bits sit inside the container.
            f |= isAlignedHigh ? kAudioFormatFlagIsAlignedHigh : kAudioFormatFlagIsPacked
            if !isInterleaved { f |= kAudioFormatFlagIsNonInterleaved }
            return f
        }
    }

    /// An integer-PCM `CMSampleBuffer`, each sample set by `fill` in the ±1.0
    /// range and quantised to the layout's depth.
    ///
    /// Values are written exactly as the layout describes them, so a converter
    /// that misreads the container produces obviously wrong numbers rather than
    /// plausible ones.
    static func integer(
        frames: Int,
        channels: UInt32 = 2,
        sampleRate: Double = 48_000,
        layout: IntegerLayout = .int16,
        fill: (_ channel: Int, _ frame: Int) -> Float = { ch, f in
            // Non-constant and channel-dependent, so a channel swap or a
            // collapsed conversion cannot accidentally satisfy an assertion.
            sin(Float(f) * 0.05 + Float(ch)) * 0.5
        }
    ) -> CMSampleBuffer {
        let ch = Int(channels)
        let bytesPerSample = Int(layout.bytesPerSample)
        // For non-interleaved, `mBytesPerFrame` describes ONE channel's stride.
        let bytesPerFrame = layout.isInterleaved ? UInt32(bytesPerSample * ch) : layout.bytesPerSample

        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: layout.formatFlags,
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: channels,
            mBitsPerChannel: layout.bitsPerChannel,
            mReserved: 0
        )

        // Full scale for the *significant* bits, then shifted up if the layout
        // parks them at the top of a wider word.
        let maxMagnitude = Double(Int64(1) << (Int(layout.bitsPerChannel) - 1))
        let shift = layout.isAlignedHigh
            ? (bytesPerSample * 8) - Int(layout.bitsPerChannel)
            : 0

        var bytes = [UInt8](repeating: 0, count: frames * ch * bytesPerSample)
        for frame in 0..<frames {
            for channel in 0..<ch {
                let clamped = max(-1.0, min(1.0, Double(fill(channel, frame))))
                let value = Int64(clamped * (maxMagnitude - 1)) << shift
                // Interleaved packs channels within a frame; non-interleaved
                // lays each channel's frames end to end.
                let sampleIndex = layout.isInterleaved
                    ? frame * ch + channel
                    : channel * frames + frame
                let offset = sampleIndex * bytesPerSample
                for byte in 0..<bytesPerSample {
                    bytes[offset + byte] = UInt8(truncatingIfNeeded: value >> (8 * byte))
                }
            }
        }

        return makeRawSampleBuffer(asbd: &asbd, bytes: bytes, frames: frames,
                                   channels: channels, isInterleaved: layout.isInterleaved)
    }

    /// Wrap raw bytes and a hand-built ASBD into a `CMSampleBuffer`.
    ///
    /// Non-interleaved needs a real `AudioBufferList` with one buffer per
    /// channel: a single contiguous block would be read as interleaved, and the
    /// channels would come back shuffled rather than obviously broken.
    private static func makeRawSampleBuffer(
        asbd: inout AudioStreamBasicDescription,
        bytes: [UInt8],
        frames: Int,
        channels: UInt32,
        isInterleaved: Bool
    ) -> CMSampleBuffer {
        var formatDescription: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault, asbd: &asbd,
            layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil,
            extensions: nil, formatDescriptionOut: &formatDescription
        )

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(asbd.mSampleRate)),
            presentationTimeStamp: .zero,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreate(
            allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
            makeDataReadyCallback: nil, refcon: nil,
            formatDescription: formatDescription,
            sampleCount: frames, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 0, sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        let bufferCount = isInterleaved ? 1 : Int(channels)
        let perBuffer = bytes.count / bufferCount
        let ablSize = MemoryLayout<AudioBufferList>.size
            + (bufferCount - 1) * MemoryLayout<AudioBuffer>.size
        let ablRaw = UnsafeMutableRawPointer.allocate(
            byteCount: ablSize, alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { ablRaw.deallocate() }
        let abl = UnsafeMutableAudioBufferListPointer(
            ablRaw.assumingMemoryBound(to: AudioBufferList.self)
        )
        abl.count = bufferCount

        // `SetDataBufferFromAudioBufferList` copies into CoreMedia-owned
        // storage, so this scratch block need not outlive the call — unlike the
        // Float32 path above, which hands over an AVAudioPCMBuffer's memory and
        // has to pin its lifetime with an attachment.
        let raw = UnsafeMutableRawPointer.allocate(byteCount: bytes.count, alignment: 1)
        defer { raw.deallocate() }
        bytes.withUnsafeBytes { raw.copyMemory(from: $0.baseAddress!, byteCount: bytes.count) }

        for i in 0..<bufferCount {
            abl[i] = AudioBuffer(
                mNumberChannels: isInterleaved ? channels : 1,
                mDataByteSize: UInt32(perBuffer),
                mData: raw.advanced(by: i * perBuffer)
            )
        }

        CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer!,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            bufferList: abl.unsafePointer
        )
        return sampleBuffer!
    }
}

//
//  MicrophoneFormatTests.swift
//  HomeRecTests
//
//  BL-150: `AudioSampleConverter.makePCMBuffer` silently drops every buffer a
//  microphone delivers in an integer PCM format.
//
//  Found by manual acceptance on 2026-08-02, not by this suite — and the reason
//  the suite missed it is worth stating. `SampleBufferFixtures` only synthesises
//  **Float32** buffers, so every existing test feeds `makePCMBuffer` exactly the
//  format it already assumes. The fixtures encode the same assumption as the
//  code they exercise, which makes them incapable of failing on it.
//
//  What the device actually sent (Focusrite Scarlett 2i2 4th Gen, logged from a
//  real capture):
//
//      4ch 48000.0Hz fmt=1819304813 flags=12
//
//  `1819304813` is `'lpcm'`; `flags=12` is
//  `kAudioFormatFlagIsPacked | kAudioFormatFlagIsSignedInteger`, with no
//  non-interleaved bit — so: **4-channel, interleaved, signed integer**.
//  (Four channels is correct for that interface: two analog inputs plus two
//  loopback channels. It is not a fault.)
//
//  `makePCMBuffer` returned nil for it, the caller's `guard … else { return }`
//  discarded the buffer without logging, and the recording finished as a
//  header-only file with "No audio was captured for this recording".
//
//  ⚠️ This is exactly what the `audio-pipeline` skill warns about: the SCK
//  config's `sampleRate`/`channelCount` govern the `.audio` output ONLY, while a
//  `.microphone` buffer arrives in the device's native format. System-audio
//  capture works because SCK pins it to Float32; microphone capture works only
//  by luck, on devices that happen to deliver Float32.
//

import Testing
import AVFoundation
import CoreMedia
@testable import HomeRec

@Suite("Microphone buffer formats")
struct MicrophoneFormatTests {

    /// Build an interleaved **integer** PCM `CMSampleBuffer`, which is what a
    /// real interface delivers and what no existing fixture can produce.
    private func makeIntegerSampleBuffer(
        channels: UInt32,
        frames: Int,
        sampleRate: Double = 48_000,
        bitsPerChannel: UInt32 = 16,
        bytesPerSample: UInt32? = nil,
        formatFlags: AudioFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
    ) throws -> CMSampleBuffer {
        // Container size is independent of bit depth — 24-bit audio commonly
        // travels in 4 bytes. Defaulting to bitsPerChannel/8 only covers the
        // packed case.
        let sampleBytes = bytesPerSample ?? (bitsPerChannel / 8)
        let bytesPerFrame = channels * sampleBytes
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            // Precisely the flags observed from the device: packed, signed
            // integer, interleaved (no kAudioFormatFlagIsNonInterleaved).
            mFormatFlags: formatFlags,
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: channels,
            mBitsPerChannel: bitsPerChannel,
            mReserved: 0
        )

        var formatDescription: CMAudioFormatDescription?
        try #require(CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault, asbd: &asbd,
            layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil,
            extensions: nil, formatDescriptionOut: &formatDescription
        ) == noErr)
        let format = try #require(formatDescription)

        // Non-zero, non-constant sample data, so a silent all-zero result is
        // distinguishable from a correctly converted one.
        let byteCount = frames * Int(bytesPerFrame)
        var bytes = [UInt8](repeating: 0, count: byteCount)
        for i in stride(from: 0, to: byteCount, by: 2) {
            let v = Int16(truncatingIfNeeded: (i * 37) % 20_000 - 10_000)
            bytes[i] = UInt8(truncatingIfNeeded: v)
            bytes[i + 1] = UInt8(truncatingIfNeeded: v >> 8)
        }

        var blockBuffer: CMBlockBuffer?
        try #require(CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: byteCount,
            blockAllocator: kCFAllocatorDefault, customBlockSource: nil,
            offsetToData: 0, dataLength: byteCount, flags: 0, blockBufferOut: &blockBuffer
        ) == noErr)
        let block = try #require(blockBuffer)
        try #require(bytes.withUnsafeBytes {
            CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block,
                                          offsetIntoDestination: 0, dataLength: byteCount)
        } == noErr)

        var sampleBuffer: CMSampleBuffer?
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(sampleRate)),
            presentationTimeStamp: .zero,
            decodeTimeStamp: .invalid
        )
        var sizes = Int(bytesPerFrame)
        try #require(CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault, dataBuffer: block, formatDescription: format,
            sampleCount: frames, sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 1, sampleSizeArray: &sizes, sampleBufferOut: &sampleBuffer
        ) == noErr)
        return try #require(sampleBuffer)
    }

    /// The shape the Scarlett 2i2 4th Gen actually delivers.
    @Test("A 4-channel interleaved Int16 microphone buffer survives conversion")
    func integerMicrophoneBufferConverts() throws {
        let sample = try makeIntegerSampleBuffer(channels: 4, frames: 512)
        let pcm = try #require(
            AudioSampleConverter.makePCMBuffer(from: sample),
            "makePCMBuffer returned nil for 4ch interleaved Int16 — the exact buffer a Scarlett 2i2 sends. Every such buffer is dropped by the caller's guard, and the take is written as a header with no audio."
        )
        #expect(pcm.frameLength == 512)
        #expect(pcm.format.channelCount == 4)

        // Converting must not silently yield digital black. An all-zero result
        // would pass a nil-check while still losing the recording.
        let data = try #require(pcm.floatChannelData)
        let peak = (0..<Int(pcm.format.channelCount)).flatMap { ch in
            (0..<Int(pcm.frameLength)).map { abs(data[ch][$0]) }
        }.max() ?? 0
        #expect(peak > 0.0001, "converted buffer is silent — samples were not carried across")
    }

    /// The exact format logged from the hardware: `4ch 48000.0Hz 24-bit
    /// flags=20` — signed integer, aligned high, in a 4-byte container. This is
    /// the buffer that produced a header-only file; the 16-bit test above did
    /// not reproduce it, because bit depth was inferred rather than logged.
    @Test("A 4-channel 24-bit aligned-high buffer — the Scarlett's real format")
    func realScarlettFormatConverts() throws {
        let sample = try makeIntegerSampleBuffer(
            channels: 4, frames: 512, bitsPerChannel: 24, bytesPerSample: 4,
            formatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsAlignedHigh
        )
        let pcm = try #require(
            AudioSampleConverter.makePCMBuffer(from: sample),
            "makePCMBuffer returned nil for 4ch 24-bit aligned-high — the format a Scarlett 2i2 4th Gen actually sends."
        )
        #expect(pcm.frameLength == 512)
        #expect(pcm.format.channelCount == 4)
        let data = try #require(pcm.floatChannelData)
        let peak = (0..<4).flatMap { ch in (0..<512).map { abs(data[ch][$0]) } }.max() ?? 0
        #expect(peak > 0.0001, "converted buffer is silent")
        #expect(peak <= 1.0, "samples exceed full scale — wrong divisor for the container")
    }

    /// Stereo integer input is the common case for most interfaces, so it is
    /// asserted separately: a fix that only handled four channels would leave
    /// every 2-channel integer device broken in the same way.
    @Test("A 2-channel interleaved Int16 microphone buffer survives conversion")
    func stereoIntegerBufferConverts() throws {
        let sample = try makeIntegerSampleBuffer(channels: 2, frames: 256)
        let pcm = try #require(AudioSampleConverter.makePCMBuffer(from: sample))
        #expect(pcm.frameLength == 256)
        #expect(pcm.format.channelCount == 2)
    }

    /// Regression guard for the path that already works, so a fix for the
    /// integer case cannot break system-audio capture.
    @Test("Float32 buffers still convert, unchanged")
    func floatBufferStillConverts() throws {
        let sample = SampleBufferFixtures.interleaved(frames: 256) { ch, f in
            Float(f % 32) / 64.0 + Float(ch) * 0.25
        }
        let pcm = try #require(AudioSampleConverter.makePCMBuffer(from: sample))
        #expect(pcm.frameLength == 256)
    }
}

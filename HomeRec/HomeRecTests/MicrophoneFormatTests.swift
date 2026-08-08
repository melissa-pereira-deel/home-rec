//
//  MicrophoneFormatTests.swift
//  HomeRecTests
//
//  BL-150: `AudioSampleConverter.makePCMBuffer` dropped every buffer a
//  microphone delivered in an integer PCM format, and the caller discarded it
//  without logging — so a recording finished as a header with no audio and the
//  only symptom was "No audio was captured for this recording".
//
//  Found by manual acceptance, not by this suite, and the reason is worth
//  keeping: `SampleBufferFixtures` could only build **Float32** buffers, so
//  every test fed the converter exactly the format it already assumed. The
//  fixtures encoded the same belief as the code, which made them incapable of
//  failing on it. 282 tests green, feature broken.
//
//  Measured from the hardware (Focusrite Scarlett 2i2 4th Gen):
//
//      4ch 48000Hz 24-bit int alignedHigh container=4B flags=20
//
//  ⚠️ The general hazard, from the `audio-pipeline` skill: the SCK config's
//  `sampleRate`/`channelCount` govern the `.audio` output ONLY. A `.microphone`
//  buffer arrives in the device's native format. System-audio capture works
//  because SCK pins it to Float32; microphone capture worked only on devices
//  that happened to send Float32 — and this interface offers no Float32 format
//  at any sample rate.
//

import Testing
import AVFoundation
import CoreMedia
@testable import HomeRec

@Suite("Microphone buffer formats")
struct MicrophoneFormatTests {

    /// Peak absolute sample across every channel — a converted buffer must be
    /// neither silent nor beyond full scale.
    private func peak(_ pcm: AVAudioPCMBuffer) throws -> Float {
        let data = try #require(pcm.floatChannelData)
        return (0..<Int(pcm.format.channelCount)).flatMap { ch in
            (0..<Int(pcm.frameLength)).map { abs(data[ch][$0]) }
        }.max() ?? 0
    }

    /// The exact shape the hardware sends. This is the regression that matters:
    /// four channels (two analog inputs plus two loopback — correct for the
    /// device, not a fault) of 24-bit aligned-high audio in a 4-byte container.
    @Test("The Scarlett's real format: 4ch 24-bit aligned-high")
    func realHardwareFormatConverts() throws {
        let sample = SampleBufferFixtures.integer(
            frames: 512, channels: 4, layout: .int24AlignedHigh
        )
        let pcm = try #require(
            AudioSampleConverter.makePCMBuffer(from: sample),
            "returned nil for the format a Scarlett 2i2 4th Gen actually sends — every buffer is dropped and the take is written as a header with no audio"
        )
        #expect(pcm.frameLength == 512)
        #expect(pcm.format.channelCount == 4)

        let p = try peak(pcm)
        #expect(p > 0.01, "converted buffer is silent — samples were not carried across")
        #expect(p <= 1.0, "samples exceed full scale — wrong divisor for the container")
    }

    /// Every integer layout a device might plausibly present. Parameterised so a
    /// fix that handles only the one interface on the developer's desk fails
    /// here rather than in someone else's studio.
    @Test(
        "Integer layouts all convert",
        arguments: [
            SampleBufferFixtures.IntegerLayout.int16,
            SampleBufferFixtures.IntegerLayout.int32,
            SampleBufferFixtures.IntegerLayout.int24Packed,
            SampleBufferFixtures.IntegerLayout.int24AlignedHigh
        ]
    )
    func integerLayoutsConvert(layout: SampleBufferFixtures.IntegerLayout) throws {
        let sample = SampleBufferFixtures.integer(frames: 256, channels: 2, layout: layout)
        let pcm = try #require(
            AudioSampleConverter.makePCMBuffer(from: sample),
            "returned nil for \(layout.bitsPerChannel)-bit in a \(layout.bytesPerSample)-byte container (alignedHigh=\(layout.isAlignedHigh))"
        )
        #expect(pcm.frameLength == 256)
        #expect(pcm.format.channelCount == 2)

        let p = try peak(pcm)
        #expect(p > 0.01, "\(layout.bitsPerChannel)-bit converted to silence")
        #expect(p <= 1.0, "\(layout.bitsPerChannel)-bit exceeded full scale")
    }

    /// Non-interleaved integer input, which arrives as one `AudioBuffer` per
    /// channel rather than one interleaved block. Separate code in the
    /// converter, so a fix to one path does not imply the other.
    ///
    /// ⚠️ This asserts the actual sample **values**, not merely that the result
    /// is non-silent. Mutation-tested: with a "peak > 0.01" assertion it
    /// **passed against the unfixed converter**, because reading Int16 bytes as
    /// `Float` yields garbage that is still loud. A test that cannot fail on
    /// wrong data is not a test — the project has shipped several of those.
    @Test("Non-interleaved integer input converts to the right values")
    func nonInterleavedIntegerConverts() throws {
        let layout = SampleBufferFixtures.IntegerLayout(bitsPerChannel: 16, isInterleaved: false)
        // A known ramp, distinct per channel, so a swap or a misread is visible.
        let expected: (Int, Int) -> Float = { ch, f in
            Float(f % 8) / 16.0 + Float(ch) * 0.25
        }
        let sample = SampleBufferFixtures.integer(
            frames: 256, channels: 2, layout: layout, fill: expected
        )
        let pcm = try #require(AudioSampleConverter.makePCMBuffer(from: sample))
        #expect(pcm.frameLength == 256)

        let data = try #require(pcm.floatChannelData)
        // 16-bit quantisation is ~3e-5; allow an order of magnitude over it.
        let tolerance: Float = 0.001
        var worst: Float = 0
        for ch in 0..<2 {
            for frame in 0..<256 {
                worst = max(worst, abs(data[ch][frame] - expected(ch, frame)))
            }
        }
        #expect(worst < tolerance, "samples differ from what was written by up to \(worst) — the container was misread")
    }

    /// `AVAudioFormat(commonFormat:sampleRate:channels:interleaved:)` returns
    /// **nil above 2 channels** — measured: 1 and 2 succeed, 3/4/6/8 do not. It
    /// has no layout to infer beyond mono and stereo and will not guess. That
    /// was the second of the three stacked defects: fixing integer decoding
    /// alone still failed here, because the format could not be constructed.
    @Test("Channel counts above stereo construct a format", arguments: [1, 2, 4, 6, 8] as [UInt32])
    func multichannelFormatsConvert(channels: UInt32) throws {
        let sample = SampleBufferFixtures.integer(frames: 128, channels: channels, layout: .int16)
        let pcm = try #require(
            AudioSampleConverter.makePCMBuffer(from: sample),
            "returned nil for \(channels) channels — AVAudioFormat needs an explicit layout above stereo"
        )
        #expect(pcm.format.channelCount == channels)
        #expect(pcm.frameLength == 128)
    }

    /// Regression guard for the path that already worked, so a fix aimed at
    /// integer formats cannot quietly break system-audio capture.
    @Test("Float32 buffers still convert, unchanged")
    func floatBufferStillConverts() throws {
        let sample = SampleBufferFixtures.interleaved(frames: 256) { ch, f in
            Float(f % 32) / 64.0 + Float(ch) * 0.25
        }
        let pcm = try #require(AudioSampleConverter.makePCMBuffer(from: sample))
        #expect(pcm.frameLength == 256)
    }

    // MARK: - Through the normalizer (BL-150, second half)
    //
    // ⚠️ Everything above stops at `makePCMBuffer`, and that is exactly where
    // the first fix stopped being enough. Conversion succeeded — 4 channels,
    // peak 0.5 — and then `AudioFormatNormalizer` turned it into silence,
    // because `AVAudioConverter` defaults `channelMap` to `[-1, -1]` for a
    // discrete layout and reports success while emitting zeros. A test that
    // ends one stage early cannot see that. These do not.

    /// The end-to-end assertion the earlier round was missing: audio in, audio
    /// out. Fails on the pre-`channelMap` normalizer.
    @Test("A 4-channel buffer survives normalization without becoming silence")
    func multichannelSurvivesNormalization() throws {
        let sample = SampleBufferFixtures.integer(
            frames: 512, channels: 4, layout: .int24AlignedHigh
        )
        let converted = try #require(AudioSampleConverter.makePCMBuffer(from: sample))
        #expect(try peak(converted) > 0.01, "precondition: conversion should already work")

        let normalized = try #require(
            AudioFormatNormalizer().normalize(converted),
            "normalize returned nil for a 4-channel buffer"
        )
        #expect(normalized.format.channelCount == 2)
        #expect(
            try peak(normalized) > 0.01,
            "normalized to digital silence — AVAudioConverter mapped no source channels, and reported success while doing it"
        )
    }

    /// Channel counts a multi-input interface or an aggregate device might
    /// present. A fix that handles only 4 would leave 6- and 8-channel devices
    /// silently broken in exactly the same way.
    @Test("Every channel count normalizes to audible stereo", arguments: [1, 2, 4, 6, 8] as [UInt32])
    func everyChannelCountNormalizes(channels: UInt32) throws {
        let sample = SampleBufferFixtures.integer(frames: 256, channels: channels, layout: .int16)
        let converted = try #require(AudioSampleConverter.makePCMBuffer(from: sample))
        let normalized = try #require(
            AudioFormatNormalizer().normalize(converted),
            "normalize returned nil for \(channels) channels"
        )
        #expect(normalized.format.channelCount == 2)
        #expect(try peak(normalized) > 0.01, "\(channels) channels normalized to silence")
    }

    /// The map must take channels 1 and 2 specifically — not sum, and not some
    /// other pair. On a Scarlett 2i2 channels 3–4 are Loopback, carrying what
    /// the Mac is playing, so a take that folded them in would put system audio
    /// into a microphone recording.
    @Test("Normalization takes the first two channels, not a sum of all of them")
    func normalizationTakesFirstTwoChannels() throws {
        // Channels 0 and 1 carry distinct DC levels; 2 and 3 carry a much larger
        // one, so summing or picking the wrong pair is unmistakable.
        let sample = SampleBufferFixtures.integer(frames: 256, channels: 4, layout: .int16) { ch, _ in
            switch ch {
            case 0: return 0.10
            case 1: return 0.20
            default: return 0.80   // stand-in for loopback content
            }
        }
        let converted = try #require(AudioSampleConverter.makePCMBuffer(from: sample))
        let normalized = try #require(AudioFormatNormalizer().normalize(converted))
        let data = try #require(normalized.floatChannelData)

        // Sampled away from the edges: a resampler's first frames ramp up.
        let left = data[0][128]
        let right = data[1][128]
        #expect(abs(left - 0.10) < 0.02, "left should be channel 1 (0.10), got \(left)")
        #expect(abs(right - 0.20) < 0.02, "right should be channel 2 (0.20), got \(right)")
        #expect(left < 0.5 && right < 0.5, "loopback content leaked into the take")
    }
}

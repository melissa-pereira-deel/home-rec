//
//  AudioFormatNormalizerTests.swift
//  HomeRecTests
//
//  BL-112: every captured buffer must reach an encoder in the canonical
//  48 kHz / stereo / Float32 / non-interleaved format the encoder was told to
//  expect. A microphone's buffers follow the *device's* native format, so this
//  is the only thing standing between a 44.1 kHz mono mic and a corrupt file.
//

import Testing
import AVFoundation
@testable import HomeRec

struct AudioFormatNormalizerTests {

    /// A continuous sine, so a discontinuity at a buffer seam is detectable.
    /// Phase is a function of absolute frame index, never of position within a
    /// buffer — otherwise every buffer restarts at zero and the test measures
    /// nothing.
    private func sineBuffer(
        startFrame: Int,
        frames: Int,
        sampleRate: Double,
        channels: Int
    ) -> AVAudioPCMBuffer {
        SampleBufferFixtures.makePCMBuffer(
            channels: channels,
            frames: frames,
            sampleRate: sampleRate,
            interleaved: false
        ) { _, frame in
            let t = Double(startFrame + frame) / sampleRate
            return Float(sin(2.0 * .pi * 440.0 * t))
        }
    }

    private func maxAdjacentStep(_ samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0 }
        var maximum: Float = 0
        for i in 1..<samples.count {
            maximum = max(maximum, abs(samples[i] - samples[i - 1]))
        }
        return maximum
    }

    private func leftChannel(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let data = buffer.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: data[0], count: Int(buffer.frameLength)))
    }

    // MARK: - Pass-through

    @Test("A canonical buffer is returned untouched, not round-tripped")
    func canonicalBufferPassesThrough() {
        let normalizer = AudioFormatNormalizer()
        let input = sineBuffer(startFrame: 0, frames: 1024, sampleRate: 48_000, channels: 2)

        let output = normalizer.normalize(input)

        // Identity, not equality: system-audio capture is already canonical, and
        // BL-051's golden-file regression asserts byte-identical output. Sending
        // it through a converter at all would risk changing those bytes.
        #expect(output === input)
    }

    // MARK: - Conversion

    @Test("A 44.1kHz mono buffer becomes a 48kHz stereo buffer")
    func monoAt44kBecomesCanonical() throws {
        let normalizer = AudioFormatNormalizer()
        let input = sineBuffer(startFrame: 0, frames: 1024, sampleRate: 44_100, channels: 1)

        let output = try #require(normalizer.normalize(input))

        #expect(output.format.sampleRate == 48_000)
        #expect(output.format.channelCount == 2)
        #expect(output.format.isInterleaved == false)
        #expect(output.frameLength > 0)
    }

    @Test("Mono input reaches both output channels")
    func monoIsDuplicatedNotLeftOnly() throws {
        let normalizer = AudioFormatNormalizer()
        let input = sineBuffer(startFrame: 0, frames: 2048, sampleRate: 44_100, channels: 1)

        let output = try #require(normalizer.normalize(input))
        let data = try #require(output.floatChannelData)
        let frames = Int(output.frameLength)

        var rightEnergy: Float = 0
        var maxChannelDelta: Float = 0
        for frame in 0..<frames {
            rightEnergy += abs(data[1][frame])
            maxChannelDelta = max(maxChannelDelta, abs(data[0][frame] - data[1][frame]))
        }
        // A silent right channel would mean the mic ends up hard-left in the file.
        #expect(rightEnergy > 0)
        #expect(maxChannelDelta == 0)
    }

    @Test("Output length is reported, not assumed")
    func outputFrameLengthVariesAndIsReadBack() throws {
        // A constant input length does not produce a constant output length, so
        // computing `frameLength` instead of reading it back would truncate or
        // over-report. Assert only that what comes back is self-consistent.
        let normalizer = AudioFormatNormalizer()
        for index in 0..<8 {
            let input = sineBuffer(
                startFrame: index * 1024, frames: 1024, sampleRate: 44_100, channels: 1
            )
            let output = try #require(normalizer.normalize(input))
            #expect(output.frameLength <= output.frameCapacity)
            #expect(output.frameLength > 0)
        }
    }

    // MARK: - The reason the converter is held across buffers

    @Test("Resampling stays continuous across buffer seams")
    func consecutiveBuffersHaveNoSeamDiscontinuity() throws {
        // This is the test that justifies holding one stateful AVAudioConverter.
        // Rebuilding it (or calling reset()) per buffer loses the resampler's
        // history, which produces a full-scale jump at every seam — an audible
        // click ~47x/second. A 440 Hz sine at 48 kHz steps at most ~0.058 between
        // adjacent samples; anything near 1.0 is a discontinuity, not signal.
        let normalizer = AudioFormatNormalizer()
        var stitched: [Float] = []

        for index in 0..<12 {
            let input = sineBuffer(
                startFrame: index * 1024, frames: 1024, sampleRate: 44_100, channels: 1
            )
            let output = try #require(normalizer.normalize(input))
            stitched.append(contentsOf: leftChannel(output))
        }

        #expect(stitched.count > 10_000)
        // Generous bound: the natural step is ~0.058, a seam click measures ~0.99.
        #expect(maxAdjacentStep(stitched) < 0.2)
    }

    @Test("A fresh normalizer per buffer is what continuity protects against")
    func rebuildingPerBufferProducesSeamClicks() throws {
        // The control for the test above. If this ever stops failing to be
        // discontinuous, the continuity assertion has become vacuous and would
        // pass even with the statefulness removed.
        var stitched: [Float] = []
        for index in 0..<12 {
            let perBuffer = AudioFormatNormalizer()
            let input = sineBuffer(
                startFrame: index * 1024, frames: 1024, sampleRate: 44_100, channels: 1
            )
            let output = try #require(perBuffer.normalize(input))
            stitched.append(contentsOf: leftChannel(output))
        }
        #expect(maxAdjacentStep(stitched) > 0.2)
    }

    @Test("A mid-stream format change is handled rather than dropped")
    func inputFormatChangeRebuildsTheConverter() throws {
        // Swapping input device mid-recording changes the buffer format. One
        // click is unavoidable; silently dropping every subsequent buffer is not.
        let normalizer = AudioFormatNormalizer()

        let first = try #require(
            normalizer.normalize(sineBuffer(startFrame: 0, frames: 512, sampleRate: 44_100, channels: 1))
        )
        #expect(first.frameLength > 0)

        let second = try #require(
            normalizer.normalize(sineBuffer(startFrame: 0, frames: 512, sampleRate: 16_000, channels: 1))
        )
        #expect(second.format.sampleRate == 48_000)
        #expect(second.format.channelCount == 2)
        #expect(second.frameLength > 0)
    }
}

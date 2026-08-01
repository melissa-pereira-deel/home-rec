//
//  M4AEncoderTests.swift
//  HomeRecTests
//
//  BL-012: drive M4AEncoder (through the AudioFileEncoder protocol) with a
//  synthetic Float32 PCM stream and assert the produced .m4a is a valid,
//  decodable AAC file with the right channel count and a duration matching the
//  input. AAC is lossy, so we assert decodability + duration tolerance, never
//  bytes (the format-agnostic hook noted in AudioFileEncoderTests).
//

import Testing
import Foundation
import AVFoundation
@testable import HomeRec

/// `.serialized` for the same reason as `EncoderFormatGuardTests`: `finalize()`
/// blocks on a semaphore, and parallel blocking waits starve Swift's cooperative
/// thread pool on a low-core CI runner (BL-147).
@Suite(.serialized)
@MainActor
struct M4AEncoderTests {

    private let inputSampleRate: Double = 48_000
    private let channels = 2
    private let bufferCount = 48
    private let framesPerBuffer = 1_024   // 48 × 1024 = 49,152 frames ≈ 1.024 s

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("m4a-test-\(UUID().uuidString).m4a")
    }

    /// A non-interleaved Float32 buffer (what the real pipeline feeds), filled
    /// with a mild non-zero signal.
    private func buffer(_ index: Int) -> AVAudioPCMBuffer {
        SampleBufferFixtures.makePCMBuffer(
            channels: channels, frames: framesPerBuffer,
            sampleRate: inputSampleRate, interleaved: false
        ) { ch, frame in
            let n = index * self.framesPerBuffer + frame
            let v = Float(sin(Double(n) * 0.02)) * 0.4
            return ch == 0 ? v : -v
        }
    }

    private func encodeStream(to url: URL) throws {
        let encoder: any AudioFileEncoder = M4AEncoder()
        try encoder.createFile(at: url, sampleRate: inputSampleRate, channels: channels)
        for i in 0..<bufferCount {
            try encoder.writeBuffer(buffer(i))
        }
        try encoder.finalize()
    }

    @Test("Encodes a synthetic stream to a valid, decodable stereo .m4a")
    func producesValidM4A() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try encodeStream(to: url)

        // File exists and has real content.
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        #expect(size > 0)

        // Decodable as audio, stereo.
        let file = try AVAudioFile(forReading: url)
        #expect(file.fileFormat.channelCount == AVAudioChannelCount(channels))

        // Duration matches the input within tolerance (AAC adds encoder
        // priming/padding, so allow a small delta rather than exact equality).
        let expected = Double(bufferCount * framesPerBuffer) / inputSampleRate
        let actual = Double(file.length) / file.fileFormat.sampleRate
        #expect(abs(actual - expected) < 0.15)
    }

    @Test("Output is AAC at the configured 44.1kHz")
    func outputIsAAC44k() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try encodeStream(to: url)

        let file = try AVAudioFile(forReading: url)
        #expect(file.fileFormat.sampleRate == 44_100)
    }

    @Test("finalize before createFile throws")
    func finalizeBeforeCreateThrows() {
        let encoder: any AudioFileEncoder = M4AEncoder()
        #expect(throws: M4AEncoderError.notOpen) {
            try encoder.finalize()
        }
    }

    // MARK: - BL-016 crash durability

    /// The M4A analogue of `WAVWriterTests.periodicHeaderMakesFilePlayableWithoutFinalize`.
    /// Before BL-016 the `moov` atom was written only at `finishWriting`, so a
    /// crash or force-quit mid-recording lost the entire take. Fragmenting makes
    /// the file periodically valid on disk.
    ///
    /// Unlike the WAV test this cannot be fully synchronous: the fragment is
    /// flushed by AVFoundation's own encoding queue. So we poll for the file to
    /// become readable with a hard ceiling — it fails rather than hangs, and
    /// never sleeps for a fixed duration.
    @Test("A partial M4A is playable without finalize (crash safety)")
    func partialFileIsPlayableWithoutFinalize() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let encoder: any AudioFileEncoder = M4AEncoder()
        try encoder.createFile(at: url, sampleRate: inputSampleRate, channels: channels)

        // Write comfortably more than one fragment interval of audio.
        let seconds = M4AEncoder.fragmentIntervalSeconds * 3
        let needed = Int((inputSampleRate * seconds) / Double(framesPerBuffer))
        for i in 0..<needed {
            try encoder.writeBuffer(buffer(i))
        }

        // Deliberately DO NOT finalize — simulate a crash / force-quit, taking a
        // snapshot exactly as the file sits on disk right now.
        let partial = url.deletingLastPathComponent()
            .appendingPathComponent("partial-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: partial) }

        // Wall-clock deadline, not an iteration count: each pass also copies a
        // growing file and attempts an open, so a fixed loop count understates
        // the real ceiling on a loaded CI runner. Breaks on first success
        // (typically pass 1–2), so the headroom is free when the test passes.
        var recovered: AVAudioFramePosition = 0
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            try? FileManager.default.removeItem(at: partial)
            try? FileManager.default.copyItem(at: url, to: partial)
            if let f = try? AVAudioFile(forReading: partial), f.length > 0 {
                recovered = f.length
                break
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(recovered > 0, "a partial M4A must be readable without finalize")

        // Finalizing normally must still produce the complete file. Assert the
        // exact expected length rather than only "longer than the fragment" —
        // the latter becomes a coin flip if fragmentIntervalSeconds ever divides
        // the written duration evenly.
        try encoder.finalize()
        let full = try AVAudioFile(forReading: url)
        #expect(full.length >= recovered)
        let expectedSeconds = Double(needed * framesPerBuffer) / inputSampleRate
        let actualSeconds = Double(full.length) / full.fileFormat.sampleRate
        #expect(abs(actualSeconds - expectedSeconds) < 0.15)
    }
}

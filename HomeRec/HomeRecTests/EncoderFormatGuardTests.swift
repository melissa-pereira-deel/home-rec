//
//  EncoderFormatGuardTests.swift
//  HomeRecTests
//
//  BL-112: an encoder is told its input format once, in `createFile`, and then
//  stamps a header / configures a writer input from it. A later buffer that
//  disagrees is not a bad frame — it is silent corruption (WAV) or the loss of
//  the entire take at stop (M4A). Both must refuse instead.
//
//  FLAC already had this guard from BL-013 and is covered in `FLACEncoderTests`.
//

import Testing
import Foundation
import AVFoundation
@testable import HomeRec

struct EncoderFormatGuardTests {

    private func tempURL(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("guard-\(UUID().uuidString).\(ext)")
    }

    private func buffer(sampleRate: Double, channels: Int, frames: Int = 256) -> AVAudioPCMBuffer {
        SampleBufferFixtures.makePCMBuffer(
            channels: channels,
            frames: frames,
            sampleRate: sampleRate,
            interleaved: false
        ) { channel, frame in
            // Asymmetric across channels so a swap or a mono/stereo confusion
            // can't accidentally satisfy an assertion.
            Float(frame % 32) / 64.0 + Float(channel) * 0.25
        }
    }

    // MARK: - WAV

    @Test("WAV refuses a buffer whose sample rate contradicts its header")
    func wavRejectsWrongSampleRate() throws {
        let url = tempURL("wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = WAVWriter()
        try writer.createFile(at: url, sampleRate: 48_000, channels: 2)

        // Header says 48 kHz; this plays ~8.8% fast if written.
        #expect(throws: WAVWriterError.formatMismatch) {
            try writer.writeBuffer(self.buffer(sampleRate: 44_100, channels: 2))
        }
    }

    @Test("WAV refuses a mono buffer in a stereo-declared file")
    func wavRejectsWrongChannelCount() throws {
        let url = tempURL("wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = WAVWriter()
        try writer.createFile(at: url, sampleRate: 48_000, channels: 2)

        // The interleave loop uses the buffer's channel count while the header
        // declares two: written, this reads back as L/R pairs — half speed, an
        // octave down, with no error anywhere.
        #expect(throws: WAVWriterError.formatMismatch) {
            try writer.writeBuffer(self.buffer(sampleRate: 48_000, channels: 1))
        }
    }

    @Test("WAV still accepts a buffer that matches what it was told")
    func wavAcceptsMatchingFormat() throws {
        let url = tempURL("wav")
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = WAVWriter()
        try writer.createFile(at: url, sampleRate: 48_000, channels: 2)
        try writer.writeBuffer(buffer(sampleRate: 48_000, channels: 2))
        try writer.finalize()

        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
        // 44-byte header + 256 frames x 2ch x 2 bytes.
        #expect(size == 44 + 256 * 2 * 2)
    }

    // MARK: - M4A

    @Test("M4A refuses a buffer whose sample rate contradicts its timeline")
    func m4aRejectsWrongSampleRate() throws {
        let url = tempURL("m4a")
        defer { try? FileManager.default.removeItem(at: url) }

        let encoder = M4AEncoder()
        try encoder.createFile(at: url, sampleRate: 48_000, channels: 2)
        defer { try? encoder.finalize() }

        #expect(throws: M4AEncoderError.formatMismatch) {
            try encoder.writeBuffer(self.buffer(sampleRate: 44_100, channels: 2))
        }
    }

    @Test("M4A refuses a mono buffer rather than losing the take at stop")
    func m4aRejectsWrongChannelCount() throws {
        let url = tempURL("m4a")
        defer { try? FileManager.default.removeItem(at: url) }

        let encoder = M4AEncoder()
        try encoder.createFile(at: url, sampleRate: 48_000, channels: 2)
        defer { try? encoder.finalize() }

        // Without the guard the append is refused, the refusal was discarded,
        // and `finalize()` threw `.writeFailed` — the whole recording gone, with
        // nothing indicating when it broke.
        #expect(throws: M4AEncoderError.formatMismatch) {
            try encoder.writeBuffer(self.buffer(sampleRate: 48_000, channels: 1))
        }
    }

    @Test("M4A still encodes a matching buffer to a playable file")
    func m4aAcceptsMatchingFormat() async throws {
        let url = tempURL("m4a")
        defer { try? FileManager.default.removeItem(at: url) }

        let encoder = M4AEncoder()
        try encoder.createFile(at: url, sampleRate: 48_000, channels: 2)
        for index in 0..<16 {
            try encoder.writeBuffer(buffer(sampleRate: 48_000, channels: 2, frames: 1024 + index))
        }
        try encoder.finalize()

        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        #expect(tracks.isEmpty == false)
    }
}

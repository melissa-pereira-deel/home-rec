//
//  AudioRecorderTests.swift
//  HomeRecTests
//
//  BL-024: the recording path confines writer state to a single serial queue.
//  These tests assert no trailing buffers are dropped on stop and exercise
//  rapid start/stop cycles (run under Thread Sanitizer to catch data races).
//

import Testing
import Foundation
import AVFoundation
@testable import HomeRec

@MainActor
struct AudioRecorderTests {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("audiorecorder-test-\(UUID().uuidString).wav")
    }

    /// Build a silent, canonical non-interleaved Float32 PCM buffer with the given
    /// frame count — the same shape every `AudioCapturing` source delivers (BL-099).
    private func makePCMBuffer(frames: Int, sampleRate: Double = 48000, channels: Int = 2) -> AVAudioPCMBuffer {
        SampleBufferFixtures.makePCMBuffer(
            channels: channels, frames: frames, sampleRate: sampleRate, interleaved: false
        ) { _, _ in 0 }
    }

    /// Read the WAV `data` chunk size (UInt32 LE at offset 40).
    private func wavDataSize(at url: URL) throws -> Int {
        let b = [UInt8](try Data(contentsOf: url))
        return Int(UInt32(b[40]) | (UInt32(b[41]) << 8) | (UInt32(b[42]) << 16) | (UInt32(b[43]) << 24))
    }

    @Test("All submitted buffers are written — no trailing drops on stop")
    func noBufferDropsOnStop() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let recorder = AudioRecorder()
        try recorder.startRecording(to: url, format: .wav)

        let bufferCount = 50
        let framesPerBuffer = 64
        for _ in 0..<bufferCount {
            recorder.processAudioSample(makePCMBuffer(frames: framesPerBuffer))
        }
        try await recorder.stopRecording()   // drains all in-flight buffers, then finalizes

        // 48kHz stereo Int16: frames * channels(2) * 2 bytes
        let expected = bufferCount * framesPerBuffer * 2 * 2
        #expect(try wavDataSize(at: url) == expected)
    }

    @Test("20 rapid start/stop cycles produce no corrupt-header files (TSan target)")
    func rapidStartStopCycles() async throws {
        let buffersPerCycle = 5
        let framesPerBuffer = 32
        for _ in 0..<20 {
            let url = tempURL()
            defer { try? FileManager.default.removeItem(at: url) }

            let recorder = AudioRecorder()
            try recorder.startRecording(to: url, format: .wav)
            for _ in 0..<buffersPerCycle {
                recorder.processAudioSample(makePCMBuffer(frames: framesPerBuffer))
            }
            try await recorder.stopRecording()

            // Header must be valid and match the audio written (no corruption).
            let expected = buffersPerCycle * framesPerBuffer * 2 * 2
            #expect(try wavDataSize(at: url) == expected)
        }
    }

    @Test("stopRecording without an active recording throws")
    func stopWithoutStartThrows() async {
        let recorder = AudioRecorder()
        await #expect(throws: AudioRecorderError.self) {
            try await recorder.stopRecording()
        }
    }

    // MARK: - BL-016 finalize-error propagation

    /// An encoder whose `finalize()` always fails, so the stop path's error
    /// handling can be driven without a real codec failure.
    private final class FailingFinalizeEncoder: AudioFileEncoder {
        struct Boom: Error, Equatable {}
        private(set) var finalizeCount = 0
        func createFile(at url: URL, sampleRate: Double, channels: Int) throws {
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }
        func writeBuffer(_ buffer: AVAudioPCMBuffer) throws {}
        func finalize() throws {
            finalizeCount += 1
            throw Boom()
        }
    }

    @Test("A finalize failure propagates instead of being silently swallowed")
    func finalizeErrorPropagates() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let recorder = AudioRecorder(encoderFactory: { _ in FailingFinalizeEncoder() })
        try recorder.startRecording(to: url, format: .wav)

        await #expect(throws: FailingFinalizeEncoder.Boom.self) {
            try await recorder.stopRecording()
        }
    }

    /// The regression this guards: releasing the encoder inside a `defer` so a
    /// failed finalize can't strand the recorder in a permanently-recording state
    /// that refuses every subsequent start.
    @Test("A failed finalize still releases the encoder")
    func failedFinalizeStillClearsState() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let recorder = AudioRecorder(encoderFactory: { _ in FailingFinalizeEncoder() })
        try recorder.startRecording(to: url, format: .wav)
        #expect(recorder.recording)

        await #expect(throws: FailingFinalizeEncoder.Boom.self) {
            try await recorder.stopRecording()
        }

        #expect(!recorder.recording)
        // A second stop reports "not recording", not another finalize attempt.
        await #expect(throws: AudioRecorderError.self) {
            try await recorder.stopRecording()
        }
        // And a fresh recording can still be started.
        let next = tempURL()
        defer { try? FileManager.default.removeItem(at: next) }
        try recorder.startRecording(to: next, format: .wav)
        #expect(recorder.recording)
    }
}

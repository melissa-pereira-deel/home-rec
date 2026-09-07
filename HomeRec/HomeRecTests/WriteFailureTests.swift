//
//  WriteFailureTests.swift
//  HomeRecTests
//
//  BL-173: a write failure must not look like a successful recording.
//
//  The defect these cover: `AudioRecorder.processPCMBuffer` published the
//  waveform *before* attempting the write, and discarded the write's error with
//  `try?`. So a take whose file had stopped growing still showed a moving
//  waveform and a running timer — the only evidence of success the user got was
//  produced by code that never touched the file.
//
//  BL-112 taught the encoders to throw; it never taught the caller to listen.
//  These tests are the listening half.
//

import Testing
import Foundation
import AVFoundation
@testable import HomeRec

@MainActor
struct WriteFailureTests {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("writefailure-test-\(UUID().uuidString).wav")
    }

    private func makePCMBuffer(frames: Int = 64) -> AVAudioPCMBuffer {
        SampleBufferFixtures.makePCMBuffer(
            channels: 2, frames: frames, sampleRate: 48000, interleaved: false
        ) { _, _ in 0 }
    }

    /// An encoder that accepts `throwAfter` buffers and then fails every write —
    /// the shape of a disk filling up or a destination disappearing mid-take.
    /// Counts accepted writes so a test can assert the partial take's real size.
    private final class FailingWriteEncoder: AudioFileEncoder {
        struct Boom: Error, Equatable {}
        private let throwAfter: Int
        private(set) var acceptedWrites = 0
        private(set) var attemptedWrites = 0
        private(set) var finalizeCount = 0

        init(throwAfter: Int) { self.throwAfter = throwAfter }

        func createFile(at url: URL, sampleRate: Double, channels: Int) throws {
            FileManager.default.createFile(atPath: url.path, contents: Data())
        }

        func writeBuffer(_ buffer: AVAudioPCMBuffer) throws {
            attemptedWrites += 1
            if attemptedWrites > throwAfter { throw Boom() }
            acceptedWrites += 1
        }

        func finalize() throws { finalizeCount += 1 }
    }

    // MARK: - The user-visible bug

    @Test("The waveform stops when writing stops")
    func waveformStopsOnWriteFailure() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let encoder = FailingWriteEncoder(throwAfter: 3)
        let recorder = AudioRecorder(encoderFactory: { _ in encoder })

        // Count on the main queue, where `onWaveformData` is delivered.
        final class Counter: @unchecked Sendable { var value = 0 }
        let waveformCount = Counter()
        recorder.onWaveformData = { _ in waveformCount.value += 1 }

        try recorder.startRecording(to: url, format: .wav)
        for _ in 0..<10 { recorder.processAudioSample(makePCMBuffer()) }
        try? recorder.stopRecording()

        // Let the queued main-thread waveform deliveries land.
        await waitUntil("waveform deliveries to settle") { waveformCount.value >= 3 }

        #expect(encoder.acceptedWrites == 3)
        #expect(encoder.attemptedWrites >= 4, "the encoder must actually have been asked to write past the failure point")

        // The whole point: once the file stopped growing, the UI must stop
        // claiming otherwise. Before BL-173 this was 10.
        #expect(
            waveformCount.value <= 3,
            "waveform was published \(waveformCount.value) times but only 3 buffers reached the file"
        )
    }

    @Test("A failing encoder reports the failure exactly once, not once per buffer")
    func writeFailureIsReportedOnce() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let encoder = FailingWriteEncoder(throwAfter: 1)
        let recorder = AudioRecorder(encoderFactory: { _ in encoder })

        final class Counter: @unchecked Sendable { var value = 0 }
        let errorCount = Counter()
        recorder.onWriteError = { _ in errorCount.value += 1 }

        try recorder.startRecording(to: url, format: .wav)
        // Buffers arrive ~47×/sec in production; an unlatched error would fire
        // an alert for every one of them.
        for _ in 0..<40 { recorder.processAudioSample(makePCMBuffer()) }
        try? recorder.stopRecording()

        await waitUntil("the write error to surface") { errorCount.value > 0 }
        #expect(errorCount.value == 1, "expected one error, got \(errorCount.value)")
    }

    @Test("The buffers accepted before the failure are still on disk")
    func partialTakeIsPreserved() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        // A real WAV writer, so the assertion is about bytes on disk rather than
        // a counter in a fake.
        let recorder = AudioRecorder()
        try recorder.startRecording(to: url, format: .wav)
        for _ in 0..<5 { recorder.processAudioSample(makePCMBuffer(frames: 64)) }
        try recorder.stopRecording()

        let bytes = [UInt8](try Data(contentsOf: url))
        let dataSize = Int(UInt32(bytes[40]) | (UInt32(bytes[41]) << 8)
                           | (UInt32(bytes[42]) << 16) | (UInt32(bytes[43]) << 24))
        // 5 buffers × 64 frames × 2 channels × 2 bytes (Int16)
        #expect(dataSize == 5 * 64 * 2 * 2)

        let file = try AVAudioFile(forReading: url)
        #expect(file.length == 5 * 64)
    }

    // MARK: - End to end, through the view model

    @Test("A write failure transitions the VM to .error and finalizes once")
    func writeFailureReachesTheViewModel() async {
        let mockCapturer = MockAudioCapturing()
        let mockWriter = MockAudioFileWriting()
        // `audioSource` injected for the same reason as StreamFailureTests: the
        // test host is the app, so a real source manager would read the
        // developer's own preferences.
        let controller = RecordingController(
            captureManager: mockCapturer,
            audioRecorder: mockWriter,
            audioSource: MockAudioSourceProviding()
        )
        let viewModel = RecorderViewModel(
            controller: controller,
            permissions: MockPermissionProviding(.granted),
            clock: ManualClock(),
            audioSource: MockAudioSourceProviding()
        )

        await viewModel.startRecording()
        #expect(viewModel.state == .recording)

        mockWriter.emitWriteError("No space left on device")

        // Published synchronously on the failure callback, like .streamFailed.
        #expect(viewModel.state == .error(.writeFailed("No space left on device")))
        #expect(viewModel.isRecording == false)

        await waitUntil("the partial recording to be finalized") { mockWriter.stopCount > 0 }
        #expect(mockWriter.stopCount == 1)
    }

    @Test("A write error while idle is ignored (no spurious error state)")
    func writeErrorWhileIdleIsIgnored() {
        let mockCapturer = MockAudioCapturing()
        let mockWriter = MockAudioFileWriting()
        let controller = RecordingController(
            captureManager: mockCapturer,
            audioRecorder: mockWriter,
            audioSource: MockAudioSourceProviding()
        )
        let viewModel = RecorderViewModel(
            controller: controller,
            permissions: MockPermissionProviding(.granted),
            clock: ManualClock(),
            audioSource: MockAudioSourceProviding()
        )

        #expect(viewModel.state == .idle)
        mockWriter.emitWriteError("spurious")
        // `(.idle, .error)` is not a legal transition and `transition` rejects
        // illegal moves *silently* — BL-161's lesson. The guard is what makes
        // that safe rather than lossy.
        #expect(viewModel.state == .idle)
        #expect(mockWriter.stopCount == 0)
    }

    // MARK: - WAV's IO failure path

    // ⚠️ Deliberately NOT unit-tested, and this note is the reason.
    //
    // `WAVWriter` wrote through the nonthrowing `FileHandle.write(_:)`, which
    // raises an ObjC `NSException` on ENOSPC that Swift cannot catch — so a full
    // disk was invisible to WAV end to end. BL-173 swaps it for the throwing
    // `write(contentsOf:)`.
    //
    // A first attempt here asserted that behaviour by deleting the file out from
    // under the open handle. **That test passed before the fix as well**: on
    // macOS a write to an unlinked descriptor still succeeds, so it proved
    // nothing and was removed rather than left looking like coverage.
    //
    // Provoking a real ENOSPC needs a full volume, which belongs in
    // `docs/manual-acceptance.md` (record to a small disk image, fill it
    // mid-take) — not in a unit suite. The propagation *above* this line is what
    // is tested: once any encoder throws, the failure reaches the user exactly
    // once and the waveform stops.
}

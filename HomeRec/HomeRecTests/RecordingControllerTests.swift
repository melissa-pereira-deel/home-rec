//
//  RecordingControllerTests.swift
//  HomeRecTests
//
//  BL-015: the controller threads the chosen AudioFormat into both the file
//  path (extension) and the recorder (encoder). Uses the injectable mock seams.
//

import Testing
import Foundation
@testable import HomeRec

@MainActor
struct RecordingControllerTests {

    private func makeController(
        recorder: MockAudioFileWriting? = nil,
        capture: MockAudioCapturing? = nil,
        audioSource: MockAudioSourceProviding? = nil
    ) -> RecordingController {
        RecordingController(
            captureManager: capture ?? MockAudioCapturing(),
            audioRecorder: recorder ?? MockAudioFileWriting(),
            saveLocation: MockSaveLocationProviding(directory: FileManager.default.temporaryDirectory),
            audioSource: audioSource ?? MockAudioSourceProviding()
        )
    }

    @Test("generateFilePath uses the format's extension", arguments: [AudioFormat.wav, .m4a])
    func filePathExtensionFollowsFormat(_ format: AudioFormat) {
        let url = makeController().generateFilePath(format: format)
        #expect(url.pathExtension == format.fileExtension)
    }

    @Test("startRecording threads the format into the recorder and the file URL")
    func startThreadsFormat() async throws {
        let recorder = MockAudioFileWriting()
        let controller = makeController(recorder: recorder)

        let url = try await controller.startRecording(format: .m4a)

        #expect(recorder.lastStartFormat == .m4a)
        #expect(url.pathExtension == "m4a")
        #expect(controller.recordingURL?.pathExtension == "m4a")
    }

    @Test("startRecording threads the selected AudioSource into capture setup (BL-100)")
    func startThreadsAudioSource() async throws {
        let capture = MockAudioCapturing()
        let audioSource = MockAudioSourceProviding(selectedSource: .app(bundleID: "com.apple.logic10"))
        let controller = makeController(capture: capture, audioSource: audioSource)

        _ = try await controller.startRecording(format: .wav)

        #expect(capture.lastSource == .app(bundleID: "com.apple.logic10"))
        #expect(audioSource.validateCount == 1)
    }

    @Test("An unvalidatable source fails before any file is created (BL-100 pre-flight)")
    func invalidSourceFailsBeforeFileCreation() async {
        let recorder = MockAudioFileWriting()
        let capture = MockAudioCapturing()
        let audioSource = MockAudioSourceProviding(selectedSource: .app(bundleID: "com.apple.logic10"))
        audioSource.validateError = AudioSourceError.appNotRunning("com.apple.logic10")
        let controller = makeController(recorder: recorder, capture: capture, audioSource: audioSource)

        await #expect(throws: AudioSourceError.self) {
            try await controller.startRecording(format: .wav)
        }

        #expect(recorder.startCount == 0)
        #expect(capture.setupCount == 0)
        #expect(controller.recordingURL == nil)
    }

    // MARK: - BL-016 teardown ordering

    private struct FinalizeFailure: Error, Equatable {}

    // MARK: - Transactional start (BL-171a)

    // `startRecording` used to acquire the encoder and the file, then make two
    // awaited capture calls, with no `do`/`catch` and no `defer`. A throw from
    // either left an open encoder, a file on disk the controller had no
    // reference to, a retained SCStream, and a stale waveform sink — and
    // `deinit` was gated on `captureManager.capturing`, which is only true after
    // `startCapture()` succeeds, so the one object holding both was structurally
    // forbidden from cleaning up.

    private struct StageFailure: Error, Equatable { let stage: String }

    @Test("A failure at capture setup releases the encoder and cleans up")
    func setupFailureRollsBack() async throws {
        let recorder = MockAudioFileWriting()
        let capture = MockAudioCapturing()
        capture.setupError = StageFailure(stage: "setup")
        let controller = makeController(recorder: recorder, capture: capture)

        await #expect(throws: StageFailure.self) {
            _ = try await controller.startRecording(format: .wav)
        }

        #expect(recorder.stopCount == 1, "the encoder opened at start must be released")
        #expect(capture.cleanupCount == 1, "the partially configured stream must be released")
        #expect(recorder.onWaveformData == nil, "a stale waveform sink outlived the failed take")
        #expect(controller.recordingURL == nil)
        #expect(controller.isRecording == false)
    }

    @Test("A failure at capture start releases the encoder and cleans up")
    func startCaptureFailureRollsBack() async throws {
        let recorder = MockAudioFileWriting()
        let capture = MockAudioCapturing()
        capture.startCaptureError = StageFailure(stage: "start")
        let controller = makeController(recorder: recorder, capture: capture)

        await #expect(throws: StageFailure.self) {
            _ = try await controller.startRecording(format: .wav)
        }

        #expect(recorder.stopCount == 1)
        #expect(capture.cleanupCount == 1)
        #expect(capture.capturing == false)
        #expect(controller.recordingURL == nil)
    }

    @Test("A failure creating the encoder leaves nothing to clean up, and does not wedge")
    func encoderCreationFailureRollsBack() async throws {
        let recorder = MockAudioFileWriting()
        recorder.startError = StageFailure(stage: "encoder")
        let capture = MockAudioCapturing()
        let controller = makeController(recorder: recorder, capture: capture)

        await #expect(throws: StageFailure.self) {
            _ = try await controller.startRecording(format: .wav)
        }

        #expect(capture.setupCount == 0, "capture must not be set up after the encoder failed")
        #expect(controller.recordingURL == nil)
    }

    @Test("The rollback does not replace the diagnosis")
    func originalErrorSurvivesRollback() async throws {
        // The teardown is best-effort and must never become the reported cause —
        // that would bury the real one, which is the failure BL-016 fixed on the
        // stop path and the same mistake would be easy to make here.
        let recorder = MockAudioFileWriting()
        recorder.stopError = StageFailure(stage: "teardown")
        let capture = MockAudioCapturing()
        capture.startCaptureError = StageFailure(stage: "start")
        let controller = makeController(recorder: recorder, capture: capture)

        do {
            _ = try await controller.startRecording(format: .wav)
            Issue.record("expected the start failure to propagate")
        } catch let error as StageFailure {
            #expect(error.stage == "start", "got the teardown error instead of the cause")
        }
    }

    @Test("A subsequent start succeeds after a failed one")
    func nextStartSucceedsAfterFailure() async throws {
        let recorder = MockAudioFileWriting()
        let capture = MockAudioCapturing()
        capture.startCaptureError = StageFailure(stage: "start")
        let controller = makeController(recorder: recorder, capture: capture)

        await #expect(throws: StageFailure.self) {
            _ = try await controller.startRecording(format: .wav)
        }

        capture.startCaptureError = nil
        _ = try await controller.startRecording(format: .wav)
        #expect(controller.isRecording)
        #expect(controller.recordingURL != nil)
    }

    @Test("A thrown stopCapture no longer bypasses finalize and cleanup")
    func stopCaptureFailureStillTearsDown() async throws {
        // `try await captureManager.stopCapture()` was the one call in
        // `stopRecording` not wrapped, so a throw there skipped finalize,
        // cleanup, the waveform clear and the URL clear — one line above the
        // comment explaining why that must not happen.
        let recorder = MockAudioFileWriting()
        let capture = MockAudioCapturing()
        let controller = makeController(recorder: recorder, capture: capture)

        _ = try await controller.startRecording(format: .wav)
        capture.stopCaptureError = StageFailure(stage: "stopCapture")

        await #expect(throws: StageFailure.self) {
            try await controller.stopRecording()
        }

        #expect(recorder.stopCount == 1, "the file was left open")
        #expect(capture.cleanupCount == 1, "the stream was leaked")
        #expect(controller.recordingURL == nil)
    }

    // MARK: - The orphan on disk

    @Test("A failed start leaves no file behind, and no phantom recovery row")
    func failedStartLeavesNoOrphan() async throws {
        // A real AudioRecorder over a real WAV encoder, because the mock writer
        // touches no disk and this assertion is about disk.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("orphan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let capture = MockAudioCapturing()
        capture.startCaptureError = StageFailure(stage: "start")
        let controller = RecordingController(
            captureManager: capture,
            audioRecorder: AudioRecorder(),
            saveLocation: MockSaveLocationProviding(directory: dir),
            audioSource: MockAudioSourceProviding()
        )

        await #expect(throws: StageFailure.self) {
            _ = try await controller.startRecording(format: .wav)
        }

        let left = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(left.isEmpty, "left behind: \(left)")

        // A 44-byte WAV orphan passes `isUnfinalized` — `44 > 44` is false — so
        // it would show up as "Too short to recover", asserting a crash that
        // never happened.
        let scanner = RecoveryScanner(saveLocation: MockSaveLocationProviding(directory: dir))
        #expect(scanner.scan(excluding: nil).isEmpty, "a failed start produced a recovery row")
    }

    @Test("No audio can reach the encoder when the start throws")
    func noAudioIsCapturedOnAFailedStart() async throws {
        // The precondition the unconditional delete rests on. If capture ever
        // begins delivering before `startCapture()` throws, this fails — and the
        // delete has to become conditional rather than silently discarding a
        // real take.
        let recorder = MockAudioFileWriting()
        let capture = MockAudioCapturing()
        capture.startCaptureError = StageFailure(stage: "start")
        let controller = makeController(recorder: recorder, capture: capture)

        await #expect(throws: StageFailure.self) {
            _ = try await controller.startRecording(format: .wav)
        }

        #expect(recorder.processedBufferCount == 0, "a buffer reached the encoder before the throw")
    }

    /// The regression this guards: a finalize failure must not skip teardown.
    /// Rethrowing straight out of `stopRecording()` would leak the SCStream and
    /// strand a stale recording URL — a worse outcome than the error itself.
    @Test("A finalize failure still tears down capture, then rethrows")
    func finalizeFailureStillTearsDown() async throws {
        let recorder = MockAudioFileWriting()
        let capture = MockAudioCapturing()
        let controller = makeController(recorder: recorder, capture: capture)

        _ = try await controller.startRecording(format: .wav)
        recorder.stopError = FinalizeFailure()

        await #expect(throws: FinalizeFailure.self) {
            try await controller.stopRecording()
        }

        // Teardown completed despite the throw.
        #expect(capture.stopCount == 1)
        #expect(capture.cleanupCount == 1)
        #expect(controller.recordingURL == nil)
    }

    @Test("A clean stop tears down and does not throw")
    func cleanStopTearsDown() async throws {
        let recorder = MockAudioFileWriting()
        let capture = MockAudioCapturing()
        let controller = makeController(recorder: recorder, capture: capture)

        _ = try await controller.startRecording(format: .wav)
        try await controller.stopRecording()

        #expect(recorder.stopCount == 1)
        #expect(capture.cleanupCount == 1)
        #expect(controller.recordingURL == nil)
    }
}

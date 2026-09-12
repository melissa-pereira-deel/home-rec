import Testing
import Foundation
@testable import HomeRec

@MainActor
struct RecordingSessionTests {
    private struct InjectedFailure: Error {}

    /// A one-shot suspension that stays open for later calls (including deinit).
    @MainActor
    private final class Gate {
        private(set) var isWaiting = false
        private var released = false
        private var continuation: CheckedContinuation<Void, Never>?

        func wait() async {
            guard !released else { return }
            // `cleanup()` runs on three controller paths plus `deinit`, so a
            // gate can be entered twice. Overwriting would strand the first
            // continuation and hang the test past any timeout.
            precondition(continuation == nil, "Gate does not support concurrent waiters")
            await withCheckedContinuation {
                continuation = $0
                isWaiting = true
            }
        }

        func release() {
            released = true
            continuation?.resume()
            continuation = nil
        }
    }

    /// Real interrupted bytes make a missing exclusion observable on disk.
    private func writeInterruptedWAV(at url: URL) throws {
        let live = url.deletingLastPathComponent().appendingPathComponent("fixture.wav")
        let writer = WAVWriter()
        defer {
            try? writer.finalize()
            try? FileManager.default.removeItem(at: live)
        }
        try writer.createFile(at: live, sampleRate: 48_000, channels: 2)
        let buffer = SampleBufferFixtures.makePCMBuffer(
            channels: 2, frames: 1_024, sampleRate: 48_000, interleaved: false
        ) { _, _ in 0.25 }
        try writer.writeBuffer(buffer)
        try FileManager.default.copyItem(at: live, to: url)
    }

    @MainActor
    private final class Fixture {
        let directory: URL
        let defaults: UserDefaults
        let defaultsName = "RecordingSessionTests.\(UUID().uuidString)"
        let capture = MockAudioCapturing()
        let writer = MockAudioFileWriting()
        let controller: RecordingController
        let recorder: RecorderViewModel
        let scanner: RecoveryScanner
        let recovery: RecoveryViewModel

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("session-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defaults = try #require(UserDefaults(suiteName: defaultsName))
            let location = MockSaveLocationProviding(directory: directory)
            let source = MockAudioSourceProviding()
            controller = RecordingController(
                captureManager: capture, audioRecorder: writer,
                saveLocation: location, audioSource: source
            )
            recorder = RecorderViewModel(
                controller: controller, permissions: MockPermissionProviding(),
                clock: ManualClock(), saveLocation: location, audioSource: source,
                installLocation: MockInstallLocationProviding(), defaults: defaults,
                notificationCenter: NotificationCenter()
            )
            scanner = RecoveryScanner(saveLocation: location)
            recovery = RecoveryViewModel(scanner: scanner, inProgressURL: recorder.recordingURLProvider)
        }

        func cleanup() {
            // Test hooks may capture the fixture; release them before teardown.
            writer.onStart = nil
            writer.onStop = nil
            capture.onSetup = nil
            capture.onStartCapture = nil
            capture.onStopCapture = nil
            capture.onCleanup = nil
            defaults.removePersistentDomain(forName: defaultsName)
            try? FileManager.default.removeItem(at: directory)
        }

        func expectProtected(_ url: URL, state: RecordingState) {
            #expect(recorder.state == state)
            #expect(controller.recordingURL == url)
            #expect(scanner.scan(excluding: nil).count == 1, "fixture must be recoverable without exclusion")
            recovery.refresh()
            #expect(recovery.recordings.isEmpty)
        }
    }

    @Test("Ownership precedes file creation and covers both starting awaits", arguments: [false, true])
    func startingExcludesBeforeCapture(holdStartCapture: Bool) async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let gate = Gate()
        defer { gate.release() }
        let previous = f.directory.appendingPathComponent("previous.wav")
        f.recorder.lastRecordingURL = previous
        f.writer.onStart = { url in
            #expect(f.controller.recordingURL == url, "ownership must precede the writer's first file creation")
            #expect(!FileManager.default.fileExists(atPath: url.path))
            #expect(f.recorder.lastRecordingURL == previous)
            try writeInterruptedWAV(at: url)
            f.expectProtected(url, state: .starting)
        }
        if holdStartCapture {
            f.capture.onStartCapture = { await gate.wait() }
        } else {
            f.capture.onSetup = { await gate.wait() }
        }

        let start = Task { await f.recorder.startRecording() }
        await waitUntil("capture start suspension") { gate.isWaiting }
        let url = try #require(f.controller.recordingURL)
        f.expectProtected(url, state: .starting)
        #expect(!f.capture.capturing)
        #expect(f.recorder.lastRecordingURL == previous)

        // A second caller cannot replace the session across a suspended start.
        await #expect(throws: RecordingControllerError.self) {
            _ = try await f.controller.startRecording(format: .wav)
        }
        #expect(f.writer.startCount == 1)
        #expect(f.controller.recordingURL == url)

        gate.release()
        await start.value
        f.expectProtected(url, state: .recording)
        await f.recorder.stopRecording()
        #expect(f.controller.recordingURL == nil)
        #expect(f.recorder.lastRecordingURL == url)
    }

    @Test("Stopping retains ownership through finalization and cleanup, even on error", arguments: [false, true])
    func stoppingRetainsUntilCleanup(finalizeFails: Bool) async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let stopGate = Gate()
        let cleanupGate = Gate()
        defer { stopGate.release(); cleanupGate.release() }
        f.writer.onStart = { try writeInterruptedWAV(at: $0) }
        await f.recorder.startRecording()
        let url = try #require(f.controller.recordingURL)
        f.capture.onStopCapture = { await stopGate.wait() }
        f.capture.onCleanup = { await cleanupGate.wait() }
        f.writer.onStop = { f.expectProtected(url, state: .stopping) }
        if finalizeFails { f.writer.stopError = InjectedFailure() }

        let stop = Task { await f.recorder.stopRecording() }
        await waitUntil("stopCapture suspension") { stopGate.isWaiting }
        f.expectProtected(url, state: .stopping)
        stopGate.release()
        await waitUntil("post-finalize cleanup suspension") { cleanupGate.isWaiting }
        #expect(f.writer.stopCount == 1)
        f.expectProtected(url, state: .stopping)

        await #expect(throws: RecordingControllerError.self) {
            _ = try await f.controller.startRecording(format: .wav)
        }
        #expect(f.controller.recordingURL == url)
        cleanupGate.release()
        await stop.value
        #expect(f.controller.recordingURL == nil)
        #expect(f.recorder.recordingURLProvider() == nil)
        #expect(f.recorder.lastRecordingURL == url)
        if finalizeFails {
            guard case .error = f.recorder.state else {
                Issue.record("expected the finalize error to reach the UI")
                return
            }
        } else {
            #expect(f.recorder.state == .idle)
        }
        f.recovery.refresh()
        #expect(f.recovery.recordings.count == 1, "a released file is eligible again")
    }

    @Test("Failed starts retain ownership until rollback finalization and cleanup finish",
          arguments: ["creation", "setup", "start"])
    func rollbackRetainsUntilCleanup(stage: String) async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let cleanupGate = Gate()
        defer { cleanupGate.release() }
        f.writer.onStart = { url in
            #expect(f.controller.recordingURL == url)
            #expect(!FileManager.default.fileExists(atPath: url.path))
            try writeInterruptedWAV(at: url)
        }
        switch stage {
        case "creation": f.writer.startError = InjectedFailure()
        case "setup": f.capture.setupError = InjectedFailure()
        default: f.capture.startCaptureError = InjectedFailure()
        }
        f.writer.onStop = {
            guard let url = f.controller.recordingURL else {
                Issue.record("rollback released ownership before finalization")
                return
            }
            f.expectProtected(url, state: .starting)
        }
        f.capture.onCleanup = { await cleanupGate.wait() }

        let start = Task { await f.recorder.startRecording() }
        await waitUntil("failed-start cleanup suspension") { cleanupGate.isWaiting }
        let url = try #require(f.controller.recordingURL)
        #expect(f.writer.stopCount == 1)
        f.expectProtected(url, state: .starting)
        cleanupGate.release()
        await start.value
        #expect(f.controller.recordingURL == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        f.recovery.refresh()
        #expect(f.recovery.recordings.isEmpty)
    }

    @Test("Failure teardown keeps ownership even after capture stops")
    func failureTeardownRetainsUntilCleanup() async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let cleanupGate = Gate()
        defer { cleanupGate.release() }
        f.writer.onStart = { try writeInterruptedWAV(at: $0) }
        _ = try await f.controller.startRecording(format: .wav)
        let url = try #require(f.controller.recordingURL)
        f.writer.stopError = InjectedFailure()
        f.capture.onCleanup = { await cleanupGate.wait() }
        let finish = Task { await f.controller.finalizeAfterFailure() }
        await waitUntil("failure teardown cleanup") { cleanupGate.isWaiting }
        #expect(!f.controller.isRecording)
        #expect(f.controller.recordingURL == url)
        f.recovery.refresh()
        #expect(f.recovery.recordings.isEmpty)
        cleanupGate.release()
        await finish.value
        #expect(f.controller.recordingURL == nil)
    }

    @Test("Repair and trash refuse a row that became owned after scanning", arguments: [false, true])
    func staleRowsRecheckOwnership(trash: Bool) async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let url = f.directory.appendingPathComponent("recording_reused.wav")
        let controller = FixedPathController(
            fileURL: url, captureManager: f.capture, audioRecorder: f.writer,
            saveLocation: MockSaveLocationProviding(directory: f.directory),
            audioSource: MockAudioSourceProviding()
        )
        let recovery = RecoveryViewModel(
            scanner: f.scanner,
            inProgressURL: {
                // Equivalent file URL with a different textual spelling.
                controller.recordingURL?.deletingLastPathComponent()
                    .appendingPathComponent("./\(url.lastPathComponent)")
            }
        )
        // The same recovery model scans an older take, then receives the stale
        // action after that path has become a new session's output.
        try writeInterruptedWAV(at: url)
        recovery.refresh()
        let stale = try #require(recovery.recordings.first)
        try FileManager.default.removeItem(at: url)
        f.writer.onStart = { try writeInterruptedWAV(at: $0) }
        _ = try await controller.startRecording(format: .wav)
        let before = try Data(contentsOf: url)
        if trash { recovery.moveToTrash(stale) } else { recovery.recover(stale) }
        #expect(recovery.errorMessage != nil)
        #expect(recovery.recordings.isEmpty)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try Data(contentsOf: url) == before, "a stale action modified an owned file")

        try await controller.stopRecording()
        recovery.refresh()
        #expect(recovery.recordings.count == 1, "refusal must not mark the file as handled")
        recovery.errorMessage = nil
        recovery.recover(stale)
        #expect(recovery.errorMessage == nil)
        #expect(recovery.recordings.isEmpty)
        #expect(try WAVWriter.isUnfinalized(at: url) == false)
    }

    /// BL-170's ceiling is the likeliest way a user meets a draining teardown:
    /// the alert says the take saved complete, so pressing Record again is the
    /// obvious next move, and `finalizeAfterFailure` is still running when they do.
    @Test("A retry during failure teardown waits for it instead of blaming the user")
    func retryDuringTeardownWaitsForIt() async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let cleanupGate = Gate()
        defer { cleanupGate.release() }
        f.writer.onStart = { try writeInterruptedWAV(at: $0) }
        await f.recorder.startRecording()
        #expect(f.recorder.state == .recording)
        let first = try #require(f.controller.recordingURL)

        f.capture.onCleanup = { await cleanupGate.wait() }
        f.writer.emitWriteError(.sizeLimitReached)
        #expect(f.recorder.state == .error(.sizeLimitReached))
        await waitUntil("failure teardown cleanup") { cleanupGate.isWaiting }

        // The user presses Record for the next take, mid-teardown.
        let retry = Task { await f.recorder.startRecording() }
        await waitUntil("the retry to park in .starting") { f.recorder.state == .starting }
        #expect(f.controller.recordingURL == first, "the draining take still owns its file")

        cleanupGate.release()
        await retry.value

        #expect(f.recorder.state == .recording, "the retry must land once teardown finishes")
        let second = try #require(f.controller.recordingURL)
        #expect(second != first, "the new take must not reuse the finished file")
        #expect(
            f.recorder.errorMessage?.localizedCaseInsensitiveContains("audio is playing") != true,
            "a take still finalizing is not a missing-audio problem"
        )
        await f.recorder.stopRecording()
    }

    /// The refusal still has to read honestly if it is ever reached: the generic
    /// clause would send someone to check their speakers while Home Rec closed
    /// a file.
    @Test("A refused start names the real reason and offers the retry")
    func refusedStartReadsHonestly() {
        let error = RecorderError.stillFinishing
        #expect(error.message.localizedCaseInsensitiveContains("still finishing"))
        #expect(!error.message.localizedCaseInsensitiveContains("audio is playing"))
        #expect(error.recovery == .tryAgain)
    }

    /// Pins a filename so a scan-then-own race does not depend on the clock.
    @MainActor
    private final class FixedPathController: RecordingController {
        let fileURL: URL

        init(fileURL: URL, captureManager: AudioCapturing, audioRecorder: AudioFileWriting,
             saveLocation: SaveLocationProviding, audioSource: AudioSourceProviding) {
            self.fileURL = fileURL
            super.init(captureManager: captureManager, audioRecorder: audioRecorder,
                       saveLocation: saveLocation, audioSource: audioSource)
        }

        override func generateFilePath(format: AudioFormat) -> URL { fileURL }
    }
}

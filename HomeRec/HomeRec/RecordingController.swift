//
//  RecordingController.swift
//  HomeRec
//
//  Orchestrates the recording workflow
//

import Foundation
import os

/// Errors originating from the recording controller before/around capture.
enum RecordingControllerError: Error {
    case insufficientDiskSpace
    case sessionInProgress
}

/// Controller that coordinates audio recording workflow
class RecordingController: RecordingControlling {

    // MARK: - Properties

    private let captureManager: AudioCapturing
    private let audioRecorder: AudioFileWriting
    private let saveLocation: SaveLocationProviding
    private let audioSource: AudioSourceProviding

    private var session: RecordingSession?

    /// Callback for waveform visualization data
    var onWaveformData: (([Float]) -> Void)?

    /// Forwarded from the capture manager when the stream fails mid-recording.
    var onStreamError: (@MainActor (String) -> Void)?

    /// Forwarded from the recorder when a buffer cannot be written (BL-173).
    var onWriteError: (@MainActor (WriteFailure) -> Void)?

    // MARK: - Initialization

    init(
        captureManager: AudioCapturing? = nil,
        audioRecorder: AudioFileWriting? = nil,
        saveLocation: SaveLocationProviding? = nil,
        audioSource: AudioSourceProviding? = nil
    ) {
        self.captureManager = captureManager ?? ScreenCaptureAudioManager()
        self.audioRecorder = audioRecorder ?? AudioRecorder()
        self.saveLocation = saveLocation ?? SaveLocationManager()
        self.audioSource = audioSource ?? AudioSourceManager()
        self.captureManager.onStreamError = { [weak self] message in
            self?.onStreamError?(message)
        }
        self.audioRecorder.onWriteError = { [weak self] message in
            self?.onWriteError?(message)
        }
    }

    // MARK: - Public Methods

    /// Start recording system audio in the given output `format` (BL-015).
    /// - Returns: URL where the recording is being saved
    /// - Throws: Error if recording cannot start
    @MainActor
    func startRecording(format: AudioFormat) async throws -> URL {
        // Pre-flight: fail before touching disk if the selected source isn't
        // capturable right now (BL-100 — e.g. the chosen app isn't running).
        let source = audioSource.selectedSource
        try await audioSource.validate(source)

        // Validation suspends. A take that acquired ownership meanwhile must
        // keep it until teardown completes, even if the UI has entered error.
        guard session == nil else { throw RecordingControllerError.sessionInProgress }

        // Generate file path (extension follows the chosen format).
        let fileURL = generateFilePath(format: format)

        // Refuse to start a doomed recording on a near-full disk.
        if let available = DiskSpace.availableBytes(at: fileURL),
           !DiskSpace.hasEnoughSpace(availableBytes: available) {
            throw RecordingControllerError.insufficientDiskSpace
        }

        // Wire waveform callback
        audioRecorder.onWaveformData = onWaveformData

        session = RecordingSession(fileURL: fileURL)

        // Everything from here acquires something, so it is one transaction
        // (BL-171a). Before this, a throw from either capture call left an open
        // encoder, a file on disk the controller had no reference to, a retained
        // SCStream, and a stale waveform sink — and `deinit` could not rescue any
        // of it, because it was gated on capture having started.
        do {
            // Creates the file in the chosen format.
            try audioRecorder.startRecording(to: fileURL, format: format)

            // Set up capture with audio callback
            let recorder = audioRecorder  // Keep strong reference
            try await captureManager.setupCapture(source: source) { pcmBuffer in
                recorder.processAudioSample(pcmBuffer)
            }

            // Start capturing system audio
            try await captureManager.startCapture()
        } catch {
            await rollbackFailedStart(fileURL: fileURL)
            throw error
        }

        Log.recorder.info("Recording started")
        return fileURL
    }

    /// Stop recording
    /// - Throws: Error if stop fails
    func stopRecording() async throws {
        // Stop capturing audio.
        //
        // Latched rather than rethrown for the same reason as the finalize below,
        // which it used to sit one line above without sharing (BL-171a): a throw
        // here skipped finalize, cleanup, the waveform clear and the URL clear —
        // leaving the file open and the stream leaked, the exact outcome the
        // comment below says the design prevents.
        let captureError: Error?
        do {
            try await captureManager.stopCapture()
            captureError = nil
        } catch {
            captureError = error
        }

        // Finalize the file, but capture the error rather than rethrowing here:
        // the teardown below must run either way, or a failed finalize would leak
        // the capture session and leave a stale recording URL behind. (BL-016 —
        // the error used to be swallowed inside AudioRecorder, so before now this
        // path could never be reached.)
        let finalizeError: Error?
        do {
            try audioRecorder.stopRecording()
            finalizeError = nil
        } catch {
            finalizeError = error
        }

        // Clean up capture manager
        await captureManager.cleanup()

        audioRecorder.onWaveformData = nil
        session = nil

        // Capture first: it happened first, and it is the more likely cause.
        if let captureError {
            Log.recorder.error(
                "Stop capture failed: \(captureError.localizedDescription, privacy: .public)"
            )
            throw captureError
        }
        if let finalizeError {
            Log.recorder.error(
                "Finalize failed on stop: \(finalizeError.localizedDescription, privacy: .public)"
            )
            throw finalizeError
        }
        Log.recorder.info("Recording stopped")
    }

    /// Release everything a failed start acquired, then let the caller rethrow.
    ///
    /// Deliberately best-effort — every call here is `try?`, per this project's
    /// rule that `try?` belongs in cleanup and nowhere else. A rollback that
    /// threw would replace the diagnosis with its own, the mistake BL-016 fixed
    /// on the stop path.
    ///
    /// **The file is removed unconditionally, and that is safe because no audio
    /// can have reached it.** The capture callback is installed during
    /// `setupCapture`, but cannot fire until `stream.startCapture()` has
    /// succeeded — so a throw anywhere above means zero buffers were written.
    /// `noAudioIsCapturedOnAFailedStart` pins that precondition; if capture ever
    /// begins delivering earlier, it fails rather than letting this silently
    /// discard a real take.
    ///
    /// Leaving the file is not the safer option it looks like. An abandoned WAV
    /// is exactly 44 bytes, and `isUnfinalized` tests `total > headerByteCount`
    /// — `44 > 44` is false, so it reports **true** and puts a "Too short to
    /// recover" row in Recover Recordings for a crash that never happened.
    /// Finalizing instead of deleting does not help: it rewrites the same 44
    /// bytes. FLAC and M4A orphans are skipped by the scanner but still litter
    /// the save folder with unopenable files.
    private func rollbackFailedStart(fileURL: URL) async {
        try? audioRecorder.stopRecording()
        await captureManager.cleanup()
        audioRecorder.onWaveformData = nil
        try? FileManager.default.removeItem(at: fileURL)
        session = nil
        Log.recorder.error("Recording start failed; rolled back")
    }

    /// Finalize after an unexpected capture failure. The stream has already
    /// stopped, so capture teardown is best-effort; finalizing the recorder
    /// preserves the audio captured before the failure as a playable file.
    func finalizeAfterFailure() async {
        try? await captureManager.stopCapture()
        // Deliberately swallowed, unlike the user-initiated stop path (BL-016):
        // the caller is already reporting `.streamFailed`, which is the more
        // useful diagnosis, and replacing it with a finalize error would bury
        // the actual cause. The partial file is preserved either way — for WAV
        // by its periodic header, for M4A by its movie fragments.
        try? audioRecorder.stopRecording()
        await captureManager.cleanup()
        audioRecorder.onWaveformData = nil
        session = nil
        Log.recorder.error("Recording finalized after stream failure")
    }

    /// Check if currently recording
    var isRecording: Bool {
        return captureManager.capturing
    }

    /// The session's file, from before creation through finalization and cleanup.
    var recordingURL: URL? {
        return session?.fileURL
    }

    // MARK: - File path

    /// Generate a unique file path in the resolved save directory, with the
    /// extension for `format` (BL-015). `internal` for unit testing. The directory
    /// comes from `SaveLocationProviding`, which always resolves to a writable
    /// folder (falling back to the Desktop).
    func generateFilePath(format: AudioFormat) -> URL {
        let directory = saveLocation.resolvedDirectory

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let base = "recording_\(timestamp)"
        let ext = format.fileExtension

        // Avoid clobbering an existing file (timestamps are second-granular).
        var candidate = directory.appendingPathComponent("\(base).\(ext)")
        var suffix = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base) (\(suffix)).\(ext)")
            suffix += 1
        }
        return candidate
    }

    // MARK: - Cleanup

    deinit {
        // Capture managers directly to avoid referencing self inside the Task closure
        let captureManager = captureManager
        let audioRecorder = audioRecorder
        Task { @MainActor in
            // No `capturing` gate (BL-171a). It was only ever true after
            // `startCapture()` succeeded, so on a failed start this returned
            // immediately and the encoder was never released. Every call below
            // already no-ops safely when nothing was acquired: `stopCapture`
            // early-returns on a nil stream, `stopRecording` throws
            // `.notRecording` into a `try?`, and `cleanup` is safe after no,
            // partial or full setup.
            try? await captureManager.stopCapture()
            try? audioRecorder.stopRecording()
            await captureManager.cleanup()
        }
    }
}

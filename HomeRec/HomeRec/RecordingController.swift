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
}

/// Controller that coordinates audio recording workflow
class RecordingController: RecordingControlling {

    // MARK: - Properties

    private let captureManager: AudioCapturing
    private let audioRecorder: AudioFileWriting
    private let saveLocation: SaveLocationProviding
    private let audioSource: AudioSourceProviding

    private var currentRecordingURL: URL?

    /// Callback for waveform visualization data
    var onWaveformData: (([Float]) -> Void)?

    /// Forwarded from the capture manager when the stream fails mid-recording.
    var onStreamError: (@MainActor (String) -> Void)?

    /// Forwarded from the recorder when a buffer cannot be written (BL-173).
    var onWriteError: (@MainActor (String) -> Void)?

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

        // Generate file path (extension follows the chosen format).
        let fileURL = generateFilePath(format: format)

        // Refuse to start a doomed recording on a near-full disk.
        if let available = DiskSpace.availableBytes(at: fileURL),
           !DiskSpace.hasEnoughSpace(availableBytes: available) {
            throw RecordingControllerError.insufficientDiskSpace
        }

        // Wire waveform callback
        audioRecorder.onWaveformData = onWaveformData

        // Start audio recorder first (creates the file in the chosen format).
        try audioRecorder.startRecording(to: fileURL, format: format)

        // Set up capture with audio callback
        let recorder = audioRecorder  // Keep strong reference
        try await captureManager.setupCapture(source: source) { pcmBuffer in
            recorder.processAudioSample(pcmBuffer)
        }

        // Start capturing system audio
        try await captureManager.startCapture()

        currentRecordingURL = fileURL
        Log.recorder.info("Recording started")
        return fileURL
    }

    /// Stop recording
    /// - Throws: Error if stop fails
    func stopRecording() async throws {
        // Stop capturing audio
        try await captureManager.stopCapture()

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
        currentRecordingURL = nil

        if let finalizeError {
            Log.recorder.error(
                "Finalize failed on stop: \(finalizeError.localizedDescription, privacy: .public)"
            )
            throw finalizeError
        }
        Log.recorder.info("Recording stopped")
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
        currentRecordingURL = nil
        Log.recorder.error("Recording finalized after stream failure")
    }

    /// Check if currently recording
    var isRecording: Bool {
        return captureManager.capturing
    }

    /// Get current recording URL
    var recordingURL: URL? {
        return currentRecordingURL
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
            guard captureManager.capturing else { return }
            try? await captureManager.stopCapture()
            try? audioRecorder.stopRecording()
            await captureManager.cleanup()
        }
    }
}

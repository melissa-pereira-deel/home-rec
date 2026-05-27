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

    private var currentRecordingURL: URL?

    /// Callback for waveform visualization data
    var onWaveformData: (([Float]) -> Void)?

    /// Forwarded from the capture manager when the stream fails mid-recording.
    var onStreamError: (@MainActor (String) -> Void)?

    // MARK: - Initialization

    init(
        captureManager: AudioCapturing? = nil,
        audioRecorder: AudioFileWriting? = nil,
        saveLocation: SaveLocationProviding? = nil
    ) {
        self.captureManager = captureManager ?? ScreenCaptureAudioManager()
        self.audioRecorder = audioRecorder ?? AudioRecorder()
        self.saveLocation = saveLocation ?? SaveLocationManager()
        self.captureManager.onStreamError = { [weak self] message in
            self?.onStreamError?(message)
        }
    }

    // MARK: - Public Methods

    /// Start recording system audio
    /// - Returns: URL where the recording is being saved
    /// - Throws: Error if recording cannot start
    @MainActor
    func startRecording() async throws -> URL {
        // Generate file path
        let fileURL = generateFilePath()

        // Refuse to start a doomed recording on a near-full disk.
        if let available = DiskSpace.availableBytes(at: fileURL),
           !DiskSpace.hasEnoughSpace(availableBytes: available) {
            throw RecordingControllerError.insufficientDiskSpace
        }

        // Wire waveform callback
        audioRecorder.onWaveformData = onWaveformData

        // Start audio recorder first (creates WAV file)
        try audioRecorder.startRecording(to: fileURL)

        // Set up capture with audio callback
        let recorder = audioRecorder  // Keep strong reference
        try await captureManager.setupCapture { sampleBuffer in
            recorder.processAudioSample(sampleBuffer)
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

        // Stop recorder and finalize WAV file
        try audioRecorder.stopRecording()

        // Clean up capture manager
        await captureManager.cleanup()

        audioRecorder.onWaveformData = nil
        currentRecordingURL = nil
        Log.recorder.info("Recording stopped")
    }

    /// Finalize after an unexpected capture failure. The stream has already
    /// stopped, so capture teardown is best-effort; finalizing the recorder
    /// preserves the audio captured before the failure as a playable file.
    func finalizeAfterFailure() async {
        try? await captureManager.stopCapture()
        try? audioRecorder.stopRecording()   // finalizes the partial WAV
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

    /// Generate a unique file path in the resolved save directory.
    /// `internal` for unit testing. The directory comes from `SaveLocationProviding`,
    /// which always resolves to a writable folder (falling back to the Desktop).
    func generateFilePath() -> URL {
        let directory = saveLocation.resolvedDirectory

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let base = "recording_\(timestamp)"

        // Avoid clobbering an existing file (timestamps are second-granular).
        var candidate = directory.appendingPathComponent("\(base).wav")
        var suffix = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base) (\(suffix)).wav")
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

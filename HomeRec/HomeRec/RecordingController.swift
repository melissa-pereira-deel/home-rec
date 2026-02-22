//
//  RecordingController.swift
//  HomeRec
//
//  Orchestrates the recording workflow
//

import Foundation

/// Controller that coordinates audio recording workflow
class RecordingController {

    // MARK: - Properties

    private let captureManager = ScreenCaptureAudioManager()
    private let audioRecorder = AudioRecorder()

    private var currentRecordingURL: URL?

    /// Callback for waveform visualization data
    var onWaveformData: (([Float]) -> Void)?

    // MARK: - Public Methods

    /// Start recording system audio
    /// - Returns: URL where the recording is being saved
    /// - Throws: Error if recording cannot start
    @MainActor
    func startRecording() async throws -> URL {
        DebugLogger.log("🎬 RecordingController.startRecording() called")
        NSLog("🎬 RecordingController: Starting recording")

        // Generate file path
        let fileURL = generateFilePath()
        DebugLogger.log("   📁 Generated file path: \(fileURL.path)")
        NSLog("📁 File path: \(fileURL.path)")

        // Wire waveform callback
        audioRecorder.onWaveformData = onWaveformData

        // Start audio recorder first (creates WAV file)
        DebugLogger.log("   Starting AudioRecorder...")
        try audioRecorder.startRecording(to: fileURL)
        DebugLogger.log("   ✅ AudioRecorder started")
        NSLog("✅ AudioRecorder started")

        // Set up capture with audio callback - use unowned self to avoid retain cycle
        let recorder = audioRecorder  // Keep strong reference
        DebugLogger.log("   Setting up capture manager...")
        try await captureManager.setupCapture { sampleBuffer in
            DebugLogger.log("🎵 SCStream callback received sample!")
            NSLog("🎵 Callback received sample")
            recorder.processAudioSample(sampleBuffer)
        }
        DebugLogger.log("   ✅ Capture manager set up")
        NSLog("✅ Capture manager set up")

        // Start capturing system audio
        DebugLogger.log("   Starting capture...")
        try await captureManager.startCapture()
        DebugLogger.log("   ✅ Capture started successfully")
        NSLog("✅ Capture started")

        currentRecordingURL = fileURL
        DebugLogger.log("✅ RecordingController.startRecording() completed, returning fileURL")
        return fileURL
    }

    /// Stop recording
    /// - Throws: Error if stop fails
    func stopRecording() async throws {
        DebugLogger.log("🛑 RecordingController.stopRecording() called")

        // Stop capturing audio
        DebugLogger.log("   Stopping capture manager...")
        try await captureManager.stopCapture()
        DebugLogger.log("   ✅ Capture manager stopped")

        // Stop recorder and finalize WAV file
        DebugLogger.log("   Stopping audio recorder...")
        try audioRecorder.stopRecording()
        DebugLogger.log("   ✅ Audio recorder stopped")

        // Clean up capture manager
        DebugLogger.log("   Cleaning up capture manager...")
        await captureManager.cleanup()
        DebugLogger.log("   ✅ Cleanup complete")

        audioRecorder.onWaveformData = nil
        currentRecordingURL = nil
        DebugLogger.log("✅ RecordingController.stopRecording() completed")
    }

    /// Check if currently recording
    var isRecording: Bool {
        return captureManager.capturing
    }

    /// Get current recording URL
    var recordingURL: URL? {
        return currentRecordingURL
    }

    // MARK: - Private Methods

    /// Generate file path with timestamp
    /// - Returns: URL for the new recording file
    private func generateFilePath() -> URL {
        // Get Desktop directory
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!

        // Generate filename with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "recording_\(timestamp).wav"

        return desktopURL.appendingPathComponent(filename)
    }

    // MARK: - Cleanup

    deinit {
        // Clean up resources on deallocation
        Task {
            if isRecording {
                try? await stopRecording()
            }
        }
    }
}

//
//  RecorderViewModel.swift
//  HomeRec
//
//  View model for the recorder UI
//

import Foundation
import SwiftUI
import Combine

/// View model managing recording state and user interactions
@MainActor
class RecorderViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isRecording = false
    @Published var duration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var lastRecordingURL: URL?
    @Published var permissionStatus: PermissionStatus = .notDetermined
    @Published var waveformSamples: [Float] = Array(repeating: 0, count: 200)

    // MARK: - Private Properties

    private let controller = RecordingController()
    private var recordingStartTime: Date?
    private var timer: Timer?

    // MARK: - Initialization

    init() {
        checkPermission()
    }

    // MARK: - Public Methods

    /// Check permission status
    func checkPermission() {
        permissionStatus = PermissionManager.checkPermission()
    }

    /// Request permission
    func requestPermission() async {
        let granted = await PermissionManager.requestPermission()
        permissionStatus = granted ? .granted : .denied

        if !granted {
            showError(message: "Screen Recording permission is required to record system audio. Please grant permission in System Settings.")
        }
    }

    /// Start recording
    func startRecording() async {
        DebugLogger.log("🎬 RecorderViewModel.startRecording() called")
        DebugLogger.log("   Permission status: \(permissionStatus)")

        // Check permission first
        if permissionStatus != .granted {
            DebugLogger.log("   ⚠️ Permission not granted, requesting...")
            await requestPermission()
            if permissionStatus != .granted {
                DebugLogger.log("   ❌ Permission denied, aborting")
                return
            }
        }

        do {
            DebugLogger.log("   ✅ Permission OK, calling controller.startRecording()...")
            // Wire waveform callback
            controller.onWaveformData = { [weak self] samples in
                Task { @MainActor in
                    self?.waveformSamples = samples
                }
            }
            // Start recording
            let fileURL = try await controller.startRecording()
            DebugLogger.log("   ✅ Controller returned fileURL: \(fileURL.path)")
            lastRecordingURL = fileURL

            // Update state
            isRecording = true
            recordingStartTime = Date()
            duration = 0

            // Start duration timer
            startTimer()
            DebugLogger.log("   ✅ Recording started successfully!")

        } catch {
            DebugLogger.log("   ❌ Error: \(error.localizedDescription)")
            showError(message: "Failed to start recording: \(error.localizedDescription)")
        }
    }

    /// Stop recording
    func stopRecording() async {
        DebugLogger.log("🛑 RecorderViewModel.stopRecording() called")
        do {
            // Stop recording
            try await controller.stopRecording()

            // Update state
            isRecording = false
            stopTimer()
            waveformSamples = Array(repeating: 0, count: 200)
            DebugLogger.log("   ✅ Recording stopped successfully!")

        } catch {
            DebugLogger.log("   ❌ Error: \(error.localizedDescription)")
            showError(message: "Failed to stop recording: \(error.localizedDescription)")
        }
    }

    /// Toggle recording state
    func toggleRecording() async {
        DebugLogger.log("🔄 toggleRecording() called, isRecording=\(isRecording)")
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    /// Reveal recording in Finder
    func revealInFinder() {
        guard let url = lastRecordingURL else { return }

        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Open System Settings
    /// Triggers a screen capture access request first so the app registers
    /// in the Screen Recording permission list before the user sees Settings.
    func openSystemSettings() {
        PermissionManager.registerAndOpenSettings()
    }

    // MARK: - Private Methods

    /// Start duration timer
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                guard let startTime = self.recordingStartTime else { return }
                self.duration = Date().timeIntervalSince(startTime)
            }
        }
    }

    /// Stop duration timer
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Show error message
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - Computed Properties

    /// Formatted duration string (MM:SS)
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Status text
    var statusText: String {
        if isRecording {
            return "Recording"
        } else if permissionStatus != .granted {
            return "Almost ready"
        } else {
            return "Play something, then hit record"
        }
    }

    // MARK: - Cleanup

    deinit {
        timer?.invalidate()
        timer = nil
    }
}

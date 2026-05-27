//
//  RecorderViewModel.swift
//  HomeRec
//
//  View model for the recorder UI
//

import Foundation
import SwiftUI
import AppKit
import Combine
import os

/// View model managing recording state and user interactions
@MainActor
class RecorderViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Single source of truth for the recording lifecycle. The UI derives from this.
    @Published private(set) var state: RecordingState = .idle
    @Published var duration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var showError = false
    /// A recovery action to offer alongside the current error, if any.
    @Published var recoverySuggestion: RecoverySuggestion?
    /// Set once a recording passes the long-recording threshold.
    @Published var showLongRecordingWarning = false
    /// Whether the first-run onboarding sheet should be shown.
    @Published var showOnboarding = false
    @Published var lastRecordingURL: URL?
    @Published var permissionStatus: PermissionStatus = .notDetermined
    @Published var waveformSamples: [Float] = Array(repeating: 0, count: 200)
    /// Display name of the current save location (folder name, or "Desktop").
    @Published private(set) var saveLocationName: String = "Desktop"
    /// Whether a non-default save location is configured (controls the Reset affordance).
    @Published private(set) var hasCustomSaveLocation = false

    /// Whether a recording is actively capturing. Derived from `state`.
    var isRecording: Bool { state == .recording }

    /// Full path of the current save location, for tooltips / accessibility.
    var saveLocationPath: String { saveLocation.resolvedDirectory.path }

    // MARK: - Private Properties

    private let controller: RecordingControlling
    private let permissions: PermissionProviding
    private let clock: DurationClock
    private let saveLocation: SaveLocationProviding
    private var recordingStartTime: Date?
    private var longRecordingWarned = false
    private var activationObserver: NSObjectProtocol?
    private let defaults: UserDefaults
    private let onboardingCompletedKey = "hasCompletedOnboarding"

    // MARK: - Initialization

    init(
        controller: RecordingControlling? = nil,
        permissions: PermissionProviding? = nil,
        clock: DurationClock? = nil,
        saveLocation: SaveLocationProviding? = nil,
        defaults: UserDefaults = .standard
    ) {
        let resolvedSaveLocation = saveLocation ?? SaveLocationManager(defaults: defaults)
        self.saveLocation = resolvedSaveLocation
        self.controller = controller ?? RecordingController(saveLocation: resolvedSaveLocation)
        self.permissions = permissions ?? PermissionManager()
        self.clock = clock ?? SystemDurationClock()
        self.defaults = defaults
        self.showOnboarding = !defaults.bool(forKey: onboardingCompletedKey)
        self.controller.onStreamError = { [weak self] message in
            self?.handleStreamFailure(message)
        }
        refreshSaveLocationDisplay()
        // Re-probe permission whenever the app regains focus, so granting Screen
        // Recording in System Settings takes effect without a relaunch.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.checkPermission() }
        }
        Task {
            await checkPermission()
        }
    }

    deinit {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }

    // MARK: - Public Methods

    /// Check permission status
    func checkPermission() async {
        permissionStatus = await permissions.checkPermission()
    }

    /// Request permission
    func requestPermission() async {
        let granted = await permissions.requestPermission()
        permissionStatus = granted ? .granted : .denied

        if !granted {
            presentError(
                "Home Rec needs Screen Recording permission to capture audio (it never records your screen). You can turn it on in System Settings.",
                recovery: .openSettings
            )
        }
    }

    /// Start recording
    func startRecording() async {
        // Only legal from idle or a prior error state.
        guard state.canTransition(to: .starting) else { return }

        // Check permission first; if not granted, remain in the current state.
        if permissionStatus != .granted {
            await requestPermission()
            if permissionStatus != .granted {
                return
            }
        }

        transition(to: .starting)

        do {
            // Wire waveform callback
            controller.onWaveformData = { [weak self] samples in
                Task { @MainActor in
                    self?.waveformSamples = samples
                }
            }
            // Start recording
            let fileURL = try await controller.startRecording()
            lastRecordingURL = fileURL
            recordingStartTime = clock.now
            duration = 0
            longRecordingWarned = false

            transition(to: .recording)

            // Start duration timer
            startTimer()

            // If the chosen save folder was unavailable, the recording fell back to
            // the Desktop — tell the user (non-blocking; recording continues).
            if saveLocation.isConfiguredLocationUnavailable {
                presentError(RecorderError.saveLocationUnavailable.message, recovery: .chooseFolder)
            }

        } catch RecordingControllerError.insufficientDiskSpace {
            Log.recorder.error("Refusing to record: insufficient disk space")
            transition(to: .error(.diskFull))
        } catch {
            Log.recorder.error("Failed to start recording: \(error.localizedDescription, privacy: .public)")
            transition(to: .error(.startFailed(error.localizedDescription)))
        }
    }

    /// Stop recording
    func stopRecording() async {
        guard state.canTransition(to: .stopping) else { return }

        transition(to: .stopping)

        do {
            try await controller.stopRecording()

            stopTimer()
            waveformSamples = Array(repeating: 0, count: 200)

            transition(to: .idle)

        } catch {
            Log.recorder.error("Failed to stop recording: \(error.localizedDescription, privacy: .public)")
            transition(to: .error(.stopFailed(error.localizedDescription)))
        }
    }

    /// Toggle recording state
    func toggleRecording() async {
        switch state {
        case .idle, .error:
            await startRecording()
        case .recording:
            await stopRecording()
        case .starting, .stopping, .recovering:
            // Ignore taps during in-flight transitions.
            break
        }
    }

    /// Reveal recording in Finder
    func revealInFinder() {
        guard let url = lastRecordingURL else { return }

        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Open System Settings
    func openSystemSettings() {
        permissions.openSystemPreferences()
    }

    /// Present the folder chooser; persist the picked directory.
    func chooseSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = saveLocation.resolvedDirectory
        panel.prompt = "Choose"
        panel.message = "Choose where Home Rec saves recordings"

        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            saveLocation.setSaveDirectory(url)
            refreshSaveLocationDisplay()
        }
    }

    /// Reset the save location back to the Desktop default.
    func resetSaveLocation() {
        saveLocation.reset()
        refreshSaveLocationDisplay()
    }

    /// Mark first-run onboarding complete and dismiss it.
    func completeOnboarding() {
        defaults.set(true, forKey: onboardingCompletedKey)
        showOnboarding = false
    }

    /// Re-open the onboarding sheet (e.g. from the Help menu).
    func showOnboardingAgain() {
        showOnboarding = true
    }

    // MARK: - Private Methods

    /// Handle an unexpected capture-stream failure mid-recording: surface the
    /// error state immediately, then finalize the partial recording so the
    /// audio captured before the failure is preserved.
    private func handleStreamFailure(_ message: String) {
        guard state == .recording else { return }
        stopTimer()
        waveformSamples = Array(repeating: 0, count: 200)
        transition(to: .error(.streamFailed(message)))
        Task { [weak self] in
            await self?.controller.finalizeAfterFailure()
        }
    }

    /// Apply a state transition, rejecting illegal ones. Surfaces the alert when
    /// entering an error state.
    private func transition(to next: RecordingState) {
        guard state.canTransition(to: next) else {
            Log.recorder.error("Rejected illegal recording-state transition")
            return
        }
        state = next
        if case .error(let recorderError) = next {
            presentError(recorderError.message, recovery: recorderError.recovery)
        }
    }

    /// Start duration timer
    private func startTimer() {
        clock.startTicking(every: 0.1) { [weak self] in
            guard let self, let startTime = self.recordingStartTime else { return }
            self.duration = self.clock.now.timeIntervalSince(startTime)
            if !self.longRecordingWarned && self.duration >= DiskSpace.longRecordingThreshold {
                self.longRecordingWarned = true
                self.showLongRecordingWarning = true
            }
        }
    }

    /// Stop duration timer
    private func stopTimer() {
        clock.stopTicking()
    }

    /// Present a user-facing error with optional recovery action.
    private func presentError(_ message: String, recovery: RecoverySuggestion?) {
        errorMessage = message
        recoverySuggestion = recovery
        showError = true
    }

    /// Perform the current error's recovery action (from the alert button).
    func performRecovery() {
        let suggestion = recoverySuggestion
        showError = false
        switch suggestion {
        case .openSettings:
            openSystemSettings()
        case .tryAgain:
            Task { await startRecording() }
        case .chooseFolder:
            chooseSaveLocation()
        case nil:
            break
        }
    }

    /// Refresh the published save-location display from the provider.
    private func refreshSaveLocationDisplay() {
        saveLocationName = saveLocation.configuredDirectory?.lastPathComponent ?? "Desktop"
        hasCustomSaveLocation = saveLocation.configuredDirectory != nil
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
        switch state {
        case .recording:
            return "Recording"
        case .starting:
            return "Starting…"
        case .stopping:
            return "Stopping…"
        case .recovering:
            return "Recovering…"
        case .error:
            return "Something went wrong"
        case .idle:
            return permissionStatus != .granted ? "Almost ready" : "Play something, then hit record"
        }
    }
}

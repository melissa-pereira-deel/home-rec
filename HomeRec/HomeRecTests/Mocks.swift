//
//  Mocks.swift
//  HomeRecTests
//
//  Test doubles for the recording protocols, enabling hardware-free tests
//  of the workflow (BL-003 seams used by BL-020 / BL-005).
//

import Foundation
import AVFoundation
@testable import HomeRec

@MainActor
final class MockAudioCapturing: AudioCapturing {
    var capturing = false
    var onStreamError: (@MainActor (String) -> Void)?
    private(set) var setupCount = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var cleanupCount = 0
    /// The source passed to the most recent `setupCapture`, for assertions (BL-100).
    private(set) var lastSource: AudioSource?
    private var audioCallback: ((AVAudioPCMBuffer) -> Void)?

    func setupCapture(source: AudioSource, audioCallback: @escaping (AVAudioPCMBuffer) -> Void) async throws {
        setupCount += 1
        lastSource = source
        self.audioCallback = audioCallback
    }

    func startCapture() async throws {
        startCount += 1
        capturing = true
    }

    func stopCapture() async throws {
        stopCount += 1
        capturing = false
    }

    func cleanup() async {
        cleanupCount += 1
    }

    /// Simulate the capture stream dying unexpectedly.
    func simulateStreamError(_ message: String) {
        capturing = false
        onStreamError?(message)
    }
}

@MainActor
final class MockAudioFileWriting: AudioFileWriting {
    var onWaveformData: (([Float]) -> Void)?
    private(set) var recording = false
    private(set) var startCount = 0
    private(set) var stopCount = 0
    /// Format passed to the most recent `startRecording(to:format:)`, for assertions.
    private(set) var lastStartFormat: AudioFormat?
    /// Fired each time `stopRecording()` (the finalize point) is called.
    var onStop: (() -> Void)?
    /// If set, `stopRecording()` throws this — models a finalize failure so the
    /// controller's teardown-before-rethrow ordering can be asserted (BL-016).
    var stopError: Error?

    func startRecording(to fileURL: URL, format: AudioFormat) throws {
        startCount += 1
        lastStartFormat = format
        recording = true
    }

    func processAudioSample(_ pcmBuffer: AVAudioPCMBuffer) {}

    func stopRecording() throws {
        stopCount += 1
        recording = false
        onStop?()
        if let stopError { throw stopError }
    }
}

@MainActor
final class MockPermissionProviding: PermissionProviding {
    var status: PermissionStatus
    private(set) var openSettingsCount = 0
    /// Probes received, so tests can assert a poll loop actually stopped —
    /// a leaked loop is invisible from published state alone.
    private(set) var checkCount = 0
    /// Kinds the caller asked about, in order.
    private(set) var requestedKinds: [PermissionKind] = []
    /// Suspends `checkPermission` until `resumePendingChecks()` is called, so a
    /// test can hold one probe mid-flight and start a second — the shape of the
    /// overlapping-probe race.
    var holdsChecks = false
    private var pending: [CheckedContinuation<Void, Never>] = []

    /// Silent launch-time reads, counted separately from authoritative probes —
    /// the whole point of BL-085 is *which* of the two a call site uses.
    private(set) var preflightCount = 0
    /// What `preflight` reports, independent of `status`. Defaults to tracking
    /// `status`; pin it to model the real API's latching, where the system value
    /// moves on while preflight keeps answering with what it saw at launch.
    var preflightStatus: PermissionStatus?

    init(_ status: PermissionStatus = .granted) {
        self.status = status
    }

    func preflight(_ kind: PermissionKind = .screenCapture) -> PermissionStatus {
        preflightCount += 1
        return preflightStatus ?? status
    }

    func checkPermission(_ kind: PermissionKind = .screenCapture) async -> PermissionStatus {
        checkCount += 1
        requestedKinds.append(kind)
        if holdsChecks {
            await withCheckedContinuation { pending.append($0) }
        }
        return status
    }

    func requestPermission(_ kind: PermissionKind = .screenCapture) async -> Bool { status == .granted }
    func openSystemPreferences(for kind: PermissionKind = .screenCapture) { openSettingsCount += 1 }

    /// Release every held probe.
    func resumePendingChecks() {
        let held = pending
        pending = []
        held.forEach { $0.resume() }
    }
}

/// Poll clock that never returns from a wait, so a deadline built on it never
/// fires — lets a test hold the "probe still in flight" state open.
@MainActor
final class NeverPollClock: PollClock {
    func sleep(for interval: TimeInterval) async throws {
        // Long enough to never fire within a test, but still cancellable — an
        // uncancellable wait would leak a task past the end of the run.
        try await Task.sleep(nanoseconds: .max / 2)
    }
}

/// Poll clock whose waits return immediately, so a poll loop runs at full speed
/// under test and the suite never sleeps.
@MainActor
final class ImmediatePollClock: PollClock {
    private(set) var sleepCount = 0
    func sleep(for interval: TimeInterval) async throws {
        sleepCount += 1
        try Task.checkCancellation()
        await Task.yield()
    }
}

@MainActor
final class MockAudioSourceProviding: AudioSourceProviding {
    var selectedSource: AudioSource
    var availableAppsResult: [RunningAppInfo] = []
    /// If set, `validate(_:)` throws this instead of succeeding.
    var validateError: Error?
    private(set) var setCount = 0
    private(set) var validateCount = 0

    init(selectedSource: AudioSource = .systemAll) {
        self.selectedSource = selectedSource
    }

    func setSelectedSource(_ source: AudioSource) {
        setCount += 1
        selectedSource = source
    }

    func validate(_ source: AudioSource) async throws {
        validateCount += 1
        if let validateError { throw validateError }
    }

    private(set) var availableAppsCallCount = 0

    func availableApps() async throws -> [RunningAppInfo] {
        availableAppsCallCount += 1
        return availableAppsResult
    }

    var availableInputDevicesResult: [InputDeviceInfo] = []

    func availableInputDevices() -> [InputDeviceInfo] {
        availableInputDevicesResult
    }

    var knownAppNamesResult: [String: String] = [:]

    func knownAppName(forBundleID bundleID: String) -> String? {
        knownAppNamesResult[bundleID]
    }
}

@MainActor
final class MockSaveLocationProviding: SaveLocationProviding {
    var configuredDirectory: URL?
    var resolvedDirectory: URL
    var isConfiguredLocationUnavailable = false
    private(set) var setCount = 0
    private(set) var resetCount = 0

    init(directory: URL) {
        self.resolvedDirectory = directory
        self.configuredDirectory = directory
    }

    func setSaveDirectory(_ url: URL) {
        setCount += 1
        configuredDirectory = url
        resolvedDirectory = url
    }

    func reset() {
        resetCount += 1
        configuredDirectory = nil
    }
}

/// Install location as a test input (BL-082). Defaults to `.applications` so the
/// existing suites — which care about recording, not about where the bundle
/// lives — are unaffected by the location tier.
@MainActor
final class MockInstallLocationProviding: InstallLocationProviding {
    var location: InstallLocation
    var bundleURL: URL

    init(
        _ location: InstallLocation = .applications,
        bundleURL: URL = URL(fileURLWithPath: "/Applications/Home Rec.app")
    ) {
        self.location = location
        self.bundleURL = bundleURL
    }
}

@MainActor
final class ManualClock: DurationClock {
    var now: Date = Date(timeIntervalSinceReferenceDate: 0)
    private var tick: (@MainActor () -> Void)?

    var isTicking: Bool { tick != nil }

    func startTicking(every interval: TimeInterval, onTick: @escaping @MainActor () -> Void) {
        tick = onTick
    }

    func stopTicking() {
        tick = nil
    }

    /// Advance the clock and fire the tick once, simulating a timer firing.
    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
        tick?()
    }
}

@MainActor
final class MockRecordingControlling: RecordingControlling {
    var onWaveformData: (([Float]) -> Void)?
    var onStreamError: (@MainActor (String) -> Void)?
    private(set) var isRecording = false
    private(set) var recordingURL: URL?

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var finalizeCount = 0

    /// If set, `startRecording(format:)` throws this instead of succeeding.
    var startError: Error?
    /// If set, `stopRecording()` throws this instead of succeeding.
    var stopError: Error?
    var fileURL = URL(fileURLWithPath: "/tmp/mock-recording.wav")
    /// Format passed to the most recent `startRecording(format:)`, for assertions.
    private(set) var lastStartFormat: AudioFormat?
    /// Fired when `finalizeAfterFailure()` runs.
    var onFinalize: (() -> Void)?

    func startRecording(format: AudioFormat) async throws -> URL {
        startCount += 1
        lastStartFormat = format
        if let startError { throw startError }
        isRecording = true
        recordingURL = fileURL
        return fileURL
    }

    func stopRecording() async throws {
        stopCount += 1
        if let stopError { throw stopError }
        isRecording = false
        recordingURL = nil
    }

    func finalizeAfterFailure() async {
        finalizeCount += 1
        isRecording = false
        recordingURL = nil
        onFinalize?()
    }

    /// Simulate the underlying capture stream failing.
    func emitStreamError(_ message: String) {
        onStreamError?(message)
    }
}

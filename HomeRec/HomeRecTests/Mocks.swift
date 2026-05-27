//
//  Mocks.swift
//  HomeRecTests
//
//  Test doubles for the recording protocols, enabling hardware-free tests
//  of the workflow (BL-003 seams used by BL-020 / BL-005).
//

import Foundation
import CoreMedia
@testable import HomeRec

@MainActor
final class MockAudioCapturing: AudioCapturing {
    var capturing = false
    var onStreamError: (@MainActor (String) -> Void)?
    private(set) var setupCount = 0
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var cleanupCount = 0
    private var audioCallback: ((CMSampleBuffer) -> Void)?

    func setupCapture(audioCallback: @escaping (CMSampleBuffer) -> Void) async throws {
        setupCount += 1
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
    /// Fired each time `stopRecording()` (the finalize point) is called.
    var onStop: (() -> Void)?

    func startRecording(to fileURL: URL) throws {
        startCount += 1
        recording = true
    }

    func processAudioSample(_ sampleBuffer: CMSampleBuffer) {}

    func stopRecording() throws {
        stopCount += 1
        recording = false
        onStop?()
    }
}

@MainActor
final class MockPermissionProviding: PermissionProviding {
    var status: PermissionStatus
    private(set) var openSettingsCount = 0

    init(_ status: PermissionStatus = .granted) {
        self.status = status
    }

    func checkPermission() async -> PermissionStatus { status }
    func requestPermission() async -> Bool { status == .granted }
    func openSystemPreferences() { openSettingsCount += 1 }
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

    /// If set, `startRecording()` throws this instead of succeeding.
    var startError: Error?
    /// If set, `stopRecording()` throws this instead of succeeding.
    var stopError: Error?
    var fileURL = URL(fileURLWithPath: "/tmp/mock-recording.wav")
    /// Fired when `finalizeAfterFailure()` runs.
    var onFinalize: (() -> Void)?

    func startRecording() async throws -> URL {
        startCount += 1
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

//
//  RecorderViewModelTests.swift
//  HomeRecTests
//
//  BL-005: view-model lifecycle tests — state transitions, permission gating,
//  error handling, duration timing (via injected clock), and stream-failure.
//  Deterministic, no hardware/permission, no sleeps.
//

import Testing
import Foundation
@testable import HomeRec

/// A controllable error with a known message for assertions.
private struct TestError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
struct RecorderViewModelTests {

    private func makeViewModel(
        controller: MockRecordingControlling? = nil,
        permission: PermissionStatus = .granted,
        clock: ManualClock? = nil,
        saveLocation: SaveLocationProviding? = nil
    ) -> RecorderViewModel {
        RecorderViewModel(
            controller: controller ?? MockRecordingControlling(),
            permissions: MockPermissionProviding(permission),
            clock: clock ?? ManualClock(),
            saveLocation: saveLocation
        )
    }

    @Test("Initial state is idle")
    func initialStateIsIdle() {
        let viewModel = makeViewModel()
        #expect(viewModel.state == .idle)
        #expect(viewModel.isRecording == false)
    }

    @Test("Re-probing reflects a newly granted permission without relaunch (BL-040)")
    func permissionReprobeUpdatesState() async {
        let permission = MockPermissionProviding(.denied)
        let viewModel = RecorderViewModel(
            controller: MockRecordingControlling(),
            permissions: permission,
            clock: ManualClock()
        )

        await viewModel.checkPermission()
        #expect(viewModel.permissionStatus == .denied)

        // User flips the toggle in System Settings; app re-probes on regaining focus.
        permission.status = .granted
        await viewModel.checkPermission()
        #expect(viewModel.permissionStatus == .granted)
    }

    @Test("startRecording with granted permission transitions to recording")
    func startWithPermissionRecords() async {
        let controller = MockRecordingControlling()
        let viewModel = makeViewModel(controller: controller, permission: .granted)

        await viewModel.startRecording()

        #expect(viewModel.state == .recording)
        #expect(viewModel.isRecording)
        #expect(controller.startCount == 1)
        #expect(viewModel.lastRecordingURL == controller.fileURL)
    }

    @Test("startRecording with denied permission does not record and surfaces an error")
    func startWithoutPermissionDoesNotRecord() async {
        let controller = MockRecordingControlling()
        let viewModel = makeViewModel(controller: controller, permission: .denied)

        await viewModel.startRecording()

        #expect(viewModel.state == .idle)
        #expect(controller.startCount == 0)
        #expect(viewModel.showError)
    }

    @Test("stopRecording returns to idle and resets the waveform")
    func stopReturnsToIdle() async {
        let controller = MockRecordingControlling()
        let viewModel = makeViewModel(controller: controller)

        await viewModel.startRecording()
        #expect(viewModel.state == .recording)

        await viewModel.stopRecording()

        #expect(viewModel.state == .idle)
        #expect(controller.stopCount == 1)
        #expect(viewModel.waveformSamples == Array(repeating: 0, count: 200))
    }

    @Test("A controller start error transitions to .error with plain copy + recovery")
    func startErrorSurfacesErrorState() async {
        let controller = MockRecordingControlling()
        controller.startError = TestError(message: "no capture device")
        let viewModel = makeViewModel(controller: controller)

        await viewModel.startRecording()

        #expect(viewModel.state == .error(.startFailed("no capture device")))
        // User-facing copy is plain language and does not leak the raw detail.
        #expect(viewModel.errorMessage == RecorderError.startFailed("no capture device").message)
        #expect(viewModel.errorMessage?.contains("no capture device") == false)
        #expect(viewModel.recoverySuggestion == .tryAgain)
        #expect(viewModel.showError)
    }

    @Test("Recovery action .openSettings opens System Settings and dismisses the error")
    func recoveryOpensSettings() async {
        let controller = MockRecordingControlling()
        let permission = MockPermissionProviding(.granted)
        let viewModel = RecorderViewModel(controller: controller, permissions: permission, clock: ManualClock())

        await viewModel.startRecording()
        controller.emitStreamError("permission turned off")
        #expect(viewModel.recoverySuggestion == .openSettings)
        #expect(viewModel.showError)

        viewModel.performRecovery()

        #expect(permission.openSettingsCount == 1)
        #expect(viewModel.showError == false)
    }

    @Test("Duration advances using the injected clock, not a real timer")
    func durationAdvancesWithClock() async {
        let clock = ManualClock()
        let viewModel = makeViewModel(clock: clock)

        await viewModel.startRecording()
        #expect(viewModel.duration == 0)
        #expect(clock.isTicking)

        clock.advance(by: 5)
        #expect(viewModel.duration == 5)

        clock.advance(by: 2.5)
        #expect(viewModel.duration == 7.5)

        await viewModel.stopRecording()
        #expect(clock.isTicking == false)
    }

    @Test("Onboarding shows on first launch, and not after completion (BL-041)")
    func onboardingShownOnce() {
        let defaults = UserDefaults(suiteName: "onboarding-test-\(UUID().uuidString)")!

        let first = RecorderViewModel(
            controller: MockRecordingControlling(),
            permissions: MockPermissionProviding(),
            clock: ManualClock(),
            defaults: defaults
        )
        #expect(first.showOnboarding)

        first.completeOnboarding()
        #expect(first.showOnboarding == false)

        // A fresh launch with the same defaults does not show it again.
        let second = RecorderViewModel(
            controller: MockRecordingControlling(),
            permissions: MockPermissionProviding(),
            clock: ManualClock(),
            defaults: defaults
        )
        #expect(second.showOnboarding == false)

        // …but it can be re-opened on demand.
        second.showOnboardingAgain()
        #expect(second.showOnboarding)
    }

    @Test("View model reflects a custom save location and resets it to Desktop")
    func saveLocationDisplayAndReset() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("vm-save-\(UUID().uuidString)", isDirectory: true)
        let mock = MockSaveLocationProviding(directory: dir)
        let viewModel = makeViewModel(saveLocation: mock)

        #expect(viewModel.saveLocationName == dir.lastPathComponent)
        #expect(viewModel.hasCustomSaveLocation)

        viewModel.resetSaveLocation()

        #expect(viewModel.saveLocationName == "Desktop")
        #expect(viewModel.hasCustomSaveLocation == false)
        #expect(mock.resetCount == 1)
    }

    @Test("Disk-space threshold logic")
    func diskSpaceThreshold() {
        #expect(DiskSpace.hasEnoughSpace(availableBytes: DiskSpace.minimumBytesToRecord))
        #expect(DiskSpace.hasEnoughSpace(availableBytes: DiskSpace.minimumBytesToRecord - 1) == false)
        #expect(DiskSpace.hasEnoughSpace(availableBytes: 10 * 1024 * 1024) == false)
    }

    @Test("Insufficient disk space surfaces a disk-full error, not a generic one")
    func insufficientDiskSpaceSurfacesDiskFull() async {
        let controller = MockRecordingControlling()
        controller.startError = RecordingControllerError.insufficientDiskSpace
        let viewModel = makeViewModel(controller: controller)

        await viewModel.startRecording()

        #expect(viewModel.state == .error(.diskFull))
        #expect(viewModel.errorMessage == RecorderError.diskFull.message)
    }

    @Test("A long recording triggers a one-time warning once past the threshold")
    func longRecordingWarning() async {
        let clock = ManualClock()
        let viewModel = makeViewModel(clock: clock)

        await viewModel.startRecording()
        #expect(viewModel.showLongRecordingWarning == false)

        clock.advance(by: DiskSpace.longRecordingThreshold + 1)
        #expect(viewModel.showLongRecordingWarning)
    }

    @Test("Stream-failure callback transitions to .error and finalizes once")
    func streamFailureHandled() async {
        let controller = MockRecordingControlling()
        let viewModel = makeViewModel(controller: controller)

        await viewModel.startRecording()
        #expect(viewModel.state == .recording)

        await confirmation("controller finalized exactly once") { finalized in
            controller.onFinalize = { finalized() }
            controller.emitStreamError("display went to sleep")

            #expect(viewModel.state == .error(.streamFailed("display went to sleep")))

            while controller.finalizeCount == 0 {
                await Task.yield()
            }
        }

        #expect(controller.finalizeCount == 1)
        #expect(viewModel.isRecording == false)
    }
}

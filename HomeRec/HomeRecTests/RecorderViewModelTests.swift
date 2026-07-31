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

    @Test("The capture source the menu reads is the instance it was given")
    func captureSourceIsSharedNotDuplicated() {
        // The menu writes the selection through `viewModel.audioSource`; the
        // controller reads it at `startRecording`. A second instance would make
        // that write invisible to the next recording — silent today, because
        // every read hits UserDefaults and so duplicates agree by accident.
        // Pin the exposure before BL-111's in-memory cache removes that accident.
        let shared = MockAudioSourceProviding(selectedSource: .app(bundleID: "com.example.app"))
        let viewModel = RecorderViewModel(
            controller: MockRecordingControlling(),
            permissions: MockPermissionProviding(.granted),
            clock: ManualClock(),
            audioSource: shared
        )
        #expect(viewModel.audioSource === shared)
        #expect(viewModel.audioSource.selectedSource == .app(bundleID: "com.example.app"))
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
        // Denied, because that is what a permission-related stream failure means —
        // and because opening Settings is now gated on the answer (BL-087): an
        // already-granted user has nothing to go there for.
        let permission = MockPermissionProviding(.denied)
        let viewModel = RecorderViewModel(
            controller: controller,
            permissions: permission,
            clock: ManualClock(),
            pollClock: ImmediatePollClock(),
            registrationTimeout: 0
        )
        viewModel.permissionStatus = .granted   // stale, as it would be mid-recording

        await viewModel.startRecording()
        controller.emitStreamError("permission turned off")
        #expect(viewModel.recoverySuggestion == .openSettings)
        #expect(viewModel.showError)

        viewModel.performRecovery()
        // Opening Settings is now async: it waits for the registering probe first
        // so the pane doesn't render a list Home Rec isn't in yet (BL-087).
        for _ in 0..<2000 where permission.openSettingsCount == 0 { await Task.yield() }

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

    /// BL-016 made the stop path's catch branch reachable (finalize errors used
    /// to be swallowed inside AudioRecorder). The timer must be torn down there
    /// too — otherwise it keeps republishing `duration` at 10Hz for the lifetime
    /// of the app, and can fire the long-recording warning about a recording
    /// that has already ended.
    @Test("A failed stop surfaces the error and still stops the timer")
    func failedStopStopsTheTimer() async {
        struct FinalizeFailure: Error {}
        let controller = MockRecordingControlling()
        let clock = ManualClock()
        let viewModel = makeViewModel(controller: controller, clock: clock)

        await viewModel.startRecording()
        #expect(clock.isTicking)

        controller.stopError = FinalizeFailure()
        await viewModel.stopRecording()

        // The failure is surfaced, not silently treated as a clean stop…
        if case .error(.stopFailed) = viewModel.state {} else {
            Issue.record("expected .stopFailed, got \(viewModel.state)")
        }
        // …and the timer is not leaked.
        #expect(clock.isTicking == false)
        #expect(viewModel.isRecording == false)
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

    @Test("An unavailable save folder records to Desktop with a non-blocking notice")
    func unavailableSaveLocationShowsNoticeWhileRecording() async {
        let gone = FileManager.default.temporaryDirectory
            .appendingPathComponent("gone-\(UUID().uuidString)", isDirectory: true)
        let saveLocation = MockSaveLocationProviding(directory: gone)
        saveLocation.isConfiguredLocationUnavailable = true
        let viewModel = makeViewModel(saveLocation: saveLocation)

        await viewModel.startRecording()

        #expect(viewModel.state == .recording)          // recording proceeds (to Desktop)
        #expect(viewModel.showError)                     // non-blocking notice
        #expect(viewModel.recoverySuggestion == .chooseFolder)
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

    // MARK: - Format selection (BL-015)

    /// An isolated UserDefaults so format-persistence tests don't bleed together.
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "BL015-\(UUID().uuidString)")!
    }

    private func makeViewModel(
        controller: MockRecordingControlling,
        defaults: UserDefaults
    ) -> RecorderViewModel {
        RecorderViewModel(
            controller: controller,
            permissions: MockPermissionProviding(.granted),
            clock: ManualClock(),
            saveLocation: MockSaveLocationProviding(directory: FileManager.default.temporaryDirectory),
            defaults: defaults
        )
    }

    @Test("Default format is WAV with empty defaults")
    func defaultFormatIsWav() {
        let vm = makeViewModel(controller: MockRecordingControlling(), defaults: freshDefaults())
        #expect(vm.selectedFormat == .wav)
    }

    @Test("setFormat updates the published value and persists it")
    func setFormatPersists() {
        let defaults = freshDefaults()
        let vm = makeViewModel(controller: MockRecordingControlling(), defaults: defaults)

        vm.setFormat(.m4a)

        #expect(vm.selectedFormat == .m4a)
        #expect(defaults.string(forKey: "selectedFormat") == "m4a")
    }

    @Test("Selected format persists across view-model instances")
    func formatPersistsAcrossInstances() {
        let defaults = freshDefaults()
        makeViewModel(controller: MockRecordingControlling(), defaults: defaults).setFormat(.m4a)

        let reopened = makeViewModel(controller: MockRecordingControlling(), defaults: defaults)
        #expect(reopened.selectedFormat == .m4a)
    }

    @Test("An unparseable stored format falls back to WAV")
    func garbageStoredFormatFallsBack() {
        let defaults = freshDefaults()
        defaults.set("garbage", forKey: "selectedFormat")

        let vm = makeViewModel(controller: MockRecordingControlling(), defaults: defaults)
        #expect(vm.selectedFormat == .wav)
    }

    @Test("A valid-but-unavailable stored format falls back to WAV")
    func unavailableStoredFormatFallsBack() {
        let defaults = freshDefaults()
        defaults.set("mp3", forKey: "selectedFormat")   // valid raw value, not in `available`

        let vm = makeViewModel(controller: MockRecordingControlling(), defaults: defaults)
        #expect(vm.selectedFormat == .wav)
    }

    @Test("setFormat rejects a format that isn't available")
    func setFormatRejectsUnavailable() {
        let defaults = freshDefaults()
        let vm = makeViewModel(controller: MockRecordingControlling(), defaults: defaults)

        vm.setFormat(.mp3)   // not in AudioFormat.available

        #expect(vm.selectedFormat == .wav)
        #expect(defaults.string(forKey: "selectedFormat") == nil)
    }

    @Test("The selected format flows into the controller at record start")
    func selectedFormatFlowsToController() async {
        let controller = MockRecordingControlling()
        let vm = makeViewModel(controller: controller, defaults: freshDefaults())

        vm.setFormat(.m4a)
        await vm.startRecording()

        #expect(controller.lastStartFormat == .m4a)
    }
}

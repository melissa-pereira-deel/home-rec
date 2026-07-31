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

// MARK: - The source name shown on both surfaces

@MainActor
struct CaptureSourceNameTests {

    private func makeViewModel(
        source: MockAudioSourceProviding
    ) -> RecorderViewModel {
        RecorderViewModel(
            controller: MockRecordingControlling(),
            permissions: MockPermissionProviding(.granted),
            clock: ManualClock(),
            audioSource: source
        )
    }

    @Test("A selected app is named, not shown as a bundle identifier")
    func selectedAppIsNamed() {
        // Regression: `captureSourceName` read a `knownAppNames` dictionary on
        // the view model that nothing ever wrote, so this fell through to
        // `?? bundleID` and the status line read "Ready to record
        // com.ableton.live" on both surfaces — for the headline feature.
        let source = MockAudioSourceProviding(selectedSource: .app(bundleID: "com.ableton.live"))
        source.knownAppNamesResult = ["com.ableton.live": "Ableton Live"]
        let viewModel = makeViewModel(source: source)

        #expect(viewModel.captureSourceName == "Ableton Live")
        #expect(viewModel.statusText == "Ready to record Ableton Live")
    }

    @Test("An app never seen in the picker still renders something usable")
    func unknownAppFallsBackToBundleID() {
        // Only reachable for a selection restored from a build that predates the
        // name memory. Ugly, but naming it wrongly would be worse.
        let source = MockAudioSourceProviding(selectedSource: .app(bundleID: "com.unknown.app"))
        let viewModel = makeViewModel(source: source)
        #expect(viewModel.captureSourceName == "com.unknown.app")
    }

    @Test("Naming the source performs zero app enumeration")
    func namingNeverEnumerates() {
        // Enumeration costs a permission prompt. The status line is evaluated on
        // every view update, so if it ever enumerated the app would prompt
        // continuously — the worst possible version of the BL-085 bug.
        let source = MockAudioSourceProviding(selectedSource: .app(bundleID: "com.ableton.live"))
        source.knownAppNamesResult = ["com.ableton.live": "Ableton Live"]
        let viewModel = makeViewModel(source: source)

        _ = viewModel.statusText
        _ = viewModel.captureSourceName
        #expect(source.availableAppsCallCount == 0)
    }
}

// MARK: - The settings shelf follows the state machine

@MainActor
struct SettingsShelfVisibilityTests {

    private func makeViewModel() -> RecorderViewModel {
        RecorderViewModel(
            controller: MockRecordingControlling(),
            permissions: MockPermissionProviding(.granted),
            clock: ManualClock(),
            audioSource: MockAudioSourceProviding()
        )
    }

    @Test("The shelf is shown when idle and hidden while a take is running")
    func shelfHidesForTheWholeTake() async {
        let viewModel = makeViewModel()
        #expect(viewModel.showsSettingsShelf)

        await viewModel.startRecording()
        #expect(viewModel.state == .recording)
        #expect(viewModel.showsSettingsShelf == false)

        await viewModel.stopRecording()
        #expect(viewModel.showsSettingsShelf)
    }

    @Test("The shelf reappears after a failure so the user can change settings to fix it")
    func shelfIsAvailableInErrorState() async {
        let controller = MockRecordingControlling()
        controller.startError = NSError(domain: "test", code: 1)
        let viewModel = RecorderViewModel(
            controller: controller,
            permissions: MockPermissionProviding(.granted),
            clock: ManualClock(),
            audioSource: MockAudioSourceProviding()
        )

        await viewModel.startRecording()
        #expect(viewModel.showsSettingsShelf)
    }

    @Test("The shelf and the capture-source menu are driven by one rule")
    func shelfAgreesWithMenuSection() {
        // Was gated on `isRecording`, i.e. `.recording` **only** — so the shelf
        // stayed visible and clickable through `.starting` and `.stopping`,
        // offering a format switch for a take whose format was already captured.
        // Two rules for "settings are locked" is what let them diverge; this
        // pins that there is now one. The per-state truth table lives in
        // `CaptureSourceMenuTests.lockMirrorsRecordingState`.
        #expect(RecordingState.starting.allowsCaptureSourceChange == false)
        #expect(RecordingState.stopping.allowsCaptureSourceChange == false)
        #expect(RecordingState.recovering.allowsCaptureSourceChange == false)
    }
}

// MARK: - Errors from the v1.1 capture sources say what actually went wrong

@MainActor
struct CaptureSourceErrorTests {

    @Test("An unavailable source keeps its own copy instead of the generic message")
    func sourceUnavailableUsesItsOwnCopy() async {
        // Regression: every non-disk-space failure was flattened into
        // `.startFailed(error.localizedDescription)`, so a quit app or an
        // unplugged mic reported "Make sure some audio is playing, then try
        // again" — advice that cannot work for either cause — and discarded the
        // accurate copy `AudioSourceError` had already written.
        let source = MockAudioSourceProviding(selectedSource: .app(bundleID: "com.ableton.live"))
        source.validateError = AudioSourceError.appNotRunning("com.ableton.live")
        let controller = RecordingController(
            captureManager: MockAudioCapturing(),
            audioRecorder: MockAudioFileWriting(),
            saveLocation: MockSaveLocationProviding(directory: FileManager.default.temporaryDirectory),
            audioSource: source
        )
        let viewModel = RecorderViewModel(
            controller: controller,
            permissions: MockPermissionProviding(.granted),
            clock: ManualClock(),
            audioSource: source
        )

        await viewModel.startRecording()

        #expect(viewModel.state == .error(.sourceUnavailable(.appNotRunning("com.ableton.live"))))
        let message = try? #require(viewModel.errorMessage)
        #expect(message?.contains("not currently running") == true)
        #expect(message?.contains("audio is playing") == false)
    }

    @Test("An unavailable source does not offer Try again")
    func sourceUnavailableOffersNoRetry() {
        // The app is still closed and the mic is still unplugged, so a retry
        // fails identically. Offering it is a loop dressed as a way out.
        #expect(RecorderError.sourceUnavailable(.appNotRunning("x")).recovery == nil)
        #expect(RecorderError.sourceUnavailable(.micNotAvailable("y")).recovery == nil)
    }

    @Test("Denied microphone access points at Settings, never at Try again")
    func microphoneDeniedOffersSettings() {
        // Once denied, `AVCaptureDevice.requestAccess` returns false immediately
        // and without prompting — so `.tryAgain` here is an infinite loop with a
        // button on it. Settings is the only real way out.
        #expect(RecorderError.microphoneDenied.recovery == .openMicrophoneSettings)
        #expect(RecorderError.microphoneDenied.recovery != .tryAgain)
        #expect(RecorderError.microphoneDenied.message.contains("microphone"))
    }

    @Test("Microphone recovery opens the Microphone pane, not Screen Recording")
    func microphoneRecoveryOpensTheRightPane() {
        // Sending someone to the wrong System Settings pane is the exact failure
        // BL-081 existed to fix.
        #expect(PermissionKind.microphone.settingsAnchor == "Privacy_Microphone")
        #expect(PermissionKind.screenCapture.settingsAnchor == "Privacy_ScreenCapture")
    }
}

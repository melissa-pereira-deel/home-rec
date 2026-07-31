//
//  MonitorControllerTests.swift
//  HomeRecTests
//
//  BL-131: what can be asserted about live monitoring *without* hardware —
//  the mode state machine, persistence, and the invariant that a monitor
//  failure never touches recording.
//
//  Deliberately absent: anything that needs to hear something. Latency, glitch
//  behaviour under concurrent SCK mic capture, and the feedback warning are
//  human checks and are recorded as such rather than faked with a mock that
//  would prove nothing.
//

import Testing
import Foundation
@testable import HomeRec

@MainActor
struct MonitorControllerTests {

    private func makeDefaults() -> UserDefaults {
        let suite = UserDefaults(suiteName: "MonitorControllerTests-\(UUID().uuidString)")!
        return suite
    }

    // MARK: - The state machine

    @Test(
        "Monitoring runs exactly when the mode and recording state say it should",
        arguments: [
            (MonitoringMode.off, false, false),
            (MonitoringMode.off, true, false),
            (MonitoringMode.always, false, true),
            (MonitoringMode.always, true, true),
            (MonitoringMode.whileRecording, false, false),
            (MonitoringMode.whileRecording, true, true)
        ]
    )
    func shouldRunCoversEveryCombination(_ testCase: (MonitoringMode, Bool, Bool)) {
        let (mode, isRecording, expected) = testCase
        #expect(MonitorController.shouldRun(mode: mode, isRecording: isRecording) == expected)
    }

    @Test("Three modes, and every one of them is reachable")
    func modesAreExhaustiveAndDistinct() {
        // The spec had two booleans for these three meanings, which makes a
        // fourth state that is indistinguishable from `.always`. Pin that the
        // model has no unreachable combination.
        let outcomes = MonitoringMode.allCases.map { mode in
            [
                MonitorController.shouldRun(mode: mode, isRecording: false),
                MonitorController.shouldRun(mode: mode, isRecording: true)
            ]
        }
        #expect(MonitoringMode.allCases.count == 3)
        #expect(Set(outcomes.map(\.description)).count == 3)
    }

    // MARK: - Persistence

    @Test("Mode survives a relaunch")
    func modePersists() {
        let defaults = makeDefaults()
        let first = MonitorController(defaults: defaults)
        #expect(first.mode == .off)

        first.setMode(.whileRecording)

        let second = MonitorController(defaults: defaults)
        #expect(second.mode == .whileRecording)
    }

    @Test("Defaults to off on first run")
    func defaultsToOff() {
        // Monitoring through built-in speakers feeds back, and starting an engine
        // unasked would light the microphone indicator on launch.
        #expect(MonitorController(defaults: makeDefaults()).mode == .off)
    }

    @Test("An unreadable stored value falls back to off rather than throwing")
    func corruptStoredModeFallsBack() {
        let defaults = makeDefaults()
        defaults.set("monitor-everything-always", forKey: "monitoringMode")
        #expect(MonitorController(defaults: defaults).mode == .off)
    }

    // MARK: - The invariant that matters

    @Test("A monitor failure warns and never starts monitoring")
    func failureIsNonFatal() {
        // The whole point of BL-131 requirement 6: monitoring and recording
        // reliability are decoupled. `MonitorController` has no reference to
        // `RecorderViewModel` or `RecordingState` at all — the warning channel
        // is the only way out of this type — so a monitor failure is
        // *structurally* incapable of failing a recording.
        var warnings: [MonitorError] = []
        let controller = MonitorController(
            defaults: makeDefaults(),
            currentDeviceUID: { nil }   // no device -> cannot start
        )
        controller.onWarning = { warnings.append($0) }

        controller.setMode(.always)

        #expect(warnings == [.deviceUnavailable])
        #expect(controller.isMonitoring == false)
        // The mode still reflects what the user asked for: they turned it on,
        // and it should resume when a device appears rather than silently
        // reverting and making them wonder whether the click registered.
        #expect(controller.mode == .always)
    }

    @Test("Turning monitoring off stops it without a warning")
    func turningOffIsSilent() {
        var warnings: [MonitorError] = []
        let controller = MonitorController(defaults: makeDefaults(), currentDeviceUID: { nil })
        controller.setMode(.always)
        warnings.removeAll()
        controller.onWarning = { warnings.append($0) }

        controller.setMode(.off)

        #expect(controller.isMonitoring == false)
        #expect(warnings.isEmpty)
    }

    @Test("While-recording mode reacts to the recording lifecycle")
    func whileRecordingFollowsRecordingState() {
        var warnings: [MonitorError] = []
        let controller = MonitorController(defaults: makeDefaults(), currentDeviceUID: { nil })
        controller.onWarning = { warnings.append($0) }

        controller.setMode(.whileRecording)
        // Idle: nothing attempted, so nothing to warn about.
        #expect(warnings.isEmpty)

        controller.recordingStateChanged(isRecording: true)
        // Now it tried, and failed for want of a device — which is a warning,
        // not a recording failure.
        #expect(warnings == [.deviceUnavailable])

        controller.recordingStateChanged(isRecording: false)
        #expect(controller.isMonitoring == false)
    }
}

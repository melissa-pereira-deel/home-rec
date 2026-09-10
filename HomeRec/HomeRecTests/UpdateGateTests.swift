//
//  UpdateGateTests.swift
//  HomeRecTests
//
//  BL-034: the rule that keeps Sparkle from destroying a take.
//
//  Installing an update quits and relaunches the app. If that happens with a
//  recording open, the encoder never reaches `finalize()` — a WAV keeps a header
//  claiming length it doesn't have, an M4A loses its `moov` atom, and a FLAC is
//  unplayable until repaired. The gate is asserted here rather than in the
//  Sparkle glue because `SPUUpdater` reaches the network when constructed, so a
//  test that built one would be neither hermetic nor fast.
//

import Testing
import AppKit
@testable import HomeRec

@MainActor
struct UpdateGateTests {

    private func context(
        canInstall: Bool = true,
        unlocked: Bool = true,
        updaterUsable: Bool = true
    ) -> OverflowContext {
        OverflowContext(
            allowsCaptureSourceChange: unlocked,
            allowsUpdateInstall: canInstall,
            updaterIsUsable: updaterUsable
        )
    }

    private func updateRow(_ context: OverflowContext) -> OverflowAction? {
        OverflowMenu.actions(context).first { $0.id == "checkForUpdates" }
    }

    // MARK: - The rule

    @Test("Only states with no open file permit an update")
    func gateMirrorsRecordingState() {
        #expect(RecordingState.idle.allowsUpdateInstall)
        // Same reasoning as `allowsCaptureSourceChange`: an error state has no
        // take in flight, and updating is a legitimate way out of one.
        #expect(RecordingState.error(.startFailed("x")).allowsUpdateInstall)

        #expect(RecordingState.starting.allowsUpdateInstall == false)
        #expect(RecordingState.recording.allowsUpdateInstall == false)
        #expect(RecordingState.recovering.allowsUpdateInstall == false)
    }

    @Test("Stopping is blocked — it is the most dangerous moment, not the safest")
    func stoppingIsBlocked() {
        // The tempting reading of `.stopping` is "the recording is over, so it is
        // fine now". It is the opposite: `.stopping` is exactly when the file is
        // being finalized, so terminating here loses a take that was otherwise
        // complete. Called out separately because this is the case a reasonable
        // person gets wrong.
        #expect(RecordingState.stopping.allowsUpdateInstall == false)
    }

    // MARK: - The menu row

    @Test("The row is always present, in both states")
    func rowAlwaysExists() {
        // The design decision this guards: unlike the capture-source rows, which
        // are *hidden* while recording, this one is greyed. An app-level action
        // that is present in every other state would read as a bug if it
        // vanished mid-take — and a grey row can explain itself via its tooltip
        // where an absent row cannot.
        #expect(updateRow(context(canInstall: true)) != nil)
        #expect(updateRow(context(canInstall: false)) != nil)
    }

    @Test("The row is disabled exactly when an update would be unsafe")
    func rowFollowsTheGate() throws {
        #expect(try #require(updateRow(context(canInstall: true))).isEnabled)
        #expect(try #require(updateRow(context(canInstall: false))).isEnabled == false)
    }

    @Test("A disabled row explains itself; an enabled one stays quiet")
    func tooltipOnlyWhenDisabled() throws {
        // Tooltips are used sparingly in this menu — only where a row's state
        // isn't self-evident. "Why is this grey?" is exactly that case.
        let blocked = try #require(updateRow(context(canInstall: false)))
        #expect(blocked.toolTip?.isEmpty == false)
        #expect(try #require(updateRow(context(canInstall: true))).toolTip == nil)
    }

    @Test("The row survives the capture-source lock rather than being hidden by it")
    func rowIsIndependentOfTheSourceLock() {
        // `allowsCaptureSourceChange` and `allowsUpdateInstall` agree today, so
        // this drives them apart by hand: source rows locked, updates permitted.
        // Without a distinct field the row would disappear here, which is the
        // regression this catches if someone later folds the two together.
        let context = context(canInstall: true, unlocked: false)
        #expect(updateRow(context)?.isEnabled == true)
        #expect(OverflowMenu.actions(context).contains { $0.isSourceRow } == false)
    }

    // MARK: - The updater must not run in a test host

    @Test("Blocked installs never construct or start Sparkle, and commands refuse", arguments: [
        InstallLocation.translocated, .readOnlyVolume
    ])
    func blockedInstallNeverStarts(location: InstallLocation) throws {
        let checker = TestUpdateChecker()
        var constructions = 0
        let updater = UpdaterController(
            installLocation: location,
            isSafeToInstall: { true },
            environment: [:],
            makeUpdater: { _ in
                constructions += 1
                return checker
            }
        )
        #expect(updater.unavailable == .blockedInstallLocation)
        #expect(!updater.isUsable)
        #expect(!updater.canCheckForUpdates)
        updater.checkForUpdates()

        let previous = OverflowMenu.onCheckForUpdates
        defer { OverflowMenu.onCheckForUpdates = previous }
        OverflowMenu.onCheckForUpdates = { updater.checkForUpdates() }
        let row = try #require(updateRow(OverflowContext(installLocation: location)))
        row.perform()

        #expect(constructions == 0)
        #expect(checker.starts == 0)
        #expect(checker.checks == 0)
    }

    @Test("Allowed locations start the updater and retain live recording gates", arguments: [
        InstallLocation.applications, .developerBuild,
        .elsewhere(URL(fileURLWithPath: "/Volumes/External/Home Rec.app"))
    ])
    func allowedInstallStarts(location: InstallLocation) {
        let checker = TestUpdateChecker()
        var constructions = 0
        let updater = UpdaterController(
            installLocation: location,
            isSafeToInstall: { checker.isSafeToInstall },
            environment: [:],
            makeUpdater: { _ in
                constructions += 1
                return checker
            }
        )
        #expect(constructions == 1)
        #expect(checker.starts == 1)
        #expect(updater.isUsable)
        #expect(updater.canCheckForUpdates)
        updater.checkForUpdates()
        #expect(checker.checks == 1)

        checker.isSafeToInstall = false
        #expect(!updater.canCheckForUpdates)
        updater.checkForUpdates()
        #expect(checker.checks == 1)
        checker.isSafeToInstall = true
        checker.canCheckForUpdates = false
        #expect(!updater.canCheckForUpdates)
        updater.checkForUpdates()
        #expect(checker.checks == 1)
    }

    @Test("A test-host preflight also prevents construction")
    func testHostPreventsConstruction() {
        var constructions = 0
        let updater = UpdaterController(
            installLocation: .applications,
            isSafeToInstall: { true },
            environment: ["XCTestConfigurationFilePath": ""],
            makeUpdater: { _ in
                constructions += 1
                return TestUpdateChecker()
            }
        )
        #expect(updater.unavailable == .notRunInTestHost)
        #expect(!updater.canCheckForUpdates)
        updater.checkForUpdates()
        #expect(constructions == 0)
    }

    @Test("A failed startup still refuses manual checks even if Sparkle says it can check")
    func startupFailureRefusesCommands() {
        Diagnostics.clearUpdaterStartupFailure()
        defer { Diagnostics.clearUpdaterStartupFailure() }

        let checker = TestUpdateChecker()
        checker.startError = NSError(
            domain: "HomeRecUpdaterTests",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "Synthetic updater startup failure"]
        )
        let updater = UpdaterController(
            installLocation: .applications,
            isSafeToInstall: { true },
            environment: [:],
            makeUpdater: { _ in checker }
        )
        #expect(checker.starts == 1)
        #expect(updater.unavailable == .startFailed)
        #expect(!updater.canCheckForUpdates)
        updater.checkForUpdates()
        #expect(checker.checks == 0)

        let report = Diagnostics.report()
        #expect(report.contains("Updater startup failure:"))
        #expect(report.contains("Domain: HomeRecUpdaterTests"))
        #expect(report.contains("Code: 42"))
        #expect(report.contains("Synthetic updater startup failure"))
    }

    @Test("Blocked install rows use canonical copy before recording or startup failures", arguments: [
        InstallLocation.translocated, .readOnlyVolume
    ])
    func blockedLocationMenu(location: InstallLocation) throws {
        for canInstall in [true, false] {
            for usable in [true, false] {
                let context = OverflowContext(
                    allowsUpdateInstall: canInstall,
                    updaterIsUsable: usable,
                    installLocation: location
                )
                let row = try #require(updateRow(context))
                #expect(!row.isEnabled)
                #expect(row.toolTip == location.explanation)
                let menu = OverflowMenu.makeNSMenu(context)
                let item = try #require(menu.items.first { $0.title == row.title })
                #expect(!item.isEnabled)
                #expect(item.toolTip == location.explanation)
            }
        }
    }

    @Test("Writable external and developer installs keep the update menu available", arguments: [
        InstallLocation.applications, .developerBuild,
        .elsewhere(URL(fileURLWithPath: "/Volumes/External/Home Rec.app"))
    ])
    func allowedLocationMenu(location: InstallLocation) throws {
        let row = try #require(updateRow(OverflowContext(installLocation: location)))
        #expect(row.isEnabled)
        #expect(row.toolTip == nil)
    }

    @Test("A test host runs no updater at all")
    func testHostRunsNoUpdater() {
        // This is the regression guard for a CI break that cost a full run.
        // `TEST_HOST` makes this app its own test host, so anything Sparkle does
        // at launch happens *inside* the test process. With `startingUpdater:
        // true`, a failed start put a modal `NSAlert` on the main thread one
        // second in — which races XCTest's own startup. A fast machine wins the
        // race and the suite passes; CI's slower VM loses it and reports "Test
        // runner never began executing tests after launching" with zero tests
        // run. Identical code, identical command, opposite results.
        //
        // Xcode sets this variable whenever it injects a test bundle, so it is
        // exactly the condition to refuse on.
        #expect(UpdaterController.shouldRunUpdater(in: ["XCTestConfigurationFilePath": "/x.xctestconfiguration"]) == false)
        #expect(UpdaterController.shouldRunUpdater(in: [:]))
        // An empty value still means a test bundle was injected.
        #expect(UpdaterController.shouldRunUpdater(in: ["XCTestConfigurationFilePath": ""]) == false)
    }

    @Test("This very process is one the updater must refuse to run in")
    func thisProcessIsATestHost() {
        // Asserted against the *live* environment, not a synthesised one: if the
        // variable Xcode sets is ever renamed, the pure test above keeps passing
        // against a name that no longer exists, and the guard silently stops
        // guarding. This fails instead.
        #expect(UpdaterController.shouldRunUpdater(in: ProcessInfo.processInfo.environment) == false)
    }

    @Test("An unusable updater disables the row and says something useful")
    func unusableUpdaterDisablesTheRow() throws {
        let context = context(updaterUsable: false)
        #expect(try #require(updateRow(context)).isEnabled == false)
        let tip = try #require(OverflowMenu.updateRowTooltip(context))
        // Names no cause — every cause is a misconfigured build the user can't
        // act on — but must still leave them somewhere to go.
        #expect(tip.localizedCaseInsensitiveContains("homerec.app"))
    }

    @Test("Recording wins the explanation when both reasons apply")
    func recordingTooltipTakesPrecedence() throws {
        // Recording is the reason the user caused and the only one that clears
        // by itself, so it is the more useful thing to say.
        let both = context(canInstall: false, updaterUsable: false)
        #expect(try #require(OverflowMenu.updateRowTooltip(both)).localizedCaseInsensitiveContains("recording"))
        #expect(OverflowMenu.updateRowTooltip(context()) == nil)
    }

    @Test("Blocking an update reads as a reason plus a way forward")
    func deferralExplainsItself() throws {
        // The project's error rule: `errorDescription` *and* a
        // `recoverySuggestion` that can actually be acted on. Sparkle surfaces
        // these verbatim when a user-initiated check is refused, so a bare
        // "operation not permitted" would be the whole of what they read.
        let error = UpdateDeferred.recordingInProgress
        #expect(try #require(error.errorDescription).isEmpty == false)
        let suggestion = try #require(error.recoverySuggestion)
        #expect(suggestion.localizedCaseInsensitiveContains("stop recording"))
    }
}

/// Counts construction-independent updater effects without running Sparkle.
@MainActor
private final class TestUpdateChecker: UpdateChecking {
    var isSafeToInstall = true
    var canCheckForUpdates = true
    var startError: Error?
    private(set) var starts = 0
    private(set) var checks = 0

    func start() throws {
        starts += 1
        if let startError { throw startError }
    }

    func checkForUpdates() {
        checks += 1
    }
}

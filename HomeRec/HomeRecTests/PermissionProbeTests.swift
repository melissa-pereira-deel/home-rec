//
//  PermissionProbeTests.swift
//  HomeRecTests
//
//  BL-085: which permission API each call site uses, and why it matters.
//
//  The distinction under test is invisible in the UI — both APIs return the same
//  status — so nothing but these tests will notice if a future change points a
//  launch path at the authoritative probe again. That probe can raise a system
//  prompt, so the regression it guards is "a permission dialog appears at launch
//  before the user has asked for anything".
//

import Testing
import Foundation
import AppKit
@testable import HomeRec

@MainActor
struct PermissionProbeTests {

    /// Each test gets its own notification center. `.default` is process-global
    /// and the suites run unserialized, so a synthetic `didBecomeActive` posted by
    /// one suite reaches every other suite's live view model — which silently
    /// consumes activations these tests are counting.
    private let center = NotificationCenter()

    private func makeViewModel(_ permissions: MockPermissionProviding) -> RecorderViewModel {
        RecorderViewModel(
            controller: MockRecordingControlling(),
            permissions: permissions,
            clock: ManualClock(),
            notificationCenter: center
        )
    }

    // MARK: - Launch

    /// The core of the item. A launch probe through `checkPermission` is what put
    /// an unrequested dialog on screen; preflight is silent.
    @Test("Launch reads permission silently and never uses the prompting probe")
    func launchUsesPreflightOnly() async {
        let permissions = MockPermissionProviding(.denied)
        let viewModel = makeViewModel(permissions)

        // Waiting on the preflight is what makes the `checkCount == 0` below
        // mean anything: it proves the launch path ran before we assert which
        // API it used.
        await waitUntil("the launch probe to complete") { permissions.preflightCount == 1 }

        #expect(permissions.preflightCount == 1)
        #expect(permissions.checkCount == 0, "Launch must not call the probe that can prompt")
        #expect(viewModel.permissionStatus == .denied)
    }

    @Test("A granted launch is reflected without the prompting probe")
    func grantedLaunchUsesPreflight() async {
        let permissions = MockPermissionProviding(.granted)
        let viewModel = makeViewModel(permissions)
        await waitUntil("launch to reflect the granted status") {
            viewModel.permissionStatus == .granted
        }

        #expect(viewModel.permissionStatus == .granted)
        #expect(permissions.checkCount == 0)
    }

    // MARK: - The guide's poll loop

    /// Guards the inverse mistake: "optimising" the watcher onto the silent API.
    /// The real `CGPreflightScreenCaptureAccess` latches its answer at process
    /// start — measured holding `.granted` for 57s after permission was revoked —
    /// so a loop built on it would wait forever for a grant it can never see.
    @Test("The grant watcher polls the live API, not the latched one")
    func watcherPollsTheLiveAPI() async {
        let permissions = MockPermissionProviding(.denied)
        permissions.preflightStatus = .denied     // frozen, as the real API is
        let watcher = PermissionGrantWatcher(
            permissions: permissions,
            clock: ImmediatePollClock(),
            interval: 0
        )
        var granted = false
        watcher.onGranted = { granted = true }

        watcher.startPolling()
        await waitUntil("the watcher's third probe") { permissions.checkCount >= 3 }

        // The system grants; preflight stays stale forever.
        permissions.status = .granted
        await waitUntil("the watcher to announce the grant") { granted }

        #expect(granted, "A latched preflight would never reach this")
        #expect(permissions.preflightCount == 0, "The loop must not use the silent API")
    }

    // MARK: - Activation re-probe

    /// Fires `didBecomeActiveNotification` and lets the observer's task settle.
    ///
    /// Unconditional by necessity: every caller asserts that the activation did
    /// *not* probe, and there is no positive edge to wait on. Each such test
    /// pairs this with a non-vacuity check that the launch path ran.
    private func activate() async {
        center.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        await settle()
    }

    /// `didBecomeActive` fires on launch too, and before this guard a fresh
    /// ungranted install got the system prompt at launch with zero clicks — found
    /// live during the v1.0.1 manual pass. The gate is *intent*: no probe until the
    /// user has gone looking for the permission, however many times the app is
    /// activated first.
    @Test("Activations never probe until the user has sought the permission")
    func activationDoesNotProbeBeforeIntent() async {
        let permissions = MockPermissionProviding(.denied)
        let viewModel = makeViewModel(permissions)
        await waitUntil("the launch probe to complete") { permissions.preflightCount == 1 }

        // Launch, then a switch away and back, then another. None is a request.
        await activate()
        await activate()
        await activate()

        #expect(permissions.checkCount == 0,
                "No probe may run before the user asks — this is the zero-click prompt")
        // Non-vacuity: the launch path did run and did read state — silently.
        #expect(permissions.preflightCount == 1)
        #expect(viewModel.permissionStatus == .denied)
    }

    @Test("Activation does not re-probe when permission is already granted")
    func activationSkipsProbeWhenGranted() async {
        let permissions = MockPermissionProviding(.granted)
        let viewModel = makeViewModel(permissions)
        await waitUntil("launch to reflect the granted status") {
            viewModel.permissionStatus == .granted
        }
        let baseline = permissions.checkCount

        // Intent is set, so the *only* thing still holding the observer back is
        // the already-granted guard: drop that guard and these activations probe.
        await viewModel.requestPermission()

        await activate()
        await activate()

        #expect(viewModel.permissionStatus == .granted)
        #expect(permissions.checkCount == baseline, "Already granted — nothing to ask")
    }

    /// BL-040 regression guard, and the reason the gate is intent rather than
    /// ordinality: once the user *has* asked, coming back must re-detect the grant
    /// — that is the entire scenario the observer exists for.
    @Test("Returning after seeking permission re-detects a grant made meanwhile")
    func activationReprobesAfterSeekingPermission() async {
        let permissions = MockPermissionProviding(.denied)
        let viewModel = makeViewModel(permissions)
        await waitUntil("the launch probe to complete") { permissions.preflightCount == 1 }
        #expect(viewModel.permissionStatus == .denied)

        await viewModel.requestPermission()   // sent to System Settings
        permissions.status = .granted        // granted while away
        await activate()                     // and back
        await waitUntil("the return probe to re-detect the grant") {
            viewModel.permissionStatus == .granted
        }

        #expect(viewModel.permissionStatus == .granted)
        #expect(permissions.checkCount >= 1)
    }

    // MARK: - Registration before System Settings (BL-087)

    private func makeSettingsViewModel(
        _ permissions: MockPermissionProviding,
        clock: PollClock
    ) -> RecorderViewModel {
        RecorderViewModel(
            controller: MockRecordingControlling(),
            permissions: permissions,
            clock: ManualClock(),
            notificationCenter: center,
            pollClock: clock,
            registrationTimeout: 0
        )
    }

    /// The defect from the v1.0.1 manual pass: the pane opened before the app had
    /// ever registered with TCC, so Home Rec was absent from the list and the user
    /// had to add it with "+". An app joins that list only by making the
    /// registering call, so it must complete before the pane opens.
    @Test("System Settings does not open until a registering probe has completed")
    func settingsWaitsForRegistration() async {
        let permissions = MockPermissionProviding(.denied)
        permissions.holdsChecks = true
        let viewModel = makeSettingsViewModel(permissions, clock: NeverPollClock())

        viewModel.openSystemSettings()
        await waitUntil("the registering probe to start") { permissions.checkCount >= 1 }

        // Probe in flight, pane still shut.
        #expect(permissions.checkCount >= 1)
        #expect(permissions.openSettingsCount == 0, "The pane must not open ahead of registration")

        permissions.holdsChecks = false
        permissions.resumePendingChecks()
        await waitUntil("the pane to open once registration completes") {
            permissions.openSettingsCount == 1
        }

        #expect(permissions.openSettingsCount == 1)
    }

    /// A hung probe must not become a dead click: past the deadline the pane opens
    /// anyway. The probe is left running — registration is the point of it.
    @Test("A probe that never returns still lets System Settings open")
    func settingsOpensAfterRegistrationDeadline() async {
        let permissions = MockPermissionProviding(.denied)
        permissions.holdsChecks = true
        // ImmediatePollClock makes the deadline fire at once, deterministically.
        let viewModel = makeSettingsViewModel(permissions, clock: ImmediatePollClock())

        viewModel.openSystemSettings()
        await waitUntil("the deadline to open the pane without the probe") {
            permissions.openSettingsCount == 1
        }

        #expect(permissions.openSettingsCount == 1)

        permissions.holdsChecks = false
        permissions.resumePendingChecks()
    }

    /// Now that the answer is known before opening: an already-granted user has no
    /// reason to be sent to System Settings at all.
    @Test("An already-granted user is not sent to System Settings")
    func grantedUserIsNotSentToSettings() async {
        let permissions = MockPermissionProviding(.granted)
        let viewModel = makeSettingsViewModel(permissions, clock: NeverPollClock())

        viewModel.openSystemSettings()
        // The probe is the positive edge; the settle then covers the window in
        // which a regression would have gone on to open the pane.
        await waitUntil("the registering probe to complete") { permissions.checkCount >= 1 }
        await settle()

        #expect(viewModel.permissionStatus == .granted)
        #expect(permissions.openSettingsCount == 0)
    }

    // MARK: - Grant detection without the panel (BL-088)

    /// The exact check-4 failure: grant via the Settings toggle while the app
    /// sits untouched in the background. With only a single return-probe this
    /// races the TCC write and can strand the app at "Almost ready" until
    /// relaunch — observed live. The watcher's poll must catch it with no user
    /// interaction at all.
    @Test("A grant made while the app is backgrounded flips state with no interaction")
    func backgroundGrantIsDetectedWithoutInteraction() async {
        let permissions = MockPermissionProviding(.denied)
        let viewModel = makeSettingsViewModel(permissions, clock: ImmediatePollClock())

        viewModel.openSystemSettings()
        await waitUntil("the watcher's third poll") { permissions.checkCount >= 3 }
        #expect(viewModel.permissionStatus == .denied)

        // The user flips the toggle in System Settings. No clicks on Home Rec,
        // no activation — nothing but the state changing out from under us.
        permissions.status = .granted
        await waitUntil("the background poll to notice the grant") {
            viewModel.permissionStatus == .granted
        }

        #expect(viewModel.permissionStatus == .granted)
    }

    /// BL-156. The flake that turned CI red on a CHANGELOG-only commit was this
    /// bug, not a slow test: intermittently the grant above was observed and then
    /// *thrown away*.
    ///
    /// `openSystemSettings()` starts the watcher and the registration probe
    /// together, and the registration probe deliberately outlives its own
    /// deadline. So when the watcher sees the grant, that first probe is often
    /// still in flight, holding the single-flight slot — the watcher's handoff
    /// joined it instead of writing, and the probe then landed its pre-grant
    /// `.denied` on top of the grant. The watcher stops the moment it fires, so
    /// nothing asked again: stuck at "Almost ready" until relaunch, which is the
    /// failure the watcher exists to prevent.
    ///
    /// Held deterministically here — the real thing needs a slow probe and an
    /// unlucky interleaving, which is why it surfaced roughly one run in four.
    @Test("A grant survives a slower probe that was issued before it")
    func grantSurvivesAnOlderInFlightProbe() async {
        let permissions = MockPermissionProviding(.denied)
        permissions.answersWithStatusAtIssue = true
        permissions.holdsChecks = true
        let viewModel = makeSettingsViewModel(permissions, clock: ImmediatePollClock())

        // A probe is issued while still denied and parked mid-flight, holding the
        // single-flight slot exactly as the registration probe does. Starting it
        // explicitly is what makes this deterministic: driven through
        // `openSystemSettings()` alone, whether the slot is taken before the
        // watcher fires is left to task ordering — which is the whole reason the
        // original defect surfaced only about one run in four.
        let older = Task { await viewModel.checkPermission() }
        await waitUntil("the older probe to be in flight") { permissions.checkCount >= 1 }

        // The user grants, and the watcher observes it while that probe is parked.
        permissions.holdsChecks = false
        permissions.status = .granted
        viewModel.openSystemSettings()
        await waitUntil("the watcher to observe the grant") {
            viewModel.permissionStatus == .granted
        }

        // Now the older probe finally lands. It answers the question it was asked
        // — "granted?" *before* the toggle — and must not overwrite the grant.
        permissions.resumePendingChecks()
        _ = await older.value
        await settle()

        #expect(viewModel.permissionStatus == .granted,
                "A probe older than the grant must not un-grant the app")
    }

    /// BL-085 guard on the relocated loop: it must start only behind the user's
    /// own click, never at launch or on idle activation.
    @Test("The watcher never polls before the user heads to Settings")
    func watcherDoesNotPollBeforeIntent() async {
        let permissions = MockPermissionProviding(.denied)
        let viewModel = makeViewModel(permissions)
        await waitUntil("the launch probe to complete") { permissions.preflightCount == 1 }

        await activate()
        await activate()

        #expect(viewModel.grantWatcherIsPolling == false)
        #expect(permissions.checkCount == 0)
    }
}

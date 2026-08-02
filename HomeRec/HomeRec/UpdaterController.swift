//
//  UpdaterController.swift
//  HomeRec
//
//  Sparkle integration (BL-034).
//
//  Home Rec's problem is not "how do I add an auto-updater" — Sparkle's stock
//  setup is three lines. It is that installing an update **quits and relaunches
//  the app**, and this app spends its time holding an open audio file that is
//  only valid once `finalize()` has run. An update that lands mid-take destroys
//  that take.
//
//  So the integration is two gates over the stock behaviour:
//
//  1. `mayPerformUpdateCheck` refuses to *start* anything while a take is open.
//  2. `shouldPostponeRelaunchForUpdate` catches the case gate 1 cannot: a check
//     that began before recording started and finished during it. Sparkle hands
//     us a handler and waits until we invoke it.
//
//  Gate 2 is why this type holds state at all. Without it the window is real
//  and silent: start a check, hit record, and Sparkle relaunches underneath you.
//

import AppKit
import Sparkle
import os

/// Owns the Sparkle updater and the policy around it.
///
/// The *rule* lives on `RecordingState.allowsUpdateInstall`, not here, so it is
/// reachable by a test without constructing an `SPUUpdater` — which would reach
/// the network on init.
@MainActor
final class UpdaterController {

    /// Retained because `SPUStandardUpdaterController` holds its delegate weakly.
    private let gate: UpdaterGate
    /// `nil` in a unit-test host, where the app must not run an updater at all.
    private let controller: SPUStandardUpdaterController?

    /// Why the updater cannot be used, or `nil` when it started cleanly.
    private(set) var unavailable: UpdaterUnavailable?

    /// - Parameters:
    ///   - isSafeToInstall: Answers "is it safe to terminate this process right
    ///     now?" — read at the moment Sparkle asks, never cached, because
    ///     recording starts and stops long after this object is built.
    ///   - environment: Injected so the test-host rule stays assertable.
    init(
        isSafeToInstall: @escaping @MainActor () -> Bool,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        let gate = UpdaterGate(isSafeToInstall: isSafeToInstall)
        self.gate = gate

        guard Self.shouldRunUpdater(in: environment) else {
            self.controller = nil
            self.unavailable = .notRunInTestHost
            return
        }

        // ⚠️ `startingUpdater: false` is load-bearing, and the two ways to start
        // are a trap. `SPUStandardUpdaterController.startUpdater()` is
        // non-throwing and, on failure, waits one second and then runs a modal
        // `NSAlert` we do not control. The one we want is `SPUUpdater`'s, which
        // throws and shows nothing — and which Swift imports as `start()`, not
        // `startUpdater()`, so the obvious spelling silently resolves to the
        // wrong object's method.
        //
        // That modal is not merely ugly. `TEST_HOST` makes this app its own test
        // host, so a modal on the main thread races XCTest's startup: on a fast
        // machine the runner wins and the suite passes, on CI's slower VM the
        // alert wins and the whole run reports "Test runner never began
        // executing tests after launching" with zero tests. Measured 2026-08-02.
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: gate,
            userDriverDelegate: nil
        )
        self.controller = controller

        do {
            try controller.updater.start()
        } catch {
            // Deliberately quiet: a start failure means a misconfigured build,
            // which the user can do nothing about. Surfacing it well is BL-148.
            self.unavailable = .startFailed
            Log.recorder.error(
                "Sparkle updater failed to start: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Whether this process should run an updater at all.
    ///
    /// A unit-test host must not: it has no user to update, and Sparkle's
    /// machinery — network, XPC helpers, modal alerts — is pure side effect in a
    /// test run. Xcode sets `XCTestConfigurationFilePath` when it injects a test
    /// bundle, which is exactly the situation `TEST_HOST` creates.
    ///
    /// Pure and `nonisolated` so it is assertable without building an
    /// `SPUUpdater`, which reaches the network.
    nonisolated static func shouldRunUpdater(in environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] == nil
    }

    /// False when the updater never started, so the menu row can be disabled
    /// rather than silently doing nothing when clicked.
    var isUsable: Bool { unavailable == nil }

    /// False while a check is in flight, while a take is open, and whenever the
    /// updater is unusable.
    ///
    /// ⚠️ That last clause is not redundant. After a failed start Sparkle's own
    /// `canCheckForUpdates` still reports `true` — it tracks whether a session is
    /// in progress, not whether the updater ever started — while
    /// `checkForUpdates()` degrades to a silent no-op. Without this the row would
    /// look enabled and do nothing at all, which is worse than an honest error.
    var canCheckForUpdates: Bool {
        guard let controller, isUsable else { return false }
        return controller.updater.canCheckForUpdates && gate.isSafeToInstall()
    }

    func checkForUpdates() {
        guard let controller, isUsable else { return }
        controller.updater.checkForUpdates()
    }

    /// Releases an update that finished downloading during a take.
    ///
    /// Must be called when recording ends, or a postponed relaunch waits
    /// forever — Sparkle has no timeout on the handler it gave us.
    func recordingDidEnd() {
        gate.releasePostponedRelaunch()
    }
}

/// The `SPUUpdaterDelegate`, split out only so `UpdaterController` can pass a
/// fully-formed delegate to Sparkle's initializer without a two-phase `init`.
@MainActor
private final class UpdaterGate: NSObject, SPUUpdaterDelegate {

    let isSafeToInstall: @MainActor () -> Bool

    /// Sparkle's continuation, held while a take finishes. Non-nil means an
    /// update is downloaded and waiting to relaunch us.
    private var postponedRelaunch: (() -> Void)?

    init(isSafeToInstall: @escaping @MainActor () -> Bool) {
        self.isSafeToInstall = isSafeToInstall
    }

    func releasePostponedRelaunch() {
        guard let relaunch = postponedRelaunch else { return }
        postponedRelaunch = nil
        Log.recorder.info("Recording ended; releasing the postponed update relaunch")
        relaunch()
    }

    // MARK: - SPUUpdaterDelegate

    /// Imported into Swift as `throws` returning `Void`: throwing vetoes the
    /// check, and `NSLocalizedDescriptionKey` is what Sparkle shows if the user
    /// asked for it explicitly.
    ///
    /// The Swift name is `updater(_:mayPerform:)`, **not** the header's
    /// `mayPerformUpdateCheck:` — the import both drops the `error:` parameter
    /// and renames the selector. Writing the obvious spelling compiles as a new
    /// method that merely looks like a delegate callback and is never called;
    /// here it was a hard error only because the old name is explicitly
    /// deprecated.
    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard !isSafeToInstall() else { return }
        throw UpdateDeferred.recordingInProgress
    }

    /// The backstop for a download that completed mid-take. Returning `true`
    /// parks the relaunch until `installHandler` runs; `releasePostponedRelaunch`
    /// is the only thing that runs it.
    func updater(
        _ updater: SPUUpdater,
        shouldPostponeRelaunchForUpdate item: SUAppcastItem,
        untilInvokingBlock installHandler: @escaping () -> Void
    ) -> Bool {
        guard !isSafeToInstall() else { return false }
        Log.recorder.info("Update ready but a recording is open; postponing relaunch")
        postponedRelaunch = installHandler
        return true
    }
}

/// Why the updater is unusable for this whole process run.
///
/// Distinct from `UpdateDeferred`, which is temporary and clears when recording
/// stops. These two do not: they last until the app is relaunched.
enum UpdaterUnavailable: Equatable, Sendable {
    /// Running as a unit-test host. Not an error — the correct outcome.
    case notRunInTestHost
    /// `startUpdater()` threw. Always a misconfigured build (bad feed URL, bad
    /// or missing `SUPublicEDKey`); never something the user caused or can fix.
    case startFailed
}

/// Why an update check was refused.
///
/// A `LocalizedError` with a `recoverySuggestion`, per the project's error rule —
/// this string is what the user reads if they clicked "Check for Updates…" and
/// the answer was no.
enum UpdateDeferred: LocalizedError {
    case recordingInProgress

    var errorDescription: String? {
        switch self {
        case .recordingInProgress:
            return "Home Rec is recording."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .recordingInProgress:
            return "Installing an update restarts Home Rec, which would end the recording. Stop recording, then check again."
        }
    }
}

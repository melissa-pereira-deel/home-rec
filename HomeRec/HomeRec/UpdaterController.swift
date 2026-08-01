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
    private let controller: SPUStandardUpdaterController

    /// - Parameter isSafeToInstall: Answers "is it safe to terminate this
    ///   process right now?" — read at the moment Sparkle asks, never cached,
    ///   because recording starts and stops long after this object is built.
    init(isSafeToInstall: @escaping @MainActor () -> Bool) {
        let gate = UpdaterGate(isSafeToInstall: isSafeToInstall)
        self.gate = gate
        // `startingUpdater: true` schedules the background check Sparkle is for.
        // The feed URL and public key come from Info.plist (`SUFeedURL`,
        // `SUPublicEDKey`) — see `InfoPlistTests`.
        self.controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: gate,
            userDriverDelegate: nil
        )
    }

    /// False while a check is already in flight, and while a take is open.
    ///
    /// Sparkle's own `canCheckForUpdates` covers only the first. Adding the
    /// second is what lets the menu row explain itself by being disabled rather
    /// than failing after the user clicks it.
    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates && gate.isSafeToInstall()
    }

    func checkForUpdates() {
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

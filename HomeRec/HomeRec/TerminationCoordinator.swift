//
//  TerminationCoordinator.swift
//  HomeRec
//
//  BL-174: quitting during a take must finish the recording, not sever it.
//

import AppKit

/// Decides whether the app may quit right now, and if not, finishes the open
/// take first.
///
/// Why this is a separate type rather than code in `AppDelegate`: the delegate is
/// reachable only through AppKit's application lifecycle, so anything written
/// there is untestable by construction — `ReskinSnapshots.swift` already records
/// that no test covers `AppDelegate`. Everything here is injected, so the whole
/// decision is drivable from a test.
///
/// The shape is deliberately `UpdaterGate`'s (`UpdaterController.swift`): a
/// late-read predicate, and a parked continuation released exactly once. There,
/// Sparkle's `installHandler` is the continuation; here it is
/// `NSApp.reply(toApplicationShouldTerminate:)`.
///
/// The one thing that gate cannot lend us is a bound. It has none on purpose —
/// it waits for the user to stop recording of their own accord. Someone who
/// pressed ⌘Q is not waiting for themselves, so this one gives up and quits.
@MainActor
final class TerminationCoordinator {

    /// Answers "is it safe to end this process right now?", read at the moment
    /// AppKit asks rather than captured, because takes start and stop long after
    /// this object is built.
    private let isSafeToQuit: @MainActor () -> Bool

    /// Finishes whatever is open. Returns when the file is safe, or when it has
    /// done everything it can.
    private let drain: @MainActor () async -> Void

    /// How long to wait before quitting anyway.
    ///
    /// ⚠️ **This bounds the parts of the drain that yield — not all of it.**
    /// `AudioRecorder.stopRecording()` runs `processingQueue.sync` from the main
    /// actor, so a finalize that stalls blocks the main thread outright, and
    /// nothing scheduled on it can run — including this timeout and including
    /// `NSApp.reply`. The sleep below is therefore deliberately *not* main-actor
    /// isolated: it elapses regardless, and fires the moment the main thread is
    /// free again.
    ///
    /// What that leaves genuinely unbounded is a hung `M4AEncoder.finalize()`,
    /// whose `DispatchSemaphore.wait()` has no timeout (TD-014). That is not
    /// fixable from out here, and sequencing constraint 9 forbids fixing it as
    /// part of this item. Recorded so the bound is not mistaken for more
    /// protection than it gives.
    private let timeout: Duration

    /// Injected so tests never touch `NSApp`.
    private let reply: @MainActor (Bool) -> Void

    private var hasReplied = false
    private var isDraining = false

    init(
        timeout: Duration = .seconds(5),
        isSafeToQuit: @escaping @MainActor () -> Bool,
        drain: @escaping @MainActor () async -> Void,
        reply: @escaping @MainActor (Bool) -> Void = { NSApp.reply(toApplicationShouldTerminate: $0) }
    ) {
        self.timeout = timeout
        self.isSafeToQuit = isSafeToQuit
        self.drain = drain
        self.reply = reply
    }

    /// AppKit's `applicationShouldTerminate`, with the decision extracted.
    func shouldTerminate() -> NSApplication.TerminateReply {
        if isSafeToQuit() {
            return .terminateNow
        }

        // A second ⌘Q while already finishing must not start a second drain, and
        // must not reply twice — replying twice traps.
        guard !isDraining else { return .terminateLater }
        isDraining = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.drain()
            self.replyOnce()
        }

        // Off the main actor on purpose — see `timeout`. `self` is captured
        // strongly and unconditionally: a coordinator that got deallocated while
        // a quit was pending would leave AppKit waiting on a reply that never
        // comes, which is the unquittable app this item exists to prevent.
        Task.detached { [self, timeout] in
            try? await Task.sleep(for: timeout)
            await MainActor.run { self.replyOnce() }
        }

        return .terminateLater
    }

    /// `NSApp.reply(toApplicationShouldTerminate:)` must be called exactly once;
    /// the drain finishing and the bound expiring are a genuine race.
    private func replyOnce() {
        guard !hasReplied else { return }
        hasReplied = true
        reply(true)
    }
}

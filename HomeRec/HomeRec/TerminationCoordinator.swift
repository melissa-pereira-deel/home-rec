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

    /// Explicit Quit gives the open take this long to close. The audio
    /// processing queue owns encoder I/O, so the deadline can answer AppKit
    /// even when an M4A writer is still finishing.
    private let timeout: Duration

    static let defaultTimeout: Duration = .seconds(5)

    /// Injected so tests never touch `NSApp`.
    private let reply: @MainActor (Bool) -> Void

    private var hasReplied = false
    private var isDraining = false

    init(
        timeout: Duration = TerminationCoordinator.defaultTimeout,
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
        // AppKit is already waiting for the original drain's reply.
        guard !isDraining else { return .terminateLater }
        if isSafeToQuit() { return .terminateNow }

        isDraining = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.drain()
            self.replyOnce()
        }

        // Keep the coordinator alive until it can answer AppKit.
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

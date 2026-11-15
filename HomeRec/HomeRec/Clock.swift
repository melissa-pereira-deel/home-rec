//
//  Clock.swift
//  HomeRec
//
//  Time source for the recording duration timer. Injecting it lets tests
//  advance time deterministically instead of waiting on a real Timer.
//

import Foundation

/// Supplies the current time and a repeating tick for the duration display.
@MainActor
protocol DurationClock: AnyObject {
    var now: Date { get }
    func startTicking(every interval: TimeInterval, onTick: @escaping @MainActor () -> Void)
    func stopTicking()
}

/// Production clock backed by the system clock and a run-loop `Timer`.
@MainActor
final class SystemDurationClock: DurationClock {
    private var timer: Timer?
    private var onTick: (@MainActor () -> Void)?

    var now: Date { Date() }

    func startTicking(every interval: TimeInterval, onTick: @escaping @MainActor () -> Void) {
        stopTicking()
        self.onTick = onTick
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.onTick?() }
        }
    }

    func stopTicking() {
        timer?.invalidate()
        timer = nil
        onTick = nil
    }

    /// ⚠️ Known Swift 6 violation, left in place deliberately — see below.
    ///
    /// A plain `deinit` is nonisolated, so reading `timer` (a non-Sendable
    /// `Timer?`) here is an error in the Swift 6 language mode, and invalidating
    /// off-main is a genuine bug on top of that: `Timer.invalidate()` is
    /// documented as valid only on the thread that scheduled the timer, which
    /// here is the main run loop.
    ///
    /// `isolated deinit` (SE-0371) fixes both in one word, and **this project
    /// cannot use it yet**: it is stable from Swift 6.2, but CI builds with
    /// Xcode 16.4 / Swift 6.1.2, where it still requires
    /// `-enable-experimental-feature IsolatedDeinit` and is a hard compile
    /// error without it. Tried, and it failed CI on all four sites that wanted
    /// it (this one, `PermissionGrantWatcher`, `RecorderViewModel`,
    /// `RecordingController`). Revisit when the CI image's Xcode provides 6.2.
    ///
    /// The teardown itself is load-bearing rather than tidy:
    /// `Timer.scheduledTimer` hands the run loop a strong reference to the timer
    /// while the block holds `self` weakly, so a clock released without this
    /// leaves a repeating timer firing into a nil `self` for the life of the
    /// process.
    deinit {
        timer?.invalidate()
    }
}

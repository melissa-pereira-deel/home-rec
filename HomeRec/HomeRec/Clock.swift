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

    /// `isolated deinit` (SE-0371), not a plain one, and not for tidiness.
    ///
    /// A plain `deinit` is nonisolated, so it runs wherever the last reference
    /// was released. Two things follow, and only one of them is a warning:
    /// reading `timer` (a non-Sendable `Timer?`) from there is an error in the
    /// Swift 6 language mode, and invalidating off-main is a genuine bug —
    /// `Timer.invalidate()` is documented as valid only on the thread that
    /// scheduled the timer, which here is the main run loop.
    ///
    /// ⚠️ **Requires Swift 6.2 or newer.** Below that it needs
    /// `-enable-experimental-feature IsolatedDeinit` and is otherwise a hard
    /// compile error. This is part of why `.github/workflows/ci.yml` pins
    /// `DEVELOPER_DIR` rather than inheriting the image default: that default
    /// was Xcode 16.4 / Swift 6.1.2, where this exact line failed both jobs.
    /// **If that pin is ever lowered below Xcode 26.0 / Swift 6.2, this site and
    /// the three below are what break first** — and `Clock`'s is the one whose
    /// revert reintroduces a bug, not just a warning.
    ///
    /// The teardown itself is load-bearing: `Timer.scheduledTimer` hands the run
    /// loop a strong reference to the timer while the block holds `self` weakly,
    /// so a clock released without this leaves a repeating timer firing into a
    /// nil `self` for the life of the process.
    isolated deinit {
        timer?.invalidate()
    }
}

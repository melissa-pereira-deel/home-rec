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

    /// `isolated deinit` (SE-0371), not a plain one, and the reason is not
    /// ceremony. A plain `deinit` runs wherever the last reference was released,
    /// and `Timer.invalidate()` is documented as valid only on the thread that
    /// scheduled the timer — here, the main run loop. The teardown is also
    /// load-bearing rather than tidy: `Timer.scheduledTimer` hands the run loop
    /// a strong reference to the timer while the block holds `self` weakly, so
    /// a clock released without this would leave a repeating timer firing into
    /// a nil `self` for the life of the process.
    isolated deinit {
        timer?.invalidate()
    }
}

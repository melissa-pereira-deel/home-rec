import Foundation

/// First-order lag with direction-dependent time constants — the movement of
/// a meter needle, integrated per frame.
///
/// A reference type held in `@State` on purpose. The integrator is advanced
/// from inside a `TimelineView` body, and a value type there would either have
/// to be written back through a binding (a publish per frame, and a second
/// layout pass) or mutated during view evaluation (undefined). A plain class
/// that SwiftUI does not observe can be stepped during drawing with no
/// invalidation at all: the `TimelineView` is already redrawing, so nothing
/// needs to be told about the change.
final class BallisticIntegrator {
    /// Smoothed position in 0...1.
    private(set) var position: Double = 0
    private var lastTick: Date?

    /// Advance to `date` and return the new position.
    ///
    /// - Parameters:
    ///   - target: Instantaneous input level, 0...1.
    ///   - date: Frame time; the elapsed interval is derived from it so the
    ///     feel is identical at 60Hz, 120Hz, or a stuttering frame rate.
    ///   - ballistics: Attack and release time constants.
    func step(target: Double, at date: Date, ballistics: POBallistics) -> Double {
        let dt = lastTick.map { max(0, date.timeIntervalSince($0)) } ?? (1.0 / 60)
        lastTick = date

        let clamped = min(1, max(0, target))
        let tau = ballistics.timeConstant(rising: clamped > position)
        guard tau > 0 else {
            position = clamped
            return position
        }
        // Exponential approach solved for the actual elapsed time rather than
        // a fixed per-frame coefficient, so a dropped frame does not leave the
        // needle behind.
        let k = 1 - exp(-dt / tau)
        position += (clamped - position) * k
        return position
    }

    /// Jump to a value without integrating, for reduced-motion presentation
    /// and for resetting between takes.
    func snap(to value: Double, at date: Date? = nil) {
        position = min(1, max(0, value))
        lastTick = date
    }
}

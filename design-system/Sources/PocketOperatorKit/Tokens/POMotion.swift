import SwiftUI

/// The motion language, stored as physics parameters rather than as
/// `Animation` values so the numbers stay inspectable, comparable, and
/// documentable.
///
/// The governing idea: **nothing in this system eases the way software eases.**
/// A key going down is a mass hitting a stop — fast, linear, terminated. A key
/// coming up is a spring — quick, slightly overshooting, settling. An LCD
/// segment does not fade, it switches. A needle does not interpolate, it
/// integrates. Whenever a choice arises between "smooth" and "mechanical",
/// this kit picks mechanical.
public struct POMotion: Sendable, Equatable {

    // MARK: - Key physics

    /// Time for a cap to reach the bottom of its travel.
    ///
    /// 50 ms, eased out, with no spring: a finger pressing a real key is far
    /// stiffer than the key's return spring, so the down-stroke is dominated
    /// by the finger and simply stops at the plinth. Springing the press makes
    /// caps feel like jelly, which is the single fastest way to lose the
    /// hardware illusion.
    public var keyPressDuration: TimeInterval
    /// Return-spring response. The cap is pushed back by its own dome, which
    /// is light and lightly damped, so it overshoots slightly and settles —
    /// that overshoot is the visual equivalent of the clack.
    public var keyReleaseResponse: Double
    /// Damping of the return spring. Below ~0.5 the cap visibly bounces twice
    /// and reads as rubber; above ~0.7 it reads as a screen animation.
    public var keyReleaseDamping: Double

    // MARK: - Display

    /// Blink rate for a display element in points per second, as a square
    /// wave. LCD segments have no intermediate state; crossfading a blinking
    /// `REC` is the tell that a display is drawn rather than driven.
    public var displayBlinkHz: Double
    /// Residual opacity of a blinked-off segment — not zero, because the
    /// segment is still physically there.
    public var displayBlinkOffOpacity: Double
    /// Duration of a full-screen invert flash used to punctuate a committed
    /// action. Long enough to register, short enough not to be a transition.
    public var displayFlashDuration: TimeInterval
    /// Per-character delay when a display types a value in. Roughly the
    /// character rate of a slow serial link, which is the reference.
    public var displayTypeInterval: TimeInterval

    // MARK: - Continuous controls

    /// Detent snap after a fader is released.
    public var detentResponse: Double
    public var detentDamping: Double

    // MARK: - Meter ballistics

    /// Needle rise time constant.
    ///
    /// A standard VU movement reaches 99% of a step in about 300 ms; modelled
    /// as a first-order lag that is a time constant near 90 ms. Fast, because
    /// a meter that lags a transient is useless for its actual job.
    public var meterAttack: TimeInterval
    /// Needle fall time constant.
    ///
    /// Deliberately ~4x the attack. The asymmetry is the whole illusion: a
    /// physical needle is *driven* upward by the signal but returns only under
    /// its own spring and damping, so it snaps up and drifts down. Symmetric
    /// smoothing looks like a progress bar. This is also why the meter is
    /// readable at all — the eye can follow a slow decay and estimate a peak,
    /// but cannot follow a symmetric flutter.
    public var meterRelease: TimeInterval

    // MARK: - Lamps

    public var lampBlinkHz: Double

    public init(
        keyPressDuration: TimeInterval = 0.05,
        keyReleaseResponse: Double = 0.18,
        keyReleaseDamping: Double = 0.55,
        displayBlinkHz: Double = 2,
        displayBlinkOffOpacity: Double = 0.07,
        displayFlashDuration: TimeInterval = 0.12,
        displayTypeInterval: TimeInterval = 0.03,
        detentResponse: Double = 0.15,
        detentDamping: Double = 0.9,
        meterAttack: TimeInterval = 0.09,
        meterRelease: TimeInterval = 0.35,
        lampBlinkHz: Double = 2
    ) {
        self.keyPressDuration = keyPressDuration
        self.keyReleaseResponse = keyReleaseResponse
        self.keyReleaseDamping = keyReleaseDamping
        self.displayBlinkHz = displayBlinkHz
        self.displayBlinkOffOpacity = displayBlinkOffOpacity
        self.displayFlashDuration = displayFlashDuration
        self.displayTypeInterval = displayTypeInterval
        self.detentResponse = detentResponse
        self.detentDamping = detentDamping
        self.meterAttack = meterAttack
        self.meterRelease = meterRelease
        self.lampBlinkHz = lampBlinkHz
    }

    public static let standard = POMotion()

    /// Down-stroke animation.
    public var keyPress: Animation {
        .easeOut(duration: keyPressDuration)
    }

    /// Return-stroke animation.
    public var keyRelease: Animation {
        .spring(response: keyReleaseResponse, dampingFraction: keyReleaseDamping)
    }

    public var detentSnap: Animation {
        .spring(response: detentResponse, dampingFraction: detentDamping)
    }

    /// The animation for a press state change in whichever direction it is
    /// heading. Kept here rather than in the key so a product can retune press
    /// feel globally.
    public func keyTransition(isPressed: Bool) -> Animation {
        isPressed ? keyPress : keyRelease
    }
}

/// Ballistics for a meter movement, in first-order time constants.
///
/// Expressed as a pair because the pair *is* the character of the instrument:
/// a VU meter averages, a PPM catches peaks and holds them, and a numeric
/// readout does neither.
public struct POBallistics: Sendable, Equatable {
    /// Time constant while the signal is rising.
    public var attack: TimeInterval
    /// Time constant while the signal is falling.
    public var release: TimeInterval

    public init(attack: TimeInterval, release: TimeInterval) {
        self.attack = attack
        self.release = release
    }

    /// Standard VU movement: reads average loudness, ignores brief transients.
    public static let vu = POBallistics(attack: 0.09, release: 0.35)
    /// Peak programme meter: catches transients almost instantly and falls
    /// back slowly enough to be read.
    public static let peak = POBallistics(attack: 0.004, release: 0.85)
    /// No ballistics — follows the signal exactly. Correct for a digital bar
    /// graph, wrong for anything with a needle.
    public static let instant = POBallistics(attack: 0, release: 0)

    /// Time constant to apply given the direction of travel.
    public func timeConstant(rising: Bool) -> TimeInterval {
        rising ? attack : release
    }
}

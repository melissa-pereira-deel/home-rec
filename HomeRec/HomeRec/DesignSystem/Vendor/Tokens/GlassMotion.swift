import SwiftUI

// MARK: - Motion tokens

/// The motion vocabulary.
///
/// This is a recorder. Motion in it has exactly one job: to make a state
/// change legible in the moment it happens. Nothing decorates, nothing
/// bounces for character, and nothing animates a value the user is reading
/// (the timer's digits cross-fade; they never slide).
///
/// Every duration in the kit comes from this list.
public enum GlassMotionToken: String, CaseIterable, Hashable, Sendable {
    /// 0.10s ease-out — press feedback. Below ~0.08s a press reads as a
    /// glitch; above ~0.14s it reads as lag.
    case press
    /// 0.12s ease-out — hover.
    case hover
    /// 0.15s ease-out — chip selection, small reveals.
    case quick
    /// 0.18s ease-out — the notice slot swap. Fast enough that the shelf
    /// doesn't appear to "leave", slow enough to be seen leaving.
    case swap
    /// 0.20s ease-out — modal presentation, conditional slot flip.
    case reveal
    /// Spring (0.35 / 0.8) — a row expanding into the player. Springs are
    /// reserved for things that change *size*, where a linear curve looks
    /// mechanical.
    case expand
    /// Spring (0.40 / 0.75) — the materialize beat when a take lands.
    case materialize
    /// Linear 1/30s — playhead and live-trace updates. Linear because the
    /// value is time itself; easing time is a lie.
    case playhead

    public var animation: Animation {
        switch self {
        case .press: .easeOut(duration: 0.10)
        case .hover: .easeOut(duration: 0.12)
        case .quick: .easeOut(duration: 0.15)
        case .swap: .easeOut(duration: 0.18)
        case .reveal: .easeOut(duration: 0.20)
        case .expand: .spring(response: 0.35, dampingFraction: 0.80)
        case .materialize: .spring(response: 0.40, dampingFraction: 0.75)
        case .playhead: .linear(duration: 1.0 / 30.0)
        }
    }

    /// What survives `reduceMotion`.
    ///
    /// The rule: **position and scale changes are removed, opacity changes
    /// are kept.** A user who asked for less motion still needs to see that
    /// the notice row replaced the shelf — they just shouldn't have to watch
    /// it travel. Press/hover feedback is dropped entirely; the pill's colour
    /// change already carries it.
    public var reducedAnimation: Animation? {
        switch self {
        case .press, .hover: nil
        case .quick, .swap, .reveal, .expand, .materialize: .easeOut(duration: 0.15)
        case .playhead: .linear(duration: 1.0 / 30.0)
        }
    }
}

// MARK: - Transport timings

/// Timings the transport state machine is specified against.
///
/// These are not animation curves — they are how long a *state* lasts, and
/// they are part of the product contract: `arming` is visible for long enough
/// to read, `stopping` for long enough that a saved file feels saved, and
/// `saved` dwells rather than snapping back so the number a user just made
/// doesn't evaporate.
public enum GlassTransportTiming {
    /// Minimum time the `arming` label is shown, even if capture starts
    /// sooner. A control that flickers through a state is worse than one that
    /// never showed it.
    public static let minimumArming: TimeInterval = 0.25
    /// Minimum time `stopping` ("saving…") is shown.
    public static let minimumStopping: TimeInterval = 0.45
    /// How long the `saved` beat dwells before the control returns to `idle`.
    /// The control is *already re-armable* during this window — the dwell is
    /// presentation, never a lock.
    public static let savedDwell: TimeInterval = 1.4
}

// MARK: - Applying motion

/// Applies a motion token, honouring `reduceMotion`.
public struct GlassAnimationModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let token: GlassMotionToken
    let value: Value

    public func body(content: Content) -> some View {
        content.animation(reduceMotion ? token.reducedAnimation : token.animation, value: value)
    }
}

public extension View {
    /// Animates changes to `value` with a motion token, automatically
    /// degrading under Reduce Motion. Prefer this over `.animation(_:value:)`
    /// everywhere in the kit — a raw `.animation` call is a missed
    /// accessibility check waiting to happen.
    func glassAnimation<V: Equatable>(_ token: GlassMotionToken, value: V) -> some View {
        modifier(GlassAnimationModifier(token: token, value: value))
    }
}

public extension GlassMotionToken {
    /// Resolves the token for imperative `withAnimation` calls, where there is
    /// no modifier to read the environment for you.
    ///
    /// ```swift
    /// withAnimation(GlassMotionToken.quick.resolved(reduceMotion: reduceMotion)) { … }
    /// ```
    func resolved(reduceMotion: Bool) -> Animation? {
        reduceMotion ? reducedAnimation : animation
    }
}

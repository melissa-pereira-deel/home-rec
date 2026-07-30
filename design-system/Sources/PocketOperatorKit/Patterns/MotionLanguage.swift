import SwiftUI

/// # The motion language
///
/// Four kinds of movement exist in this system, and nothing else does:
///
/// 1. **Travel.** A key goes down fast and linear, comes up on a light spring.
///    This is the only transform applied to a control.
/// 2. **Switching.** Lamps and display segments change state instantaneously,
///    on a square wave when they blink. Nothing on a display fades.
/// 3. **Integration.** Meter needles follow a first-order lag with asymmetric
///    time constants. They are never `withAnimation`-ed; they are stepped per
///    frame from a signal.
/// 4. **Punctuation.** A committed action is marked by a single display
///    invert flash of about 120 ms, and nothing else. No confetti, no sheet
///    transition, no bounce.
///
/// What is deliberately absent: cross-fades between screens, easing on
/// opacity, scale-in appearances, and any motion whose purpose is delight
/// rather than report. A device that animates for pleasure stops reading as a
/// device.
///
/// ## Reduced motion
///
/// Every one of the four resolves to a still, legible state:
///
/// - travel keeps the offset but drops the animation, so a press still shows
///   as depressed without a spring;
/// - blinking renders steady-on, because the blink carries state and losing it
///   would lose information;
/// - meters update at a low fixed cadence instead of at display refresh, and
///   drop the ballistic lag;
/// - the invert flash is skipped, with the display going straight to its new
///   content.
@available(macOS 15, *)
public struct POBlink: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isActive: Bool
    let hz: Double
    let offOpacity: Double

    @ViewBuilder
    public func body(content: Content) -> some View {
        if isActive && !reduceMotion {
            // Scheduled at twice the blink rate so each half-cycle gets its own
            // tick; the phase is derived from wall clock so every blinking
            // element on a panel is in lockstep, as a shared clock line would
            // make them.
            TimelineView(.periodic(from: .now, by: 1 / (hz * 2))) { context in
                let phase = Int(context.date.timeIntervalSince1970 * hz * 2)
                content.opacity(phase.isMultiple(of: 2) ? 1 : offOpacity)
            }
        } else {
            content
        }
    }
}

@available(macOS 15, *)
public extension View {
    /// Blink this view as a hard square wave.
    ///
    /// - Parameter offOpacity: Residual opacity in the off half-cycle. Not
    ///   zero — an unlit segment or lamp is still physically present.
    func poBlink(isActive: Bool, hz: Double = 2, offOpacity: Double = 0.07) -> some View {
        modifier(POBlink(isActive: isActive, hz: hz, offOpacity: offOpacity))
    }
}

/// Types a string in one character at a time, the way a slow serial link
/// delivers to a display.
///
/// Used to punctuate a value arriving rather than to decorate it, so it runs
/// once per new value and is skipped entirely under Reduce Motion.
@available(macOS 15, *)
public struct TypedText: View {
    @Environment(\.poTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = 0

    private let text: String
    private let content: (String) -> AnyView

    public init<Rendered: View>(
        _ text: String,
        @ViewBuilder content: @escaping (String) -> Rendered
    ) {
        self.text = text
        self.content = { AnyView(content($0)) }
    }

    public var body: some View {
        content(String(text.prefix(revealed)))
            // Assistive technology reads the finished value, never the partial
            // string; a half-typed name is noise, not information.
            .accessibilityLabel(text)
            .task(id: text) { await reveal() }
    }

    private func reveal() async {
        guard !reduceMotion else {
            revealed = text.count
            return
        }
        revealed = 0
        for index in 0...text.count {
            revealed = index
            try? await Task.sleep(for: .seconds(theme.motion.displayTypeInterval))
        }
    }
}

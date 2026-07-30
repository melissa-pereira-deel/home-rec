import SwiftUI

/// A panel lamp.
///
/// The language's primary way of saying "this is happening". A lamp is a
/// physical part with exactly three states and no in-between, so it never
/// pulses, breathes, or crossfades — it switches. Anything that needs a
/// gradient of meaning belongs on a meter instead.
@available(macOS 15, *)
public struct IndicatorLamp: View {

    public enum Mode: Sendable, Equatable {
        case off
        case on
        /// Hard square-wave blink. Under Reduce Motion this renders steady-on,
        /// since the blink carries state that must not be lost.
        case blinking
    }

    /// What the lamp is reporting, which decides its colour.
    public enum Role: Sendable, Equatable {
        /// Something is running now.
        case active
        /// Ready, nominal.
        case armed
        /// Fault, clipping, attention.
        case warning
        case custom(Color)
    }

    @Environment(\.poTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let mode: Mode
    private let role: Role
    private let diameter: CGFloat?
    private let accessibilityLabel: String?

    /// - Parameter accessibilityLabel: What the lamp reports, e.g. "Recording".
    ///   Without it the lamp is invisible to assistive technology, which is
    ///   how a purely-physical status signal quietly excludes people.
    public init(
        _ mode: Mode,
        role: Role = .active,
        diameter: CGFloat? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.mode = mode
        self.role = role
        self.diameter = diameter
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        let size = diameter ?? theme.metrics.lampDiameter
        lens(size: size)
            .frame(width: size, height: size)
            .accessibilityElement()
            .poAccessibilityLabel(accessibilityLabel)
            .poAccessibilityValue(accessibilityLabel == nil ? nil : spokenState)
            .accessibilityHidden(accessibilityLabel == nil)
    }

    @ViewBuilder
    private func lens(size: CGFloat) -> some View {
        switch mode {
        case .off:
            litLens(size: size, isLit: false)
        case .on:
            litLens(size: size, isLit: true)
        case .blinking:
            litLens(size: size, isLit: true)
                .poBlink(isActive: true, hz: theme.motion.lampBlinkHz, offOpacity: 0.12)
        }
    }

    private func litLens(size: CGFloat, isLit: Bool) -> some View {
        Circle()
            .fill(isLit ? tint : theme.colors.lampOff)
            .overlay {
                // Dark rim: the lens sits in a bored hole, so its edge is
                // always in shadow whether it is lit or not.
                Circle().strokeBorder(.black.opacity(0.55), lineWidth: 0.5)
            }
            .background {
                if isLit {
                    // Bloom outside the lens, not inside it: light escaping
                    // around the bezel is what a lit indicator looks like.
                    Circle()
                        .fill(tint.opacity(0.45))
                        .blur(radius: size * 0.45)
                        .scaleEffect(1.8)
                }
            }
    }

    private var tint: Color {
        switch role {
        case .active: theme.colors.lampActive
        case .armed: theme.colors.lampArmed
        case .warning: theme.colors.lampWarn
        case .custom(let color): color
        }
    }

    private var spokenState: String {
        switch mode {
        case .off: "off"
        case .on: "on"
        case .blinking: "active"
        }
    }
}

/// A lamp with its printed legend beside it — the standard panel annunciator.
@available(macOS 15, *)
public struct LampAnnunciator: View {
    @Environment(\.poTheme) private var theme

    private let legend: String
    private let mode: IndicatorLamp.Mode
    private let role: IndicatorLamp.Role
    private let accessibilityLabel: String?

    public init(
        _ legend: String,
        mode: IndicatorLamp.Mode,
        role: IndicatorLamp.Role = .active,
        accessibilityLabel: String? = nil
    ) {
        self.legend = legend
        self.mode = mode
        self.role = role
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: theme.metrics.spacing.snug) {
            IndicatorLamp(mode, role: role)
            ScreenPrintLabel(legend, scale: .micro, isDecorative: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? legend)
        .accessibilityValue(spokenState)
    }

    private var spokenState: String {
        switch mode {
        case .off: "off"
        case .on: "on"
        case .blinking: "active"
        }
    }
}

@available(macOS 15, *)
#Preview("Lamps") {
    HStack(spacing: 24) {
        LampAnnunciator("REC", mode: .blinking, role: .active, accessibilityLabel: "Recording")
        LampAnnunciator("RDY", mode: .on, role: .armed, accessibilityLabel: "Ready")
        LampAnnunciator("CLIP", mode: .off, role: .warning, accessibilityLabel: "Clipping")
    }
    .padding(30)
    .background(Color.poHex(0x0A0A0A))
}

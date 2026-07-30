import SwiftUI

// MARK: - Variant

/// The pill's register.
///
/// Home Rec's controls are flat capsules with lowercase labels — the
/// "untitled" register — and the variant is how a control declares what kind
/// of thing it is, not how it wants to look:
///
/// - `solid` — the accent. *One* control on screen may be solid at a time.
///   It is the record/stop pill, or the onboarding CTA, and nothing else.
/// - `solidTinted` — a solid in a status colour, for a destructive or warning
///   action that must read as consequential without borrowing the record red.
/// - `neutral` — a filled but unaccented control: the same shape, none of the
///   urgency. Blocked states use it, which is the point: a pill that can't
///   record must not look like the pill that can.
/// - `neutralProminent` — a near-white fill with dark text. The default
///   action where the accent must not be spent: a notice's recovery action is
///   the thing to press, but a red pill there would put a second record-red on
///   the panel and make a recoverable error look like a failure. Achromatic,
///   and unmistakably the primary of its group.
/// - `ghost` — outline only. Secondary, reversible, safe.
public enum GlassPillVariant: Equatable {
    case solid
    case solidTinted(Color)
    case neutral
    case neutralProminent
    case ghost
}

// MARK: - Size

/// Pill sizes. Each is a height, a horizontal padding and a type role — never
/// a free-form combination, so two pills at the same size are always the same
/// pill.
public enum GlassPillSize: String, CaseIterable, Hashable, Sendable {
    /// 44pt — the primary transport control.
    case large
    /// 36pt — secondary card actions (open System Settings).
    case medium
    /// 32pt — in-row transport (play/pause).
    case small
    /// 30pt — recording-bar stop.
    case compact
    /// 26pt visual / 28pt hit — inline confirmations and notice actions.
    case mini

    func height(_ metrics: GlassMetrics) -> CGFloat {
        switch self {
        case .large: metrics.controlHeightLarge
        case .medium: metrics.controlHeightMedium
        case .small: metrics.controlHeightSmall
        case .compact: metrics.controlHeightCompact
        case .mini: metrics.controlHeightMini
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .large: GlassSpacing.xxxl - GlassSpacing.xxs   // 26
        case .medium: GlassSpacing.xxl - GlassSpacing.xxs   // 20
        case .small: GlassSpacing.xl - GlassSpacing.xxs     // 16
        case .compact: GlassSpacing.xl - GlassSpacing.xxs   // 16
        case .mini: GlassSpacing.md                          // 12
        }
    }

    var textRole: GlassTextRole {
        switch self {
        case .large: .control
        case .medium: .bodyEmphasized
        case .small, .compact: .controlCompact
        case .mini: .captionSmall
        }
    }

    /// Symbol point size. Symbols sit optically large next to lowercase type,
    /// so they run ~5pt below the label size at every step.
    var symbolSize: CGFloat {
        switch self {
        case .large: 9
        case .medium: 10
        case .small: 9
        case .compact: 8
        case .mini: 8
        }
    }

    /// Gap between symbol and label. Tighter at small sizes so the pair reads
    /// as one word-shape rather than two objects.
    var iconSpacing: CGFloat {
        switch self {
        case .large: GlassSpacing.sm + 3   // 9
        case .medium, .small: GlassSpacing.sm + 1   // 7
        case .compact, .mini: GlassSpacing.sm       // 6
        }
    }
}

// MARK: - Button style

/// The flat pill. Hover lifts it 3%, press drops it 3% and darkens 6% — the
/// entire physical vocabulary of the Glass register, applied to every control
/// in the kit so a pill anywhere feels like a pill everywhere.
public struct GlassPillButtonStyle: ButtonStyle {
    public var variant: GlassPillVariant
    public var size: GlassPillSize
    /// Stretches the pill to its container. Off by default: a capsule that
    /// spans a panel stops reading as a button.
    public var isFullWidth: Bool

    public init(
        variant: GlassPillVariant = .solid,
        size: GlassPillSize = .large,
        isFullWidth: Bool = false
    ) {
        self.variant = variant
        self.size = size
        self.isFullWidth = isFullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        GlassPillBody(
            configuration: configuration,
            variant: variant,
            size: size,
            isFullWidth: isFullWidth
        )
    }
}

public extension ButtonStyle where Self == GlassPillButtonStyle {
    static var glassPill: GlassPillButtonStyle { GlassPillButtonStyle() }

    static func glassPill(
        _ variant: GlassPillVariant,
        size: GlassPillSize = .large,
        isFullWidth: Bool = false
    ) -> GlassPillButtonStyle {
        GlassPillButtonStyle(variant: variant, size: size, isFullWidth: isFullWidth)
    }
}

private struct GlassPillBody: View {
    let configuration: ButtonStyle.Configuration
    let variant: GlassPillVariant
    let size: GlassPillSize
    let isFullWidth: Bool

    @Environment(\.glassTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        configuration.label
            .glassText(size.textRole)
            .fontWeight(size == .mini ? .semibold : nil)
            .foregroundStyle(foreground)
            // Optical centering. Inter's cap height sits low in a capsule of
            // this proportion, so a mathematically centred label reads 1pt
            // low. Only applied when Inter is actually the resolved face —
            // SF is centred correctly and would be pushed *off* centre.
            .offset(y: opticalOffset)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: size.height(theme.metrics))
            .background(fill, in: Capsule())
            .overlay {
                if case .ghost = variant {
                    Capsule().strokeBorder(theme.colors.lineStrong, lineWidth: theme.metrics.hairline)
                }
            }
            // Visual capsule first, then the hit region is grown to the
            // minimum target. The scale effects below deliberately sit
            // *outside* the content shape: a hit region that grows on hover
            // makes the pointer chase its own hover state at the boundary.
            .contentShape(Capsule())
            .padding(.vertical, hitPadding)
            .contentShape(Capsule())
            .scaleEffect(scale)
            .brightness(configuration.isPressed && isEnabled ? -0.06 : 0)
            .glassAnimation(.hover, value: isHovering)
            .glassAnimation(.press, value: configuration.isPressed)
            .glassHover($isHovering, showsPointingHand: isEnabled)
            .opacity(isEnabled ? 1 : 0.85)
    }

    /// Grows a sub-minimum control's hit region to `minimumHitTarget` without
    /// changing what you see. The mini pill is 26pt of capsule and 28pt of
    /// target.
    private var hitPadding: CGFloat {
        max(0, (theme.metrics.minimumHitTarget - size.height(theme.metrics)) / 2)
    }

    private var opticalOffset: CGFloat {
        theme.typography.usesCustomUIFamily && size == .large ? -1 : 0
    }

    private var scale: CGFloat {
        guard isEnabled, !reduceMotion else { return 1 }
        if configuration.isPressed { return 0.97 }
        return isHovering ? 1.03 : 1.0
    }

    private var fill: Color {
        switch variant {
        case .solid:
            if !isEnabled { return theme.colors.accentMuted }
            return configuration.isPressed ? theme.colors.accentStrong : theme.colors.accent
        case .solidTinted(let tint):
            return isEnabled ? tint : tint.opacity(0.45)
        case .neutral:
            return theme.colors.surfaceCard.opacity(isEnabled ? 1 : 0.7)
        case .neutralProminent:
            // Deliberately near-white rather than pure: pure white against the
            // near-black ground haloes at small sizes.
            return theme.colors.textPrimary.opacity(isEnabled ? 0.92 : 0.4)
        case .ghost:
            return theme.colors.surfaceInset
        }
    }

    private var foreground: Color {
        switch variant {
        case .solid, .solidTinted:
            // A disabled control is exempt from WCAG contrast (1.4.3), but it
            // still has to be readable enough to tell you *what* is disabled —
            // hence 75% rather than a token dim.
            theme.colors.textOnAccent.opacity(isEnabled ? 1 : 0.75)
        case .neutralProminent:
            // Dark-on-light: 14:1 against the 92% fill.
            theme.colors.ground.opacity(isEnabled ? 1 : 0.55)
        case .neutral, .ghost:
            isEnabled ? theme.colors.textPrimary : theme.colors.textSecondary
        }
    }
}

// MARK: - Convenience view

/// A pill button with the kit's label composition: optional SF Symbol, then a
/// lowercase label, never wrapping.
public struct GlassPillButton: View {
    private let title: String
    private let systemImage: String?
    private let variant: GlassPillVariant
    private let size: GlassPillSize
    private let isFullWidth: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        variant: GlassPillVariant = .solid,
        size: GlassPillSize = .large,
        isFullWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.size = size
        self.isFullWidth = isFullWidth
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: size.iconSpacing) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: size.symbolSize, weight: .bold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    // A control label that wraps has stopped being a control.
                    // Truncation here is a bug report, not a layout: it means
                    // the label is too long for the register.
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .buttonStyle(GlassPillButtonStyle(variant: variant, size: size, isFullWidth: isFullWidth))
    }
}

#Preview("Pill buttons") {
    GlassPreviewStage {
        VStack(alignment: .leading, spacing: GlassSpacing.l) {
            ForEach(GlassPillSize.allCases, id: \.self) { size in
                HStack(spacing: GlassSpacing.m) {
                    Text(size.rawValue).glassText(.metaSmall, color: .textTertiary).frame(width: 60, alignment: .leading)
                    GlassPillButton("record", systemImage: "circle.fill", variant: .solid, size: size) {}
                    GlassPillButton("neutral", variant: .neutral, size: size) {}
                    GlassPillButton("ghost", variant: .ghost, size: size) {}
                    GlassPillButton("stop", variant: .solidTinted(GlassColors.standard.statusWarning), size: size) {}
                    GlassPillButton("disabled", variant: .solid, size: size) {}.disabled(true)
                }
            }
        }
    }
}

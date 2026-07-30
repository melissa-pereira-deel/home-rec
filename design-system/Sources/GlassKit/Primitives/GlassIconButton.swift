import SwiftUI

/// An SF Symbol in a hit target.
///
/// The visual is a 12pt glyph; the target is 28pt square. That ratio is
/// deliberate and it is the reason this primitive exists — a bare `Image` in a
/// `Button` gives you a ~14pt target, which is a coin toss for anyone whose
/// hands aren't perfectly steady, and it is exactly the mistake that gets made
/// every time an icon button is hand-rolled.
///
/// `accessibilityLabel` is a required initialiser argument, not an optional
/// modifier. An icon button without a label is unusable with VoiceOver, and
/// the type system is a better reviewer than a checklist.
public struct GlassIconButton: View {
    private let systemImage: String
    private let label: String
    private let hint: String?
    private let symbolSize: CGFloat
    private let colorRole: GlassColorRole
    private let action: () -> Void

    @Environment(\.glassTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    public init(
        systemImage: String,
        accessibilityLabel: String,
        accessibilityHint: String? = nil,
        symbolSize: CGFloat = 12,
        color: GlassColorRole = .textTertiary,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.label = accessibilityLabel
        self.hint = accessibilityHint
        self.symbolSize = symbolSize
        self.colorRole = color
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(foreground)
                .frame(
                    width: theme.metrics.minimumHitTarget,
                    height: theme.metrics.minimumHitTarget
                )
                .background {
                    if isHovering && isEnabled {
                        RoundedRectangle(cornerRadius: GlassRadius.control, style: .continuous)
                            .fill(theme.colors.surfaceInset)
                    }
                }
                // Rectangle, not the symbol's own shape: the target must be
                // the whole 28pt square, including its empty corners.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassHover($isHovering, showsPointingHand: isEnabled)
        .glassAnimation(.hover, value: isHovering)
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
    }

    private var foreground: Color {
        if !isEnabled { return theme.colors.textTertiary.opacity(0.5) }
        return isHovering ? theme.colors.textPrimary : theme.colors[colorRole]
    }
}

/// Interactive text with a real affordance.
///
/// Text that does something must not look like text that reports something.
/// The link gets a hover background, a pointing-hand cursor and a 28pt target;
/// the mono register keeps it quiet enough to sit next to metadata without
/// competing with the panel's one accent.
public struct GlassNavLink: View {
    private let title: String
    private let hint: String?
    private let action: () -> Void

    @Environment(\.glassTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    public init(_ title: String, accessibilityHint: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.hint = accessibilityHint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .glassText(.meta)
                .foregroundStyle(isHovering ? theme.colors.textPrimary : theme.colors.textTertiary)
                .lineLimit(1)
                .padding(.horizontal, GlassSpacing.s)
                // The visible hover plate stays 24pt — a 28pt plate next to
                // 10pt mono reads as a button and unbalances the header row —
                // while the hit region below grows to the 28pt floor.
                .frame(height: 24)
                .background {
                    if isHovering && isEnabled {
                        RoundedRectangle(cornerRadius: GlassRadius.control, style: .continuous)
                            .fill(theme.colors.surfaceInset)
                    }
                }
                .padding(.vertical, (theme.metrics.minimumHitTarget - 24) / 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassHover($isHovering, showsPointingHand: isEnabled)
        .glassAnimation(.hover, value: isHovering)
        .accessibilityHint(hint ?? "")
    }
}

#Preview("Icon button + nav link") {
    GlassPreviewStage {
        HStack(spacing: GlassSpacing.l) {
            GlassIconButton(
                systemImage: "slider.horizontal.3",
                accessibilityLabel: "settings",
                accessibilityHint: "Format and save location"
            ) {}
            GlassIconButton(systemImage: "xmark", accessibilityLabel: "dismiss") {}
            GlassIconButton(systemImage: "play.fill", accessibilityLabel: "play") {}.disabled(true)
            GlassNavLink("all takes →") {}
            GlassNavLink("← record") {}
        }
    }
}

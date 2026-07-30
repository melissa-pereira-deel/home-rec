import SwiftUI

/// A selectable capsule: library filters, format pickers, anything where the
/// options are few, mutually exclusive, and short enough to sit in a row.
///
/// A chip is not a small pill. Pills *do* something; chips *choose* something,
/// which is why a chip carries `.isSelected` (and the `isSelected`
/// accessibility trait) rather than a variant, and why an unselected chip is
/// still visible — a ghost chip row reads as disabled.
public struct GlassChip: View {
    private let title: String
    private let isSelected: Bool
    private let help: String?
    private let action: () -> Void

    @Environment(\.glassTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    public init(
        _ title: String,
        isSelected: Bool,
        help: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.help = help
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .glassText(.caption)
                .foregroundStyle(isSelected ? theme.colors.textPrimary : theme.colors.textTertiary)
                .padding(.horizontal, GlassSpacing.md - 1)
                .padding(.vertical, GlassSpacing.sm - 1)
                .background(
                    theme.colors.surfaceCard.opacity(background),
                    in: Capsule()
                )
                .overlay {
                    Capsule().strokeBorder(
                        isSelected ? theme.colors.lineStrong : theme.colors.line,
                        lineWidth: theme.metrics.hairline
                    )
                }
                .contentShape(Capsule())
                // Chips are ~24pt tall by type metrics; the target is grown to
                // the 28pt floor without moving the capsule.
                .padding(.vertical, GlassSpacing.xxs)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassHover($isHovering, showsPointingHand: isEnabled)
        .glassAnimation(.quick, value: isSelected)
        .glassAnimation(.hover, value: isHovering)
        .help(help ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Selected chips are opaque, unselected ones sit at 35% — enough that the
    /// row reads as a set of options, not as one option and some ghosts.
    /// Hover splits the difference so the affordance is felt before the click.
    private var background: Double {
        if isSelected { return 1 }
        return isHovering ? 0.6 : 0.35
    }
}

#Preview("Chips") {
    GlassPreviewStage {
        HStack(spacing: GlassSpacing.sm) {
            GlassChip("all", isSelected: true) {}
            GlassChip("wav", isSelected: false) {}
            GlassChip("m4a", isSelected: false) {}
            GlassChip("flac", isSelected: false, help: "Interrupted FLAC files can't be played back.") {}
            GlassChip("this week", isSelected: false) {}
            GlassChip("locked", isSelected: false) {}.disabled(true)
        }
    }
}

import SwiftUI

/// A non-interactive marker: `v4`, `active`, `monitoring · not recorded`.
///
/// Badges are outlined rather than filled by default, because a filled badge
/// at this size competes with the pills — and in a recorder, nothing may
/// compete with the pills. The filled variant exists for the one case where a
/// badge must be read *before* the thing it labels (a status that changes the
/// meaning of the row it sits in).
public struct GlassBadge: View {
    public enum Style: Equatable {
        /// Hairline capsule, text in the tint. The default.
        case outline
        /// Filled capsule, text in `textOnAccent`.
        case filled
    }

    private let title: String
    private let style: Style
    private let tintRole: GlassColorRole
    private let size: GlassTextRole

    @Environment(\.glassTheme) private var theme

    public init(
        _ title: String,
        style: Style = .outline,
        tint: GlassColorRole = .textTertiary,
        textRole: GlassTextRole = .metaSmall
    ) {
        self.title = title
        self.style = style
        self.tintRole = tint
        self.size = textRole
    }

    public var body: some View {
        Text(title)
            .glassText(size)
            .foregroundStyle(style == .filled ? theme.colors.textOnAccent : tint)
            .padding(.horizontal, GlassSpacing.sm - 1)
            .padding(.vertical, 1.5)
            .background {
                if style == .filled {
                    Capsule().fill(tint)
                }
            }
            .overlay {
                if style == .outline {
                    Capsule().strokeBorder(tint.opacity(0.55), lineWidth: theme.metrics.hairline)
                }
            }
            // Badges are decoration *of* their neighbour, so they must not be
            // a separate VoiceOver stop — the row that contains one is
            // responsible for folding it into its own label.
            .accessibilityHidden(true)
    }

    private var tint: Color { theme.colors[tintRole] }
}

/// A live status marker with a breathing dot — the "something is happening"
/// primitive. Used by the recording bar and anywhere a capture is in flight.
public struct GlassPulseDot: View {
    private let isAnimating: Bool

    @Environment(\.glassTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isAnimating: Bool = true) {
        self.isAnimating = isAnimating
    }

    public var body: some View {
        Group {
            if isAnimating && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                    dot.opacity(breathe(at: context.date))
                }
            } else {
                // Reduce Motion: a steady dot at the *bright* end of the
                // breath, never the dim end — the indicator's job is to say
                // "recording", and a permanently dim dot says "idle".
                dot.opacity(isAnimating ? 1 : 0.5)
            }
        }
        .frame(width: theme.metrics.pulseDotSize, height: theme.metrics.pulseDotSize)
        .accessibilityHidden(true)
    }

    private var dot: some View {
        Circle().fill(theme.colors.accent)
    }

    /// ~0.7Hz breath between 40% and 100%. Slower than a heartbeat on
    /// purpose: this runs for hours, and anything faster becomes a nag.
    private func breathe(at date: Date) -> Double {
        0.7 + 0.3 * sin(date.timeIntervalSince1970 * .pi * 1.4)
    }
}

#Preview("Badges") {
    GlassPreviewStage {
        HStack(spacing: GlassSpacing.m) {
            GlassBadge("v4")
            GlassBadge("active", tint: .textAccent)
            GlassBadge("monitoring · not recorded", tint: .textTertiary, textRole: .metaSmall)
            GlassBadge("new", style: .filled, tint: .accent)
            GlassPulseDot()
            GlassPulseDot(isAnimating: false)
        }
    }
}

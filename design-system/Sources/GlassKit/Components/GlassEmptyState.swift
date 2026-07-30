import SwiftUI

/// The two empty states, which are not the same state.
///
/// "You have no recordings" and "your filter matched none of your recordings"
/// feel identical to render and completely different to receive. The first
/// needs an invitation; the second needs a way out. Collapsing them into one
/// "No items" is the single most common way a library loses a user — they
/// conclude their files are gone.
public struct GlassEmptyState: View {
    public enum Kind {
        /// Nothing exists yet. Carries an invitation, no action — the action
        /// is the record button, which is already on screen.
        case nothingYet(hint: String)
        /// Something exists, but not under this filter. Carries the way back.
        case noMatches(resetTitle: String, onReset: () -> Void)
    }

    private let title: String
    private let kind: Kind

    public init(title: String, kind: Kind) {
        self.title = title
        self.kind = kind
    }

    /// `nothing here yet. / record something.`
    public static func nothingYet(
        title: String = "nothing here yet.",
        hint: String = "record something."
    ) -> GlassEmptyState {
        GlassEmptyState(title: title, kind: .nothingYet(hint: hint))
    }

    /// `no m4a takes.` + `show all`
    public static func noMatches(
        filterLabel: String,
        resetTitle: String = "show all",
        onReset: @escaping () -> Void
    ) -> GlassEmptyState {
        GlassEmptyState(title: "no \(filterLabel) takes.", kind: .noMatches(resetTitle: resetTitle, onReset: onReset))
    }

    public var body: some View {
        VStack(spacing: GlassSpacing.s) {
            Spacer(minLength: 0)
            Text(title)
                .glassText(.body, color: .textPrimary)
            switch kind {
            case .nothingYet(let hint):
                GlassMetaLabel(hint)
            case .noMatches(let resetTitle, let onReset):
                GlassNavLink(resetTitle, accessibilityHint: "Clears the filter.", action: onReset)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

#Preview("Empty states") {
    GlassPreviewStage {
        VStack(spacing: GlassSpacing.xxl) {
            GlassEmptyState.nothingYet()
                .frame(height: 90)
            GlassDivider()
            GlassEmptyState.noMatches(filterLabel: "m4a") {}
                .frame(height: 90)
        }
    }
}

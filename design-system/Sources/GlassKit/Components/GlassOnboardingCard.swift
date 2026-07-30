import SwiftUI

// MARK: - Copy

/// Reference copy for the onboarding card, from the Glass spec. Every string
/// is overridable — a design system supplies the *shape* of an onboarding
/// card, not the words a product says on first launch.
public struct GlassOnboardingCopy {
    public var title: String
    public var subtitle: String
    public var permissionTitle: String
    public var permissionDetail: String
    public var permissionSymbol: String
    public var settingsAction: String
    public var settingsActionInProgress: String
    /// Shown *only* in the not-granted state, under the settings action —
    /// context for the place the button just sent you.
    public var settingsHint: String?
    public var grantedTitle: String
    public var grantedSymbol: String
    public var primaryTitleGranted: String
    public var primaryTitleUngranted: String

    public init(
        title: String = GlassBrand.name,
        subtitle: String = "Records what your Mac is playing. Lossless WAV.",
        permissionTitle: String = "Needs Screen Recording permission",
        permissionDetail: String = "Audio only — your screen is never recorded.",
        permissionSymbol: String = "lock.shield",
        settingsAction: String = "open System Settings",
        settingsActionInProgress: String = "opening…",
        settingsHint: String? = "Look under \u{201C}Screen & System Audio Recording\u{201D} — not the audio-only list.",
        grantedTitle: String = "Ready to record",
        grantedSymbol: String = "checkmark.circle.fill",
        primaryTitleGranted: String = "get started",
        primaryTitleUngranted: String = "done"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.permissionTitle = permissionTitle
        self.permissionDetail = permissionDetail
        self.permissionSymbol = permissionSymbol
        self.settingsAction = settingsAction
        self.settingsActionInProgress = settingsActionInProgress
        self.settingsHint = settingsHint
        self.grantedTitle = grantedTitle
        self.grantedSymbol = grantedSymbol
        self.primaryTitleGranted = primaryTitleGranted
        self.primaryTitleUngranted = primaryTitleUngranted
    }

    public static let standard = GlassOnboardingCopy()
}

// MARK: - Card

/// The first-run card.
///
/// Element order is fixed: **icon → title → supporting copy → permission info
/// → conditional slot → primary CTA**, and the conditional slot has a *fixed
/// height in both states*.
///
/// That fixed height is the entire design of this component. Permission can
/// land while the card is on screen — the user grants it in System Settings
/// and comes back, or a watcher notices — and when it does, the slot swaps
/// from "open System Settings" + hint to "Ready to record". A flexible slot
/// would shrink by ~30pt at that moment and pull the primary button up out
/// from under the cursor, which is how a first-run flow ends with an
/// accidental click on nothing.
public struct GlassOnboardingCard<Icon: View>: View {

    /// The one thing the card branches on.
    public enum PermissionState: Equatable {
        case granted
        case needsPermission(isOpeningSettings: Bool)

        var isGranted: Bool { self == .granted }
    }

    private let state: PermissionState
    private let copy: GlassOnboardingCopy
    private let isFixedSize: Bool
    private let icon: Icon
    private let onOpenSettings: () -> Void
    private let onPrimary: () -> Void

    @Environment(\.glassTheme) private var theme

    public init(
        state: PermissionState,
        copy: GlassOnboardingCopy = .standard,
        isFixedSize: Bool = true,
        @ViewBuilder icon: () -> Icon,
        onOpenSettings: @escaping () -> Void,
        onPrimary: @escaping () -> Void
    ) {
        self.state = state
        self.copy = copy
        self.isFixedSize = isFixedSize
        self.icon = icon()
        self.onOpenSettings = onOpenSettings
        self.onPrimary = onPrimary
    }

    public var body: some View {
        VStack(spacing: 0) {
            icon
                .frame(width: 64, height: 64)
                .glassElevation(.panel)
                .accessibilityHidden(true)
            gap(GlassSpacing.l)

            Text(copy.title)
                .glassText(.wordmark, color: .textPrimary)
            gap(GlassSpacing.s)

            Text(copy.subtitle)
                .glassText(.body, color: .textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            gap(GlassSpacing.xxxl - GlassSpacing.xs)

            permissionRow
            gap(GlassSpacing.xl - GlassSpacing.xxs)

            conditionalSlot
            gap(GlassSpacing.xl)

            primaryButton
        }
        .padding(
            EdgeInsets(
                top: GlassSpacing.xxxl, leading: GlassSpacing.xxxl + GlassSpacing.xs,
                bottom: GlassSpacing.xxl + GlassSpacing.xs, trailing: GlassSpacing.xxxl + GlassSpacing.xs
            )
        )
        .frame(
            width: isFixedSize ? theme.metrics.onboardingCardSize.width : nil,
            height: isFixedSize ? theme.metrics.onboardingCardSize.height : nil
        )
        .glassSurface(.modal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(copy.title)
        .accessibilityAddTraits(.isModal)
    }

    /// The card's one inset container: the ask and the reassurance live
    /// together, because the worry they answer is a single worry. Splitting
    /// them into a bullet list is what made the shipping card a wall of text.
    private var permissionRow: some View {
        HStack(spacing: GlassSpacing.md) {
            // Symbols that annotate text are sized by that text's role rather
            // than by a point size, so they scale with it under Dynamic Type
            // and can never drift out of proportion with the label.
            Image(systemName: copy.permissionSymbol)
                .glassText(.title)
                .foregroundStyle(theme.colors.textSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: GlassSpacing.xxs + 1) {
                Text(copy.permissionTitle)
                    .glassText(.bodyEmphasized, color: .textPrimary)
                Text(copy.permissionDetail)
                    .glassText(.caption, color: .textSecondary)
            }
            .lineLimit(1)
            // Fills the row, not the card: a flexible spacer here would let
            // the inset box stretch to the card's full width on a re-layout.
            Spacer(minLength: 0)
        }
        .padding(.vertical, GlassSpacing.l)
        .padding(.horizontal, GlassSpacing.xl - GlassSpacing.xxs)
        .glassSurface(.inset)
        .accessibilityElement(children: .combine)
    }

    private var conditionalSlot: some View {
        ZStack {
            switch state {
            case .granted:
                HStack(spacing: GlassSpacing.sm) {
                    Image(systemName: copy.grantedSymbol)
                        .glassText(.title)
                        .accessibilityHidden(true)
                    Text(copy.grantedTitle)
                        .glassText(.bodyEmphasized)
                }
                .foregroundStyle(theme.colors.statusSuccess)
                .transition(.opacity)
                .accessibilityElement(children: .combine)

            case .needsPermission(let isOpening):
                VStack(spacing: GlassSpacing.s) {
                    GlassPillButton(
                        isOpening ? copy.settingsActionInProgress : copy.settingsAction,
                        emphasis: .secondary,
                        size: .medium,
                        action: onOpenSettings
                    )
                    .disabled(isOpening)
                    if let hint = copy.settingsHint {
                        Text(hint)
                            .glassText(.captionSmall, color: .textTertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(height: theme.metrics.onboardingSlotHeight)
        .glassAnimation(.reveal, value: state)
    }

    private var primaryButton: some View {
        GlassPillButton(
            state.isGranted ? copy.primaryTitleGranted : copy.primaryTitleUngranted,
            emphasis: .primary,
            size: .large,
            action: onPrimary
        )
        // The accent glow is the only shadow in the kit that isn't black. It
        // exists because this pill sits on a card that already has a 30pt
        // drop shadow — a second black shadow would disappear into the first.
        .shadow(color: theme.colors.accent.opacity(0.3), radius: 14, y: 4)
        .keyboardShortcut(.defaultAction)
    }

    private func gap(_ height: CGFloat) -> some View {
        Color.clear.frame(height: height)
    }
}

public extension GlassOnboardingCard where Icon == GlassBrandMarkPlaceholder {
    /// Convenience initialiser using the kit's placeholder mark. Real apps
    /// pass their own icon — the kit ships no brand assets.
    init(
        state: PermissionState,
        copy: GlassOnboardingCopy = .standard,
        isFixedSize: Bool = true,
        onOpenSettings: @escaping () -> Void,
        onPrimary: @escaping () -> Void
    ) {
        self.init(
            state: state,
            copy: copy,
            isFixedSize: isFixedSize,
            icon: { GlassBrandMarkPlaceholder() },
            onOpenSettings: onOpenSettings,
            onPrimary: onPrimary
        )
    }
}

/// A stand-in app mark: a dark rounded square with an accent dot. Drawn, not
/// bundled — the kit has no resources, and a placeholder that looks
/// *deliberately* like a placeholder is better than one mistaken for art.
public struct GlassBrandMarkPlaceholder: View {
    @Environment(\.glassTheme) private var theme

    public init() {}

    public var body: some View {
        RoundedRectangle(cornerRadius: 14.7, style: .continuous)
            .fill(Color.black.opacity(0.9))
            .overlay {
                Circle()
                    .fill(theme.colors.accent)
                    .frame(width: 18, height: 18)
            }
    }
}

/// Presents a card over a scrimmed, blurred surface — the in-window
/// presentation used for capture and previews. Shipping apps should keep
/// `.sheet`; this exists so the card can be rendered in a gallery.
public struct GlassModalScrim<Content: View>: View {
    @Environment(\.glassTheme) private var theme
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ZStack {
            theme.colors.surfaceScrim
            content
        }
    }
}

#Preview("Onboarding — needs permission") {
    ZStack {
        GlassBackdrop()
        GlassModalScrim {
            GlassOnboardingCard(
                state: .needsPermission(isOpeningSettings: false),
                onOpenSettings: {},
                onPrimary: {}
            )
        }
    }
    .frame(width: 480, height: 500)
}

#Preview("Onboarding — granted") {
    ZStack {
        GlassBackdrop()
        GlassModalScrim {
            GlassOnboardingCard(state: .granted, onOpenSettings: {}, onPrimary: {})
        }
    }
    .frame(width: 480, height: 500)
}

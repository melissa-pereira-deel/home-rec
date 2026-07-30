import SwiftUI

// MARK: - Model

/// A notice's severity — and, because the two are the same question, its
/// **priority**. See `GlassNoticeQueue` for the ordering rule.
public enum GlassNoticeKind: Int, CaseIterable, Comparable, Hashable, Sendable {
    /// Something failed. Red. Always wins the slot.
    case error = 0
    /// Something needs a decision but nothing is broken — the long-recording
    /// warning. Amber.
    case warning = 1
    /// A terminal condition the app can't recover from, such as running
    /// translocated. Neutral, and never dismissible: dismissing a block would
    /// leave a permanently broken app looking fine.
    case blocked = 2
    /// Advisory. Lowest priority, always dismissible.
    case info = 3

    public static func < (lhs: GlassNoticeKind, rhs: GlassNoticeKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The colour role for the severity **icon** — the only coloured element
    /// in a notice.
    ///
    /// Colour used to run the border and the primary action too. That made a
    /// notice the loudest object on a panel whose whole language is hairlines
    /// and one accent: a red-bordered box beside the red record pill put two
    /// competing reds on screen and made a recoverable error look like a
    /// failure state. Confining severity to a 13pt glyph keeps the surface
    /// identical to every other card, so notices stack and sit inline without
    /// restyling their surroundings — and the glyph still carries the meaning,
    /// because shape differs per kind as well as colour.
    public var iconRole: GlassColorRole {
        switch self {
        case .error: .statusDanger
        case .warning: .statusWarning
        // Blocked and info are not failures of the recording — they are
        // conditions. Grey is the honest colour for both.
        case .blocked, .info: .textTertiary
        }
    }

    /// The severity glyph. Shape carries the meaning as much as colour does,
    /// which is what keeps the notice readable in greyscale and for the ~8%
    /// of men with a red/green deficiency.
    public var iconName: String {
        switch self {
        case .error: "exclamationmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .blocked: "hand.raised.fill"
        case .info: "info.circle"
        }
    }

    /// How VoiceOver introduces the notice. Without this a notice reads as a
    /// bare sentence with no indication that anything is wrong.
    public var accessibilityPrefix: String {
        switch self {
        case .error: "Problem"
        case .warning: "Warning"
        case .blocked: "Blocked"
        case .info: "Note"
        }
    }
}

/// A recovery action attached to a notice.
public struct GlassNoticeAction: Identifiable {
    public enum Emphasis { case primary, secondary }

    public let id = UUID()
    public let title: String
    public let emphasis: Emphasis
    public let action: () -> Void

    public init(_ title: String, emphasis: Emphasis = .primary, action: @escaping () -> Void) {
        self.title = title
        self.emphasis = emphasis
        self.action = action
    }
}

/// Something the user needs to know, with what to do about it.
///
/// Copy is supplied by the host verbatim — the kit deliberately ships no
/// default error strings. Error copy is product surface area, it is already
/// written and reviewed in the app, and a design system that paraphrases it
/// creates two sources of truth for the same sentence.
public struct GlassNotice: Identifiable {
    public let id: String
    public var kind: GlassNoticeKind
    public var message: String
    public var actions: [GlassNoticeAction]
    public var isDismissible: Bool

    public init(
        id: String,
        kind: GlassNoticeKind,
        message: String,
        actions: [GlassNoticeAction] = [],
        isDismissible: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.message = message
        self.actions = actions
        self.isDismissible = isDismissible
    }
}

// MARK: - Row

/// The notice surface.
///
/// One row, on the panel itself — not an alert. Alerts are modal, they can
/// only appear on a window, and a menu-bar-only user never sees them; the
/// shipping app's disk-full and permission errors were invisible in the
/// popover for exactly that reason. A row renders anywhere the kit renders.
public struct GlassNoticeRow: View {
    private let notice: GlassNotice
    private let dismissTitle: String
    private let onDismiss: () -> Void

    @Environment(\.glassTheme) private var theme

    public init(
        _ notice: GlassNotice,
        dismissTitle: String = "dismiss",
        onDismiss: @escaping () -> Void = {}
    ) {
        self.notice = notice
        self.dismissTitle = dismissTitle
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(alignment: .top, spacing: GlassSpacing.s) {
            icon
            VStack(alignment: .leading, spacing: GlassSpacing.s) {
                message
                if !notice.actions.isEmpty || notice.isDismissible {
                    actionRow
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GlassSpacing.md)
        // The same neutral card every other container uses. A notice is a
        // message, not a different material.
        .glassSurface(.card)
        // `.contain` rather than `.combine`: the actions must stay individually
        // reachable, but the container carries the severity so a VoiceOver user
        // hears "Problem" before the sentence.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(notice.kind.accessibilityPrefix)
        .accessibilityValue(notice.message)
    }

    private var icon: some View {
        Image(systemName: notice.kind.iconName)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(theme.colors[notice.kind.iconRole])
            // Nudged onto the first line's cap height. The glyph's own box is
            // taller than the 12pt caption beside it, so centring it on the
            // line box would leave it visibly low.
            .padding(.top, 1)
            .accessibilityHidden(true)
    }

    private var message: some View {
        Text(notice.message)
            .glassText(.captionSmall, color: .textPrimary)
            // Notice copy is the one text in the kit allowed to wrap; it must
            // never truncate, because the truncated half is always the part
            // that says what to do.
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Emphasis is weight, not hue and not an outline: the recovery action is
    /// a near-white fill, its alternative a light grey one, and `dismiss` —
    /// which is an escape rather than a choice — carries no resting fill at
    /// all. Nothing here is stroked.
    private var actionRow: some View {
        HStack(spacing: GlassSpacing.s) {
            ForEach(orderedActions) { action in
                GlassPillButton(
                    action.title,
                    emphasis: action.emphasis == .primary ? .primaryNeutral : .secondary,
                    size: .mini,
                    action: action.action
                )
            }
            if notice.isDismissible {
                GlassPillButton(dismissTitle, emphasis: .tertiary, size: .mini, action: onDismiss)
            }
            Spacer(minLength: 0)
        }
    }

    /// Primary first, then secondaries in the order given; `dismiss` renders
    /// after both. Ordered here rather than trusting the caller, so the button
    /// to press is always leftmost — a notice that ordered them differently
    /// per error would move the target under a user mid-reach.
    private var orderedActions: [GlassNoticeAction] {
        notice.actions.filter { $0.emphasis == .primary }
            + notice.actions.filter { $0.emphasis == .secondary }
    }
}

#Preview("Notices") {
    GlassPreviewStage {
        VStack(spacing: GlassSpacing.md) {
            GlassNoticeRow(
                GlassNotice(
                    id: "startFailed",
                    kind: .error,
                    message: "Home Rec couldn't start recording. Make sure some audio is playing, then try again.",
                    actions: [.init("Try again") {}]
                )
            )
            GlassNoticeRow(
                GlassNotice(
                    id: "longRecording",
                    kind: .warning,
                    message: "You've been recording for a while. Long recordings use a lot of disk space — about 10 MB per minute.",
                    actions: [
                        .init("Stop") {},
                        .init("Keep recording", emphasis: .secondary) {},
                    ],
                    isDismissible: false
                )
            )
            GlassNoticeRow(
                GlassNotice(
                    id: "translocated",
                    kind: .blocked,
                    message: "Home Rec can't record from the disk image. Quit, drag it to your Applications folder, and open it from there.",
                    isDismissible: false
                )
            )
            GlassNoticeRow(
                GlassNotice(id: "info", kind: .info, message: "Saved to Desktop.")
            )
        }
    }
}

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

    /// The colour role that tints the notice's border and primary action.
    public var tintRole: GlassColorRole {
        switch self {
        case .error: .statusDanger
        case .warning: .statusWarning
        case .blocked: .statusNeutral
        case .info: .statusNeutral
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
        VStack(alignment: .leading, spacing: GlassSpacing.s) {
            Text(notice.message)
                .glassText(.captionSmall, color: .textPrimary)
                // Notice copy is the one text in the kit allowed to wrap; it
                // must never truncate, because the truncated half is always
                // the part that says what to do.
                .fixedSize(horizontal: false, vertical: true)

            if !notice.actions.isEmpty || notice.isDismissible {
                HStack(spacing: GlassSpacing.s) {
                    ForEach(notice.actions) { action in
                        GlassPillButton(
                            action.title,
                            variant: action.emphasis == .primary
                                ? .solidTinted(theme.colors[notice.kind.tintRole])
                                : .neutral,
                            size: .mini,
                            action: action.action
                        )
                    }
                    if notice.isDismissible {
                        GlassPillButton(dismissTitle, variant: .neutral, size: .mini, action: onDismiss)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GlassSpacing.md)
        .glassSurface(.notice(tint: theme.colors[notice.kind.tintRole]))
        // `.contain` rather than `.combine`: the actions must stay individually
        // reachable, but the container carries the severity so a VoiceOver user
        // hears "Problem" before the sentence.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(notice.kind.accessibilityPrefix)
        .accessibilityValue(notice.message)
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

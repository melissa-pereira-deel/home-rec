import SwiftUI

/// The notice slot.
///
/// A Glass surface has **one** notice slot, and it is the same slot the shelf
/// (or any other secondary content) occupies. That is a layout decision with a
/// product reason: the recorder face is a fixed-size floating panel, so a
/// notice that *adds* height either overflows the window or pushes the
/// transport control off it. Yielding a slot instead keeps the panel's
/// geometry constant no matter how much goes wrong.
///
/// Which notice gets the slot is decided here, and the order is not arbitrary:
///
/// 1. **error** — something failed; it is the most recent thing the user did.
/// 2. **warning** — the long-recording nudge; needs a decision, nothing broken.
/// 3. **blocked** — terminal conditions like translocation. Last, despite
///    being the most severe, because it is *static*: it was true before the
///    session started and will still be true after the error is dismissed,
///    whereas an error is news.
/// 4. **info** — advisory.
///
/// Ties inside a kind break by insertion order: oldest first, so a burst of
/// failures doesn't hide the one that started it.
public enum GlassNoticeQueue {

    /// The notice that owns the slot, or `nil` when the slot is free.
    public static func topmost(of notices: [GlassNotice]) -> GlassNotice? {
        notices.enumerated()
            .min { lhs, rhs in
                if lhs.element.kind != rhs.element.kind {
                    return lhs.element.kind < rhs.element.kind
                }
                return lhs.offset < rhs.offset
            }?
            .element
    }

    /// Whether any notice wants the slot. Drives the swap between the slot's
    /// default content and the notice row.
    public static func isSlotOccupied(by notices: [GlassNotice]) -> Bool {
        !notices.isEmpty
    }

    /// The full queue in priority order — for a surface with room for more
    /// than one (a settings sheet, a diagnostics view).
    public static func ordered(_ notices: [GlassNotice]) -> [GlassNotice] {
        notices.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.kind != rhs.element.kind {
                    return lhs.element.kind < rhs.element.kind
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

/// The slot itself: renders the highest-priority notice, or its default
/// content when there is nothing to say.
///
/// ```swift
/// GlassNoticeSlot(notices: model.notices, onDismiss: model.dismiss) {
///     RecentTakesShelf(takes: model.recent)
/// }
/// ```
public struct GlassNoticeSlot<Default: View>: View {
    private let notices: [GlassNotice]
    private let onDismiss: (GlassNotice) -> Void
    private let defaultContent: Default

    public init(
        notices: [GlassNotice],
        onDismiss: @escaping (GlassNotice) -> Void = { _ in },
        @ViewBuilder default defaultContent: () -> Default
    ) {
        self.notices = notices
        self.onDismiss = onDismiss
        self.defaultContent = defaultContent()
    }

    public var body: some View {
        Group {
            if let notice = GlassNoticeQueue.topmost(of: notices) {
                GlassNoticeRow(notice) { onDismiss(notice) }
                    .transition(.opacity)
            } else {
                defaultContent
                    .transition(.opacity)
            }
        }
        // Opacity, not a slide: the two contents are different heights, and a
        // slide would make the panel's centre of gravity jump on every error.
        .glassAnimation(.swap, value: GlassNoticeQueue.topmost(of: notices)?.id)
    }
}

#Preview("Notice slot — priority") {
    GlassPreviewStage {
        VStack(alignment: .leading, spacing: GlassSpacing.md) {
            GlassEyebrow("slot with error + warning + block → error wins")
            GlassNoticeSlot(notices: [
                GlassNotice(id: "translocated", kind: .blocked, message: "Home Rec can't record from the disk image.", isDismissible: false),
                GlassNotice(id: "long", kind: .warning, message: "You've been recording for a while."),
                GlassNotice(id: "startFailed", kind: .error, message: "Home Rec couldn't start recording. Make sure some audio is playing, then try again.", actions: [.init("Try again") {}]),
            ]) {
                GlassEyebrow("recent")
            }

            GlassEyebrow("empty slot → default content")
            GlassNoticeSlot(notices: []) {
                GlassMetaLabel("recent takes go here")
            }
        }
    }
}

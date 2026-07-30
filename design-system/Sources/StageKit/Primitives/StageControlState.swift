import SwiftUI

/// The three states any stage control can be in.
///
/// There is no "hover" case: hover is a pointer affordance the primitive
/// handles internally, not a state a caller reasons about.
@available(macOS 15.0, *)
public enum StageControlState: Hashable, CaseIterable {
    /// Available, not currently applied.
    case idle
    /// Currently applied. Rendered as an inverted slab.
    case active
    /// Not applicable in the current state of the prototype. Still visible —
    /// hiding an axis that momentarily does not apply makes the scrubber
    /// reflow, and a scrubber that moves under the pointer is unusable.
    case disabled

    public var isInteractive: Bool { self != .disabled }
}

/// Restrained keyboard-focus decoration shared by every stage control.
///
/// StageKit disables the system focus effect and draws this instead, because
/// the system ring is tuned for full-size AppKit controls and overwhelms a 20pt
/// chip. The ring sits *outside* the control so it never shrinks the label.
@available(macOS 15.0, *)
struct StageFocusRing: ViewModifier {
    let isFocused: Bool
    let cornerRadius: CGFloat

    @Environment(\.stageTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let inset = theme.metrics.focusRingInset
        content.overlay {
            RoundedRectangle(cornerRadius: cornerRadius + inset, style: .continuous)
                .strokeBorder(theme.colors.focus, lineWidth: theme.metrics.focusRingWidth)
                .padding(-inset)
                .opacity(isFocused ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: isFocused)
        }
    }
}

@available(macOS 15.0, *)
extension View {
    func stageFocusRing(_ isFocused: Bool, cornerRadius: CGFloat) -> some View {
        modifier(StageFocusRing(isFocused: isFocused, cornerRadius: cornerRadius))
    }

    /// Expands the interactive area to the theme's minimum hit target without
    /// changing the painted size.
    @ViewBuilder
    func stageHitTarget() -> some View {
        modifier(StageHitTarget())
    }
}

@available(macOS 15.0, *)
struct StageHitTarget: ViewModifier {
    @Environment(\.stageTheme) private var theme

    func body(content: Content) -> some View {
        content
            .frame(minWidth: theme.metrics.minHitTarget, minHeight: theme.metrics.minHitTarget)
            .contentShape(Rectangle())
    }
}

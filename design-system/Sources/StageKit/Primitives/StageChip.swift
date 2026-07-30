import SwiftUI

/// The scrubber button: the atom of the state-driving language.
///
/// One chip means "put the prototype in this state". Idle chips are dark slabs
/// with mid-grey labels; the active chip inverts. Inversion rather than tint is
/// what lets a reviewer find the current state across a room, in a screenshot,
/// or in a photo of a screen — all three happen constantly during design review.
@available(macOS 15.0, *)
public struct StageChip: View {
    private let title: String
    private let state: StageControlState
    private let glyph: String?
    private let isKeyboardFocused: Bool
    private let accessibilityLabelText: String?
    private let accessibilityValueText: String?
    private let accessibilityHintText: String?
    private let action: () -> Void

    @Environment(\.stageTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    /// - Parameters:
    ///   - glyph: a trailing marker. `"▸"` marks a chip that *steps* through
    ///     values rather than setting one, which is otherwise invisible.
    ///   - isKeyboardFocused: supplied by the owning component, which holds the
    ///     `FocusState`. The primitive stays stateless so it can be previewed
    ///     and snapshotted in every combination.
    ///   - accessibilityLabel: overrides the visible title. Chips abbreviate
    ///     aggressively to stay out of the way; the spoken label should not.
    ///   - accessibilityValue: defaults to on/off. Components that know better
    ///     (an enum cycle, a picker) pass the real value name.
    public init(
        _ title: String,
        state: StageControlState = .idle,
        glyph: String? = nil,
        isKeyboardFocused: Bool = false,
        accessibilityLabel: String? = nil,
        accessibilityValue: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.state = state
        self.glyph = glyph
        self.isKeyboardFocused = isKeyboardFocused
        self.accessibilityLabelText = accessibilityLabel
        self.accessibilityValueText = accessibilityValue
        self.accessibilityHintText = accessibilityHint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            pill.stageHitTarget()
        }
        .buttonStyle(.plain)
        .disabled(state == .disabled)
        .onHover { isHovering = $0 && state.isInteractive }
        .accessibilityLabel(Text(accessibilityLabelText ?? title))
        .accessibilityValue(Text(resolvedAccessibilityValue))
        .accessibilityHint(Text(accessibilityHintText ?? ""))
        .accessibilityAddTraits(state == .active ? [.isSelected] : [])
    }

    private var pill: some View {
        HStack(spacing: theme.metrics.unit) {
            StageLabel(title, style: theme.typography.chip, tone: labelTone)
            if let glyph {
                Text(glyph)
                    .font(theme.typography.chip.font)
                    .foregroundStyle(theme.colors.color(labelTone))
                    // The step marker is an affordance, not content: it should
                    // register peripherally and never be read as a label.
                    .opacity(0.6)
            }
        }
        .padding(.horizontal, theme.metrics.controlPaddingHorizontal)
        .frame(height: theme.metrics.controlHeight)
        .background(fill, in: RoundedRectangle(cornerRadius: theme.metrics.controlRadius, style: .continuous))
        .stageFocusRing(isKeyboardFocused, cornerRadius: theme.metrics.controlRadius)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: state)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.09), value: isHovering)
    }

    private var fill: Color {
        switch state {
        case .active: theme.colors.controlFillActive
        case .disabled: theme.colors.controlFillDisabled
        case .idle: isHovering ? theme.colors.controlFillHover : theme.colors.controlFill
        }
    }

    private var labelTone: StageTone {
        switch state {
        case .active: .onActive
        case .disabled: .disabled
        case .idle: isHovering ? .strong : .primary
        }
    }

    private var resolvedAccessibilityValue: String {
        if let accessibilityValueText { return accessibilityValueText }
        switch state {
        case .active: return "On"
        case .idle: return "Off"
        case .disabled: return "Unavailable"
        }
    }
}

@available(macOS 15.0, *)
#Preview("StageChip states") {
    HStack(spacing: 8) {
        StageChip("IDLE") {}
        StageChip("ACTIVE", state: .active) {}
        StageChip("DISABLED", state: .disabled) {}
        StageChip("FOCUSED", isKeyboardFocused: true) {}
        StageChip("ERR", glyph: "▸") {}
        StageChip("ERR DISK", state: .active, glyph: "▸") {}
    }
    .padding(20)
    .background(StageTheme.dark.colors.chrome)
}

import SwiftUI

/// A numbered concept tab.
///
/// Tabs are text-only — no fill, no underline, no capsule. A stage typically
/// hosts three to six competing designs and the tab bar sits directly above
/// them; anything with a border there reads as part of the topmost concept's
/// frame. Selection is carried purely by label weight/brightness.
@available(macOS 15.0, *)
public struct StageTab: View {
    private let index: Int?
    private let title: String
    private let isSelected: Bool
    private let isKeyboardFocused: Bool
    private let accessibilityHintText: String?
    private let action: () -> Void

    @Environment(\.stageTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameter index: the 1-based shortcut number shown before the title.
    ///   `nil` renders the title alone, for stages with more than nine concepts
    ///   where numbering would be a lie.
    public init(
        index: Int?,
        title: String,
        isSelected: Bool,
        isKeyboardFocused: Bool = false,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.index = index
        self.title = title
        self.isSelected = isSelected
        self.isKeyboardFocused = isKeyboardFocused
        self.accessibilityHintText = accessibilityHint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            label.stageHitTarget()
        }
        .buttonStyle(.plain)
        // The number is a shortcut affordance, not part of the concept's name —
        // VoiceOver reads the name only.
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(accessibilityHintText ?? ""))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var label: some View {
        HStack(spacing: theme.metrics.unit + 1) {
            if let index {
                StageLabel("\(index)", style: theme.typography.tab, tone: tone)
                    // Half-weight the number so the eye lands on the name first
                    // but the shortcut stays discoverable.
                    .opacity(0.55)
            }
            StageLabel(title, style: theme.typography.tab, tone: tone)
        }
        .padding(.horizontal, theme.metrics.unit / 2)
        .frame(height: theme.metrics.controlHeight)
        .stageFocusRing(isKeyboardFocused, cornerRadius: theme.metrics.controlRadius)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isSelected)
    }

    private var tone: StageTone { isSelected ? .strong : .primary }
}

@available(macOS 15.0, *)
#Preview("StageTab") {
    HStack(spacing: 14) {
        StageTab(index: 1, title: "Pocket Op", isSelected: false) {}
        StageTab(index: 2, title: "Dictaphone", isSelected: true) {}
        StageTab(index: 3, title: "Braun", isSelected: false, isKeyboardFocused: true) {}
        StageTab(index: nil, title: "Unnumbered", isSelected: false) {}
    }
    .padding(20)
    .background(StageTheme.dark.colors.chrome)
}

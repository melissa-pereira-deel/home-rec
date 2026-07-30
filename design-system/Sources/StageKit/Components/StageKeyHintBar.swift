import SwiftUI

/// The run of keyboard hints at the trailing edge of the scrubber.
///
/// It reads as one grey line rather than a list, on purpose: it is a reminder
/// for someone who already knows the stage, not documentation for someone
/// learning it.
@available(macOS 15.0, *)
public struct StageKeyHintBar: View {
    private let items: [StageKeyHintItem]

    @Environment(\.stageTheme) private var theme

    public init(_ items: [StageKeyHintItem]) {
        self.items = items
    }

    public var body: some View {
        HStack(spacing: theme.metrics.unit + 2) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Text("·")
                        .font(theme.typography.hint.font)
                        .foregroundStyle(theme.colors.color(.disabled))
                        .accessibilityHidden(true)
                }
                StageKeyHint(item)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Keyboard shortcuts"))
    }
}

@available(macOS 15.0, *)
#Preview("StageKeyHintBar") {
    StageKeyHintBar([
        .init("1–4", "concept"),
        .init("\\", "screen"),
        .init("e", "error"),
        .init("⌘R"),
    ])
    .padding(16)
    .background(StageTheme.dark.colors.chrome)
}

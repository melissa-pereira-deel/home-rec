import SwiftUI

/// One keyboard affordance: the key, and optionally what it does.
@available(macOS 15.0, *)
public struct StageKeyHintItem: Identifiable, Hashable {
    /// Rendered verbatim — pass the glyphs you want the reviewer to see
    /// (`⌘R`, `1–9`, `⇥`, `\`).
    public let key: String
    /// Lowercase verb or noun. `nil` renders the key alone, which is right when
    /// a run of hints share an obvious purpose.
    public let label: String?

    public var id: String { label.map { "\(key)-\($0)" } ?? key }

    public init(_ key: String, _ label: String? = nil) {
        self.key = key
        self.label = label
    }
}

/// Displays a single keyboard shortcut.
///
/// No keycap chrome. The hint row lives at the very bottom of the stage and is
/// the least important thing on screen; boxing each key would give the quietest
/// element the most visual structure.
@available(macOS 15.0, *)
public struct StageKeyHint: View {
    private let item: StageKeyHintItem

    @Environment(\.stageTheme) private var theme

    public init(_ key: String, _ label: String? = nil) {
        self.item = StageKeyHintItem(key, label)
    }

    public init(_ item: StageKeyHintItem) {
        self.item = item
    }

    public var body: some View {
        HStack(spacing: theme.metrics.unit) {
            Text(item.key)
                .font(theme.typography.key.font)
                .tracking(theme.typography.key.tracking)
                .foregroundStyle(theme.colors.color(.muted))
            if let label = item.label {
                Text(label)
                    .font(theme.typography.hint.font)
                    .tracking(theme.typography.hint.tracking)
                    .foregroundStyle(theme.colors.color(.disabled))
            }
        }
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.label.map { "\($0), shortcut \(item.key)" } ?? "Shortcut \(item.key)"))
    }
}

@available(macOS 15.0, *)
#Preview("StageKeyHint") {
    HStack(spacing: 10) {
        StageKeyHint("1–9", "concept")
        StageKeyHint("⌘R")
        StageKeyHint("\\", "screen")
    }
    .padding(20)
    .background(StageTheme.dark.colors.chrome)
}

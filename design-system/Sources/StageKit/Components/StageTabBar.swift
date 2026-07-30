import SwiftUI

@available(macOS 15.0, *)
public struct StageTabItem: Identifiable, Hashable {
    public let id: String
    public let title: String
    /// 1-based shortcut number. `nil` for unnumbered tabs.
    public let number: Int?

    public init(id: String, title: String, number: Int?) {
        self.id = id
        self.title = title
        self.number = number
    }
}

/// The top bar: numbered concept switching, plus whatever the stage wants at
/// the trailing edge.
///
/// Left-aligned and flush to the window edge, because the tab bar is a table of
/// contents, not a title bar. Centring it would make it look like the concept's
/// own navigation.
@available(macOS 15.0, *)
public struct StageTabBar<Trailing: View>: View {
    private let items: [StageTabItem]
    @Binding private var selection: String
    private let trailing: Trailing

    @Environment(\.stageTheme) private var theme
    @FocusState private var focusedTab: String?

    public init(
        items: [StageTabItem],
        selection: Binding<String>,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.items = items
        self._selection = selection
        self.trailing = trailing()
    }

    public var body: some View {
        StageBar {
            HStack(spacing: theme.metrics.tabSpacing) {
                ForEach(items) { item in
                    StageTab(
                        index: item.number,
                        title: item.title,
                        isSelected: item.id == selection,
                        isKeyboardFocused: focusedTab == item.id,
                        accessibilityHint: hint(for: item)
                    ) {
                        selection = item.id
                    }
                    .focusable()
                    .focused($focusedTab, equals: item.id)
                }
                Spacer(minLength: theme.metrics.groupSpacing)
                trailing
            }
        }
        // Arrow keys walk the bar the way they walk a real tab control. Without
        // this a keyboard user has to tab through every tab to reach the last.
        .onKeyPress(.leftArrow) { moveFocus(by: -1) }
        .onKeyPress(.rightArrow) { moveFocus(by: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Concepts"))
    }

    private func hint(for item: StageTabItem) -> String? {
        guard let number = item.number else { return nil }
        return "Press \(number)"
    }

    private func moveFocus(by delta: Int) -> KeyPress.Result {
        guard let current = focusedTab,
              let index = items.firstIndex(where: { $0.id == current })
        else { return .ignored }
        let next = index + delta
        guard items.indices.contains(next) else { return .ignored }
        focusedTab = items[next].id
        return .handled
    }
}

@available(macOS 15.0, *)
extension StageTabBar where Trailing == EmptyView {
    public init(items: [StageTabItem], selection: Binding<String>) {
        self.init(items: items, selection: selection) { EmptyView() }
    }
}

@available(macOS 15.0, *)
#Preview("StageTabBar") {
    struct Harness: View {
        @State private var selection = "b"
        var body: some View {
            StageTabBar(
                items: [
                    .init(id: "a", title: "Pocket Op", number: 1),
                    .init(id: "b", title: "Dictaphone", number: 2),
                    .init(id: "c", title: "Braun", number: 3),
                    .init(id: "d", title: "Glass", number: 4),
                ],
                selection: $selection
            ) {
                StageChip("⇥ LIBRARY") {}
            }
            .frame(width: 620)
        }
    }
    return Harness()
}

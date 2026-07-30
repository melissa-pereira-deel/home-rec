import SwiftUI

/// A complete stage, generated from a ``StageDriver``.
///
/// Everything visible here — the numbered tabs, the trailing screen switch, the
/// chips, the hint row, the shortcuts — is derived from the concepts and axes
/// the consumer declared. Adding an axis adds a chip, a shortcut, a hint, and a
/// column of snapshots, with no further wiring. That is the difference between
/// a chrome component and a prototype operating system.
@available(macOS 15.0, *)
public struct StageWindow<Model>: View {
    @ObservedObject private var driver: StageDriver<Model>
    private let stageSize: CGSize?
    private let extraHints: [StageKeyHintItem]
    private let extraKeyHandler: ((KeyPress) -> KeyPress.Result)?

    @Environment(\.stageTheme) private var theme
    @FocusState private var stageHasFocus: Bool

    /// - Parameters:
    ///   - stageSize: exact size of the content well. See ``StageFrame``.
    ///   - hints: appended to the shortcuts StageKit derives itself. Use it for
    ///     keys your *concepts* handle, which the stage cannot know about.
    ///   - onKeyPress: last-resort handler, consulted only after StageKit's own
    ///     shortcuts decline the key.
    public init(
        driver: StageDriver<Model>,
        stageSize: CGSize? = nil,
        hints: [StageKeyHintItem] = [],
        onKeyPress: ((KeyPress) -> KeyPress.Result)? = nil
    ) {
        self.driver = driver
        self.stageSize = stageSize
        self.extraHints = hints
        self.extraKeyHandler = onKeyPress
    }

    public var body: some View {
        StageFrame(stageSize: stageSize) {
            StageTabBar(items: tabItems, selection: conceptSelection) {
                trailingAxes
            }
        } content: {
            conceptContent
        } scrubber: {
            StageScrubber(
                groups: driver.scrubberGroups,
                state: $driver.state,
                hints: driver.derivedKeyHints + extraHints
            )
        }
        // The root is focusable so bare-digit shortcuts work on launch without
        // a click. A focused control inside a concept — a text field — consumes
        // its keys first, so typing never switches concepts by accident.
        .focusable()
        .focused($stageHasFocus)
        .focusEffectDisabled()
        .onAppear { stageHasFocus = true }
        .onKeyPress { press in
            let result = driver.handleStageKey(press)
            if result == .handled { return .handled }
            return extraKeyHandler?(press) ?? .ignored
        }
    }

    // MARK: Pieces

    private var tabItems: [StageTabItem] {
        driver.concepts.enumerated().map { index, concept in
            StageTabItem(
                id: concept.id,
                title: concept.title,
                // Past nine there is no unmodified key left to offer, and a
                // number with no shortcut behind it is a lie.
                number: index < 9 ? index + 1 : nil
            )
        }
    }

    private var conceptSelection: Binding<String> {
        Binding(
            get: { driver.conceptID },
            set: { driver.select(conceptID: $0) }
        )
    }

    @ViewBuilder
    private var conceptContent: some View {
        if let concept = driver.concept {
            concept.view(state: $driver.state)
                .accessibilityLabel(Text(concept.title))
        } else {
            StageLabel("no concepts", style: theme.typography.caption, tone: .disabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var trailingAxes: some View {
        if !driver.tabBarTrailingAxes.isEmpty {
            StageScrubber(
                groups: [StageAxisGroup(id: "trailing", axes: driver.tabBarTrailingAxes)],
                state: $driver.state
            )
            // The scrubber brings its own bar surface; inside the tab bar it
            // must be transparent and unpadded, or the two bars nest visibly.
            .stageBarStripped()
        }
    }
}

/// Removes ``StageBar``'s surface from a nested component.
@available(macOS 15.0, *)
extension View {
    func stageBarStripped() -> some View {
        modifier(StageBarStripped())
    }
}

@available(macOS 15.0, *)
struct StageBarStripped: ViewModifier {
    @Environment(\.stageTheme) private var theme

    func body(content: Content) -> some View {
        var stripped = theme
        stripped.colors.chrome = .clear
        stripped.metrics.barPaddingHorizontal = 0
        stripped.metrics.barPaddingVertical = 0
        return content
            .environment(\.stageTheme, stripped)
            .fixedSize()
    }
}

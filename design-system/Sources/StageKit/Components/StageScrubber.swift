import SwiftUI

/// The bottom bar: every declared axis, rendered as chips.
///
/// This is the payoff of the axis model. A consumer never writes a chip; they
/// declare `.toggle("EMPTY", path: \.isEmpty)` and get the control, its active
/// state, its accessibility, and its place in the snapshot matrix at once.
/// Hand-written chips drift out of sync with the state they claim to set —
/// generated ones cannot.
@available(macOS 15.0, *)
public struct StageScrubber<Model>: View {
    private let groups: [StageAxisGroup<Model>]
    @Binding private var state: Model
    private let hints: [StageKeyHintItem]

    @Environment(\.stageTheme) private var theme
    @FocusState private var focusedChip: String?

    public init(
        groups: [StageAxisGroup<Model>],
        state: Binding<Model>,
        hints: [StageKeyHintItem] = []
    ) {
        self.groups = groups
        self._state = state
        self.hints = hints
    }

    public init(
        axes: [StageAxis<Model>],
        state: Binding<Model>,
        hints: [StageKeyHintItem] = []
    ) {
        self.init(groups: [StageAxisGroup(id: "default", axes: axes)], state: state, hints: hints)
    }

    public var body: some View {
        StageBar {
            VStack(alignment: .leading, spacing: theme.metrics.rowSpacing) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, group in
                    HStack(spacing: theme.metrics.groupSpacing) {
                        if let title = group.title {
                            StageLabel(title, style: theme.typography.caption, tone: .disabled)
                        }
                        ForEach(group.axes) { axis in
                            axisView(axis)
                        }
                        // Hints ride the last row so they never claim a line of
                        // their own — chrome height is stolen from the concept.
                        if index == rows.count - 1 && !hints.isEmpty {
                            Spacer(minLength: theme.metrics.groupSpacing)
                            StageKeyHintBar(hints)
                        } else {
                            // Zero minimum: a scrubber nested inside another bar
                            // must not reserve trailing space it does not use.
                            Spacer(minLength: 0)
                        }
                    }
                }
                if rows.isEmpty && !hints.isEmpty {
                    HStack {
                        Spacer(minLength: 0)
                        StageKeyHintBar(hints)
                    }
                }
            }
        }
        .onKeyPress(.leftArrow) { moveFocus(columns: -1) }
        .onKeyPress(.rightArrow) { moveFocus(columns: 1) }
        .onKeyPress(.upArrow) { moveFocus(rows: -1) }
        .onKeyPress(.downArrow) { moveFocus(rows: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("State scrubber"))
    }

    private var rows: [StageAxisGroup<Model>] { groups }

    // MARK: Axis rendering

    @ViewBuilder
    private func axisView(_ axis: StageAxis<Model>) -> some View {
        switch axis.presentation {
        case .toggle, .cycle:
            summaryChip(axis)
        case .chips:
            HStack(spacing: theme.metrics.chipSpacing) {
                ForEach(axis.values) { value in
                    optionChip(axis, value)
                }
            }
        case .segmented:
            StageSegmentedControl(
                selection: segmentedSelection(for: axis),
                segments: axis.values.map { StageSegment($0.id, $0.label) },
                enabled: axis.isEnabled(state),
                accessibilityLabel: axis.title
            )
        }
    }

    /// One chip standing for the whole axis: toggles and cycles.
    private func summaryChip(_ axis: StageAxis<Model>) -> some View {
        let controlState = axis.controlState(in: state)
        return StageChip(
            axis.summaryLabel(state),
            state: controlState,
            // The step marker stays visible even once a cycle is off its base,
            // so the affordance never disappears at the moment it is most
            // needed — when you want the *next* variant.
            glyph: axis.presentation == .cycle ? "▸" : nil,
            isKeyboardFocused: focusedChip == axis.id,
            accessibilityLabel: axis.title,
            accessibilityValue: axis.accessibilityValue(in: state),
            accessibilityHint: axis.presentation == .cycle ? "Steps to the next value" : nil
        ) {
            step(axis)
        }
        .focusable(controlState.isInteractive)
        .focused($focusedChip, equals: axis.id)
    }

    /// One chip per position: pickers and compound shots.
    private func optionChip(_ axis: StageAxis<Model>, _ value: StageAxisValue<Model>) -> some View {
        let enabled = axis.isEnabled(state)
        let isCurrent = axis.currentValueID(state) == value.id
        let id = "\(axis.id)/\(value.id)"
        return StageChip(
            value.label,
            state: enabled ? (isCurrent ? .active : .idle) : .disabled,
            isKeyboardFocused: focusedChip == id,
            accessibilityLabel: "\(axis.title), \(value.label)",
            accessibilityValue: isCurrent ? "Selected" : "Not selected"
        ) {
            state = applying(value)
        }
        .focusable(enabled)
        .focused($focusedChip, equals: id)
    }

    private func segmentedSelection(for axis: StageAxis<Model>) -> Binding<String> {
        Binding(
            get: { axis.currentValueID(state) ?? "" },
            set: { id in
                guard let value = axis.value(id: id) else { return }
                state = applying(value)
            }
        )
    }

    private func step(_ axis: StageAxis<Model>) {
        guard axis.isEnabled(state), let next = axis.value(steppedBy: 1, from: state) else { return }
        state = applying(next)
    }

    private func applying(_ value: StageAxisValue<Model>) -> Model {
        var copy = state
        value.apply(&copy)
        return copy
    }

    // MARK: Keyboard focus

    /// Focusable chip ids, row by row. Segmented axes are excluded because they
    /// own left/right themselves; they stay reachable by tab.
    private var focusGrid: [[String]] {
        rows.map { group in
            group.axes.flatMap { axis -> [String] in
                guard axis.isEnabled(state) else { return [] }
                switch axis.presentation {
                case .toggle, .cycle: return [axis.id]
                case .chips: return axis.values.map { "\(axis.id)/\($0.id)" }
                case .segmented: return []
                }
            }
        }
    }

    private func position(of id: String) -> (row: Int, column: Int)? {
        let grid = focusGrid
        for (row, ids) in grid.enumerated() {
            if let column = ids.firstIndex(of: id) { return (row, column) }
        }
        return nil
    }

    private func moveFocus(columns delta: Int) -> KeyPress.Result {
        guard let id = focusedChip, let spot = position(of: id) else { return .ignored }
        let grid = focusGrid
        let next = spot.column + delta
        guard grid[spot.row].indices.contains(next) else { return .ignored }
        focusedChip = grid[spot.row][next]
        return .handled
    }

    private func moveFocus(rows delta: Int) -> KeyPress.Result {
        guard let id = focusedChip, let spot = position(of: id) else { return .ignored }
        let grid = focusGrid
        let nextRow = spot.row + delta
        guard grid.indices.contains(nextRow), !grid[nextRow].isEmpty else { return .ignored }
        // Hold the column when moving between rows of unequal length, clamping
        // rather than wrapping — wrapping loses the reviewer's place.
        let column = min(spot.column, grid[nextRow].count - 1)
        focusedChip = grid[nextRow][column]
        return .handled
    }
}

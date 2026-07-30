import SwiftUI

@available(macOS 15.0, *)
public struct StageSegment<Value: Hashable>: Identifiable {
    public let value: Value
    public let label: String

    public var id: Value { value }

    public init(_ value: Value, _ label: String) {
        self.value = value
        self.label = label
    }
}

/// A mono segmented control for small, mutually exclusive, *ordered* sets.
///
/// Use it over a row of chips when the values form a scale (density, size,
/// count) — a joined track tells the reviewer the options are one dimension.
/// Use chips when the values are unrelated jumps.
@available(macOS 15.0, *)
public struct StageSegmentedControl<Value: Hashable>: View {
    private let segments: [StageSegment<Value>]
    @Binding private var selection: Value
    private let enabled: Bool
    private let accessibilityLabelText: String?

    @Environment(\.stageTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedSegment: Value?

    public init(
        selection: Binding<Value>,
        segments: [StageSegment<Value>],
        enabled: Bool = true,
        accessibilityLabel: String? = nil
    ) {
        self._selection = selection
        self.segments = segments
        self.enabled = enabled
        self.accessibilityLabelText = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: theme.metrics.hairline) {
            ForEach(segments) { segment in
                segmentButton(segment)
            }
        }
        .padding(theme.metrics.hairline)
        .background(
            theme.colors.controlFill,
            in: RoundedRectangle(cornerRadius: theme.metrics.controlRadius + 1, style: .continuous)
        )
        .opacity(enabled ? 1 : 0.55)
        .stageHitTarget()
        // Arrow keys walk a segmented control on every other platform; a
        // reviewer should not have to learn a new idiom for this one.
        .onKeyPress(.leftArrow) { move(by: -1) }
        .onKeyPress(.rightArrow) { move(by: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(accessibilityLabelText ?? ""))
    }

    private func segmentButton(_ segment: StageSegment<Value>) -> some View {
        let isSelected = segment.value == selection
        return Button {
            selection = segment.value
        } label: {
            StageLabel(
                segment.label,
                style: theme.typography.chip,
                tone: isSelected ? .onActive : (enabled ? .primary : .disabled)
            )
            .padding(.horizontal, theme.metrics.controlPaddingHorizontal)
            .frame(height: theme.metrics.controlHeight)
            .background(
                isSelected ? theme.colors.controlFillActive : Color.clear,
                in: RoundedRectangle(cornerRadius: theme.metrics.controlRadius, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .focusable(enabled)
        .focused($focusedSegment, equals: segment.value)
        .stageFocusRing(focusedSegment == segment.value, cornerRadius: theme.metrics.controlRadius)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isSelected)
        .accessibilityLabel(Text(segment.label))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func move(by delta: Int) -> KeyPress.Result {
        guard enabled,
              let index = segments.firstIndex(where: { $0.value == selection })
        else { return .ignored }
        let next = index + delta
        guard segments.indices.contains(next) else { return .ignored }
        selection = segments[next].value
        focusedSegment = segments[next].value
        return .handled
    }
}

@available(macOS 15.0, *)
#Preview("StageSegmentedControl") {
    struct Harness: View {
        @State private var density = "COZY"
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                StageSegmentedControl(
                    selection: $density,
                    segments: [.init("TIGHT", "TIGHT"), .init("COZY", "COZY"), .init("AIRY", "AIRY")],
                    accessibilityLabel: "Density"
                )
                StageSegmentedControl(
                    selection: .constant("COZY"),
                    segments: [.init("TIGHT", "TIGHT"), .init("COZY", "COZY")],
                    enabled: false,
                    accessibilityLabel: "Density"
                )
            }
            .padding(20)
            .background(StageTheme.dark.colors.chrome)
        }
    }
    return Harness()
}

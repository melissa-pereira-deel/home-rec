import SwiftUI

/// One filter option.
public struct GlassFilterOption<ID: Hashable>: Identifiable {
    public let id: ID
    public let label: String

    public init(id: ID, label: String) {
        self.id = id
        self.label = label
    }
}

/// A single-select chip row.
///
/// Chips, not a segmented control or a menu: the options are few, their labels
/// are short, and the set is worth seeing at rest — a menu would hide the fact
/// that filtering is possible at all, which is how a library ends up feeling
/// like it has no tools.
///
/// The bar is a single accessibility container with a `Filter` label, so
/// VoiceOver announces "Filter, wav, selected, 2 of 5" instead of five loose
/// buttons.
public struct GlassFilterChipBar<ID: Hashable>: View {
    private let options: [GlassFilterOption<ID>]
    @Binding private var selection: ID
    private let accessibilityLabel: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        options: [GlassFilterOption<ID>],
        selection: Binding<ID>,
        accessibilityLabel: String = "Filter"
    ) {
        self.options = options
        self._selection = selection
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: GlassSpacing.sm) {
            ForEach(options) { option in
                GlassChip(option.label, isSelected: option.id == selection) {
                    withAnimation(GlassMotionToken.quick.resolved(reduceMotion: reduceMotion)) {
                        selection = option.id
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("Filter chips") {
    struct Host: View {
        @State private var selection = "all"
        var body: some View {
            GlassPreviewStage {
                GlassFilterChipBar(
                    options: [
                        .init(id: "all", label: "all"),
                        .init(id: "wav", label: "wav"),
                        .init(id: "m4a", label: "m4a"),
                        .init(id: "flac", label: "flac"),
                        .init(id: "week", label: "this week"),
                    ],
                    selection: $selection
                )
            }
        }
    }
    return Host()
}

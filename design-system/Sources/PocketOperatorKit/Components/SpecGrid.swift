import SwiftUI

/// One label/value pair in a printed data block.
public struct SpecCell: Identifiable, Sendable, Equatable {
    public let id: String
    public var label: String
    public var value: String
    /// Spoken form of the pair. Defaults to "label, value", which is wrong for
    /// abbreviations — "FMT, WAV" should be "Format, WAV".
    public var accessibilityLabel: String?

    public init(
        id: String? = nil,
        label: String,
        value: String,
        accessibilityLabel: String? = nil
    ) {
        self.id = id ?? label
        self.label = label
        self.value = value
        self.accessibilityLabel = accessibilityLabel
    }
}

/// The screen-printed technical data block.
///
/// This is the element that most strongly signals "instrument": a device
/// states its own specification on its face, permanently, whether or not
/// anyone needs it right now. The rules are the ones a real spec panel
/// follows — equal-width cells, hairline dividers, label dimmer than value,
/// everything monospaced so the columns line up down the whole block.
///
/// Values here should be *facts about the device or the current setting*, not
/// status. Status belongs on the display or a lamp.
@available(macOS 15, *)
public struct SpecGrid: View {
    @Environment(\.poTheme) private var theme

    private let cells: [SpecCell]
    private let rowHeight: CGFloat
    private let accessibilityLabel: String?

    public init(
        _ cells: [SpecCell],
        rowHeight: CGFloat = 30,
        accessibilityLabel: String? = "Specification"
    ) {
        self.cells = cells
        self.rowHeight = rowHeight
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                if index > 0 {
                    HairlineEtch(.vertical)
                }
                cellView(cell)
            }
        }
        .frame(height: rowHeight)
        .poEtchedFrame()
        .accessibilityElement(children: .contain)
        .poAccessibilityLabel(accessibilityLabel)
    }

    private func cellView(_ cell: SpecCell) -> some View {
        HStack(spacing: theme.metrics.spacing.tight + 1) {
            ScreenPrintLabel(cell.label, scale: .micro, isDecorative: true)
            ScreenPrintValue(cell.value, isDecorative: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cell.accessibilityLabel ?? cell.label)
        .accessibilityValue(cell.value)
    }
}

@available(macOS 15, *)
#Preview("Spec grid") {
    SpecGrid([
        SpecCell(label: "MODE", value: "SEQ", accessibilityLabel: "Mode"),
        SpecCell(label: "BPM", value: "128", accessibilityLabel: "Tempo"),
        SpecCell(label: "STEP", value: "16", accessibilityLabel: "Steps"),
        SpecCell(label: "SWING", value: "54", accessibilityLabel: "Swing"),
        SpecCell(label: "BANK", value: "A2", accessibilityLabel: "Bank"),
    ])
    .frame(width: 420)
    .padding(24)
    .background(Color.poHex(0x0A0A0A))
}

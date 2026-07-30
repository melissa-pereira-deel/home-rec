import SwiftUI

/// One key in a matrix.
///
/// Deliberately a plain value rather than a view builder: a key bed is a
/// manufactured part with a fixed pitch, and letting callers put arbitrary
/// views in the cells is how a key bed turns back into a stack of buttons.
@available(macOS 15, *)
public struct KeyGridItem: Identifiable {
    public let id: String
    /// Legend printed on the cap.
    public var legend: String
    /// Spoken name. Required in practice — cap legends are abbreviations.
    public var accessibilityLabel: String?
    public var accessibilityHint: String?
    public var variant: HardwareKeyVariant
    public var isEnabled: Bool
    /// Latched state, for keys that stay down.
    public var isOn: Bool
    public var action: () -> Void

    public init(
        id: String? = nil,
        legend: String,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        variant: HardwareKeyVariant = .neutral,
        isEnabled: Bool = true,
        isOn: Bool = false,
        action: @escaping () -> Void
    ) {
        self.id = id ?? legend
        self.legend = legend
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.variant = variant
        self.isEnabled = isEnabled
        self.isOn = isOn
        self.action = action
    }

    /// A blank position in the moulding — a key that was never fitted.
    public static func blank(id: String) -> KeyGridItem {
        KeyGridItem(id: id, legend: "", isEnabled: false, action: {})
    }
}

/// A matrix of keys seated in a moulded bed.
///
/// The bed is what makes a grid of buttons read as a key*board*: a single
/// recess, a single texture, uniform pitch, and no gaps that are not the
/// moulded web between two caps.
@available(macOS 15, *)
public struct KeyGrid: View {
    @Environment(\.poTheme) private var theme

    private let items: [KeyGridItem]
    private let columns: Int
    private let keySize: HardwareKeySize
    private let isSeatedInWell: Bool
    private let caption: String?
    private let accessibilityLabel: String?

    /// - Parameters:
    ///   - columns: Cells per row. Rows are filled in order; a short final row
    ///     is left-aligned, as an unpopulated moulding would be.
    ///   - isSeatedInWell: Whether to draw the recessed bed. Off when the grid
    ///     is already inside another recess.
    public init(
        _ items: [KeyGridItem],
        columns: Int = 4,
        keySize: HardwareKeySize = .regular,
        isSeatedInWell: Bool = true,
        caption: String? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.items = items
        self.columns = max(1, columns)
        self.keySize = keySize
        self.isSeatedInWell = isSeatedInWell
        self.caption = caption
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        let grid = VStack(spacing: theme.metrics.spacing.key) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: theme.metrics.spacing.key) {
                    ForEach(row) { item in
                        key(for: item)
                    }
                    if row.count < columns {
                        // Keeps a short final row left-aligned at the same
                        // pitch instead of letting it centre or stretch.
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .poAccessibilityLabel(accessibilityLabel)

        return VStack(alignment: .leading, spacing: theme.metrics.spacing.snug) {
            if let caption {
                ScreenPrintLabel(caption, scale: .micro, isDecorative: true)
            }
            if isSeatedInWell {
                grid.poWell()
            } else {
                grid
            }
        }
    }

    @ViewBuilder
    private func key(for item: KeyGridItem) -> some View {
        if item.legend.isEmpty {
            // An unfitted position is a hole in the bed, not an invisible
            // button; it keeps the pitch without offering a target.
            Color.clear
                .frame(
                    width: keySize.dimensions(theme.metrics).width,
                    height: keySize.dimensions(theme.metrics).height
                )
                .accessibilityHidden(true)
        } else {
            HardwareKey(
                item.legend,
                variant: item.variant,
                size: keySize,
                isOn: item.isOn,
                accessibilityLabel: item.accessibilityLabel ?? item.legend,
                accessibilityHint: item.accessibilityHint,
                action: item.action
            )
            .disabled(!item.isEnabled)
        }
    }

    private var rows: [[KeyGridItem]] {
        stride(from: 0, to: items.count, by: columns).map { start in
            Array(items[start..<min(start + columns, items.count)])
        }
    }
}

@available(macOS 15, *)
#Preview("Key grid") {
    KeyGrid(
        (1...8).map { index in
            KeyGridItem(
                legend: String(format: "%02d", index),
                accessibilityLabel: "Slot \(index)",
                action: {}
            )
        } + [
            KeyGridItem(legend: "SRC", accessibilityLabel: "Source", action: {}),
            KeyGridItem(legend: "FMT", accessibilityLabel: "Format", action: {}),
            KeyGridItem(legend: "LOOP", accessibilityLabel: "Loop", isOn: true, action: {}),
            KeyGridItem(legend: "REC", accessibilityLabel: "Record", variant: .accent, action: {}),
        ],
        columns: 4,
        caption: "PATTERN BANK"
    )
    .padding(30)
    .background(Color.poHex(0x0A0A0A))
}

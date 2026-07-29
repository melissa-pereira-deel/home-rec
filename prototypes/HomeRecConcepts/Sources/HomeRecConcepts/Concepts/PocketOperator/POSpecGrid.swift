import SwiftUI

/// Metadata as hardware print: monospaced label/value cells separated by
/// 1px rules — the TE spec-sheet look.
struct POSpecGrid: View {
    @EnvironmentObject private var store: PrototypeStateStore

    var body: some View {
        HStack(spacing: 0) {
            cell("FMT", store.selectedFormat.rawValue.uppercased())
            divider
            cell("RATE", "48K")
            divider
            cell("BIT", store.selectedFormat == .flac ? "24" : "16")
            divider
            cell("GAIN", String(format: "%02.0f", store.gain * 10))
            divider
            cell("TAKES", String(format: "%02d", store.library.count))
        }
        .frame(height: 30)
        .overlay(Rectangle().strokeBorder(POTheme.rule, lineWidth: 1))
    }

    private var divider: some View {
        Rectangle().fill(POTheme.rule).frame(width: 1)
    }

    private func cell(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            POTheme.microLabel(label, size: 7)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(white: 0.78))
        }
        .frame(maxWidth: .infinity)
    }
}

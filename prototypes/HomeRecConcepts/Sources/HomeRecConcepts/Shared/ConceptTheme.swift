import SwiftUI

/// Styling contract each concept hands to the shared LibraryScaffold —
/// palette, type, and chrome radii. Structure stays shared; skin varies.
struct LibraryStyle {
    var rowFill: Color
    var rowStroke: Color
    var title: Color
    var meta: Color
    var accent: Color
    var cornerRadius: CGFloat = 10
    /// Waveform thumbnail color for unselected rows.
    var thumb: Color
    /// Row shadow (index cards want one; flush rows don't).
    var rowShadow: Color = .clear
    /// Label/icon color on accent-filled controls (the flat play pill).
    /// White reads on red; orange and amber want dark labels.
    var accentLabel: Color = .white

    func titleText(_ text: String, size: CGFloat = 13) -> some View {
        Text(text)
            .font(.custom("Inter", size: size, relativeTo: .body))
            .foregroundStyle(title)
    }

    func metaText(_ text: String, size: CGFloat = 10) -> some View {
        Text(text)
            .font(.system(size: size, design: .monospaced))
            .foregroundStyle(meta)
    }
}

/// Optional chip filter (Glass concept): lowercase label + predicate.
struct LibraryChip {
    let label: String
    let matches: (FakeRecording) -> Bool
}

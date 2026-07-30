import SwiftUI

/// A hairline separator.
///
/// Deliberately near-invisible. The chrome's structure is already carried by
/// the fill difference between bar and stage well; the hairline exists only to
/// keep that edge crisp when a concept's own background happens to land on the
/// same value as the chrome.
@available(macOS 15.0, *)
public struct StageDivider: View {
    public enum Orientation: Hashable {
        case horizontal
        case vertical
    }

    private let orientation: Orientation
    private let inset: CGFloat

    @Environment(\.stageTheme) private var theme

    /// - Parameter inset: leading/trailing inset along the divider's long axis.
    ///   Use it for dividers *inside* a bar; edge-to-edge for structural ones.
    public init(_ orientation: Orientation = .horizontal, inset: CGFloat = 0) {
        self.orientation = orientation
        self.inset = inset
    }

    public var body: some View {
        Rectangle()
            .fill(theme.colors.separator)
            .frame(
                width: orientation == .vertical ? theme.metrics.hairline : nil,
                height: orientation == .horizontal ? theme.metrics.hairline : nil
            )
            .padding(orientation == .horizontal ? .horizontal : .vertical, inset)
            .accessibilityHidden(true)
    }
}

@available(macOS 15.0, *)
#Preview("StageDivider") {
    VStack(spacing: 12) {
        StageDivider()
        HStack(spacing: 12) {
            StageLabel("left")
            StageDivider(.vertical).frame(height: 14)
            StageLabel("right")
        }
        StageDivider(inset: 40)
    }
    .padding(20)
    .background(StageTheme.dark.colors.chrome)
}

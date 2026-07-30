import SwiftUI

/// The chrome surface shared by the tab bar and the scrubber.
///
/// Exists so hand-authored chrome sits on exactly the same fill and insets as
/// the generated kind — a stage with one bar padded differently from the other
/// looks broken in a way nobody can name.
@available(macOS 15.0, *)
public struct StageBar<Content: View>: View {
    private let content: Content

    @Environment(\.stageTheme) private var theme

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, theme.metrics.barPaddingHorizontal)
            .padding(.vertical, theme.metrics.barPaddingVertical)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors.chrome)
    }
}

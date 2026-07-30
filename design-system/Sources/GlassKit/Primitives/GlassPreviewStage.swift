import SwiftUI

/// The standard stage for previews and specimens: the Glass ground, a panel,
/// and the theme injected the way a real host would inject it.
///
/// Exported rather than kept internal so that an engineer building a screen
/// with this kit can preview their own composition in the same conditions the
/// kit was designed in. A Glass component previewed on white is a component
/// previewed in a place it will never be.
public struct GlassPreviewStage<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    public init(padding: CGFloat = GlassSpacing.xxl, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        ZStack {
            GlassBackdrop()
            GlassPanel {
                content
            }
            .padding(padding)
        }
        .glassThemeAdaptingToContrast()
    }
}

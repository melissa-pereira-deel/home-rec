import SwiftUI

/// The ground the glass has something to blur.
///
/// A frosted panel over a flat black window is just a grey rectangle — the
/// material has nothing to sample. The backdrop is a quiet deep-blue mesh:
/// enough tonal variation that the blur has something to do, dark and
/// desaturated enough that it never competes with the one accent.
///
/// The mesh is deliberately *asymmetric* (the centre control point sits at
/// 0.55/0.45, not 0.5/0.5) so the gradient doesn't read as a symmetrical
/// vignette, which is the tell of a generated background.
@available(macOS 15.0, *)
public struct GlassBackdrop: View {
    public init() {}

    public var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.55, 0.45], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                Color(glassHex: 0x0D1221), Color(glassHex: 0x1A1F38), Color(glassHex: 0x0D0F1A),
                Color(glassHex: 0x141A30), Color(glassHex: 0x212440), Color(glassHex: 0x0F1424),
                Color(glassHex: 0x0A0D17), Color(glassHex: 0x121426), Color(glassHex: 0x0D0F1C),
            ]
        )
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A flat fallback for hosts that can't spend a mesh gradient (menu-bar
/// popovers, snapshot tests, macOS < 15).
public struct GlassFlatGround: View {
    @Environment(\.glassTheme) private var theme

    public init() {}

    public var body: some View {
        theme.colors.ground
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

#Preview("Backdrop") {
    GlassBackdrop()
        .frame(width: 480, height: 320)
}

import SwiftUI

/// The device body: a moulded shell with a machined edge and a faint surface
/// grain.
///
/// This is the outermost layer of the panel hierarchy — everything else in the
/// kit is mounted *on* or cut *into* a chassis. It is the only surface allowed
/// to carry the largest corner radius, and the only one with an outward-facing
/// edge highlight.
@available(macOS 15, *)
public struct ChassisSurface<Content: View>: View {
    @Environment(\.poTheme) private var theme

    private let corner: CGFloat?
    private let padding: CGFloat?
    private let content: Content

    /// - Parameters:
    ///   - corner: Shell radius; defaults to the chassis token.
    ///   - padding: Inset from the shell edge to its contents; defaults to the
    ///     chassis spacing step.
    public init(
        corner: CGFloat? = nil,
        padding: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.corner = corner
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        let radius = corner ?? theme.metrics.chassisCorner
        content
            .padding(padding ?? theme.metrics.spacing.chassis)
            .background {
                ZStack {
                    theme.colors.chassis
                    if theme.texture.isEnabled {
                        POTexture.speckle(
                            density: theme.texture.chassisSpeckleDensity,
                            seed: theme.texture.speckleSeed,
                            light: theme.texture.speckleLight,
                            dark: theme.texture.speckleDark
                        )
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(theme.colors.chassisEdge, lineWidth: theme.metrics.hairline)
            }
    }
}

/// A raised sub-panel mounted on the chassis — one radius step down, one tone
/// up, no texture of its own.
@available(macOS 15, *)
public struct PanelSurface<Content: View>: View {
    @Environment(\.poTheme) private var theme

    private let corner: CGFloat?
    private let padding: CGFloat?
    private let content: Content

    public init(
        corner: CGFloat? = nil,
        padding: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.corner = corner
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        let radius = corner ?? theme.metrics.panelCorner
        content
            .padding(padding ?? theme.metrics.spacing.panel)
            .background(theme.colors.panel)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(theme.colors.panelEdge, lineWidth: theme.metrics.hairline)
            }
    }
}

@available(macOS 15, *)
public extension View {
    /// Mount this view on a chassis shell.
    func poChassis(corner: CGFloat? = nil, padding: CGFloat? = nil) -> some View {
        ChassisSurface(corner: corner, padding: padding) { self }
    }

    /// Mount this view on a raised sub-panel.
    func poPanel(corner: CGFloat? = nil, padding: CGFloat? = nil) -> some View {
        PanelSurface(corner: corner, padding: padding) { self }
    }
}

@available(macOS 15, *)
#Preview("Chassis and panel") {
    ChassisSurface {
        VStack(spacing: 14) {
            ScreenPrintLabel("CHASSIS SURFACE", scale: .large)
            ScreenPrintLabel("PANEL SURFACE")
                .poPanel()
        }
    }
    .frame(width: 260)
    .padding(30)
    .background(Color.black)
}

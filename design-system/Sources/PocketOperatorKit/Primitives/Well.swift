import SwiftUI

/// A recess milled into the chassis, holding controls or a display.
///
/// The recess is built from three cues, and all three are needed — drop any
/// one and it flattens back into a rectangle:
///
/// 1. an inner shadow along the top wall, cast by the lip above it;
/// 2. a hard black hairline at the cut edge;
/// 3. a *lighter* hairline one point outside it — the chamfer on the lip
///    catching the same overhead light every other bevel in the kit assumes.
@available(macOS 15, *)
public struct Well<Content: View>: View {
    @Environment(\.poTheme) private var theme

    private let corner: CGFloat?
    private let padding: CGFloat?
    private let fill: Color?
    private let hasTexture: Bool
    private let content: Content

    /// - Parameters:
    ///   - hasTexture: Applies the moulded-rubber speckle. On for control beds,
    ///     off for display cavities, whose substrate is smooth glass.
    public init(
        corner: CGFloat? = nil,
        padding: CGFloat? = nil,
        fill: Color? = nil,
        hasTexture: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.corner = corner
        self.padding = padding
        self.fill = fill
        self.hasTexture = hasTexture
        self.content = content()
    }

    public var body: some View {
        let radius = corner ?? theme.metrics.wellCorner
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(padding ?? theme.metrics.spacing.panel)
            .background {
                ZStack {
                    shape.fill(
                        (fill ?? theme.colors.well).shadow(
                            .inner(color: theme.colors.wellShadow, radius: 3, y: 2)
                        )
                    )
                    if hasTexture && theme.texture.isEnabled {
                        POTexture.speckle(
                            density: theme.texture.speckleDensity,
                            seed: theme.texture.speckleSeed,
                            light: theme.texture.speckleLight,
                            dark: theme.texture.speckleDark
                        )
                        .clipShape(shape)
                    }
                }
            }
            .poBezel(corner: radius)
    }
}

/// The machined lip around a cut-out, without the recess itself.
///
/// Separated from `Well` because a display already supplies its own substrate
/// and needs only the edge treatment, and because a bezel is occasionally
/// wanted around something that is raised rather than sunk.
@available(macOS 15, *)
public struct POBezel: ViewModifier {
    @Environment(\.poTheme) private var theme
    let corner: CGFloat?

    public func body(content: Content) -> some View {
        let radius = corner ?? theme.metrics.wellCorner
        content
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.black, lineWidth: theme.metrics.hairline)
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius + 1, style: .continuous)
                    .strokeBorder(theme.colors.wellRim, lineWidth: theme.metrics.hairline)
                    .padding(-theme.metrics.hairline)
            }
    }
}

@available(macOS 15, *)
public extension View {
    /// Seat this view in a milled recess.
    func poWell(
        corner: CGFloat? = nil,
        padding: CGFloat? = nil,
        fill: Color? = nil,
        hasTexture: Bool = true
    ) -> some View {
        Well(corner: corner, padding: padding, fill: fill, hasTexture: hasTexture) { self }
    }

    /// Apply the machined lip treatment to this view's edge.
    func poBezel(corner: CGFloat? = nil) -> some View {
        modifier(POBezel(corner: corner))
    }
}

@available(macOS 15, *)
#Preview("Well and bezel") {
    VStack(spacing: 18) {
        ScreenPrintLabel("TEXTURED CONTROL BED")
            .frame(width: 200, height: 60)
            .poWell()
        ScreenPrintLabel("SMOOTH CAVITY")
            .frame(width: 200, height: 60)
            .poWell(hasTexture: false)
    }
    .padding(30)
    .background(Color.poHex(0x0A0A0A))
}

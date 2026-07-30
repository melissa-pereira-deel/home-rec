import SwiftUI

// MARK: - Stroke

/// How a surface draws its edge. Strokes in this system are always 1pt and
/// always *inside* the shape (`strokeBorder`), so a card's stated corner
/// radius is the radius you can measure on screen.
public enum GlassStroke: Equatable {
    case none
    case role(GlassColorRole)
    /// An explicit tint at an explicit opacity — used by notices, where the
    /// border colour is the notice's severity and can't come from a fixed
    /// role.
    case tint(Color, opacity: Double)
}

// MARK: - Style

/// The declarative description of a surface.
///
/// Fills are named by role rather than by value so the whole stack re-skins
/// from the theme; `translucentCard` exists because the same card colour is
/// used both on glass (where it must let a little ground through) and on an
/// opaque host (where it must not).
public struct GlassSurfaceStyle: Equatable {

    public enum Fill: Equatable {
        case panelMaterial
        case popoverMaterial
        case card
        case inset
        case scrim
        case clear
    }

    public var fill: Fill
    public var cornerRadius: CGFloat
    public var stroke: GlassStroke
    public var elevation: GlassElevation
    /// Replaces the flat stroke with a top-lit gradient — the cue that a
    /// surface is *glass under a light* rather than a filled rectangle. Used
    /// on the live card, where the panel's own edge-light would otherwise be
    /// the only specular in the composition.
    public var edgeHighlight: Bool
    /// Applies `materials.cardOpacityOnGlass` to the card fill.
    public var translucentCard: Bool
    /// Paints a dark underlay beneath a material fill so content behind a
    /// modal can't ghost through as bright bands.
    public var modalUnderlay: Bool

    public init(
        fill: Fill,
        cornerRadius: CGFloat,
        stroke: GlassStroke = .none,
        elevation: GlassElevation = .flush,
        edgeHighlight: Bool = false,
        translucentCard: Bool = false,
        modalUnderlay: Bool = false
    ) {
        self.fill = fill
        self.cornerRadius = cornerRadius
        self.stroke = stroke
        self.elevation = elevation
        self.edgeHighlight = edgeHighlight
        self.translucentCard = translucentCard
        self.modalUnderlay = modalUnderlay
    }
}

public extension GlassSurfaceStyle {
    /// The frosted panel: the top-level container of any Glass screen.
    static let panel = GlassSurfaceStyle(
        fill: .panelMaterial,
        cornerRadius: GlassRadius.panel,
        stroke: .role(.lineStrong),
        elevation: .panel
    )

    /// A modal card floating over a scrimmed panel.
    static let modal = GlassSurfaceStyle(
        fill: .panelMaterial,
        cornerRadius: GlassRadius.panel,
        stroke: .role(.lineStrong),
        elevation: .modal,
        modalUnderlay: true
    )

    /// A settings popover.
    static let popover = GlassSurfaceStyle(
        fill: .popoverMaterial,
        cornerRadius: GlassRadius.card,
        stroke: .role(.line)
    )

    /// The default card: notices, the live card, containers inside a panel.
    static let card = GlassSurfaceStyle(
        fill: .card,
        cornerRadius: GlassRadius.card,
        stroke: .role(.line),
        translucentCard: true
    )

    /// A list row.
    static let row = GlassSurfaceStyle(
        fill: .card,
        cornerRadius: GlassRadius.card,
        stroke: .role(.line),
        elevation: .row,
        translucentCard: true
    )

    /// A row that is selected, playing, or otherwise the subject of the
    /// screen. One step up in radius and elevation, and the accent takes the
    /// border — the only place accent is spent on a container.
    static func rowActive(tint: Color) -> GlassSurfaceStyle {
        GlassSurfaceStyle(
            fill: .card,
            cornerRadius: GlassRadius.cardLarge,
            stroke: .tint(tint, opacity: 0.45),
            elevation: .raised,
            translucentCard: true
        )
    }

    /// A card nested inside a card.
    static let inner = GlassSurfaceStyle(
        fill: .card,
        cornerRadius: GlassRadius.inner,
        stroke: .role(.line),
        translucentCard: true
    )

    /// A container carved into the panel rather than stacked on it.
    static let inset = GlassSurfaceStyle(
        fill: .inset,
        cornerRadius: GlassRadius.cardLarge,
        stroke: .role(.line)
    )

    /// The live-capture card: top-lit, no shadow — it is a window into the
    /// signal, not an object on the panel.
    static let live = GlassSurfaceStyle(
        fill: .card,
        cornerRadius: GlassRadius.cardLarge,
        stroke: .none,
        edgeHighlight: true,
        translucentCard: true
    )

    /// A notice row, tinted by severity.
    static func notice(tint: Color) -> GlassSurfaceStyle {
        GlassSurfaceStyle(
            fill: .card,
            cornerRadius: GlassRadius.card,
            stroke: .tint(tint, opacity: 0.5),
            translucentCard: true
        )
    }
}

// MARK: - Modifier

public struct GlassSurfaceModifier: ViewModifier {
    @Environment(\.glassTheme) private var theme

    let style: GlassSurfaceStyle

    public func body(content: Content) -> some View {
        content
            .background { background }
            .overlay { border }
            .clipShape(shape)
            .glassElevation(style.elevation)
    }

    /// Layer order, bottom to top: modal underlay → panel tint → fill.
    @ViewBuilder
    private var background: some View {
        ZStack {
            if style.modalUnderlay {
                shape.fill(Color.black.opacity(theme.materials.modalUnderlayOpacity))
            }
            if isMaterial {
                // The tint sits *under* the material, not over it: over, it
                // would flatten the blur into a solid; under, it gives the
                // glass a body while the material still samples the ground.
                shape.fill(theme.colors.surfacePanel)
            }
            shape.fill(fillStyle)
        }
    }

    private var isMaterial: Bool {
        style.fill == .panelMaterial || style.fill == .popoverMaterial
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
    }

    private var fillStyle: AnyShapeStyle {
        switch style.fill {
        case .panelMaterial:
            // Material *plus* a tint: bare `.ultraThinMaterial` over a dark
            // ground reads washed-out grey. The tint gives the glass a body.
            AnyShapeStyle(theme.materials.panel)
        case .popoverMaterial:
            AnyShapeStyle(theme.materials.popover)
        case .card:
            AnyShapeStyle(
                theme.colors.surfaceCard
                    .opacity(style.translucentCard ? theme.materials.cardOpacityOnGlass : 1)
            )
        case .inset:
            AnyShapeStyle(theme.colors.surfaceInset)
        case .scrim:
            AnyShapeStyle(theme.colors.surfaceScrim)
        case .clear:
            AnyShapeStyle(Color.clear)
        }
    }

    @ViewBuilder
    private var border: some View {
        if style.edgeHighlight {
            shape.strokeBorder(
                LinearGradient(
                    colors: [theme.colors.line, .clear],
                    startPoint: .top,
                    endPoint: .center
                ),
                lineWidth: theme.metrics.hairline
            )
        } else {
            switch style.stroke {
            case .none:
                EmptyView()
            case .role(let role):
                shape.strokeBorder(theme.colors[role], lineWidth: theme.metrics.hairline)
            case .tint(let color, let opacity):
                shape.strokeBorder(color.opacity(opacity), lineWidth: theme.metrics.hairline)
            }
        }
    }
}

public extension View {
    /// Applies a surface: fill, stroke, corner radius and elevation, in the
    /// one order that produces a correct result. (Stroke before clip, clip
    /// before shadow — swap any two and you get either a clipped border or a
    /// shadow cast by the *content* instead of the card.)
    func glassSurface(_ style: GlassSurfaceStyle) -> some View {
        modifier(GlassSurfaceModifier(style: style))
    }
}

// MARK: - Containers

/// The frosted panel: the outermost container of a Glass screen.
///
/// Provides the panel surface and its padding. It does not size itself — the
/// host decides whether the panel fills a window, a popover, or a fixed
/// floating face.
public struct GlassPanel<Content: View>: View {
    @Environment(\.glassTheme) private var theme

    private let padding: CGFloat?
    private let style: GlassSurfaceStyle
    private let content: Content

    public init(
        padding: CGFloat? = nil,
        style: GlassSurfaceStyle = .panel,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.style = style
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding ?? GlassSpacing.xl)
            .glassSurface(style)
    }
}

/// An opaque charcoal card inside a panel.
public struct GlassCard<Content: View>: View {
    private let padding: EdgeInsets
    private let style: GlassSurfaceStyle
    private let content: Content

    public init(
        padding: EdgeInsets = EdgeInsets(
            top: GlassSpacing.m, leading: GlassSpacing.md,
            bottom: GlassSpacing.m, trailing: GlassSpacing.md
        ),
        style: GlassSurfaceStyle = .card,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.style = style
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .glassSurface(style)
    }
}

#Preview("Surfaces") {
    GlassPreviewStage {
        VStack(spacing: GlassSpacing.md) {
            ForEach(Array(GlassSurfaceSpecimen.all.enumerated()), id: \.offset) { _, specimen in
                Text(specimen.name)
                    .glassText(.meta, color: .textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(GlassSpacing.md)
                    .glassSurface(specimen.style)
            }
        }
    }
}

/// Named surface styles, for the gallery and previews.
struct GlassSurfaceSpecimen {
    let name: String
    let style: GlassSurfaceStyle

    static let all: [GlassSurfaceSpecimen] = [
        .init(name: "panel", style: .panel),
        .init(name: "card", style: .card),
        .init(name: "row", style: .row),
        .init(name: "rowActive", style: .rowActive(tint: GlassColors.standard.accent)),
        .init(name: "inner", style: .inner),
        .init(name: "inset", style: .inset),
        .init(name: "live (edge highlight)", style: .live),
        .init(name: "notice", style: .notice(tint: GlassColors.standard.statusWarning)),
        .init(name: "popover", style: .popover),
    ]
}

import SwiftUI

// MARK: - Elevation

/// The elevation ladder.
///
/// Glass has no borders in the physical sense, so depth in this system is
/// carried by three cues at once — shadow, edge-light opacity, and material.
/// A level that changes only one of the three reads as a rendering bug.
///
/// | level | shadow | edge-light | material |
/// |---|---|---|---|
/// | `flush` | none | `line` | none |
/// | `row` | 4pt / y2 | `line` | opaque card |
/// | `raised` | 6pt / y3 | tinted | opaque card |
/// | `panel` | 30pt / y18 | `lineStrong` | ultraThin |
/// | `modal` | 30pt / y18 + scrim | `lineStrong` | ultraThin over black 35% |
public enum GlassElevation: String, CaseIterable, Hashable, Sendable {
    case flush
    case row
    case raised
    case panel
    case modal

    /// Shadow colour opacity.
    public var shadowOpacity: Double {
        switch self {
        case .flush: 0
        case .row: 0.18
        case .raised: 0.22
        case .panel: 0.35
        case .modal: 0.40
        }
    }

    public var shadowRadius: CGFloat {
        switch self {
        case .flush: 0
        case .row: 4
        case .raised: 6
        case .panel: 30
        case .modal: 30
        }
    }

    public var shadowOffsetY: CGFloat {
        switch self {
        case .flush: 0
        case .row: 2
        case .raised: 3
        case .panel: 18
        case .modal: 18
        }
    }
}

public extension View {
    /// Applies an elevation's shadow. Kept separate from the surface style so
    /// a component can carry depth without a background (a floating label, a
    /// dragged row).
    func glassElevation(_ elevation: GlassElevation) -> some View {
        shadow(
            color: .black.opacity(elevation.shadowOpacity),
            radius: elevation.shadowRadius,
            y: elevation.shadowOffsetY
        )
    }
}

// MARK: - Materials

/// The material tokens.
///
/// Only one real material is used — `.ultraThinMaterial` — because the panel
/// must stay translucent enough that the ground's blue reads through it. The
/// token exists so a host targeting an opaque window can swap it once.
public struct GlassMaterials {
    /// The frosted panel material.
    public var panel: Material = .ultraThinMaterial
    /// Popovers and settings surfaces.
    public var popover: Material = .regularMaterial
    /// Opacity applied to `surfaceCard` when it sits on glass, so a hint of
    /// the ground survives under the card and the stack stays translucent.
    public var cardOpacityOnGlass: Double = 0.85
    /// Dark tint painted under a modal card's material. Without it the face
    /// behind the card ghosts through the glass as bright bands.
    public var modalUnderlayOpacity: Double = 0.35

    public init() {}

    public static let standard = GlassMaterials()
}

#Preview("Elevation ladder") {
    GlassPreviewStage {
        HStack(spacing: GlassSpacing.l) {
            ForEach(GlassElevation.allCases, id: \.self) { level in
                VStack(spacing: GlassSpacing.xs) {
                    RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous)
                        .fill(GlassColors.standard.surfaceCard)
                        .frame(width: 88, height: 52)
                        .glassElevation(level)
                    GlassMetaLabel(level.rawValue, role: .metaSmall)
                }
            }
        }
    }
}

import SwiftUI

// MARK: - Mark

/// The Home Rec mark: a rounded square with a red record dot.
///
/// This is a direct port of `favicon.svg` from homerec.app — the published
/// form of the brand — rather than a redrawing of it. Every proportion below
/// is the SVG's own number divided by its 32-unit viewBox, so the mark scales
/// to any point size and still matches the site pixel for pixel at 32pt:
///
/// | SVG | Ratio | At 24pt |
/// |---|---|---|
/// | `rx="7"` | 0.219 | 5.25 |
/// | `r="6.5"` (dot) | 0.203 | 4.88 |
/// | `stroke-width="1.5"` (square) | 0.047 | 1.13 |
/// | inset `x="0.75"` | 0.023 | 0.56 |
///
/// The site's stroke exists because a favicon has to survive both a light and
/// a dark browser chrome. GlassKit is dark-only, so the mark ships the site's
/// `prefers-color-scheme: dark` values — the lighter square and its brighter
/// edge — which is the same artwork, resolved for the one ground this kit has.
///
/// Not an `Image`: at 18pt in a panel header, a rasterised 180pt touch icon
/// carries its own white canvas and half a pixel of misalignment. Drawn, it is
/// exact at every size and needs no asset.
public struct GlassBrandMark: View {
    private let size: CGFloat

    public init(size: CGFloat = 24) {
        self.size = size
    }

    // Ratios, straight from the 32-unit viewBox.
    private var inset: CGFloat { size * 0.75 / 32 }
    private var corner: CGFloat { size * 7 / 32 }
    private var squareStroke: CGFloat { size * 1.5 / 32 }
    private var dotDiameter: CGFloat { size * 13 / 32 }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(GlassBrand.markSquare)
                .overlay {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(GlassBrand.markEdge, lineWidth: squareStroke)
                }
                .padding(inset)

            Circle()
                .fill(GlassBrand.markDot)
                .frame(width: dotDiameter, height: dotDiameter)
        }
        .frame(width: size, height: size)
        // The mark is decoration wherever it appears beside the name; the
        // lockup below owns the single accessible label for the pair.
        .accessibilityHidden(true)
    }
}

// MARK: - Brand constants

/// Brand values that are *fixed artwork*, not themeable roles.
///
/// These deliberately sit outside `GlassColors`. A palette role is something a
/// theme may re-skin; the record dot is #FF3E3E because that is what the logo
/// is, and a theme that changed it would be shipping a different logo. The
/// separation is the point — re-theming the kit must not be able to alter the
/// brand.
public enum GlassBrand {
    /// The wordmark, in the site's capitalisation. Never "home rec": the
    /// lowercase register is the *UI voice* (labels, controls, metadata), and
    /// the brand name is not a UI label.
    public static let name = "Home Rec"

    /// favicon.svg `.sq` fill, dark scheme.
    public static let markSquare = Color(glassHex: 0x2A2A2A)
    /// favicon.svg `.sq` stroke, dark scheme.
    public static let markEdge = Color(glassHex: 0x808080)
    /// favicon.svg `.dot` fill. The logo red — brighter than `colors.accent`,
    /// which is the *interface* red pulled 5% darker for large flat fills.
    public static let markDot = Color(glassHex: 0xFF3E3E)
}

// MARK: - Lockup

/// Mark + wordmark, at the site's proportions.
///
/// homerec.app sets the nav lockup at a 24pt mark, a 10pt gap and 15pt type.
/// Both sizes below hold those two ratios exactly (gap = 0.417 × mark,
/// type = 0.625 × mark), so the lockup is the same object at two scales rather
/// than two hand-tuned arrangements that drift apart.
public struct GlassBrandLockup: View {
    /// Lockup scales. Not free-form: two sizes, both derived from the site.
    public enum Size {
        /// 24pt mark / 15pt type — the site's nav lockup.
        case regular
        /// 20pt mark / 13pt type — the app panel header, where the lockup
        /// shares a row with metadata and must not outweigh it.
        case compact

        var mark: CGFloat {
            switch self {
            case .regular: 24
            case .compact: 20
            }
        }

        var gap: CGFloat { (mark * 10 / 24).rounded() }

        /// Archivo medium at −0.02em in both cases — the site's wordmark
        /// spec. `.compact` matches the `appTitle` role exactly; `.regular`
        /// sets it at the site's own 15pt, which is a brand measurement rather
        /// than a UI role and so is stated here instead of in the role table.
        func textStyle(_ typography: GlassTypography) -> GlassTextStyle {
            switch self {
            case .regular:
                GlassTextStyle(
                    family: typography.displayFamily,
                    size: 15, weight: .medium, tracking: -0.3
                )
            case .compact:
                typography.style(.appTitle)
            }
        }
    }

    private let size: Size
    private let showsMark: Bool

    @Environment(\.glassTheme) private var theme

    public init(size: Size = .compact, showsMark: Bool = true) {
        self.size = size
        self.showsMark = showsMark
    }

    public var body: some View {
        HStack(spacing: showsMark ? size.gap : 0) {
            if showsMark {
                GlassBrandMark(size: size.mark)
            }
            wordmark
        }
        // One element, one name. A VoiceOver user hears the product once,
        // not "image, Home Rec".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(GlassBrand.name)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var wordmark: some View {
        let style = size.textStyle(theme.typography)
        Text(GlassBrand.name)
            .font(theme.typography.font(style))
            .tracking(style.tracking)
            .foregroundStyle(theme.colors.textPrimary)
            .lineLimit(1)
    }
}

#Preview("Brand") {
    GlassPreviewStage {
        VStack(alignment: .leading, spacing: GlassSpacing.l) {
            GlassBrandLockup(size: .regular)
            GlassBrandLockup(size: .compact)
            GlassBrandLockup(size: .compact, showsMark: false)
            HStack(spacing: GlassSpacing.l) {
                ForEach([16, 24, 32, 64], id: \.self) { size in
                    GlassBrandMark(size: CGFloat(size))
                }
            }
        }
    }
}

import SwiftUI

/// Parameters for the procedural surface textures.
///
/// Texture is what stops large flat fills reading as "a dark rectangle". It is
/// deliberately near-invisible: at the intended density you should never be
/// able to resolve individual speckles, only notice that the surface is not
/// perfectly uniform. If you can see the pattern, it is too strong.
public struct POTextureTokens: Sendable, Equatable {
    /// Speckles per square point (divided by 4 internally, since each speckle
    /// covers roughly a 2x2 area).
    public var speckleDensity: CGFloat
    /// Fixed seed so a surface renders identically across launches and
    /// snapshot tests; texture that shimmers between runs reads as noise, not
    /// as a moulded finish.
    public var speckleSeed: UInt64
    public var speckleLight: Color
    public var speckleDark: Color

    /// Density used on the chassis itself, an order below the key bed — the
    /// shell is a smooth moulding, the bed is textured rubber.
    public var chassisSpeckleDensity: CGFloat

    public var grillePitch: CGFloat
    public var grilleDotSize: CGFloat

    public var brushedMetalSeed: UInt64

    /// Master switch. Off produces flat fills, for snapshot diffing or for a
    /// product that wants the geometry without the material.
    public var isEnabled: Bool

    public init(
        speckleDensity: CGFloat = 0.02,
        speckleSeed: UInt64 = 7,
        speckleLight: Color = .white.opacity(0.05),
        speckleDark: Color = .black.opacity(0.18),
        chassisSpeckleDensity: CGFloat = 0.004,
        grillePitch: CGFloat = 7,
        grilleDotSize: CGFloat = 2.4,
        brushedMetalSeed: UInt64 = 3,
        isEnabled: Bool = true
    ) {
        self.speckleDensity = speckleDensity
        self.speckleSeed = speckleSeed
        self.speckleLight = speckleLight
        self.speckleDark = speckleDark
        self.chassisSpeckleDensity = chassisSpeckleDensity
        self.grillePitch = grillePitch
        self.grilleDotSize = grilleDotSize
        self.brushedMetalSeed = brushedMetalSeed
        self.isEnabled = isEnabled
    }

    public static let standard = POTextureTokens()
    public static let disabled = POTextureTokens(isEnabled: false)
}

/// Procedural surface painters.
///
/// Each painter is a `Canvas` whose closure reads no observed state, so
/// SwiftUI rasterises it once at a given size and never invalidates it. A
/// device face can therefore be covered in texture and still cost nothing
/// while idle — which matters, because these surfaces are large and always
/// on screen.
public enum POTexture {

    /// Moulded-rubber speckle: sparse light and dark motes over transparency.
    /// Intended as an overlay on an already-filled surface.
    public static func speckle(
        density: CGFloat,
        seed: UInt64,
        light: Color,
        dark: Color
    ) -> some View {
        Canvas(opaque: false) { context, size in
            let count = Int(size.width * size.height * density / 4)
            guard count > 0 else { return }
            for i in 0..<count {
                let base = seed &+ UInt64(i) &* PORandom.goldenGamma
                let x = PORandom.unitValue(base) * size.width
                let y = PORandom.unitValue(base &+ 1) * size.height
                let isLight = PORandom.unitValue(base &+ 2) > 0.5
                // Dark motes are drawn a touch larger: a pit in a matte surface
                // catches more shadow than a high spot catches light.
                let d: CGFloat = isLight ? 1 : 1.3
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)),
                    with: .color(isLight ? light : dark)
                )
            }
        }
        .allowsHitTesting(false)
    }

    /// Perforated grille: a dot lattice with a hairline shadow arc on each
    /// perforation's upper-left, which is what makes a hole read as a hole.
    public static func dotGrille(
        pitch: CGFloat,
        dotSize: CGFloat,
        dotColor: Color,
        shadowColor: Color = .black.opacity(0.25)
    ) -> some View {
        Canvas(opaque: false) { context, size in
            var y = pitch / 2
            while y < size.height {
                var x = pitch / 2
                while x < size.width {
                    let rect = CGRect(
                        x: x - dotSize / 2,
                        y: y - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    var arc = Path()
                    arc.addArc(
                        center: CGPoint(x: x, y: y),
                        radius: dotSize / 2,
                        startAngle: .degrees(120),
                        endAngle: .degrees(300),
                        clockwise: false
                    )
                    context.stroke(arc, with: .color(shadowColor), lineWidth: 0.5)
                    x += pitch
                }
                y += pitch
            }
        }
        .allowsHitTesting(false)
    }

    /// Brushed metal: 1pt horizontal banding with small luma jitter. Opaque —
    /// this one *is* the surface, not an overlay.
    public static func brushedMetal(base: Color, seed: UInt64) -> some View {
        Canvas(opaque: true) { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            var y: CGFloat = 0
            var i = seed
            while y < size.height {
                let jitter = PORandom.unitValue(i) * 0.08 - 0.04
                let tint: Color = jitter > 0
                    ? .white.opacity(jitter)
                    : .black.opacity(-jitter)
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(tint)
                )
                y += 1
                i &+= PORandom.goldenGamma
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview("Textures") {
    VStack(spacing: 16) {
        POTexture.speckle(density: 0.02, seed: 7, light: .white.opacity(0.05), dark: .black.opacity(0.18))
            .frame(width: 300, height: 60)
            .background(Color.poHex(0x161616))
        POTexture.dotGrille(pitch: 7, dotSize: 2.4, dotColor: .poHex(0x2A2A2A))
            .frame(width: 300, height: 60)
            .background(Color.poHex(0x0A0A0A))
        POTexture.brushedMetal(base: .poHex(0x8F949A), seed: 3)
            .frame(width: 300, height: 60)
    }
    .padding(20)
    .background(Color.poHex(0x0A0A0A))
}

import SwiftUI

/// Static texture painters. Each is a Canvas whose closure reads no observed
/// state, so SwiftUI rasterizes once and never invalidates — idle CPU stays
/// at zero no matter how busy the texture looks.
enum TextureCanvas {
    /// Braun speaker grille: dot grid with a hairline inner-shadow arc per
    /// dot so each perforation reads as recessed.
    static func dotGrille(
        pitch: CGFloat = 7,
        dotSize: CGFloat = 2.4,
        dotColor: Color,
        shadowColor: Color = .black.opacity(0.25)
    ) -> some View {
        Canvas { context, size in
            var y: CGFloat = pitch / 2
            while y < size.height {
                var x: CGFloat = pitch / 2
                while x < size.width {
                    let rect = CGRect(
                        x: x - dotSize / 2, y: y - dotSize / 2,
                        width: dotSize, height: dotSize
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    // Upper-left inner shadow arc — the recess.
                    var arc = Path()
                    arc.addArc(
                        center: CGPoint(x: x, y: y), radius: dotSize / 2,
                        startAngle: .degrees(120), endAngle: .degrees(300),
                        clockwise: false
                    )
                    context.stroke(arc, with: .color(shadowColor), lineWidth: 0.5)
                    x += pitch
                }
                y += pitch
            }
        }
    }

    /// Rubber-bed speckle: sparse dots of ± luma over transparent.
    static func speckle(
        density: CGFloat = 0.02,
        seed: UInt64 = 7,
        lightColor: Color = .white.opacity(0.05),
        darkColor: Color = .black.opacity(0.18)
    ) -> some View {
        Canvas { context, size in
            let count = Int(size.width * size.height * density / 4)
            for i in 0..<count {
                let base = seed &+ UInt64(i) &* 0x9E3779B97F4A7C15
                let x = LevelSynth.rand(base) * size.width
                let y = LevelSynth.rand(base &+ 1) * size.height
                let light = LevelSynth.rand(base &+ 2) > 0.5
                let d: CGFloat = light ? 1 : 1.3
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)),
                    with: .color(light ? lightColor : darkColor)
                )
            }
        }
    }

    /// Brushed metal: horizontal 1pt banding with small luma jitter.
    static func brushedMetal(
        baseColor: Color = Color(red: 0.56, green: 0.57, blue: 0.60),
        seed: UInt64 = 3
    ) -> some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(baseColor))
            var y: CGFloat = 0
            var i: UInt64 = seed
            while y < size.height {
                let jitter = LevelSynth.rand(i) * 0.08 - 0.04
                let color: Color = jitter > 0
                    ? .white.opacity(jitter)
                    : .black.opacity(-jitter)
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(color)
                )
                y += 1
                i &+= 0x9E3779B97F4A7C15
            }
        }
    }
}

#Preview("Textures") {
    VStack(spacing: 16) {
        TextureCanvas.dotGrille(dotColor: Color(red: 0.84, green: 0.82, blue: 0.79))
            .frame(width: 300, height: 100)
            .background(Color(red: 0.95, green: 0.94, blue: 0.91))
        TextureCanvas.speckle()
            .frame(width: 300, height: 60)
            .background(Color(white: 0.09))
        TextureCanvas.brushedMetal()
            .frame(width: 300, height: 60)
    }
    .padding(20)
    .background(Color(white: 0.13))
}

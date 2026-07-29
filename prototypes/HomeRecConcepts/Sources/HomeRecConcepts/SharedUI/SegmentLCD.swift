import SwiftUI

/// Drawn seven-segment display — digits, colon, dot, dash, and the handful of
/// letters hardware status words need (REC, SAVED, RDY, ARM, PERM, VU…).
/// The skeuomorphic tell: unlit segments stay faintly visible (LCD ghosting),
/// and lit segments glow. Blink is a hard square wave — LCDs don't fade.
struct SegmentLCD: View {
    var text: String
    var color: Color
    /// Cap height of a glyph cell in points; width follows at 0.55×.
    var size: CGFloat = 24
    var ghostOpacity: Double = 0.07

    var body: some View {
        HStack(spacing: size * 0.18) {
            ForEach(Array(text.uppercased().enumerated()), id: \.offset) { _, char in
                glyphCell(char)
            }
        }
    }

    @ViewBuilder
    private func glyphCell(_ char: Character) -> some View {
        let width = size * 0.55
        if char == " " {
            Color.clear.frame(width: width * 0.5, height: size)
        } else if char == ":" || char == "." {
            Canvas { context, canvasSize in
                let dot = canvasSize.width * 0.55
                let x = (canvasSize.width - dot) / 2
                if char == ":" {
                    for y in [canvasSize.height * 0.25, canvasSize.height * 0.66] {
                        context.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)),
                            with: .color(color)
                        )
                    }
                } else {
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x, y: canvasSize.height - dot * 1.4, width: dot, height: dot
                        )),
                        with: .color(color)
                    )
                }
            }
            .frame(width: width * 0.4, height: size)
        } else {
            SegmentGlyph(
                segments: Self.glyphs[char] ?? 0,
                color: color,
                ghostOpacity: ghostOpacity
            )
            .frame(width: width, height: size)
        }
    }

    /// Segment bit layout:  bit 0 top · 1 top-right · 2 bottom-right ·
    /// 3 bottom · 4 bottom-left · 5 top-left · 6 middle
    static let glyphs: [Character: UInt8] = [
        "0": 0b0111111, "1": 0b0000110, "2": 0b1011011, "3": 0b1001111,
        "4": 0b1100110, "5": 0b1101101, "6": 0b1111101, "7": 0b0000111,
        "8": 0b1111111, "9": 0b1101111,
        "-": 0b1000000,
        "A": 0b1110111, "B": 0b1111100, "C": 0b0111001, "D": 0b1011110,
        "E": 0b1111001, "F": 0b1110001, "G": 0b0111101, "H": 0b1110110,
        "I": 0b0000110, "L": 0b0111000, "M": 0b0110111, "N": 0b1010100,
        "O": 0b0111111, "P": 0b1110011, "R": 0b1010000, "S": 0b1101101,
        "T": 0b1111000, "U": 0b0111110, "V": 0b0011110, "Y": 0b1101110,
    ]
}

/// One glyph cell: seven chamfered-quad segments drawn in a Canvas.
private struct SegmentGlyph: View {
    let segments: UInt8
    let color: Color
    let ghostOpacity: Double

    var body: some View {
        Canvas { context, size in
            let t = max(1.6, size.height * 0.085)   // segment thickness
            let w = size.width, h = size.height
            let inset = t * 0.6                      // corner breathing room

            // Horizontal segment path (chamfered ends), given its center-line rect.
            func horizontal(_ y: CGFloat) -> Path {
                var p = Path()
                let x0 = inset + t * 0.7, x1 = w - inset - t * 0.7
                p.move(to: CGPoint(x: x0 - t / 2, y: y))
                p.addLine(to: CGPoint(x: x0, y: y - t / 2))
                p.addLine(to: CGPoint(x: x1, y: y - t / 2))
                p.addLine(to: CGPoint(x: x1 + t / 2, y: y))
                p.addLine(to: CGPoint(x: x1, y: y + t / 2))
                p.addLine(to: CGPoint(x: x0, y: y + t / 2))
                p.closeSubpath()
                return p
            }
            func vertical(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat) -> Path {
                var p = Path()
                p.move(to: CGPoint(x: x, y: y0 - t / 2))
                p.addLine(to: CGPoint(x: x + t / 2, y: y0))
                p.addLine(to: CGPoint(x: x + t / 2, y: y1))
                p.addLine(to: CGPoint(x: x, y: y1 + t / 2))
                p.addLine(to: CGPoint(x: x - t / 2, y: y1))
                p.addLine(to: CGPoint(x: x - t / 2, y: y0))
                p.closeSubpath()
                return p
            }

            let mid = h / 2
            let paths: [Path] = [
                horizontal(inset + t / 2),                       // 0 top
                vertical(w - inset - t / 2, inset + t, mid - t), // 1 top-right
                vertical(w - inset - t / 2, mid + t, h - inset - t), // 2 bottom-right
                horizontal(h - inset - t / 2),                   // 3 bottom
                vertical(inset + t / 2, mid + t, h - inset - t), // 4 bottom-left
                vertical(inset + t / 2, inset + t, mid - t),     // 5 top-left
                horizontal(mid),                                 // 6 middle
            ]

            for (bit, path) in paths.enumerated() {
                let lit = segments & (1 << bit) != 0
                if lit {
                    // Glow pass under the segment, then the segment itself.
                    context.drawLayer { layer in
                        layer.addFilter(.blur(radius: size.height * 0.12))
                        layer.fill(path, with: .color(color.opacity(0.55)))
                    }
                    context.fill(path, with: .color(color))
                } else {
                    context.fill(path, with: .color(color.opacity(ghostOpacity)))
                }
            }
        }
    }
}

#Preview("Segment LCD") {
    VStack(alignment: .leading, spacing: 16) {
        SegmentLCD(text: "0:02.4", color: Color(red: 0.61, green: 0.91, blue: 0.44), size: 34)
        SegmentLCD(text: "REC", color: Color(red: 0.61, green: 0.91, blue: 0.44), size: 20)
        SegmentLCD(text: "12:07", color: Color(red: 1.0, green: 0.69, blue: 0.13), size: 28)
        SegmentLCD(text: "SAVED", color: Color(red: 1.0, green: 0.69, blue: 0.13), size: 16)
    }
    .padding(24)
    .background(Color(red: 0.08, green: 0.1, blue: 0.07))
}

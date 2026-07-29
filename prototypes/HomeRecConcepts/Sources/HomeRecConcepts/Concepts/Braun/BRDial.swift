import SwiftUI

/// The one rotary dial: flat cap, single index line, ring of hairline ticks.
/// Drag rotates through ±150° mapping to 0...1. The concept's only flourish.
struct BRDial: View {
    @Binding var value: Double
    var diameter: CGFloat = 120

    private static let sweep: Double = 150   // degrees each side of top

    var body: some View {
        ZStack {
            tickRing
            dialCap
        }
        .frame(width: diameter + 28, height: diameter + 28)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    let center = CGPoint(x: (diameter + 28) / 2, y: (diameter + 28) / 2)
                    let dx = drag.location.x - center.x
                    let dy = drag.location.y - center.y
                    // Angle from 12 o'clock, clockwise positive.
                    var degrees = Foundation.atan2(Double(dx), Double(-dy)) * 180 / .pi
                    degrees = min(Self.sweep, max(-Self.sweep, degrees))
                    value = (degrees + Self.sweep) / (2 * Self.sweep)
                }
        )
    }

    private var tickRing: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = size.width / 2
            for i in 0..<21 {
                let fraction = Double(i) / 20
                let angle = (-Self.sweep + fraction * 2 * Self.sweep - 90) * .pi / 180
                var tick = Path()
                tick.move(to: point(center, outer - 6, angle))
                tick.addLine(to: point(center, outer, angle))
                context.stroke(
                    tick,
                    with: .color(BRTheme.label.opacity(0.7)),
                    lineWidth: 0.8
                )
            }
        }
    }

    private var dialCap: some View {
        Circle()
            .fill(BRTheme.face)
            .overlay(Circle().strokeBorder(BRTheme.rim, lineWidth: 1))
            // Barely-there dimensionality: a whisper of a shadow, no gloss.
            .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
            .overlay(
                // Index line, from center toward the edge.
                Rectangle()
                    .fill(BRTheme.ink)
                    .frame(width: 2, height: diameter * 0.42)
                    .offset(y: -diameter * 0.25)
                    .rotationEffect(.degrees(-Self.sweep + value * 2 * Self.sweep))
            )
            .frame(width: diameter, height: diameter)
    }

    private func point(_ center: CGPoint, _ radius: CGFloat, _ angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(Foundation.cos(angle)),
            y: center.y + radius * CGFloat(Foundation.sin(angle))
        )
    }
}

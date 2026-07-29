import SwiftUI

/// One tape reel: dark tape annulus, cream hub with three trapezoid spokes.
/// Rotation = banked angle (springs on the rewind clunk) + live wall-clock
/// rotation while recording. The tape annulus is fatter on the supply reel —
/// tape visibly lives somewhere.
struct DTReelView: View {
    @EnvironmentObject private var store: PrototypeStateStore

    /// Take-up spins slightly faster than supply (smaller effective radius).
    var speedFactor: Double = 1
    /// Outer radius of the wound tape, as a fraction of the reel radius.
    var tapeFill: CGFloat = 0.9
    var diameter: CGFloat = 88

    var body: some View {
        TimelineView(.animation) { context in
            reel
                // Live rotation: not animated, driven by the clock.
                .rotationEffect(.degrees(liveRotation(at: context.date)))
        }
        // Banked rotation: springs when the mechanism clunks backward.
        .rotationEffect(.degrees(store.reelBankedRotation * speedFactor))
        .animation(
            .spring(response: 0.25, dampingFraction: 0.45),
            value: store.reelBankedRotation
        )
        .frame(width: diameter, height: diameter)
    }

    private func liveRotation(at date: Date) -> Double {
        guard case .recording(let startedAt) = store.transport else { return 0 }
        return date.timeIntervalSince(startedAt) * PrototypeStateStore.reelSpeed * speedFactor
    }

    private var reel: some View {
        ZStack {
            // Wound tape.
            Circle()
                .fill(DTTheme.tape)
                .frame(width: diameter * tapeFill, height: diameter * tapeFill)
                .overlay(
                    // Faint winding sheen.
                    Circle().strokeBorder(.white.opacity(0.04), lineWidth: diameter * 0.12)
                )
            // Cream hub with spokes.
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let hubRadius = size.width / 2

                context.fill(
                    Path(ellipseIn: CGRect(
                        x: center.x - hubRadius, y: center.y - hubRadius,
                        width: hubRadius * 2, height: hubRadius * 2
                    )),
                    with: .color(DTTheme.cream)
                )
                // Three trapezoid cutouts between spokes.
                for i in 0..<3 {
                    let angle = Double(i) * 120.0 * .pi / 180
                    var cutout = Path()
                    let inner = hubRadius * 0.34
                    let outer = hubRadius * 0.82
                    let halfInner = 26.0 * .pi / 180
                    let halfOuter = 38.0 * .pi / 180
                    cutout.move(to: point(center, inner, angle - halfInner))
                    cutout.addLine(to: point(center, outer, angle - halfOuter))
                    cutout.addArc(
                        center: center, radius: outer,
                        startAngle: .radians(angle - halfOuter),
                        endAngle: .radians(angle + halfOuter),
                        clockwise: false
                    )
                    cutout.addLine(to: point(center, inner, angle + halfInner))
                    cutout.addArc(
                        center: center, radius: inner,
                        startAngle: .radians(angle + halfInner),
                        endAngle: .radians(angle - halfInner),
                        clockwise: true
                    )
                    cutout.closeSubpath()
                    context.fill(cutout, with: .color(DTTheme.tape))
                }
                // Center cap.
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: center.x - hubRadius * 0.16, y: center.y - hubRadius * 0.16,
                        width: hubRadius * 0.32, height: hubRadius * 0.32
                    )),
                    with: .color(DTTheme.creamShadow)
                )
            }
            .frame(width: diameter * 0.52, height: diameter * 0.52)
        }
        .overlay(
            Circle().strokeBorder(.black.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
    }

    private func point(_ center: CGPoint, _ radius: CGFloat, _ angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(Foundation.cos(angle)),
            y: center.y + radius * CGFloat(Foundation.sin(angle))
        )
    }
}

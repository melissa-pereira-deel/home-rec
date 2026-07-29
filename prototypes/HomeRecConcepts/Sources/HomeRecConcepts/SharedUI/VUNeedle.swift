import SwiftUI

/// Analog VU meter with asymmetric needle ballistics: fast attack, slow
/// release — integrated manually per frame, because real needles aren't
/// spring-animated. Reads `level` continuously via TimelineView.
struct VUNeedle: View {
    /// Live level source, 0...1. A closure so the meter samples at render
    /// cadence without requiring 60fps store publishes.
    var level: () -> Float
    var faceColor: Color = Color(red: 0.93, green: 0.90, blue: 0.84)
    var inkColor: Color = Color(red: 0.17, green: 0.17, blue: 0.17)
    var redZoneColor: Color = Color(red: 0.85, green: 0.23, blue: 0.17)
    var label: String = "VU"

    /// Needle sweep: −45° (rest) … +45° (full scale), 0° pointing up.
    private static let sweep: ClosedRange<Double> = -45...45

    @State private var needle: Double = 0   // 0...1 smoothed position
    @State private var lastTick: Date?

    var body: some View {
        TimelineView(.animation) { context in
            meterFace(needlePosition: updatedNeedle(at: context.date))
        }
    }

    /// Per-frame ballistic integration. Attack ~90ms, release ~350ms
    /// (time-corrected so feel is framerate-independent).
    private func updatedNeedle(at date: Date) -> Double {
        let dt = lastTick.map { date.timeIntervalSince($0) } ?? 1 / 60
        DispatchQueue.main.async {
            let target = Double(level())
            let tau = target > needle ? 0.09 : 0.35
            let k = 1 - exp(-dt / tau)
            needle += (target - needle) * k
            lastTick = date
        }
        return needle
    }

    private func meterFace(needlePosition: Double) -> some View {
        Canvas { context, size in
            let pivot = CGPoint(x: size.width / 2, y: size.height * 0.94)
            let radius = min(size.height * 0.8, size.width * 0.46)

            // Scale arc with tick marks; red zone on the last 20%.
            let arc = Path { p in
                p.addArc(
                    center: pivot, radius: radius,
                    startAngle: .degrees(Self.sweep.lowerBound - 90),
                    endAngle: .degrees(Self.sweep.upperBound - 90),
                    clockwise: false
                )
            }
            context.stroke(arc, with: .color(inkColor.opacity(0.7)), lineWidth: 1)

            let redArc = Path { p in
                p.addArc(
                    center: pivot, radius: radius,
                    startAngle: .degrees(Self.sweep.lowerBound + 0.8 * 90 - 90),
                    endAngle: .degrees(Self.sweep.upperBound - 90),
                    clockwise: false
                )
            }
            context.stroke(redArc, with: .color(redZoneColor), lineWidth: 2.5)

            for i in 0...10 {
                let f = Double(i) / 10
                let angle = Angle.degrees(
                    Self.sweep.lowerBound + f * (Self.sweep.upperBound - Self.sweep.lowerBound) - 90
                )
                let major = i.isMultiple(of: 5)
                let inner = radius - (major ? 7 : 4)
                let tick = Path { p in
                    p.move(to: point(pivot, radius, angle))
                    p.addLine(to: point(pivot, inner, angle))
                }
                context.stroke(
                    tick,
                    with: .color(f >= 0.8 ? redZoneColor : inkColor.opacity(0.75)),
                    lineWidth: major ? 1.4 : 0.8
                )
            }

            // Needle: 1.5pt, pivot bottom-center, slight overshoot past the arc.
            let needleAngle = Angle.degrees(
                Self.sweep.lowerBound
                    + needlePosition * (Self.sweep.upperBound - Self.sweep.lowerBound) - 90
            )
            let needlePath = Path { p in
                p.move(to: pivot)
                p.addLine(to: point(pivot, radius + 3, needleAngle))
            }
            context.stroke(needlePath, with: .color(inkColor), lineWidth: 1.5)

            // Pivot cap.
            context.fill(
                Path(ellipseIn: CGRect(x: pivot.x - 3, y: pivot.y - 3, width: 6, height: 6)),
                with: .color(inkColor)
            )
        }
        .background(faceColor)
        .overlay(alignment: .bottomLeading) {
            Text(label)
                .font(.system(size: 9, weight: .medium).italic())
                .foregroundStyle(inkColor.opacity(0.8))
                .padding(.leading, 8)
                .padding(.bottom, 4)
        }
    }

    private func point(_ center: CGPoint, _ radius: CGFloat, _ angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(Foundation.cos(angle.radians)),
            y: center.y + radius * CGFloat(Foundation.sin(angle.radians))
        )
    }
}

#Preview("VU needle") {
    VUNeedle(level: { Float(0.5 + 0.4 * sin(Date.now.timeIntervalSince1970 * 3)) })
        .frame(width: 160, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(30)
        .background(Color(red: 0.17, green: 0.16, blue: 0.16))
}

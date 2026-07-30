import SwiftUI

/// Scale markings on a meter face.
public struct VUScale: Sendable, Equatable {
    /// Needle sweep in degrees, 0 pointing straight up.
    public var sweep: ClosedRange<Double>
    /// Number of tick intervals across the scale.
    public var divisions: Int
    /// Every nth tick is drawn long.
    public var majorEvery: Int
    /// Fraction of full scale where the red zone begins.
    public var redZoneStart: Double

    public init(
        sweep: ClosedRange<Double> = -45...45,
        divisions: Int = 10,
        majorEvery: Int = 5,
        redZoneStart: Double = 0.8
    ) {
        self.sweep = sweep
        self.divisions = divisions
        self.majorEvery = majorEvery
        self.redZoneStart = redZoneStart
    }

    public static let standard = VUScale()
    /// Wider sweep for a larger face where the needle has room to travel.
    public static let wide = VUScale(sweep: -55...55, divisions: 12, majorEvery: 4)
}

/// An analogue meter movement.
///
/// ## Why the ballistics are asymmetric
///
/// The needle rises with a ~90 ms time constant and falls with a ~350 ms one.
/// That ratio is not a style choice — it is what a moving-coil movement
/// physically does. The coil is *driven* toward the signal by current, so it
/// rises as fast as the circuit allows; it returns only under its hairspring
/// against its own damping, so it falls slowly. Every meter anyone has ever
/// watched behaves this way, which is why the asymmetry reads as "real" long
/// before anyone consciously notices it.
///
/// It is also what makes the meter *useful*. A symmetric filter fast enough to
/// catch a transient is too fast to read; one slow enough to read misses the
/// transient. Splitting the two lets the needle snap to a peak and then hold
/// long enough for an eye to take a value off it.
///
/// ## Why the level is a closure
///
/// The meter samples at render cadence rather than being pushed values. A
/// published property updating at 60 Hz invalidates the whole enclosing view
/// tree 60 times a second; a closure read inside a `TimelineView` costs one
/// canvas redraw and touches nothing else on the panel.
@available(macOS 15, *)
public struct VUMeter: View {
    @Environment(\.poTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Live signal source, 0...1. Called once per frame.
    private let level: () -> Double
    private let ballistics: POBallistics
    private let scale: VUScale
    private let legend: String?
    private let accessibilityLabel: String
    private let accessibilityValue: (Double) -> String

    @State private var integrator = BallisticIntegrator()

    /// - Parameters:
    ///   - ballistics: Attack and release time constants. `.vu` for programme
    ///     level, `.peak` for a PPM, `.instant` to disable the movement.
    ///   - accessibilityValue: Formats the smoothed reading for speech.
    ///     Defaults to a percentage; a product with a calibrated scale should
    ///     substitute its own units.
    public init(
        level: @escaping () -> Double,
        ballistics: POBallistics = .vu,
        scale: VUScale = .standard,
        legend: String? = "VU",
        accessibilityLabel: String = "Level meter",
        accessibilityValue: @escaping (Double) -> String = { "\(Int(($0 * 100).rounded())) percent" }
    ) {
        self.level = level
        self.ballistics = ballistics
        self.scale = scale
        self.legend = legend
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
    }

    public var body: some View {
        Group {
            if reduceMotion {
                // Still a live instrument, but stepped at a rate that reads as
                // a sampled reading rather than as continuous motion, and with
                // the ballistic lag removed so the value is unambiguous.
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    face(position: sampled(at: context.date, ballistics: .instant))
                }
            } else {
                TimelineView(.animation) { context in
                    face(position: sampled(at: context.date, ballistics: ballistics))
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue(integrator.position))
    }

    private func sampled(at date: Date, ballistics: POBallistics) -> Double {
        integrator.step(target: level(), at: date, ballistics: ballistics)
    }

    private func face(position: Double) -> some View {
        let colors = theme.colors
        return Canvas(opaque: true) { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(colors.meterFace))

            // Pivot sits just below the face so the arc fills the visible
            // area; a real movement's pivot is hidden behind the bezel.
            let pivot = CGPoint(x: size.width / 2, y: size.height * 0.94)
            let radius = min(size.height * 0.8, size.width * 0.46)
            let span = scale.sweep.upperBound - scale.sweep.lowerBound

            var arc = Path()
            arc.addArc(
                center: pivot,
                radius: radius,
                startAngle: .degrees(scale.sweep.lowerBound - 90),
                endAngle: .degrees(scale.sweep.upperBound - 90),
                clockwise: false
            )
            context.stroke(arc, with: .color(colors.meterInk.opacity(0.7)), lineWidth: 1)

            var redArc = Path()
            redArc.addArc(
                center: pivot,
                radius: radius,
                startAngle: .degrees(scale.sweep.lowerBound + scale.redZoneStart * span - 90),
                endAngle: .degrees(scale.sweep.upperBound - 90),
                clockwise: false
            )
            context.stroke(redArc, with: .color(colors.meterRedZone), lineWidth: 2.5)

            for index in 0...scale.divisions {
                let fraction = Double(index) / Double(scale.divisions)
                let angle = Angle.degrees(scale.sweep.lowerBound + fraction * span - 90)
                let isMajor = index.isMultiple(of: scale.majorEvery)
                let inner = radius - (isMajor ? 7 : 4)
                var tick = Path()
                tick.move(to: point(pivot, radius, angle))
                tick.addLine(to: point(pivot, inner, angle))
                context.stroke(
                    tick,
                    with: .color(
                        fraction >= scale.redZoneStart
                            ? colors.meterRedZone
                            : colors.meterInk.opacity(0.75)
                    ),
                    lineWidth: isMajor ? 1.4 : 0.8
                )
            }

            let needleAngle = Angle.degrees(scale.sweep.lowerBound + position * span - 90)
            var needle = Path()
            needle.move(to: pivot)
            // Overshoots the arc by 3pt: a needle reads *past* its scale, and
            // stopping it exactly on the arc makes it look printed on.
            needle.addLine(to: point(pivot, radius + 3, needleAngle))
            context.stroke(needle, with: .color(colors.meterInk), lineWidth: 1.5)

            context.fill(
                Path(ellipseIn: CGRect(x: pivot.x - 3, y: pivot.y - 3, width: 6, height: 6)),
                with: .color(colors.meterInk)
            )
        }
        .overlay(alignment: .bottomLeading) {
            if let legend {
                Text(legend)
                    .font(.system(size: 9, weight: .medium).italic())
                    .foregroundStyle(colors.meterInk.opacity(0.8))
                    .padding(.leading, 8)
                    .padding(.bottom, 4)
                    .accessibilityHidden(true)
            }
        }
    }

    private func point(_ center: CGPoint, _ radius: CGFloat, _ angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(cos(angle.radians)),
            y: center.y + radius * CGFloat(sin(angle.radians))
        )
    }
}

@available(macOS 15, *)
#Preview("VU meter") {
    HStack(spacing: 20) {
        VUMeter(level: { POSampleData.level(at: Date.now.timeIntervalSince1970) })
            .frame(width: 160, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .poBezel(corner: 4)
        VUMeter(
            level: { POSampleData.level(at: Date.now.timeIntervalSince1970, seed: 5) },
            ballistics: .peak,
            legend: "PPM"
        )
        .frame(width: 160, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .poBezel(corner: 4)
    }
    .padding(30)
    .background(Color.poHex(0x0A0A0A))
}

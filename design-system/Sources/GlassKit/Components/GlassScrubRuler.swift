import SwiftUI

/// The scrub control: a field of hairline ticks with one accent indicator.
///
/// No filled track. A progress-bar-shaped scrubber implies "how much is done";
/// a ruler implies "where in the material you are", which is what a person
/// editing takes is actually asking. Every tenth tick is major, so the eye can
/// count position without a label.
///
/// `onEditingChanged` fires `true` on the first drag and `false` on release.
/// Hosts **must** use it to suspend their playback ticker: otherwise the
/// playhead keeps advancing into the drag and the two fight for the same
/// value, which feels like the control is resisting you.
public struct GlassScrubRuler: View {
    @Binding private var value: Double
    private let accessibilityLabel: String
    private let accessibilityValueText: (Double) -> String
    private let onEditingChanged: ((Bool) -> Void)?

    @Environment(\.glassTheme) private var theme
    @State private var isDragging = false

    public init(
        value: Binding<Double>,
        accessibilityLabel: String = "Playback position",
        accessibilityValue: @escaping (Double) -> String = { "\(Int($0 * 100)) percent" },
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValueText = accessibilityValue
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        GeometryReader { geometry in
            Canvas(opaque: false) { context, size in
                drawTicks(in: context, size: size)
                drawIndicator(in: context, size: size)
            }
            .contentShape(Rectangle())
            .gesture(
                // `minimumDistance: 0` makes a tap a scrub-to-here as well as
                // a drag start. On a timeline, a click that does nothing until
                // you move is a click that feels broken.
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged?(true)
                        }
                        value = (drag.location.x / max(1, geometry.size.width)).clampedToUnitInterval
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged?(false)
                    }
            )
        }
        .frame(height: theme.metrics.rulerHeight)
        // A Canvas with a DragGesture is completely invisible to assistive
        // technology — no role, no value, no way to move it. Representing it
        // as the Slider it behaves as gives VoiceOver users arrow-key
        // adjustment and a spoken position, for four lines.
        .accessibilityRepresentation {
            Slider(value: $value, in: 0...1) {
                Text(accessibilityLabel)
            }
            .accessibilityValue(accessibilityValueText(value))
        }
    }

    private func drawTicks(in context: GraphicsContext, size: CGSize) {
        let pitch = theme.metrics.rulerTickPitch
        guard pitch > 0 else { return }
        let count = Int(size.width / pitch)
        let tick = theme.colors.textTertiary
        for index in 0...max(0, count) {
            let isMajor = index.isMultiple(of: 10)
            let height: CGFloat = isMajor ? 8 : 4
            context.fill(
                Path(CGRect(
                    x: CGFloat(index) * pitch,
                    y: (size.height - height) / 2,
                    width: theme.metrics.hairline,
                    height: height
                )),
                with: .color(tick.opacity(isMajor ? 0.5 : 0.3))
            )
        }
    }

    private func drawIndicator(in context: GraphicsContext, size: CGSize) {
        let accent = theme.colors.accent
        let x = size.width * value.clampedToUnitInterval
        context.fill(
            Path(CGRect(x: x - 0.75, y: 2, width: 1.5, height: size.height - 4)),
            with: .color(accent)
        )
        // A triangle cap, not a circular knob: the knob would be the largest
        // round object on a panel whose only round object is the record pill.
        var triangle = Path()
        triangle.move(to: CGPoint(x: x - 3.5, y: 0))
        triangle.addLine(to: CGPoint(x: x + 3.5, y: 0))
        triangle.addLine(to: CGPoint(x: x, y: 4))
        triangle.closeSubpath()
        context.fill(triangle, with: .color(accent))
    }
}

#Preview("Scrub ruler") {
    struct Host: View {
        @State private var value = 0.42
        var body: some View {
            GlassPreviewStage {
                VStack(spacing: GlassSpacing.l) {
                    GlassScrubRuler(
                        value: $value,
                        accessibilityValue: { GlassTimecode.spoken($0 * 154) }
                    )
                    GlassMetaLabel(GlassTimecode.string(value * 154, matching: 154))
                }
            }
        }
    }
    return Host()
}

import SwiftUI

/// A ruled scrub bar: a field of etched ticks with one accent index mark.
///
/// The counterpart to `Fader` for positional rather than continuous values.
/// There is no filled track here either — position is read off a printed
/// scale, exactly as it is on a tape counter or a tuning dial.
@available(macOS 15, *)
public struct TickRuler: View {
    @Environment(\.poTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool

    @Binding private var value: Double
    private let tickPitch: CGFloat
    private let majorEvery: Int
    private let tint: Color?
    private let label: String
    private let step: Double
    private let accessibilityValue: (Double) -> String
    /// Fired `true` on the first drag change and `false` on release, so an
    /// owner can suspend a playback timer that would otherwise fight the drag.
    private let onEditingChanged: ((Bool) -> Void)?

    @State private var isDragging = false

    public init(
        value: Binding<Double>,
        tickPitch: CGFloat = 3,
        majorEvery: Int = 10,
        tint: Color? = nil,
        label: String = "POSITION",
        step: Double = 0.02,
        accessibilityValue: @escaping (Double) -> String = { "\(Int(($0 * 100).rounded())) percent" },
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.tickPitch = tickPitch
        self.majorEvery = majorEvery
        self.tint = tint
        self.label = label
        self.step = step
        self.accessibilityValue = accessibilityValue
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        let accent = tint ?? theme.colors.lampActive
        GeometryReader { geometry in
            Canvas(opaque: false) { context, size in
                var minor = Path()
                var major = Path()
                let count = max(1, Int(size.width / tickPitch))
                for index in 0...count {
                    let x = CGFloat(index) * tickPitch
                    let isMajor = index.isMultiple(of: majorEvery)
                    let height: CGFloat = isMajor ? 8 : 4
                    let rect = CGRect(x: x, y: (size.height - height) / 2, width: 1, height: height)
                    if isMajor { major.addRect(rect) } else { minor.addRect(rect) }
                }
                context.fill(minor, with: .color(theme.colors.etch.opacity(0.8)))
                context.fill(major, with: .color(theme.colors.screenPrint.opacity(0.7)))

                // Index mark: a full-height hairline under a small flag, the
                // way a mechanical cursor rides a printed scale.
                let x = size.width * min(1, max(0, value))
                context.fill(
                    Path(CGRect(x: x - 0.75, y: 2, width: 1.5, height: size.height - 4)),
                    with: .color(accent)
                )
                var flag = Path()
                flag.move(to: CGPoint(x: x - 3.5, y: 0))
                flag.addLine(to: CGPoint(x: x + 3.5, y: 0))
                flag.addLine(to: CGPoint(x: x, y: 4))
                flag.closeSubpath()
                context.fill(flag, with: .color(accent))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard isEnabled else { return }
                        if !isDragging {
                            isDragging = true
                            onEditingChanged?(true)
                        }
                        isFocused = true
                        value = min(1, max(0, drag.location.x / max(1, geometry.size.width)))
                    }
                    .onEnded { _ in
                        guard isEnabled else { return }
                        isDragging = false
                        onEditingChanged?(false)
                    }
            )
        }
        .frame(height: 18)
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(theme.colors.focusRing, lineWidth: 2)
                    .padding(-2)
                    .allowsHitTesting(false)
            }
        }
        .focusable(isEnabled)
        .focused($isFocused)
        .onKeyPress(.leftArrow) { nudge(-step) }
        .onKeyPress(.rightArrow) { nudge(+step) }
        .onKeyPress(.home) { nudge(to: 0) }
        .onKeyPress(.end) { nudge(to: 1) }
        // A `Canvas` driven by a drag gesture is completely invisible to
        // assistive technology. Representing it as the slider it behaves like
        // is the difference between an operable control and a decoration.
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: _ = nudge(+step)
            case .decrement: _ = nudge(-step)
            @unknown default: break
            }
        }
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func nudge(_ delta: Double) -> KeyPress.Result {
        guard isEnabled else { return .ignored }
        value = min(1, max(0, value + delta))
        onEditingChanged?(false)
        return .handled
    }

    private func nudge(to target: Double) -> KeyPress.Result {
        guard isEnabled else { return .ignored }
        value = target
        onEditingChanged?(false)
        return .handled
    }
}

@available(macOS 15, *)
#Preview("Tick ruler") {
    struct Host: View {
        @State private var position = 0.42
        var body: some View {
            TickRuler(value: $position)
                .frame(width: 380)
                .padding(30)
                .background(Color.poHex(0x0A0A0A))
        }
    }
    return Host()
}

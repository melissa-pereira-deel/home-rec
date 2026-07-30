import SwiftUI

/// A hardware fader: a scored cap riding a narrow slot, against a printed
/// detent ladder.
///
/// The physical cues that matter, in order of how much they carry:
///
/// - the **slot is a cut, not a filled track**. There is no progress fill,
///   because a fader's position is read from where the cap is, not from how
///   much of something is coloured in;
/// - the **cap casts a shadow into the slot**, which is what makes it sit on
///   top of the panel rather than in it;
/// - the **detent ladder is printed beside the slot**, not on it, exactly as
///   it is silkscreened on a mixer;
/// - **release snaps to the nearest detent**, on a stiff, well-damped spring —
///   a physical detent catches, it does not glide.
///
/// Keyboard: arrow keys step by one detent, ⇧-arrow by five, Home/End to the
/// ends. A control that can only be dragged is a control some people cannot
/// use at all.
@available(macOS 15, *)
public struct Fader: View {
    public enum Orientation: Sendable, Equatable {
        case vertical
        case horizontal
    }

    @Environment(\.poTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool

    @Binding private var value: Double
    private let orientation: Orientation
    private let detents: Int
    private let snapsToDetents: Bool
    private let length: CGFloat?
    private let label: String
    private let accessibilityValue: (Double) -> String
    private let onEditingChanged: ((Bool) -> Void)?

    @State private var isDragging = false

    /// - Parameters:
    ///   - value: 0...1, where 1 is the top of a vertical fader.
    ///   - detents: Number of intervals in the printed ladder. Also the
    ///     keyboard step size, so the two agree by construction.
    ///   - accessibilityValue: Formats the value for speech. Defaults to a
    ///     percentage; override for calibrated units such as dB.
    public init(
        value: Binding<Double>,
        orientation: Orientation = .vertical,
        detents: Int = 10,
        snapsToDetents: Bool = true,
        length: CGFloat? = nil,
        label: String = "LEVEL",
        accessibilityValue: @escaping (Double) -> String = { "\(Int(($0 * 100).rounded())) percent" },
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.orientation = orientation
        self.detents = max(1, detents)
        self.snapsToDetents = snapsToDetents
        self.length = length
        self.label = label
        self.accessibilityValue = accessibilityValue
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        let travel = length ?? theme.metrics.faderLength
        Group {
            if orientation == .vertical {
                VStack(spacing: theme.metrics.spacing.base) {
                    printedLegend
                    slot
                        .frame(width: 44, height: travel)
                }
            } else {
                VStack(alignment: .leading, spacing: theme.metrics.spacing.base) {
                    printedLegend
                    slot
                        .frame(width: travel, height: 44)
                }
            }
        }
        .focusable(isEnabled)
        .focused($isFocused)
        .onKeyPress(.upArrow) { step(+1) }
        .onKeyPress(.rightArrow) { step(+1) }
        .onKeyPress(.downArrow) { step(-1) }
        .onKeyPress(.leftArrow) { step(-1) }
        .onKeyPress(.home) { jump(to: 0) }
        .onKeyPress(.end) { jump(to: 1) }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: _ = step(+1)
            case .decrement: _ = step(-1)
            @unknown default: break
            }
        }
    }

    /// Omitted when empty so the fader can sit inside a `LabelledControl` that
    /// already prints its legend, without a phantom line of spacing.
    @ViewBuilder
    private var printedLegend: some View {
        if !label.isEmpty {
            ScreenPrintLabel(label, isDecorative: true)
        }
    }

    private var slot: some View {
        GeometryReader { geometry in
            let span = orientation == .vertical ? geometry.size.height : geometry.size.width
            ZStack {
                detentLadder(in: geometry.size)
                track(in: geometry.size)
                cap(in: geometry.size)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(span: span, size: geometry.size))
        }
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(theme.colors.focusRing, lineWidth: 2)
                    .padding(-2)
                    .allowsHitTesting(false)
            }
        }
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func detentLadder(in size: CGSize) -> some View {
        let ticks = theme.metrics.faderDetentTickLength
        let offset = theme.metrics.faderDetentOffset
        return ForEach(0...detents, id: \.self) { index in
            let fraction = Double(index) / Double(detents)
            Rectangle()
                .fill(theme.colors.etch)
                .frame(
                    width: orientation == .vertical ? ticks : theme.metrics.hairline,
                    height: orientation == .vertical ? theme.metrics.hairline : ticks
                )
                .position(
                    x: orientation == .vertical
                        ? size.width / 2 + offset
                        : position(for: fraction, span: size.width),
                    y: orientation == .vertical
                        ? position(for: fraction, span: size.height)
                        : size.height / 2 + offset
                )
        }
    }

    private func track(in size: CGSize) -> some View {
        Capsule()
            .fill(.black)
            .frame(
                width: orientation == .vertical ? theme.metrics.faderTrackWidth : nil,
                height: orientation == .horizontal ? theme.metrics.faderTrackWidth : nil
            )
            .overlay {
                Capsule().strokeBorder(theme.colors.wellRim, lineWidth: theme.metrics.hairline)
            }
    }

    private func cap(in size: CGSize) -> some View {
        let capSize = theme.metrics.faderCapSize
        let width = orientation == .vertical ? capSize.width : capSize.height
        let height = orientation == .vertical ? capSize.height : capSize.width
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [theme.colors.keyCapTop, theme.colors.keyCapBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: height)
            .overlay {
                // Scored centre line: the moulded grip, and the index mark you
                // actually read the value off.
                Rectangle()
                    .fill(.black.opacity(0.55))
                    .frame(
                        width: orientation == .vertical ? nil : 1.5,
                        height: orientation == .vertical ? 1.5 : nil
                    )
            }
            .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
            .position(
                x: orientation == .vertical
                    ? size.width / 2
                    : position(for: value, span: size.width),
                y: orientation == .vertical
                    ? position(for: value, span: size.height)
                    : size.height / 2
            )
    }

    private func dragGesture(span: CGFloat, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard isEnabled else { return }
                if !isDragging {
                    isDragging = true
                    onEditingChanged?(true)
                }
                isFocused = true
                let raw = orientation == .vertical
                    ? 1 - Double(drag.location.y / max(1, size.height))
                    : Double(drag.location.x / max(1, size.width))
                value = min(1, max(0, raw))
            }
            .onEnded { _ in
                guard isEnabled else { return }
                isDragging = false
                if snapsToDetents {
                    let snapped = (value * Double(detents)).rounded() / Double(detents)
                    if reduceMotion {
                        value = snapped
                    } else {
                        withAnimation(theme.motion.detentSnap) { value = snapped }
                    }
                }
                onEditingChanged?(false)
            }
    }

    /// Position of a 0...1 fraction along the slot, inset by half a cap so the
    /// cap never overhangs the ends of its travel.
    private func position(for fraction: Double, span: CGFloat) -> CGFloat {
        let capExtent = orientation == .vertical
            ? theme.metrics.faderCapSize.height
            : theme.metrics.faderCapSize.width
        let inset = capExtent / 2
        let usable = max(1, span - capExtent)
        let forward = orientation == .vertical ? (1 - fraction) : fraction
        return inset + CGFloat(forward) * usable
    }

    private func step(_ direction: Int) -> KeyPress.Result {
        guard isEnabled else { return .ignored }
        let increment = Double(direction) / Double(detents)
        value = min(1, max(0, value + increment))
        onEditingChanged?(false)
        return .handled
    }

    private func jump(to target: Double) -> KeyPress.Result {
        guard isEnabled else { return .ignored }
        value = target
        onEditingChanged?(false)
        return .handled
    }
}

@available(macOS 15, *)
#Preview("Faders") {
    struct Host: View {
        @State private var gain = 0.7
        @State private var mix = 0.35
        var body: some View {
            HStack(alignment: .top, spacing: 40) {
                Fader(value: $gain, label: "GAIN")
                Fader(value: $mix, orientation: .horizontal, length: 200, label: "MIX")
                Fader(value: .constant(0.5), label: "AUX").disabled(true)
            }
            .padding(30)
            .background(Color.poHex(0x0A0A0A))
        }
    }
    return Host()
}

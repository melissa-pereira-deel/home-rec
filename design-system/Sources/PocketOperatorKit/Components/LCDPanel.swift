import SwiftUI

/// The framed display: a cut cavity, a phosphor substrate, and cover glass.
///
/// Content inside a panel does not need to be told what colour to be. The
/// panel publishes its ink and substrate into the environment, so a nested
/// `SegmentLCD`, level bar or waveform picks up the right phosphor — and,
/// critically, so `isInverted` flips *everything* on the screen at once, the
/// way a display driver actually inverts.
///
/// ```swift
/// LCDPanel(isInverted: justCommitted) {
///     HStack {
///         SegmentLCD(timecode, size: 30, capacity: 7, alignment: .trailing)
///         Spacer()
///         SegmentLCD("REC", size: 16).poBlink(isActive: isRecording)
///     }
/// }
/// ```
@available(macOS 15, *)
public struct LCDPanel<Content: View>: View {
    @Environment(\.poTheme) private var theme

    private let isInverted: Bool
    private let height: CGFloat?
    private let contentAlignment: Alignment
    private let accessibilityLabel: String?
    private let content: Content

    /// - Parameters:
    ///   - isInverted: Swaps ink and substrate. Held briefly to punctuate a
    ///     committed action; not a persistent mode.
    ///   - height: Cavity height. Defaults to the display token so several
    ///     panels on one device match.
    public init(
        isInverted: Bool = false,
        height: CGFloat? = nil,
        contentAlignment: Alignment = .leading,
        accessibilityLabel: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isInverted = isInverted
        self.height = height
        self.contentAlignment = contentAlignment
        self.accessibilityLabel = accessibilityLabel
        self.content = content()
    }

    public var body: some View {
        let colors = theme.colors
        let ink = isInverted ? colors.displayBed : colors.displayOn
        let bed = isInverted ? colors.displayOn : colors.displayBed
        let radius = theme.metrics.displayCorner

        content
            .environment(\.poDisplayInk, ink)
            .environment(\.poDisplayBed, bed)
            .padding(.horizontal, theme.metrics.spacing.section - 2)
            .padding(.vertical, theme.metrics.spacing.key)
            .frame(
                maxWidth: .infinity,
                minHeight: height ?? theme.metrics.displayHeight,
                maxHeight: height ?? theme.metrics.displayHeight,
                alignment: contentAlignment
            )
            .background(bed)
            .overlay(alignment: .top) {
                // Cover glass: a single soft sheen across the upper third.
                // Anything stronger reads as a gloss filter rather than as a
                // sheet of plastic over a screen.
                LinearGradient(
                    colors: [colors.displayGlass, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: (height ?? theme.metrics.displayHeight) * 0.4)
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .poBezel(corner: radius)
            .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
            .accessibilityElement(children: .contain)
            .poAccessibilityLabel(accessibilityLabel)
    }
}

/// The stepped level bar that lives inside a display.
///
/// Digital, not analogue: segments switch, there is no needle, and the value
/// is quantised to the number of segments the display physically has. Pair it
/// with a `VUMeter` only if the product genuinely has both — showing the same
/// signal twice in two idioms is a tell that neither was chosen deliberately.
@available(macOS 15, *)
public struct LCDLevelBar: View {
    @Environment(\.poTheme) private var theme
    @Environment(\.poDisplayInk) private var inheritedInk

    private let level: Double
    private let segments: Int
    private let peak: Double?
    private let accessibilityLabel: String?

    /// - Parameters:
    ///   - level: 0...1.
    ///   - peak: Optional held peak, drawn as a single lit segment above the
    ///     bar. A peak marker is how a stepped meter reports a transient the
    ///     bar itself is too coarse and too fast to show.
    public init(
        level: Double,
        segments: Int = 12,
        peak: Double? = nil,
        accessibilityLabel: String? = "Level"
    ) {
        self.level = level
        self.segments = segments
        self.peak = peak
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        let ink = inheritedInk ?? theme.colors.displayOn
        let lit = Int((min(1, max(0, level)) * Double(segments)).rounded(.down))
        let peakIndex = peak.map { Int((min(1, max(0, $0)) * Double(segments)).rounded(.down)) }
        let size = theme.metrics.levelBarSegmentSize

        HStack(spacing: theme.metrics.levelBarSpacing) {
            ForEach(0..<segments, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(ink.opacity(opacity(index: index, lit: lit, peak: peakIndex)))
                    .frame(width: size.width, height: size.height)
            }
        }
        .accessibilityElement()
        .poAccessibilityLabel(accessibilityLabel)
        .accessibilityValue(Text("\(Int((min(1, max(0, level)) * 100).rounded())) percent"))
    }

    private func opacity(index: Int, lit: Int, peak: Int?) -> Double {
        if index < lit { return 1 }
        if let peak, index == peak { return 0.7 }
        return theme.colors.displayOffOpacity + 0.02
    }
}

@available(macOS 15, *)
#Preview("LCD panel") {
    VStack(spacing: 16) {
        LCDPanel {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SegmentLCD("0:03.2", size: 30, capacity: 7, alignment: .trailing)
                    Spacer()
                    SegmentLCD("REC", size: 16)
                }
                LCDLevelBar(level: 0.62, peak: 0.81)
            }
        }
        LCDPanel(isInverted: true, height: 56) {
            SegmentLCD("SAVED", size: 22)
        }
    }
    .frame(width: 420)
    .padding(24)
    .background(Color.poHex(0x0A0A0A))
}

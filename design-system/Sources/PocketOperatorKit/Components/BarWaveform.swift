import SwiftUI

/// A bar-rendered signal envelope.
///
/// Bars rather than a filled curve, because a segmented readout is consistent
/// with the rest of the language — the same reason the level meter is stepped.
/// Bar width and spacing are fixed in points rather than derived from the
/// sample count, so the same data reads identically at thumbnail size and at
/// full width; it is the *number of bars* that changes, not their weight.
@available(macOS 15, *)
public struct BarWaveform: View {

    public enum Mode: Sendable, Equatable {
        /// Resample the whole envelope to fill the available width. For a
        /// finished, fixed-length signal.
        case fitted
        /// Show the most recent samples flush to the trailing edge. For a live
        /// capture, where the newest sample must always be in the same place.
        case trailing
    }

    @Environment(\.poTheme) private var theme
    @Environment(\.poDisplayInk) private var inheritedInk

    private let samples: [Float]
    private let mode: Mode
    private let progress: Double?
    private let tint: Color?
    private let dimOpacity: Double
    private let barWidth: CGFloat
    private let barSpacing: CGFloat
    private let accessibilityLabel: String?

    /// - Parameters:
    ///   - progress: 0...1 playback position. Bars before it draw at full
    ///     strength and a playhead line is added; `nil` dims every bar evenly.
    ///   - accessibilityLabel: A waveform is decorative unless it is the
    ///     control being operated. Supply a label only when it carries meaning
    ///     the surrounding text does not.
    public init(
        samples: [Float],
        mode: Mode = .fitted,
        progress: Double? = nil,
        tint: Color? = nil,
        dimOpacity: Double = 0.28,
        barWidth: CGFloat = 2,
        barSpacing: CGFloat = 1,
        accessibilityLabel: String? = nil
    ) {
        self.samples = samples
        self.mode = mode
        self.progress = progress
        self.tint = tint
        self.dimOpacity = dimOpacity
        self.barWidth = barWidth
        self.barSpacing = barSpacing
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        let color = tint ?? inheritedInk ?? theme.colors.displayOn
        Canvas(opaque: false) { context, size in
            guard !samples.isEmpty else { return }
            let pitch = barWidth + barSpacing
            let capacity = max(1, Int(size.width / pitch))

            var bars = Path()
            var playedBars = Path()

            switch mode {
            case .fitted:
                let playedCount = progress.map { Int(Double(capacity) * $0) }
                for index in 0..<capacity {
                    // Nearest-sample lookup rather than averaging: it keeps a
                    // thumbnail recognisably the same shape as the full-size
                    // render, which averaging visibly does not.
                    let sample = samples[min(samples.count - 1, index * samples.count / capacity)]
                    let rect = barRect(index: index, sample: sample, pitch: pitch, size: size)
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                    if let playedCount, index < playedCount {
                        playedBars.addPath(path)
                    } else {
                        bars.addPath(path)
                    }
                }
            case .trailing:
                let window = Array(samples.suffix(capacity))
                let offset = capacity - window.count
                for (index, sample) in window.enumerated() {
                    let rect = barRect(index: offset + index, sample: sample, pitch: pitch, size: size)
                    playedBars.addPath(Path(roundedRect: rect, cornerRadius: barWidth / 2))
                }
            }

            if !bars.isEmpty {
                context.fill(bars, with: .color(color.opacity(dimOpacity)))
            }
            if !playedBars.isEmpty {
                context.fill(playedBars, with: .color(color))
            }

            if let progress, mode == .fitted {
                let x = size.width * progress
                context.fill(
                    Path(CGRect(x: x - 0.5, y: 0, width: 1, height: size.height)),
                    with: .color(color)
                )
            }
        }
        .accessibilityElement()
        .poAccessibilityLabel(accessibilityLabel)
        .accessibilityHidden(accessibilityLabel == nil)
    }

    private func barRect(index: Int, sample: Float, pitch: CGFloat, size: CGSize) -> CGRect {
        // Floor of 2pt: a silent passage still has to read as signal that
        // exists and happens to be quiet, not as a gap in the recording.
        let height = max(2, CGFloat(sample) * size.height)
        return CGRect(
            x: CGFloat(index) * pitch,
            y: (size.height - height) / 2,
            width: barWidth,
            height: height
        )
    }
}

@available(macOS 15, *)
#Preview("Waveforms") {
    VStack(spacing: 20) {
        BarWaveform(samples: POSampleData.waveform(seed: 23), progress: 0.42, tint: .poHex(0xFF6600))
            .frame(width: 380, height: 70)
        BarWaveform(samples: POSampleData.waveform(seed: 41))
            .frame(width: 380, height: 40)
        BarWaveform(samples: POSampleData.waveform(seed: 5, count: 60), mode: .trailing)
            .frame(width: 380, height: 26)
    }
    .padding(30)
    .background(Color.poHex(0x0A0A0A))
}

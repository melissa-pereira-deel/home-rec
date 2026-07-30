import SwiftUI

/// Geometry for the waveform family. Defaults come from the theme; overrides
/// exist for the two places the density genuinely differs (a 60pt trace in the
/// recording bar can't use the same bar pitch as a 380pt player).
public struct GlassWaveformStyle: Equatable {
    public var barWidth: CGFloat?
    public var barSpacing: CGFloat?
    /// Opacity of the unplayed portion.
    public var dimOpacity: Double?
    public var showsPlayhead: Bool

    public init(
        barWidth: CGFloat? = nil,
        barSpacing: CGFloat? = nil,
        dimOpacity: Double? = nil,
        showsPlayhead: Bool = true
    ) {
        self.barWidth = barWidth
        self.barSpacing = barSpacing
        self.dimOpacity = dimOpacity
        self.showsPlayhead = showsPlayhead
    }

    public static let standard = GlassWaveformStyle()
    /// A take's identity thumbnail: no playhead, no progress, just the shape.
    public static let thumbnail = GlassWaveformStyle(showsPlayhead: false)
}

// MARK: - Static waveform

/// A rendered waveform: the played portion in full accent, the rest dimmed,
/// with an optional playhead.
///
/// One component covers the thumbnail and the player because they are the same
/// object at two sizes — a take's waveform is its *identity*, the way an album
/// cover is, and a 96pt thumbnail that doesn't match the 380pt player breaks
/// that recognition. Sampling is nearest-neighbour rather than averaged for
/// the same reason: averaging flattens a thumbnail into a grey sausage and
/// every take starts looking alike.
///
/// Drawn in a single `Canvas` — one draw call for hundreds of bars, and no
/// view identity churn while a capture streams in at 30fps.
public struct GlassWaveform: View {
    private let samples: [Float]
    private let progress: Double?
    private let style: GlassWaveformStyle
    private let tintRole: GlassColorRole

    @Environment(\.glassTheme) private var theme

    public init(
        samples: [Float],
        progress: Double? = nil,
        style: GlassWaveformStyle = .standard,
        tint: GlassColorRole = .accent
    ) {
        self.samples = samples
        self.progress = progress
        self.style = style
        self.tintRole = tint
    }

    public var body: some View {
        let tint = theme.colors[tintRole]
        let barWidth = style.barWidth ?? theme.metrics.waveformBarWidth
        let pitch = barWidth + (style.barSpacing ?? theme.metrics.waveformBarSpacing)
        let dim = style.dimOpacity ?? theme.metrics.waveformDimOpacity

        Canvas(opaque: false) { context, size in
            guard !samples.isEmpty, pitch > 0 else { return }
            let count = max(1, Int(size.width / pitch))
            let playedBars = progress.map { Int(Double(count) * $0.clampedToUnitInterval) }

            for index in 0..<count {
                let sample = samples[min(samples.count - 1, index * samples.count / count)]
                // Floor of 2pt: silence is still signal. A zero-height bar
                // reads as a gap in the file rather than a quiet passage.
                let height = max(2, CGFloat(sample) * size.height)
                let rect = CGRect(
                    x: CGFloat(index) * pitch,
                    y: (size.height - height) / 2,
                    width: barWidth,
                    height: height
                )
                let isPlayed = playedBars.map { index < $0 } ?? false
                context.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 2),
                    with: .color(isPlayed ? tint : tint.opacity(dim))
                )
            }

            if let progress, style.showsPlayhead {
                let x = size.width * progress.clampedToUnitInterval
                context.fill(
                    Path(CGRect(x: x - 0.5, y: 0, width: 1, height: size.height)),
                    with: .color(tint)
                )
            }
        }
        // A waveform carries no information a screen reader can use; the
        // duration and position next to it do. Exposing it produces a stop
        // that says "image" and nothing else.
        .accessibilityHidden(true)
    }
}

// MARK: - Live waveform

/// The live capture trace: newest samples at the trailing edge, older ones
/// scrolling off the left.
///
/// Separate from `GlassWaveform` rather than a flag on it, because the two
/// answer different questions — "what does this take look like" versus "is
/// audio arriving right now". The live variant has no progress, no playhead
/// and no dim: every bar is current.
public struct GlassLiveWaveform: View {
    private let samples: [Float]
    private let style: GlassWaveformStyle
    private let tintRole: GlassColorRole
    private let opacity: Double

    @Environment(\.glassTheme) private var theme

    public init(
        samples: [Float],
        style: GlassWaveformStyle = .standard,
        tint: GlassColorRole = .accent,
        opacity: Double = 1
    ) {
        self.samples = samples
        self.style = style
        self.tintRole = tint
        self.opacity = opacity
    }

    public var body: some View {
        let tint = theme.colors[tintRole].opacity(opacity)
        let barWidth = style.barWidth ?? theme.metrics.waveformBarWidth
        let pitch = barWidth + (style.barSpacing ?? theme.metrics.waveformBarSpacing)

        Canvas(opaque: false) { context, size in
            guard !samples.isEmpty, pitch > 0 else { return }
            let count = max(1, Int(size.width / pitch))
            // Trailing window of the ring buffer: a capture shorter than the
            // view starts at the left and grows rightward, rather than
            // stretching four samples across the whole width.
            let window = Array(samples.suffix(count))
            let offset = count - window.count

            for (index, sample) in window.enumerated() {
                let height = max(2, CGFloat(sample) * size.height)
                let rect = CGRect(
                    x: CGFloat(offset + index) * pitch,
                    y: (size.height - height) / 2,
                    width: barWidth,
                    height: height
                )
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(tint))
            }
        }
        .accessibilityHidden(true)
    }
}

public extension GlassWaveform {
    /// The idle trace: a flat dotted line at the vertical centre.
    ///
    /// Not an empty view, and **not** a dead flat line during `stopping`
    /// either — an idle recorder should look like an instrument at rest, not
    /// like a broken one. The 5% floor is what produces the dotted rule you
    /// see on the idle face.
    static func idleSamples(count: Int = 96) -> [Float] {
        Array(repeating: 0.05, count: count)
    }
}

#Preview("Waveforms") {
    GlassPreviewStage {
        VStack(alignment: .leading, spacing: GlassSpacing.l) {
            GlassMetaLabel("player · progress 0.42")
            GlassWaveform(samples: GlassSampleWaveforms.identity(seed: 23), progress: 0.42)
                .frame(height: 72)
            GlassMetaLabel("thumbnail")
            GlassWaveform(
                samples: GlassSampleWaveforms.identity(seed: 41),
                style: .thumbnail,
                tint: .textPrimary
            )
            .frame(width: 96, height: 28)
            GlassMetaLabel("live")
            GlassLiveWaveform(samples: GlassSampleWaveforms.live(count: 60))
                .frame(height: 44)
            GlassMetaLabel("idle")
            GlassWaveform(samples: GlassWaveform.idleSamples(), style: .thumbnail, tint: .textPrimary)
                .frame(height: 44)
        }
    }
}

import SwiftUI

/// The untitled.stream waveform: rounded bars, played portion in accent,
/// unplayed dimmed, optional playhead line. Doubles as the identity thumbnail
/// (progress 0, small frame) and the player scrubber (large frame).
struct BarWaveform: View {
    var samples: [Float]
    var accent: Color
    /// 0...1 playback progress; nil = no playhead, all bars dimmed evenly.
    var progress: Double?
    var dimOpacity: Double = 0.28
    var barWidth: CGFloat = 2
    var barSpacing: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            guard !samples.isEmpty else { return }
            let pitch = barWidth + barSpacing
            let count = max(1, Int(size.width / pitch))
            let playedBars = progress.map { Int(Double(count) * $0) }

            for i in 0..<count {
                // Nearest-sample lookup keeps thumbnails faithful at any width.
                let sample = samples[min(samples.count - 1, i * samples.count / count)]
                let h = max(2, CGFloat(sample) * size.height)
                let rect = CGRect(
                    x: CGFloat(i) * pitch,
                    y: (size.height - h) / 2,
                    width: barWidth,
                    height: h
                )
                let isPlayed = playedBars.map { i < $0 } ?? false
                context.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 2),
                    with: .color(isPlayed ? accent : accent.opacity(dimOpacity))
                )
            }

            // Playhead line.
            if let progress {
                let x = size.width * progress
                context.fill(
                    Path(CGRect(x: x - 0.5, y: 0, width: 1, height: size.height)),
                    with: .color(accent)
                )
            }
        }
    }
}

/// Live variant: renders the store's rolling `liveSamples` ring with newest
/// samples at the trailing edge — the classic scrolling capture view.
struct LiveWaveform: View {
    var samples: [Float]
    var accent: Color
    var barWidth: CGFloat = 2
    var barSpacing: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            guard !samples.isEmpty else { return }
            let pitch = barWidth + barSpacing
            let count = max(1, Int(size.width / pitch))
            // Trailing window of the ring buffer.
            let window = Array(samples.suffix(count))
            let offset = count - window.count
            for (i, sample) in window.enumerated() {
                let h = max(2, CGFloat(sample) * size.height)
                let rect = CGRect(
                    x: CGFloat(offset + i) * pitch,
                    y: (size.height - h) / 2,
                    width: barWidth,
                    height: h
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 2),
                    with: .color(accent)
                )
            }
        }
    }
}

#Preview("Waveforms") {
    VStack(spacing: 20) {
        BarWaveform(
            samples: WaveformFactory.identity(seed: 23),
            accent: Color(red: 1.0, green: 0.24, blue: 0.24),
            progress: 0.42
        )
        .frame(width: 380, height: 80)

        BarWaveform(
            samples: WaveformFactory.identity(seed: 41),
            accent: .white,
            progress: nil
        )
        .frame(width: 96, height: 28)
    }
    .padding(30)
    .background(Color.black)
}

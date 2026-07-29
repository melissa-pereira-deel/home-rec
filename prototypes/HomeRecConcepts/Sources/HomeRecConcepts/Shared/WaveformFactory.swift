import Foundation

/// Seeded waveform generation: every fake recording gets a stable "identity"
/// waveform (untitled.stream's waveform-as-thumbnail idea), and a live take's
/// history downsamples into the same shape on save.
enum WaveformFactory {
    static let barCount = 96

    /// Stable identity waveform for a recording seed — a bounded random walk
    /// with speech-like burst envelopes.
    static func identity(seed: UInt64, bars: Int = barCount) -> [Float] {
        var samples: [Float] = []
        samples.reserveCapacity(bars)
        var walk = 0.4 + 0.3 * LevelSynth.rand(seed)
        for i in 0..<bars {
            let n = LevelSynth.rand(seed &+ UInt64(i) &* 6364136223846793005)
            // Envelope: slow noise gives phrase-level swells.
            let envelope = 0.3 + 0.7 * LevelSynth.valueNoise(Double(i) * 0.13 + Double(seed % 977))
            walk += (n - 0.5) * 0.35
            walk = min(1, max(0.06, walk))
            samples.append(Float(walk * envelope))
        }
        return samples
    }

    /// Downsample a live-capture history into an identity waveform by peaking
    /// over equal windows, so the saved thumbnail matches what was watched.
    static func downsample(_ history: [Float], to bars: Int = barCount) -> [Float] {
        guard history.count > bars else {
            return history.isEmpty ? identity(seed: 1) : padded(history, to: bars)
        }
        let window = Double(history.count) / Double(bars)
        return (0..<bars).map { i in
            let lo = Int(Double(i) * window)
            let hi = min(history.count, Int(Double(i + 1) * window))
            return history[lo..<max(lo + 1, hi)].max() ?? 0
        }
    }

    private static func padded(_ samples: [Float], to bars: Int) -> [Float] {
        samples + Array(repeating: 0.06, count: bars - samples.count)
    }
}

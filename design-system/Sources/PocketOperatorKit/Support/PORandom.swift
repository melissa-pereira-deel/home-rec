import Foundation

/// Deterministic hashing for procedural surfaces and demo data.
///
/// Textures must be reproducible: the same panel has to look identical on
/// every launch and in every snapshot, or the "moulded finish" reads as
/// television static. A seeded hash gives that for free without carrying a
/// generator's mutable state through drawing code.
public enum PORandom {
    /// Odd 64-bit constant near 2^64/φ, used to advance a seed with good
    /// avalanche between successive integers.
    public static let goldenGamma: UInt64 = 0x9E37_79B9_7F4A_7C15

    /// SplitMix64 finaliser mapped to 0...1.
    public static func unitValue(_ seed: UInt64) -> Double {
        var z = seed &+ goldenGamma
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }

    /// Cosine-interpolated 1-D value noise in 0...1.
    public static func valueNoise(_ x: Double) -> Double {
        let i = floor(x)
        let f = x - i
        let a = unitValue(UInt64(bitPattern: Int64(i)) &* 2_654_435_761)
        let b = unitValue(UInt64(bitPattern: Int64(i + 1)) &* 2_654_435_761)
        let u = (1 - cos(f * .pi)) / 2
        return a * (1 - u) + b * u
    }
}

/// Reproducible sample data for previews, galleries and layout work.
///
/// Shipped as public because building a device face without plausible signal
/// in the meters and waveforms gives a misleading impression of the design.
/// Not intended for production content.
public enum POSampleData {

    /// A waveform envelope with speech-like bursts and gaps.
    public static func waveform(seed: UInt64 = 23, count: Int = 160) -> [Float] {
        (0..<count).map { i in
            let t = Double(i) / 8
            let burst = PORandom.valueNoise(t * 0.6 + Double(seed))
            let detail = PORandom.valueNoise(t * 5.5 + Double(seed) * 3)
            let envelope = max(0, burst - 0.25) / 0.75
            return Float(min(1, 0.06 + envelope * (0.35 + 0.65 * detail)))
        }
    }

    /// A level in 0...1 that moves the way programme material moves, so meter
    /// ballistics can be judged. Pure in `t`, so it replays identically.
    public static func level(at t: TimeInterval, seed: UInt64 = 11) -> Double {
        let gate = PORandom.valueNoise(t * 0.8 + Double(seed))
        let body = PORandom.valueNoise(t * 3.1 + Double(seed) * 2)
        let transient = PORandom.valueNoise(t * 17 + Double(seed) * 5)
        guard gate > 0.42 else { return 0.03 + 0.02 * transient }
        return min(1, 0.2 + 0.6 * body + 0.2 * transient)
    }
}

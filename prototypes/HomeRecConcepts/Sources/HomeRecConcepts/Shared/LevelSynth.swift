import Foundation

/// Deterministic speech-like level envelope: alternating bursts and gaps with
/// value-noise amplitude. Pure in `t`, so the same "recording" replays
/// identically wherever the scrubber lands.
enum LevelSynth {
    /// Level in 0...1 at time `t` (seconds since recording start).
    static func level(at t: TimeInterval) -> Float {
        // Burst/gap gating: walk a seeded schedule until we find the segment
        // containing t. Segments are short enough that this stays trivial.
        var cursor: TimeInterval = 0
        var index: UInt64 = 0
        while cursor < t + 4 {
            let isBurst = index.isMultiple(of: 2)
            let duration = isBurst
                ? 0.4 + 1.4 * rand(index &* 7919 &+ 17)      // bursts 0.4–1.8s
                : 0.2 + 0.4 * rand(index &* 104729 &+ 3)     // gaps 0.2–0.6s
            if t < cursor + duration {
                guard isBurst else { return floorLevel(at: t) }
                // Amplitude drifts inside the burst; edges ramp in/out.
                let base = 0.25 + 0.65 * valueNoise(t * 3.1)
                let edge = min(1, min(t - cursor, cursor + duration - t) / 0.09)
                let jitter = 1 + 0.1 * (valueNoise(t * 23.7) * 2 - 1)
                return Float(max(0, base * Double(edge) * jitter))
            }
            cursor += duration
            index += 1
        }
        return floorLevel(at: t)
    }

    /// Room tone during gaps — never dead silence, meters should breathe.
    private static func floorLevel(at t: TimeInterval) -> Float {
        Float(0.03 + 0.02 * valueNoise(t * 11))
    }

    /// Smooth 1-D value noise in 0...1 (cosine-interpolated lattice).
    static func valueNoise(_ x: Double) -> Double {
        let i = floor(x)
        let f = x - i
        let a = rand(UInt64(bitPattern: Int64(i)) &* 2654435761)
        let b = rand(UInt64(bitPattern: Int64(i + 1)) &* 2654435761)
        let u = (1 - cos(f * .pi)) / 2
        return a * (1 - u) + b * u
    }

    /// Cheap deterministic hash → 0...1.
    static func rand(_ seed: UInt64) -> Double {
        var z = seed &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
}

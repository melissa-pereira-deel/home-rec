import Foundation

// Sample data for the gallery and previews only.
//
// Deliberately `internal`: the kit must never ship fake recordings as public
// API. A host that wants placeholder content owns that decision — and the
// moment sample data is public, it shows up in a shipping build.

/// Deterministic waveform generation. Seeded so a specimen sheet renders
/// identically every time — a gallery whose waveforms reshuffle on each launch
/// is useless for spotting a rendering regression.
enum GlassSampleWaveforms {

    /// A take's identity waveform: an attack, a body with dynamics, a decay.
    static func identity(seed: UInt64, count: Int = 96) -> [Float] {
        var rng = SplitMix64(seed: seed)
        return (0..<count).map { index in
            let position = Double(index) / Double(max(1, count - 1))
            // Envelope: quick attack, long plateau, gentle release.
            let attack = min(1, position / 0.06)
            let release = min(1, (1 - position) / 0.12)
            let envelope = min(attack, release)
            // Two slow oscillations give the body some phrasing, so the shape
            // reads as music rather than as noise.
            let phrasing = 0.55 + 0.25 * sin(position * .pi * 3.1) + 0.2 * sin(position * .pi * 7.7)
            let jitter = 0.65 + 0.35 * rng.nextUnit()
            return Float(max(0.04, min(1, envelope * phrasing * jitter)))
        }
    }

    /// A live capture ring: newest sample last.
    static func live(count: Int, seed: UInt64 = 7) -> [Float] {
        var rng = SplitMix64(seed: seed)
        return (0..<count).map { index in
            let position = Double(index) / Double(max(1, count))
            let swell = 0.35 + 0.45 * abs(sin(position * .pi * 2.3))
            return Float(max(0.05, min(1, swell * (0.6 + 0.6 * rng.nextUnit()))))
        }
    }
}

/// Sample takes covering the shapes a real library throws at the row: a long
/// name, a version stack, an hour-plus duration, a sub-minute duration.
enum GlassSampleTakes {
    static let all: [GlassTakeSummary] = [
        GlassTakeSummary(
            id: "1",
            title: "kitchen radio, morning",
            metadata: "48kHz · 16-bit · wav · 26.4MB",
            duration: 154,
            timestamp: "2h",
            waveform: GlassSampleWaveforms.identity(seed: 23)
        ),
        GlassTakeSummary(
            id: "2",
            title: "chorus idea — take 3",
            metadata: "48kHz · 24-bit · flac · 9.8MB",
            duration: 41,
            timestamp: "21h",
            waveform: GlassSampleWaveforms.identity(seed: 41)
        ),
        GlassTakeSummary(
            id: "3",
            title: "voice memo 14",
            metadata: "48kHz · 16-bit · m4a · 0.7MB",
            duration: 19,
            timestamp: "1d",
            waveform: GlassSampleWaveforms.identity(seed: 77)
        ),
        GlassTakeSummary(
            id: "4",
            title: "band practice (rough)",
            metadata: "48kHz · 24-bit · flac · 612MB",
            duration: 4323,
            timestamp: "1w",
            waveform: GlassSampleWaveforms.identity(seed: 91)
        ),
        GlassTakeSummary(
            id: "5",
            title: "a name long enough to need truncating in the row",
            metadata: "48kHz · 16-bit · wav · 105MB",
            duration: 612,
            timestamp: "3d",
            waveform: GlassSampleWaveforms.identity(seed: 13)
        ),
    ]
}

/// SplitMix64 — small, fast, and identical on every platform, which is what
/// "deterministic" has to mean for a specimen sheet.
private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 0x9E37_79B9_7F4A_7C15 &+ 0x1234_5678_9ABC_DEF0
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in 0…1.
    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}

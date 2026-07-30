import Foundation

/// A recording that never happened. Carries everything the library UI needs:
/// identity waveform, spec strings, version stack, and both naming registers
/// (poetic concept names and the shipping filename scheme).
struct FakeRecording: Identifiable {
    let id: UUID
    var name: String            // lowercase, untitled.stream voice
    var fileName: String        // shipping scheme: recording_yyyy-MM-dd_HH-mm-ss
    var date: Date
    var duration: TimeInterval
    var format: FakeFormat
    var sampleRate: String      // "48kHz"
    var bitDepth: String        // "16-bit"
    var fileSize: String        // "18.2MB"
    var samples: [Float]        // identity waveform, WaveformFactory.barCount bars

    /// SF Mono metadata line: "48kHz · 16-bit · wav · 18.2MB"
    var specLine: String {
        "\(sampleRate) · \(bitDepth) · \(format.rawValue) · \(fileSize)"
    }
}

/// Mirrors the shipping app's `AudioFormat.available` (wav/m4a/flac).
enum FakeFormat: String, CaseIterable {
    case wav, m4a, flac
}

enum FakeLibrary {
    /// Deterministic library for a seed size. IDs are seed-derived (stable
    /// across runs) so snapshots and selections are reproducible.
    static func seeded(_ seed: LibrarySeed, now: Date) -> [FakeRecording] {
        switch seed {
        case .empty: []
        case .three: Array(cannedEight(now: now).prefix(3))
        case .eight: cannedEight(now: now)
        case .fifty: cannedEight(now: now) + generated(count: 42, now: now)
        }
    }

    /// Stable UUID from a numeric seed — reproducible identity.
    static func stableID(_ seed: UInt64) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012llu", seed))!
    }

    private static func make(
        _ name: String, daysAgo: Double, duration: TimeInterval,
        format: FakeFormat, bitDepth: String, size: String,
        seed: UInt64, now: Date
    ) -> FakeRecording {
        let date = now.addingTimeInterval(-daysAgo * 86_400)
        return FakeRecording(
            id: stableID(seed),
            name: name,
            fileName: Formatters.recordingName(at: date),
            date: date,
            duration: duration,
            format: format,
            sampleRate: "48kHz",
            bitDepth: bitDepth,
            fileSize: size,
            samples: WaveformFactory.identity(seed: seed)
        )
    }

    /// The original eight, lowercase voice, dates spread over ~3 weeks.
    private static func cannedEight(now: Date) -> [FakeRecording] {
        [
            make("kitchen radio, morning", daysAgo: 0.12, duration: 154, format: .wav, bitDepth: "16-bit", size: "26.4MB", seed: 11, now: now),
            make("chorus idea — take 3", daysAgo: 0.9, duration: 41, format: .flac, bitDepth: "24-bit", size: "9.8MB", seed: 23, now: now),
            make("voice memo 14", daysAgo: 1.4, duration: 19, format: .m4a, bitDepth: "16-bit", size: "0.7MB", seed: 37, now: now),
            make("rain on the skylight", daysAgo: 3.2, duration: 612, format: .wav, bitDepth: "16-bit", size: "105MB", seed: 41, now: now),
            make("untitled", daysAgo: 5.8, duration: 8, format: .m4a, bitDepth: "16-bit", size: "0.3MB", seed: 53, now: now),
            make("band practice (rough)", daysAgo: 9.1, duration: 4_323, format: .flac, bitDepth: "24-bit", size: "612MB", seed: 67, now: now),
            make("dad's records, side b", daysAgo: 14.6, duration: 1_260, format: .wav, bitDepth: "16-bit", size: "216MB", seed: 71, now: now),
            make("synth drone experiment", daysAgo: 20.3, duration: 347, format: .flac, bitDepth: "24-bit", size: "49.1MB", seed: 89, now: now),
        ]
    }

    /// Bulk takes for the 50-item stress seed: durations 4s–4h, formats
    /// cycling, dates spread over ~5 months, a few deep version stacks.
    private static func generated(count: Int, now: Date) -> [FakeRecording] {
        let baseNames = [
            "field notes", "practice loop", "call with sam", "street sounds",
            "piano sketch", "radio grab", "rehearsal", "late night idea",
        ]
        return (0..<count).map { i in
            let seed = UInt64(1000 + i * 13)
            let r = LevelSynth.rand(seed)
            let duration = TimeInterval(4 + r * r * 14_396)   // skew short, up to ~4h
            let format = FakeFormat.allCases[i % FakeFormat.allCases.count]
            let daysAgo = 21 + Double(i) * 3.1 + r * 2
            let megabytes = duration * (format == .flac ? 0.14 : 0.19)
            return make(
                "\(baseNames[i % baseNames.count]) \(i / baseNames.count + 1)",
                daysAgo: daysAgo,
                duration: duration,
                format: format,
                bitDepth: format == .flac ? "24-bit" : "16-bit",
                size: megabytes < 1
                    ? String(format: "%.0fKB", megabytes * 1024)
                    : String(format: "%.1fMB", megabytes),
                seed: seed,
                now: now
            )
        }
    }
}

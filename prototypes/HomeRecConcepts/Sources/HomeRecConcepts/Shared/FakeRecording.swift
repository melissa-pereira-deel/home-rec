import Foundation

/// A recording that never happened. Carries everything the library UI needs:
/// identity waveform, spec strings, version stack.
struct FakeRecording: Identifiable {
    let id: UUID
    var name: String            // lowercase, untitled.stream voice
    var date: Date
    var duration: TimeInterval
    var format: FakeFormat
    var sampleRate: String      // "48kHz"
    var bitDepth: String        // "16-bit"
    var fileSize: String        // "18.2MB"
    var samples: [Float]        // identity waveform, WaveformFactory.barCount bars
    var versionCount: Int       // 1 = no stack

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
    /// Eight canned recordings, dates spread over ~3 weeks, formats varied,
    /// names in the lowercase intimate voice. `now` injected for determinism.
    static func canned(now: Date = .now) -> [FakeRecording] {
        func rec(
            _ name: String, daysAgo: Double, duration: TimeInterval,
            format: FakeFormat, bitDepth: String, size: String,
            seed: UInt64, versions: Int = 1
        ) -> FakeRecording {
            FakeRecording(
                id: UUID(),
                name: name,
                date: now.addingTimeInterval(-daysAgo * 86_400),
                duration: duration,
                format: format,
                sampleRate: "48kHz",
                bitDepth: bitDepth,
                fileSize: size,
                samples: WaveformFactory.identity(seed: seed),
                versionCount: versions
            )
        }
        return [
            rec("kitchen radio, morning", daysAgo: 0.12, duration: 154, format: .wav, bitDepth: "16-bit", size: "26.4MB", seed: 11),
            rec("chorus idea — take 3", daysAgo: 0.9, duration: 41, format: .flac, bitDepth: "24-bit", size: "9.8MB", seed: 23, versions: 3),
            rec("voice memo 14", daysAgo: 1.4, duration: 19, format: .m4a, bitDepth: "16-bit", size: "0.7MB", seed: 37),
            rec("rain on the skylight", daysAgo: 3.2, duration: 612, format: .wav, bitDepth: "16-bit", size: "105MB", seed: 41),
            rec("untitled", daysAgo: 5.8, duration: 8, format: .m4a, bitDepth: "16-bit", size: "0.3MB", seed: 53),
            rec("band practice (rough)", daysAgo: 9.1, duration: 4_323, format: .flac, bitDepth: "24-bit", size: "612MB", seed: 67, versions: 2),
            rec("dad's records, side b", daysAgo: 14.6, duration: 1_260, format: .wav, bitDepth: "16-bit", size: "216MB", seed: 71),
            rec("synth drone experiment", daysAgo: 20.3, duration: 347, format: .flac, bitDepth: "24-bit", size: "49.1MB", seed: 89),
        ]
    }
}

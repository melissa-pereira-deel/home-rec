import Foundation

enum Formatters {
    /// "0:07.4" under a minute-with-tenths feel; "12:07" past it; "1:12:03" past an hour.
    /// The tenths variant is what LCD/counter displays want while recording.
    static func timecode(_ t: TimeInterval, tenths: Bool = false) -> String {
        let total = Int(t)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        if tenths {
            let frac = Int((t - floor(t)) * 10)
            return String(format: "%d:%02d.%d", m, s, frac)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// Timecode with a format pinned to the recording's total duration, so a
    /// moving playhead label never changes width (no jump at 0:59.9 → 1:00,
    /// hours stay h:mm:ss from the first frame).
    static func timecode(_ t: TimeInterval, matching duration: TimeInterval) -> String {
        let total = Int(t)
        if duration >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        if duration < 60 {
            let frac = Int((t - floor(t)) * 10)
            return String(format: "%d:%02d.%d", total / 60, total % 60, frac)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Relative date in the quiet untitled voice: "2h", "3d", "2w".
    static func relative(_ date: Date, now: Date = .now) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<3600: return "\(max(1, Int(seconds / 60)))m"
        case ..<86_400: return "\(Int(seconds / 3600))h"
        case ..<604_800: return "\(Int(seconds / 86_400))d"
        default: return "\(Int(seconds / 604_800))w"
        }
    }

    /// Filenames in the shipping app's scheme, for saved beats.
    static func recordingName(at date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "recording_\(formatter.string(from: date))"
    }
}

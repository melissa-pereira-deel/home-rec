import Foundation

/// Library filter, store-held so it survives screen switches. Chips derive
/// from the full format set (every shipping format gets a chip).
enum LibraryFilter: Equatable {
    case all
    case format(FakeFormat)
    case thisWeek

    var label: String {
        switch self {
        case .all: "all"
        case .format(let format): format.rawValue
        case .thisWeek: "this week"
        }
    }

    /// `now` injected — snapshot determinism forbids `Date.now` in predicates.
    func matches(_ recording: FakeRecording, now: Date) -> Bool {
        switch self {
        case .all: true
        case .format(let format): recording.format == format
        case .thisWeek: recording.date > now.addingTimeInterval(-7 * 86_400)
        }
    }

    static var chips: [LibraryFilter] {
        [.all] + FakeFormat.allCases.map { .format($0) } + [.thisWeek]
    }
}

/// Library stress seeds: how many takes the fake library holds.
enum LibrarySeed: Int, CaseIterable {
    case empty = 0
    case three = 3
    case eight = 8
    case fifty = 50
}

/// Mirrors shipping `PermissionStatus` (PermissionManager.swift:15).
enum FakePermissionStatus {
    case notDetermined
    case denied
    case granted
}

/// Mirrors shipping `RecorderError` — messages and recovery labels are
/// VERBATIM from HomeRec/HomeRec/RecordingState.swift:34-76. The spec's
/// contract is zero copy changes.
enum FakeRecorderError: CaseIterable, Equatable {
    case startFailed
    case stopFailed
    case streamFailed
    case diskFull
    case saveLocationUnavailable

    var message: String {
        switch self {
        case .startFailed:
            "Home Rec couldn't start recording. Make sure some audio is playing, then try again."
        case .stopFailed:
            "Home Rec couldn't finish saving the recording. The audio captured so far may still be on your Desktop."
        case .streamFailed:
            "Recording stopped unexpectedly. This usually means Screen Recording permission was turned off, or another app took over audio capture."
        case .diskFull:
            "There isn't enough free space to start recording. Free up some disk space and try again."
        case .saveLocationUnavailable:
            "Your chosen save folder isn't available, so this recording is going to your Desktop instead."
        }
    }

    var recoveryLabel: String? {
        switch self {
        case .startFailed: "Try again"
        case .streamFailed: "Open settings"
        case .saveLocationUnavailable: "Choose folder…"
        case .stopFailed, .diskFull: nil
        }
    }
}

/// Simulated save-location model: three fake folders, custom/unavailable
/// states, mirroring the shipping keep-and-warn fallback behavior.
struct SaveLocationSim: Equatable {
    var folders = ["Desktop", "Recordings", "Field Notes"]
    var index = 0
    var isUnavailable = false

    var isCustom: Bool { index != 0 }
    var name: String { folders[index] }
}

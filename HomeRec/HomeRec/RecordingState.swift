//
//  RecordingState.swift
//  HomeRec
//
//  Single source of truth for the recording lifecycle. The view model owns
//  one RecordingState and the UI derives entirely from it, so "UI says
//  recording while nothing is written" is no longer representable.
//

import Foundation

/// A recoverable failure surfaced to the user during recording.
enum RecorderError: Error, Equatable, Sendable {
    case startFailed(String)
    case stopFailed(String)
    case streamFailed(String)
    case diskFull
    case saveLocationUnavailable

    /// The underlying technical detail (e.g. a system error description).
    /// Retained for logs/diagnostics — never shown directly to the user.
    nonisolated var detail: String {
        switch self {
        case .startFailed(let detail), .stopFailed(let detail), .streamFailed(let detail):
            return detail
        case .diskFull:
            return "insufficient free disk space"
        case .saveLocationUnavailable:
            return "configured save folder is missing or unwritable"
        }
    }

    /// Plain-language, non-technical message shown to the user.
    nonisolated var message: String {
        switch self {
        case .startFailed:
            return "Home Rec couldn't start recording. Make sure some audio is playing, then try again."
        case .stopFailed:
            return "Home Rec couldn't finish saving the recording. The audio captured so far may still be on your Desktop."
        case .streamFailed:
            return "Recording stopped unexpectedly. This usually means Screen Recording permission was turned off, or another app took over audio capture."
        case .diskFull:
            return "There isn't enough free space to start recording. Free up some disk space and try again."
        case .saveLocationUnavailable:
            return "Your chosen save folder isn't available, so this recording is going to your Desktop instead."
        }
    }

    /// A suggested next step the user can take, if any.
    nonisolated var recovery: RecoverySuggestion? {
        switch self {
        case .startFailed:
            return .tryAgain
        case .streamFailed:
            return .openSettings
        case .saveLocationUnavailable:
            return .chooseFolder
        case .stopFailed, .diskFull:
            return nil
        }
    }
}

/// A concrete recovery action offered alongside an error.
enum RecoverySuggestion: Equatable, Sendable {
    case openSettings
    case tryAgain
    case chooseFolder

    nonisolated var label: String {
        switch self {
        case .openSettings: return "Open settings"
        case .tryAgain: return "Try again"
        case .chooseFolder: return "Choose folder…"
        }
    }
}

/// The lifecycle states of a recording session.
enum RecordingState: Equatable, Sendable {
    case idle
    case starting
    case recording
    case stopping
    case error(RecorderError)
    case recovering

    /// Whether moving to `next` is a legal transition from `self`.
    /// Illegal transitions (e.g. `idle → stopping`) return `false`.
    nonisolated func canTransition(to next: RecordingState) -> Bool {
        switch (self, next) {
        case (.idle, .starting):
            return true
        case (.starting, .recording),
             (.starting, .error),
             (.starting, .idle):
            return true
        case (.recording, .stopping),
             (.recording, .error),
             (.recording, .recovering):
            return true
        case (.stopping, .idle),
             (.stopping, .error):
            return true
        case (.error, .idle),
             (.error, .starting):
            return true
        case (.recovering, .recording),
             (.recovering, .stopping),
             (.recovering, .error):
            return true
        default:
            return false
        }
    }
}

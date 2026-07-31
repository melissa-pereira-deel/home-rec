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
    /// The chosen capture source can't be captured right now — the app quit, or
    /// the microphone was unplugged (BL-100/BL-130).
    ///
    /// Carries the source error rather than its string: `AudioSourceError`
    /// already writes accurate, specific copy for both cases, and flattening it
    /// into `.startFailed` discarded that and replaced it with "make sure some
    /// audio is playing" — advice that cannot work for either cause.
    case sourceUnavailable(AudioSourceError)
    /// Microphone access was refused (BL-130).
    ///
    /// Distinct from `.startFailed` because the recovery differs and getting it
    /// wrong strands the user: once denied, `AVCaptureDevice.requestAccess`
    /// returns false **immediately and without prompting**, so offering "try
    /// again" here is an infinite loop. Settings is the only way out.
    case microphoneDenied
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
        case .sourceUnavailable(let error):
            return error.errorDescription ?? "capture source unavailable"
        case .microphoneDenied:
            return "microphone access denied"
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
        case .sourceUnavailable(let error):
            // Already written for the specific cause — the app that quit, or the
            // microphone that was unplugged.
            return error.errorDescription ?? "The capture source you chose isn't available."
        case .microphoneDenied:
            return "Home Rec doesn't have permission to use the microphone."
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
        case .sourceUnavailable:
            // Deliberately not `.tryAgain`: the app is still closed and the mic is
            // still unplugged, so retrying fails identically. The fix is to change
            // the source, which lives in the menu.
            return nil
        case .microphoneDenied:
            return .openMicrophoneSettings
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
    /// Opens the Microphone pane specifically. Separate from `.openSettings`,
    /// which goes to Screen Recording — sending someone to the wrong pane is
    /// the failure BL-081 existed to fix.
    case openMicrophoneSettings
    case tryAgain
    case chooseFolder

    nonisolated var label: String {
        switch self {
        case .openSettings:           return "Open settings"
        case .openMicrophoneSettings: return "Open settings"
        case .tryAgain:               return "Try again"
        case .chooseFolder:           return "Choose folder…"
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

    /// Whether the user may change the capture source right now (BL-111).
    ///
    /// `.error` is deliberately **true**: changing the source is one of the ways
    /// a user fixes an error (the selected app quit, a mic was unplugged), so
    /// locking them out of it there would strand them.
    ///
    /// ⚠️ Written as an exhaustive switch with **no `default`** on purpose —
    /// unlike `canTransition` below, which has one. A new state (BL-132's
    /// `.paused`) must become a compile error here so someone decides, rather
    /// than silently inheriting "false". Do not copy the escape hatch up.
    nonisolated var allowsCaptureSourceChange: Bool {
        switch self {
        case .idle, .error:
            return true
        case .starting, .recording, .stopping, .recovering:
            return false
        }
    }

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

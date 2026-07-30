import Foundation

/// Events that can move the transport.
///
/// Split into *user intent* (`primaryPressed`) and *world facts* (the rest).
/// The distinction matters: a press is a request, and the machine decides
/// whether it becomes a state change, but "the capture stream opened" is not
/// negotiable and must always be reflected.
public enum GlassTransportEvent: Hashable, Sendable {
    /// The primary control was pressed. What it means depends on the state —
    /// see `GlassTransportState.presentation`.
    case primaryPressed
    /// The capture stream is open and audio is arriving.
    case captureStarted(at: Date)
    /// The file has been finalised.
    case captureFinalized
    /// The saved beat has been displayed for `GlassTransportTiming.savedDwell`.
    case savedDwellElapsed
    /// Capture permission was granted (by the grant watcher, or on return
    /// from System Settings).
    case permissionGranted
    /// Capture permission was refused or revoked.
    case permissionChanged(GlassPermissionBlock)
    /// The app detected it is running translocated.
    case installBlocked
    /// Capture failed at any point. The transport returns to a resting state;
    /// the *reason* is a notice, not a transport state — see the note below.
    case failed
}

/// The transport's transition table.
///
/// Pure, synchronous, and free of SwiftUI: it can be unit-tested exhaustively,
/// which is the point of writing it down separately from the view.
///
/// ### Why failures aren't transport states
/// It is tempting to add `.error` to `GlassTransportState`. Don't. An error is
/// orthogonal to what the transport is doing — a save-location failure happens
/// *while the recording continues*, and folding it into the transport enum
/// would force a choice between "recording" and "error" when the truth is
/// both. Errors are notices (`GlassNotice`), the transport is a transport, and
/// the two compose.
///
/// ### Timing contract
/// - `arming` is held for at least `GlassTransportTiming.minimumArming` even
///   if the stream opens sooner. A state that flickers past is worse than one
///   that never appeared.
/// - `stopping` is held for at least `minimumStopping`.
/// - `saved` returns to `idle` after `savedDwell` — but is **fully armed for
///   the whole dwell**. The dwell is presentation, never a lock.
public enum GlassTransportMachine {

    /// The next state, or `nil` if the event doesn't apply here.
    ///
    /// Returning `nil` rather than the current state is deliberate: it lets a
    /// host distinguish "nothing changed" from "this event was handled and
    /// happened to be a no-op", which is exactly the distinction you want when
    /// something odd shows up in a log.
    public static func next(
        from state: GlassTransportState,
        on event: GlassTransportEvent,
        now: Date = .now
    ) -> GlassTransportState? {
        // World facts that override any state.
        switch event {
        case .installBlocked:
            return .blockedByInstall
        case .permissionChanged(let block):
            // An install block outranks a permission block: moving the app is
            // the prerequisite, so re-blocking on permission would replace a
            // true message with a misleading one.
            guard state != .blockedByInstall else { return nil }
            return .blockedByPermission(block)
        case .permissionGranted:
            guard state != .blockedByInstall else { return nil }
            guard state.isBlocked else { return nil }
            return .idle
        default:
            break
        }

        switch (state, event) {
        // Arming
        case (.idle, .primaryPressed), (.saved, .primaryPressed):
            return .arming
        case (.arming, .captureStarted(let date)):
            return .recording(startedAt: date)
        case (.arming, .failed):
            return .idle
        // A press during arming is refused rather than queued: queueing it
        // would make the button feel like it "remembered" a click the user
        // has already given up on.
        case (.arming, .primaryPressed):
            return nil

        // Recording
        case (.recording, .primaryPressed):
            return .stopping
        case (.recording, .failed):
            return .stopping

        // Stopping
        case (.stopping, .captureFinalized), (.stopping, .failed):
            return .saved
        case (.stopping, .primaryPressed):
            return nil

        // Saved
        case (.saved, .savedDwellElapsed):
            return .idle

        // A blocked control's press goes to System Settings or Finder — a
        // side effect, not a transition. The state changes when the *world*
        // does (`permissionGranted`), not when the button is clicked.
        case (.blockedByPermission, .primaryPressed), (.blockedByInstall, .primaryPressed):
            return nil

        default:
            return nil
        }
    }

    /// Whether a new capture can begin. `saved` counts — that is the point.
    public static func canStartRecording(in state: GlassTransportState) -> Bool {
        switch state {
        case .idle, .saved: true
        default: false
        }
    }

    /// Whether an in-flight capture can be stopped. `arming` and `stopping`
    /// are false: there is nothing to stop yet, and nothing left to stop.
    public static func canStopRecording(in state: GlassTransportState) -> Bool {
        state.isRecording
    }

    /// Elapsed capture time.
    ///
    /// Derived from the start date, never accumulated from ticks. Tick
    /// accumulation drifts — measurably, over a long session — and a recorder
    /// whose timer disagrees with its own file length loses the user's trust
    /// in everything else it says.
    public static func elapsed(in state: GlassTransportState, now: Date = .now) -> TimeInterval {
        guard let startedAt = state.startedAt else { return 0 }
        return max(0, now.timeIntervalSince(startedAt))
    }
}

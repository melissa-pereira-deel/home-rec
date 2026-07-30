import SwiftUI

// MARK: - Blocking conditions

/// Why the transport can't arm, in the order the product resolves them.
public enum GlassPermissionBlock: String, CaseIterable, Hashable, Sendable {
    /// The capture permission has never been asked for.
    case notDetermined
    /// The user said no, or revoked it later.
    case denied
    /// System Settings has been opened and the app is waiting for the grant
    /// to register. A real state, not a spinner: the app publishes it, so the
    /// control must show it rather than sitting there looking pressable.
    case openingSettings
}

// MARK: - State

/// The transport's complete state.
///
/// **This enum is the reason the kit exists.** The shipping app modelled the
/// same thing with booleans (`isRecording`, `isStarting`, `isOpeningSettings`,
/// a separate permission enum, a separate translocation flag) and the
/// inevitable happened: combinations that can't occur were representable,
/// combinations that do occur were unhandled, and the primary control ended up
/// displaying "Start recording" *while stopping*. A control that lies about
/// what it will do is worse than a control that is missing.
///
/// So: one value, seven cases, and every visual property of the control is a
/// pure function of it. There is no way to render a state that isn't in this
/// list, and no way to be in two of them at once.
///
/// ```
///                    ┌──────────── blockedByInstall (terminal)
///                    │
/// blockedByPermission┤ notDetermined → openingSettings → (grant) ─┐
///                    └ denied ───────→ openingSettings → (grant) ─┤
///                                                                 ▼
///        ┌──────────────────────────────────────────────────── idle
///        │                                                        │ press
///        ▼                                                        ▼
///      saved ◀── stopping ◀── recording ◀── (capture started) ── arming
///        │                        ▲                                │
///        └── dwell 1.4s ──────────┴── press (immediately re-armable)┘
/// ```
public enum GlassTransportState: Hashable, Sendable {
    /// Armed and ready. The control offers `record`.
    case idle
    /// Start requested; capture not yet running. Disabled — there is nothing
    /// truthful to offer for the ~250ms it takes to open a stream.
    case arming
    /// Capturing. The control offers `stop`. `startedAt` is the wall-clock
    /// origin the elapsed time must be *derived* from — never a tick counter,
    /// which drifts (a 90-minute session drifted by seconds in the prototype).
    case recording(startedAt: Date)
    /// Finalising and writing the file. Disabled, labelled `saving…`.
    case stopping
    /// A take just landed. Presented for a beat so the number the user made
    /// doesn't evaporate — but the control is **already `record` again and
    /// already enabled**. `.saved` is never a dead state.
    case saved
    /// Capture permission is missing. The control carries the fix.
    case blockedByPermission(GlassPermissionBlock)
    /// The app is running translocated (from a disk image / quarantine). This
    /// is terminal: no amount of pressing fixes it from inside the app, so the
    /// control stops offering to record and offers to reveal the app instead.
    case blockedByInstall

    /// A capture is in flight — arming, recording, or finalising.
    ///
    /// This is the predicate the "recording is never invisible" invariant is
    /// built on. It deliberately includes `arming` and `stopping`: a user who
    /// pressed record 200ms ago and switched screens must still see that
    /// something is happening.
    public var isCapturing: Bool {
        switch self {
        case .arming, .recording, .stopping: true
        default: false
        }
    }

    /// Actively writing audio.
    public var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    /// Something outside the transport is preventing capture.
    public var isBlocked: Bool {
        switch self {
        case .blockedByPermission, .blockedByInstall: true
        default: false
        }
    }

    /// Wall-clock origin of the current capture, if any.
    public var startedAt: Date? {
        if case .recording(let date) = self { return date }
        return nil
    }

    /// Whether the output format may be changed right now.
    ///
    /// Format is captured when the stream opens, so it locks for the whole
    /// capture — including `arming` and `stopping`, which is the part that
    /// gets missed: unlocking during `stopping` makes the control flicker back
    /// to enabled for 450ms and then re-lock if the user records again.
    /// Present the lock as *disabled with a reason*, never hidden.
    public var allowsFormatChange: Bool { !isCapturing }

    /// Playback is **never** blocked by capture. See `GlassMonitoringPolicy`.
    public var allowsPlayback: Bool { true }
}

// MARK: - Intent

/// What pressing the control means in the current state.
///
/// The component resolves state → intent; the host maps intent → behaviour.
/// That split is why the control can be dropped into a real app without the
/// kit knowing anything about `SCStream`, permissions, or the file system.
public enum GlassTransportIntent: String, Hashable, Sendable {
    case startRecording
    case stopRecording
    /// Take the user to the place where capture permission is granted.
    case openSystemSettings
    /// Show the translocated app in Finder so it can be moved.
    case revealInFinder
    /// The control is disabled; pressing it does nothing. Present so that
    /// `switch` over intents stays exhaustive at call sites.
    case none
}

// MARK: - Copy

/// Every string the transport control can display.
///
/// Lifted out of the component so product can revise copy — and so a host can
/// localise — without forking the view. Defaults are the shipping strings, in
/// the kit's lowercase control register.
public struct GlassTransportCopy: Hashable, Sendable {
    public var record: String
    public var stop: String
    public var arming: String
    public var saving: String
    public var allowCapture: String
    public var grantPermission: String
    public var openingSettings: String
    public var revealInFinder: String

    public init(
        record: String = "record",
        stop: String = "stop",
        arming: String = "arming…",
        saving: String = "saving…",
        allowCapture: String = "allow audio capture",
        grantPermission: String = "grant permission",
        openingSettings: String = "opening settings…",
        revealInFinder: String = "reveal in finder"
    ) {
        self.record = record
        self.stop = stop
        self.arming = arming
        self.saving = saving
        self.allowCapture = allowCapture
        self.grantPermission = grantPermission
        self.openingSettings = openingSettings
        self.revealInFinder = revealInFinder
    }

    public static let standard = GlassTransportCopy()
}

// MARK: - Presentation

/// Everything the control renders, derived from the state.
///
/// Exposed publicly because other surfaces have to agree with the pill: the
/// menu-bar item, a popover, a Touch Bar. They all read the same presentation
/// rather than re-deriving it — which is how the shipping app ended up with a
/// menu bar that looked healthy while the panel showed an error.
public struct GlassTransportPresentation: Hashable, Sendable {
    /// Visible label, in the lowercase control register.
    public let label: String
    /// SF Symbol, or `nil` for states where an icon would add nothing (a
    /// spinner-ish `arming…` reads better as pure type).
    public let symbolName: String?
    public let isEnabled: Bool
    /// `true` when the control should wear the accent. Blocked and waiting
    /// states are neutral on purpose: a control that can't record must not
    /// look like the control that can.
    public let isAccented: Bool
    /// The app is working, not refusing. Drives the pill's loading state:
    /// spinner beside the label, input blocked, announced as busy rather than
    /// as unavailable. `arming…`, `saving…` and `opening settings…` are the
    /// three — every one of them a wait the user is meant to sit through, not
    /// a door that is closed.
    public var isBusy: Bool = false
    public let intent: GlassTransportIntent
    /// VoiceOver label. Written as a sentence with a verb, because the visible
    /// lowercase label ("stop") is a fragment that reads as a noun aloud.
    public let accessibilityLabel: String
    /// VoiceOver hint, or `nil` when the label is already complete.
    public let accessibilityHint: String?
}

public extension GlassTransportState {
    /// State → presentation. The single source of truth for what the control
    /// says, whether it's enabled, and what a press means.
    ///
    /// Precedence is deliberate and mirrors the shipping app:
    /// **install block → permission → transport.** A translocated app with a
    /// denied permission has one honest thing to say, and it isn't
    /// "grant permission" — moving the app is the prerequisite.
    func presentation(copy: GlassTransportCopy = .standard) -> GlassTransportPresentation {
        switch self {
        case .blockedByInstall:
            return .init(
                label: copy.revealInFinder,
                symbolName: "arrow.up.forward.square",
                isEnabled: true,
                isAccented: false,
                intent: .revealInFinder,
                accessibilityLabel: "Reveal Home Rec in Finder",
                accessibilityHint: "Home Rec can't record from a disk image. Move it to Applications and open it from there."
            )

        case .blockedByPermission(.openingSettings):
            return .init(
                label: copy.openingSettings,
                symbolName: nil,
                isEnabled: false,
                isAccented: false,
                isBusy: true,
                intent: .none,
                accessibilityLabel: "Opening System Settings",
                accessibilityHint: "Waiting for the permission to register."
            )

        case .blockedByPermission(.notDetermined):
            // Accented: this is the one blocked state that is a *first run*
            // rather than a failure, and it is the primary call to action.
            return .init(
                label: copy.allowCapture,
                symbolName: "circle.fill",
                isEnabled: true,
                isAccented: true,
                intent: .openSystemSettings,
                accessibilityLabel: "Allow audio capture",
                accessibilityHint: "Opens System Settings to grant Screen Recording permission."
            )

        case .blockedByPermission(.denied):
            return .init(
                label: copy.grantPermission,
                symbolName: nil,
                isEnabled: true,
                isAccented: false,
                intent: .openSystemSettings,
                accessibilityLabel: "Grant permission",
                accessibilityHint: "Opens System Settings. Look under Screen & System Audio Recording."
            )

        case .arming:
            return .init(
                label: copy.arming,
                symbolName: nil,
                isEnabled: false,
                isAccented: true,
                isBusy: true,
                intent: .none,
                accessibilityLabel: "Arming",
                accessibilityHint: nil
            )

        case .recording:
            return .init(
                label: copy.stop,
                symbolName: "stop.fill",
                isEnabled: true,
                isAccented: true,
                intent: .stopRecording,
                accessibilityLabel: "Stop recording",
                accessibilityHint: nil
            )

        case .stopping:
            return .init(
                label: copy.saving,
                symbolName: nil,
                isEnabled: false,
                isAccented: true,
                isBusy: true,
                intent: .none,
                accessibilityLabel: "Saving",
                accessibilityHint: nil
            )

        case .idle, .saved:
            // `.saved` deliberately shares `.idle`'s presentation. The saved
            // beat is carried by the waveform and the timer, not by disabling
            // the control — you can start the next take the instant the last
            // one lands.
            return .init(
                label: copy.record,
                symbolName: "circle.fill",
                isEnabled: true,
                isAccented: true,
                intent: .startRecording,
                accessibilityLabel: "Start recording",
                accessibilityHint: nil
            )
        }
    }
}

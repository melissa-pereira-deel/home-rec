import SwiftUI

/// What the device is currently doing.
///
/// Defined in the kit rather than taken from a host application: a transport
/// is a property of the *instrument metaphor*, and any product using this
/// language will have some version of it. Map an application's own state onto
/// this at the boundary.
public enum TransportPhase: Sendable, Hashable, CaseIterable {
    /// The function is not available — no permission, no input, no medium.
    /// Distinct from `idle`, because the correct signal is a differently
    /// coloured cap, not a greyed-out one.
    case unavailable
    /// Ready and armed.
    case idle
    /// Committed but not yet running.
    case arming
    case recording
    case playing
    case paused
    /// Running down — finalising, flushing, closing.
    case finishing

    public var isRecording: Bool { self == .recording }

    public var isRunning: Bool {
        self == .recording || self == .playing
    }

    /// Whether the transport can accept commands at all.
    public var isOperable: Bool {
        self != .unavailable
    }
}

/// The record / stop / play cluster.
///
/// State is signalled physically and redundantly, which is the whole point of
/// the pattern: the record key changes *legend* (REC to STOP), the annunciator
/// lamp changes *mode*, and an unavailable transport changes cap *material*.
/// None of those alone would be enough — a colour change is invisible to some
/// users, a blink is suppressed under Reduce Motion, and a legend change is
/// missed by anyone not looking at that key.
@available(macOS 15, *)
public struct TransportKeys: View {
    @Environment(\.poTheme) private var theme

    private let phase: TransportPhase
    private let showsPlay: Bool
    private let showsAnnunciator: Bool
    private let keySize: HardwareKeySize
    private let onRecord: () -> Void
    private let onStop: () -> Void
    private let onPlay: (() -> Void)?

    public init(
        phase: TransportPhase,
        showsPlay: Bool = true,
        showsAnnunciator: Bool = true,
        keySize: HardwareKeySize = .regular,
        onRecord: @escaping () -> Void,
        onStop: @escaping () -> Void,
        onPlay: (() -> Void)? = nil
    ) {
        self.phase = phase
        self.showsPlay = showsPlay
        self.showsAnnunciator = showsAnnunciator
        self.keySize = keySize
        self.onRecord = onRecord
        self.onStop = onStop
        self.onPlay = onPlay
    }

    public var body: some View {
        HStack(spacing: theme.metrics.spacing.key) {
            if showsAnnunciator {
                LampAnnunciator(
                    annunciatorLegend,
                    mode: annunciatorMode,
                    role: annunciatorRole,
                    accessibilityLabel: "Transport status"
                )
                .frame(minWidth: 54, alignment: .leading)
            }

            if showsPlay, let onPlay {
                HardwareKey(
                    phase == .playing ? "PAUSE" : "PLAY",
                    size: keySize,
                    accessibilityLabel: phase == .playing ? "Pause" : "Play",
                    action: onPlay
                )
                .disabled(!phase.isOperable || phase == .recording)
            }

            HardwareKey(
                "STOP",
                size: keySize,
                accessibilityLabel: "Stop",
                action: onStop
            )
            .disabled(!phase.isRunning && phase != .paused)

            HardwareKey(
                phase.isRecording ? "STOP" : "REC",
                variant: .accent,
                size: keySize,
                accessibilityLabel: phase.isRecording ? "Stop recording" : "Record",
                accessibilityHint: phase == .unavailable ? "Unavailable" : nil,
                action: phase.isRecording ? onStop : onRecord
            )
            .disabled(!phase.isOperable || phase == .arming || phase == .finishing)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Transport")
    }

    private var annunciatorLegend: String {
        switch phase {
        case .unavailable: "N/A"
        case .idle: "RDY"
        case .arming: "ARM"
        case .recording: "REC"
        case .playing: "PLAY"
        case .paused: "PAUSE"
        case .finishing: "WAIT"
        }
    }

    private var annunciatorMode: IndicatorLamp.Mode {
        switch phase {
        case .unavailable: .off
        case .idle, .paused: .on
        case .arming, .recording, .finishing: .blinking
        case .playing: .on
        }
    }

    private var annunciatorRole: IndicatorLamp.Role {
        switch phase {
        case .unavailable: .warning
        case .idle, .paused, .playing: .armed
        case .arming, .recording, .finishing: .active
        }
    }
}

@available(macOS 15, *)
#Preview("Transport") {
    VStack(alignment: .leading, spacing: 14) {
        ForEach(
            [
                TransportPhase.unavailable, .idle, .arming,
                .recording, .playing, .paused, .finishing,
            ],
            id: \.self
        ) { phase in
            TransportKeys(
                phase: phase,
                keySize: .compact,
                onRecord: {},
                onStop: {},
                onPlay: {}
            )
        }
    }
    .padding(30)
    .background(Color.poHex(0x0A0A0A))
}

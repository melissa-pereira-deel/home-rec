import SwiftUI

/// **Policy C: playback during a capture is allowed, and the guarantee is made
/// visible.**
///
/// The alternative policies were both worse. Hard mutual exclusion (you can't
/// play while recording) punishes the user for a problem that is already
/// solved in the capture layer. Allowing it silently leaves a load-bearing
/// invariant invisible: a user who hears an old take while recording has every
/// reason to assume it is being recorded, and no way to find out that it isn't.
///
/// ### The guarantee
/// The capture excludes the app's own audio from the stream
/// (`SCStreamConfiguration.excludesCurrentProcessAudio`). In-app playback is
/// provably not in the file.
///
/// ### What the host must do for this policy to be true
/// The UI here is a promise. Two engineering conditions have to hold or the
/// promise is a lie:
///
/// 1. **A regression test** asserting `excludesCurrentProcessAudio` on the
///    built stream configuration. It is one boolean between "correct" and
///    "silently records itself".
/// 2. **Playback must run in-process** (AVAudioPlayer / AVAudioEngine), never
///    in a helper process — a helper's audio is a different process's audio,
///    and the exclusion would not apply to it.
///
/// ### Known limit, stated plainly
/// The exclusion is at the *tap*, not in the room. A setup that captures from
/// a microphone could still acoustically re-record speaker output. Home Rec
/// captures system audio only, so this does not apply today; it must be
/// revisited if microphone capture ships.
public enum GlassMonitoringPolicy {

    /// Whether the monitoring affordances should be shown.
    public static func isMonitoring(transport: GlassTransportState, isPlaying: Bool) -> Bool {
        transport.isRecording && isPlaying
    }

    /// Playback is never blocked by capture.
    public static func allowsPlayback(during transport: GlassTransportState) -> Bool { true }

    /// The persistent badge shown next to the player's transport.
    public static let badgeText = "monitoring · not recorded"

    /// The one-time explainer, shown on a user's first concurrent playback and
    /// dismissible forever. Once explained, the badge alone carries it.
    public static let explainerText =
        "playback here is monitoring only — home rec excludes its own audio from the capture, so it won't be in your recording."
}

/// The persistent monitoring marker.
public struct GlassMonitoringBadge: View {
    private let text: String

    public init(text: String = GlassMonitoringPolicy.badgeText) {
        self.text = text
    }

    public var body: some View {
        GlassBadge(text, tint: .textTertiary, textRole: .metaSmall)
            .fixedSize()
            // Unhidden, unlike other badges: this one is not decoration of a
            // neighbour, it is a *guarantee about the recording*, and a
            // VoiceOver user needs it as much as anyone.
            .accessibilityHidden(false)
            .accessibilityLabel("Monitoring only. This playback is not being recorded.")
    }
}

/// The one-time explainer row.
public struct GlassMonitoringExplainer: View {
    private let text: String
    private let onDismiss: () -> Void

    @Environment(\.glassTheme) private var theme

    public init(text: String = GlassMonitoringPolicy.explainerText, onDismiss: @escaping () -> Void) {
        self.text = text
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(alignment: .top, spacing: GlassSpacing.s) {
            Text(text)
                .glassText(.metaSmall, color: .textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: GlassSpacing.xs)
            GlassIconButton(
                systemImage: "xmark",
                accessibilityLabel: "Dismiss explanation",
                symbolSize: 8
            ) {
                onDismiss()
            }
        }
        .padding(.horizontal, GlassSpacing.m)
        .padding(.vertical, GlassSpacing.sm + 1)
        .glassSurface(
            GlassSurfaceStyle(
                fill: .card,
                cornerRadius: GlassRadius.inner - 2,
                stroke: .none,
                translucentCard: true
            )
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview("Monitoring") {
    GlassPreviewStage {
        VStack(alignment: .leading, spacing: GlassSpacing.md) {
            GlassMonitoringBadge()
            GlassMonitoringExplainer(onDismiss: {})
        }
    }
}

import SwiftUI

/// The expanded take: waveform, riding timecode, scrub ruler, transport.
///
/// Presented *in place of* the collapsed row rather than below it, so opening
/// a take doesn't push the list. The title row is the collapse affordance —
/// clicking the thing you opened is the gesture people try first.
public struct GlassTakePlayer<Take: GlassTakeRepresentable>: View {
    private let take: Take
    @Binding private var progress: Double
    private let isPlaying: Bool
    private let isMonitoring: Bool
    private let showsMonitoringExplainer: Bool
    private let onPlayPause: () -> Void
    private let onScrubbingChanged: (Bool) -> Void
    private let onDismissExplainer: () -> Void
    private let onCollapse: () -> Void

    @Environment(\.glassTheme) private var theme

    public init(
        take: Take,
        progress: Binding<Double>,
        isPlaying: Bool,
        isMonitoring: Bool = false,
        showsMonitoringExplainer: Bool = false,
        onPlayPause: @escaping () -> Void,
        onScrubbingChanged: @escaping (Bool) -> Void = { _ in },
        onDismissExplainer: @escaping () -> Void = {},
        onCollapse: @escaping () -> Void = {}
    ) {
        self.take = take
        self._progress = progress
        self.isPlaying = isPlaying
        self.isMonitoring = isMonitoring
        self.showsMonitoringExplainer = showsMonitoringExplainer
        self.onPlayPause = onPlayPause
        self.onScrubbingChanged = onScrubbingChanged
        self.onDismissExplainer = onDismissExplainer
        self.onCollapse = onCollapse
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: GlassSpacing.md) {
            titleRow
            GlassMetaLabel(take.metadata)
            player
            transportRow
            if isMonitoring && showsMonitoringExplainer {
                GlassMonitoringExplainer(onDismiss: onDismissExplainer)
            }
        }
        .padding(GlassSpacing.l)
        .glassSurface(.rowActive(tint: theme.colors.accent))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Player for \(take.title)")
    }

    private var titleRow: some View {
        Button(action: onCollapse) {
            HStack(spacing: GlassSpacing.sm) {
                Text(take.title)
                    .glassText(.title, color: .textPrimary)
                    .lineLimit(1)
                Spacer()
                GlassMetaLabel(take.timestamp)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(take.title)
        .accessibilityHint("Closes the player.")
    }

    private var player: some View {
        VStack(spacing: GlassSpacing.s) {
            GlassWaveform(samples: take.waveform, progress: progress)
                .frame(height: theme.metrics.waveformPlayerHeight)
                .overlay(alignment: .top) {
                    GlassTimecodeChip(
                        time: progress * take.duration,
                        progress: progress,
                        duration: take.duration
                    )
                    // Lifted clear of the waveform's top edge so the capsule
                    // sits above the loudest bar rather than on top of it.
                    .offset(y: -GlassSpacing.s)
                }
            GlassScrubRuler(
                value: $progress,
                accessibilityLabel: "Playback position in \(take.title)",
                accessibilityValue: { GlassTimecode.spoken($0 * take.duration) },
                onEditingChanged: onScrubbingChanged
            )
        }
    }

    private var transportRow: some View {
        HStack(spacing: GlassSpacing.md) {
            GlassPillButton(
                isPlaying ? "pause" : "play",
                systemImage: isPlaying ? "pause.fill" : "play.fill",
                emphasis: .primary,
                size: .small,
                isFullWidth: true,
                action: onPlayPause
            )
            // Pinned to the width of its widest label. "play" and "pause"
            // differ by two glyphs, and a control that resizes under the
            // cursor makes the second click land somewhere else — or, if it
            // is squeezed instead, wraps its own label onto two lines.
            .frame(width: playPauseWidth)
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            GlassMetaLabel(
                GlassTimecode.string(progress * take.duration, matching: take.duration)
                    + " / "
                    + GlassTimecode.string(take.duration, matching: take.duration)
            )
            .accessibilityLabel("Position")
            .accessibilityValue(
                "\(GlassTimecode.spoken(progress * take.duration)) of \(GlassTimecode.spoken(take.duration))"
            )

            if isMonitoring {
                GlassMonitoringBadge()
            }
            Spacer(minLength: 0)
        }
    }

    /// Enough for `pause` plus its symbol at `.small` metrics. A measured
    /// value would need a layout pass the control can't afford mid-playback.
    private var playPauseWidth: CGFloat { 96 }
}

#Preview("Take player") {
    struct Host: View {
        @State private var progress = 0.44
        var body: some View {
            GlassPreviewStage {
                VStack(spacing: GlassSpacing.md) {
                    GlassTakePlayer(
                        take: GlassSampleTakes.all[1],
                        progress: $progress,
                        isPlaying: true,
                        onPlayPause: {}
                    )
                    GlassTakePlayer(
                        take: GlassSampleTakes.all[1],
                        progress: $progress,
                        isPlaying: true,
                        isMonitoring: true,
                        showsMonitoringExplainer: true,
                        onPlayPause: {}
                    )
                }
            }
        }
    }
    return Host()
}

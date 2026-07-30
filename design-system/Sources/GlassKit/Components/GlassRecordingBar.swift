import SwiftUI

/// The bar that follows a capture around the app.
///
/// Pulsing dot, wall-clock timer, live trace, stop pill. It renders whenever
/// `state.isCapturing` and nothing else — including `arming` and `stopping`,
/// so there is no window in which a capture exists and the UI doesn't say so.
///
/// This component is the visible half of the kit's hardest invariant: **a
/// capture is never invisible and never more than one click from stop.** See
/// `Patterns/RecordingVisibility.swift` for the modifier that enforces it, and
/// prefer that over placing this by hand — a bar you have to remember to add
/// is a bar someone will forget on the next screen.
public struct GlassRecordingBar: View {
    private let state: GlassTransportState
    private let elapsed: TimeInterval
    private let samples: [Float]
    private let copy: GlassTransportCopy
    private let onStop: () -> Void

    @Environment(\.glassTheme) private var theme

    public init(
        state: GlassTransportState,
        elapsed: TimeInterval,
        samples: [Float] = [],
        copy: GlassTransportCopy = .standard,
        onStop: @escaping () -> Void
    ) {
        self.state = state
        self.elapsed = elapsed
        self.samples = samples
        self.copy = copy
        self.onStop = onStop
    }

    public var body: some View {
        if state.isCapturing {
            content
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var content: some View {
        HStack(spacing: GlassSpacing.md) {
            GlassPulseDot(isAnimating: state.isRecording)

            GlassTimecodeDisplay(time: elapsed, isLive: state.isRecording, role: .timerCompact)

            GlassLiveWaveform(samples: samples, opacity: 0.8)
                .frame(width: 60, height: 18)

            Spacer(minLength: GlassSpacing.s)

            GlassPillButton(
                stopLabel,
                systemImage: "stop.fill",
                emphasis: .primary,
                size: .compact,
                action: onStop
            )
            .disabled(!state.isRecording)
            .accessibilityLabel(state.isRecording ? "Stop recording" : stopLabel)
        }
        .padding(.horizontal, GlassSpacing.l)
        .padding(.vertical, GlassSpacing.s)
        .glassSurface(.notice(tint: theme.colors.accent))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recording in progress")
    }

    /// The bar's stop control tells the same truth as the face's pill, because
    /// it is the same state machine: you cannot stop something that is still
    /// arming, and you cannot stop something that is already saving.
    private var stopLabel: String {
        switch state {
        case .arming: copy.arming
        case .stopping: copy.saving
        default: copy.stop
        }
    }
}

#Preview("Recording bar") {
    GlassPreviewStage {
        VStack(spacing: GlassSpacing.md) {
            GlassRecordingBar(
                state: .arming,
                elapsed: 0,
                samples: GlassSampleWaveforms.live(count: 8),
                onStop: {}
            )
            GlassRecordingBar(
                state: .recording(startedAt: .now),
                elapsed: 73.1,
                samples: GlassSampleWaveforms.live(count: 60),
                onStop: {}
            )
            GlassRecordingBar(
                state: .stopping,
                elapsed: 73.4,
                samples: GlassSampleWaveforms.live(count: 60),
                onStop: {}
            )
        }
    }
}

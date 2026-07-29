import SwiftUI

/// The non-negotiable: while a capture is running, every screen shows it and
/// can stop it. Pinned above the library (and any future screen) — a
/// recording must never be invisible or unstoppable.
struct RecordingBar: View {
    @EnvironmentObject private var store: PrototypeStateStore
    var accent: Color
    var cardFill: Color
    var textPrimary: Color = .white.opacity(0.92)
    var textDim: Color = .white.opacity(0.55)

    var body: some View {
        if isVisible {
            content
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var isVisible: Bool {
        switch store.transport {
        case .starting, .recording, .stopping: true
        default: false
        }
    }

    private var content: some View {
        HStack(spacing: 12) {
            pulsingDot
            Text(Formatters.timecode(store.elapsed, tenths: store.elapsed < 3600))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(textPrimary)
                .accessibilityLabel("recording time")
                .accessibilityValue(Formatters.timecode(store.elapsed))
                .accessibilityAddTraits(.updatesFrequently)
            LiveWaveform(samples: Array(store.liveSamples.suffix(40)), accent: accent.opacity(0.8))
                .frame(width: 60, height: 18)
                .accessibilityHidden(true)
            Spacer()
            stopControl
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accent.opacity(0.35), lineWidth: 1)
        )
    }

    /// Soft breathe while recording; steady while arming/saving.
    private var pulsingDot: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { context in
            let breathe = store.transport.isRecording
                ? 0.7 + 0.3 * sin(context.date.timeIntervalSince1970 * .pi * 1.4)
                : 0.5
            Circle()
                .fill(accent)
                .frame(width: 9, height: 9)
                .opacity(breathe)
        }
        .frame(width: 9, height: 9)
        .accessibilityHidden(true)
    }

    private var stopControl: some View {
        var label = "stop"
        var enabled = true
        switch store.transport {
        case .starting: label = "arming…"; enabled = false
        case .stopping: label = "saving…"; enabled = false
        default: break
        }
        return FlatPillButton(action: { store.stop() }) {
            HStack(spacing: 7) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 8, weight: .bold))
                Text(label)
                    .font(.custom("Inter", size: 12, relativeTo: .caption))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 30)
            .background(enabled ? accent : accent.opacity(0.45), in: Capsule())
            .contentShape(Capsule())
        }
        .disabled(!enabled)
        .accessibilityLabel(enabled ? "stop recording" : label)
    }
}

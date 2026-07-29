import SwiftUI

/// Glass Shelf V2 — evolution of GSFace with ONE change: the skeuomorphic
/// hero key (metal well, gradients, travel) is replaced by a flat pill in
/// the untitled/Spotify register — solid fill, lowercase label, subtle
/// scale on hover/press, no chrome. Everything else is untouched GSFace.
struct GSFaceV2: View {
    @EnvironmentObject private var store: PrototypeStateStore

    var body: some View {
        ZStack {
            GSTheme.backdrop
            panel
                .padding(22)
        }
        .frame(width: 450, height: 450)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var panel: some View {
        VStack(spacing: 12) {
            header
            Spacer(minLength: 0)
            centerpiece
            Spacer(minLength: 0)
            shelf
        }
        .padding(18)
        .frame(maxHeight: 450 - 44)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 30, y: 18)
    }

    private var header: some View {
        HStack {
            GSTheme.lowercase("home rec", size: 13)
            Spacer()
            GSTheme.mono(store.selectedFormat.rawValue + " · 48kHz")
        }
    }

    // MARK: - Centerpiece: timer + live wave + the flat record pill

    @ViewBuilder
    private var centerpiece: some View {
        VStack(spacing: 12) {
            Text(Formatters.timecode(timerValue, tenths: timerValue < 3600))
                .font(.system(size: 30, weight: .light, design: .monospaced))
                .foregroundStyle(.white.opacity(store.transport.isRecording ? 1 : 0.55))
                .monospacedDigit()
                .contentTransition(.numericText())

            liveCard

            GSFlatRecordButton()
        }
    }

    private var timerValue: TimeInterval {
        if case .saved(let recording) = store.transport { return recording.duration }
        return store.elapsed
    }

    private var liveCard: some View {
        Group {
            if store.transport.isRecording {
                LiveWaveform(samples: store.liveSamples, accent: GSTheme.accent)
            } else if case .saved(let recording) = store.transport {
                // The materialize beat: the fresh take becomes an object.
                BarWaveform(samples: recording.samples, accent: GSTheme.accent, progress: nil, dimOpacity: 0.85)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else {
                BarWaveform(
                    samples: Array(repeating: Float(0.05), count: 96),
                    accent: .white, progress: nil
                )
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(GSTheme.card.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.08), .clear],
                        startPoint: .top, endPoint: .center
                    ),
                    lineWidth: 1
                )
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: store.transport)
    }

    // MARK: - Shelf: the three most recent takes

    private var shelf: some View {
        VStack(spacing: 6) {
            HStack {
                GSTheme.mono("recent", size: 10)
                Spacer()
                Button {
                    store.screen = .library
                } label: {
                    GSTheme.mono("all takes →", size: 10)
                }
                .buttonStyle(.plain)
            }
            ForEach(store.library.prefix(3)) { recording in
                shelfCard(recording)
            }
        }
    }

    private func shelfCard(_ recording: FakeRecording) -> some View {
        Button {
            store.screen = .library
            store.select(recording)
        } label: {
            HStack(spacing: 10) {
                BarWaveform(samples: recording.samples, accent: .white, progress: nil)
                    .frame(width: 72, height: 18)
                GSTheme.lowercase(recording.name, size: 12)
                    .lineLimit(1)
                Spacer()
                GSTheme.mono(Formatters.timecode(recording.duration), size: 10)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(GSTheme.card.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - The flat record pill

/// Flat, confident, quiet — the untitled/Spotify register. Solid brand-red
/// capsule, lowercase label, icon swap for state. Feedback is a subtle
/// scale (hover 1.03, press 0.97) and a slight darken on press. No wells,
/// no gradients, no travel.
struct GSFlatRecordButton: View {
    @EnvironmentObject private var store: PrototypeStateStore
    @State private var hovering = false

    var body: some View {
        let recording = store.transport.isRecording
        Button {
            store.toggleRecording()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: recording ? "stop.fill" : "circle.fill")
                    .font(.system(size: 9, weight: .bold))
                Text(recording ? "stop" : "record")
                    .font(.custom("Inter", size: 14, relativeTo: .body))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 26)
            .frame(height: 44)
            .background(GSTheme.accent, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(GSFlatPressStyle())
        .scaleEffect(hovering ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .onHover { hovering = $0 }
    }
}

/// Flat press feedback: scale down a touch and darken — nothing physical.
private struct GSFlatPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview("GS face v2") {
    GSFaceV2()
        .environmentObject(PrototypeStateStore.shared)
        .padding(30)
        .background(Color.black)
}

import SwiftUI

/// Direction 4 — Glass Shelf, Metal Heart. Frosted panel over a mesh
/// backdrop; recordings are charcoal cards on a shelf; the recorder itself is
/// one physical key set into brushed metal. Saved beat: the take materializes
/// as a card under the key and joins the shelf.
struct GSFace: View {
    @EnvironmentObject private var store: PrototypeStateStore

    var body: some View {
        ZStack {
            GSTheme.backdrop
            panel
                .padding(26)
        }
        .frame(width: 450, height: 450)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var panel: some View {
        VStack(spacing: 16) {
            header
            Spacer(minLength: 0)
            centerpiece
            Spacer(minLength: 0)
            shelf
        }
        .padding(20)
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

    // MARK: - Centerpiece: timer + live wave + the metal heart

    @ViewBuilder
    private var centerpiece: some View {
        VStack(spacing: 14) {
            Text(Formatters.timecode(timerValue, tenths: timerValue < 3600))
                .font(.system(size: 32, weight: .light, design: .monospaced))
                .foregroundStyle(.white.opacity(store.transport.isRecording ? 1 : 0.55))
                .monospacedDigit()
                .contentTransition(.numericText())

            liveCard

            GSHeroKey()
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
        .frame(height: 56)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
        VStack(spacing: 8) {
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
                    .frame(width: 72, height: 20)
                GSTheme.lowercase(recording.name, size: 12)
                    .lineLimit(1)
                Spacer()
                GSTheme.mono(Formatters.timecode(recording.duration), size: 10)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
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

#Preview("GS face") {
    GSFace()
        .environmentObject(PrototypeStateStore.shared)
        .padding(30)
        .background(Color.black)
}

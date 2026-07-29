import SwiftUI

/// Glass Shelf V2 — evolution of GSFace with ONE change: the skeuomorphic
/// hero key (metal well, gradients, travel) is replaced by a flat pill in
/// the untitled/Spotify register — solid fill, lowercase label, subtle
/// scale on hover/press, no chrome. Everything else is untouched GSFace.
struct GSFaceV2: View {
    @EnvironmentObject private var store: PrototypeStateStore
    @State private var showSettings = false

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
        HStack(spacing: 10) {
            Text("home rec")
                .font(.custom("Inter", size: 13, relativeTo: .body).weight(.bold))
                .foregroundStyle(.white.opacity(0.95))
            Spacer()
            GSTheme.mono(store.selectedFormat.rawValue + " · 48kHz")
            settingsButton
        }
    }

    // MARK: - Settings (sliders icon, not a gear)

    private var settingsButton: some View {
        Button {
            showSettings.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(GSTheme.textDim)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showSettings, arrowEdge: .bottom) {
            settingsPopover
        }
    }

    private var settingsPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                GSTheme.mono("format", size: 10)
                HStack(spacing: 6) {
                    ForEach(FakeFormat.allCases, id: \.self) { format in
                        formatChip(format)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                GSTheme.mono("input gain", size: 10)
                TickRuler(value: $store.gain, accent: GSTheme.accent)
                    .frame(width: 210)
            }
            VStack(alignment: .leading, spacing: 4) {
                GSTheme.mono("saving to", size: 10)
                Text("~/Desktop")
                    .font(.custom("Inter", size: 12, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(16)
    }

    private func formatChip(_ format: FakeFormat) -> some View {
        let selected = store.selectedFormat == format
        return Button {
            store.selectedFormat = format
        } label: {
            Text(format.rawValue)
                .font(.custom("Inter", size: 12, relativeTo: .caption))
                .foregroundStyle(selected ? .white : GSTheme.textDim)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    GSTheme.card.opacity(selected ? 1 : 0.35),
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(.white.opacity(selected ? 0.25 : 0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
                GSTheme.lowercase(store.displayName(for: recording), size: 12)
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
/// capsule, lowercase label, icon swap for state. Built on the shared
/// FlatPillButton so the library's play pill and this stay in lockstep.
struct GSFlatRecordButton: View {
    @EnvironmentObject private var store: PrototypeStateStore

    var body: some View {
        let recording = store.transport.isRecording
        FlatPillButton(action: { store.toggleRecording() }) {
            HStack(spacing: 9) {
                Image(systemName: recording ? "stop.fill" : "circle.fill")
                    .font(.system(size: 9, weight: .bold))
                Text(recording ? "stop" : "record")
                    .font(.custom("Inter", size: 14, relativeTo: .body))
                    .fontWeight(.semibold)
            }
            // Optical centering: Inter's cap height sits low in the capsule.
            .offset(y: -1)
            .foregroundStyle(.white)
            .padding(.horizontal, 26)
            .frame(height: 44)
            .background(GSTheme.accent, in: Capsule())
            .contentShape(Capsule())
        }
    }
}

#Preview("GS face v2") {
    GSFaceV2()
        .environmentObject(PrototypeStateStore.shared)
        .padding(30)
        .background(Color.black)
}

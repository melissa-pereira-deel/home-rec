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
            if store.showOnboarding {
                GSOnboarding()
                    .transition(.opacity)
            }
        }
        .frame(width: 450, height: 450)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeOut(duration: 0.2), value: store.showOnboarding)
    }

    private var panel: some View {
        VStack(spacing: 12) {
            header
            Spacer(minLength: 0)
            centerpiece
            Spacer(minLength: 0)
            // A notice needing attention takes the shelf's slot; the shelf
            // is one tab away. Keeps the fixed face from ever overflowing.
            if GSErrorRow.isActive(store) {
                GSErrorRow()
            } else {
                shelf
            }
        }
        .padding(18)
        .frame(maxHeight: 450 - 44)
        .animation(.easeOut(duration: 0.18), value: GSErrorRow.isActive(store))
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
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("settings")
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
                GSTheme.mono("saving to", size: 10)
                HStack(spacing: 10) {
                    Text(store.saveLocation.name)
                        .font(.custom("Inter", size: 12, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.85))
                    GSNavLink(label: "choose…") {
                        store.cycleFakeSaveFolder()
                    }
                    if store.saveLocation.isCustom {
                        GSNavLink(label: "reset to desktop") {
                            store.resetSaveLocation()
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: 250, alignment: .leading)
    }

    private func formatChip(_ format: FakeFormat) -> some View {
        let selected = store.selectedFormat == format
        let locked = store.transport.isRecording
        return Button {
            store.selectedFormat = format
        } label: {
            Text(format.rawValue)
                .font(.custom("Inter", size: 12, relativeTo: .caption))
                .foregroundStyle(selected ? .white : GSTheme.textDim)
                .opacity(locked ? 0.4 : 1)
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
        // Shipping locks format during recording; the tooltip is its copy.
        .disabled(locked)
        .help("New recordings are saved as \(format.rawValue.uppercased()). This can't change while recording.")
        .accessibilityLabel("format \(format.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
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
                .accessibilityLabel("recording time")
                .accessibilityValue(Formatters.timecode(timerValue))
                .accessibilityAddTraits(store.transport.isRecording ? .updatesFrequently : [])

            liveCard

            GSFlatRecordButton()
        }
    }

    private var timerValue: TimeInterval {
        switch store.transport {
        case .saved(let recording): recording.duration
        case .recording, .stopping: store.elapsed
        // The last take's duration dwells until the next record — the number
        // a user just made must not evaporate 1.4s after appearing.
        default: store.lastTakeDuration ?? store.elapsed
        }
    }

    private var liveCard: some View {
        Group {
            if store.transport.isRecording {
                LiveWaveform(samples: store.liveSamples, accent: GSTheme.accent)
            } else if store.transport == .stopping {
                // Freeze the last live frame, dimmed — never a dead flat line
                // between "recording" and "saved".
                LiveWaveform(samples: store.liveSamples, accent: GSTheme.accent.opacity(0.45))
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
                GSNavLink(label: "all takes →") {
                    store.screen = .library
                }
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

/// The primary control's full state machine. The pill's label, fill, and
/// enablement always tell the truth — never an armed "record" that is a
/// no-op, never a dead window after a take.
struct GSFlatRecordButton: View {
    @EnvironmentObject private var store: PrototypeStateStore

    private struct PillMode {
        var icon: String?
        var label: String
        var enabled = true
        /// Brand red for record/stop; neutral for blocked/permission states.
        var neutral = false
        var action: (PrototypeStateStore) -> Void
    }

    private var mode: PillMode {
        // Precedence mirrors shipping: translocation → permission → transport.
        if store.translocationBlocked {
            return PillMode(icon: "arrow.up.forward.square", label: "reveal in finder",
                            neutral: true, action: { _ in })
        }
        if store.isOpeningSystemSettings {
            return PillMode(icon: nil, label: "opening settings…", enabled: false,
                            neutral: true, action: { _ in })
        }
        switch store.permissionStatus {
        case .notDetermined:
            return PillMode(icon: "circle.fill", label: "allow audio capture",
                            action: { $0.simulateOpenSystemSettings() })
        case .denied:
            return PillMode(icon: nil, label: "grant permission",
                            neutral: true, action: { $0.simulateOpenSystemSettings() })
        case .granted:
            break
        }
        switch store.transport {
        case .starting:
            return PillMode(icon: nil, label: "arming…", enabled: false,
                            action: { _ in })
        case .recording:
            return PillMode(icon: "stop.fill", label: "stop",
                            action: { $0.stop() })
        case .stopping:
            return PillMode(icon: nil, label: "saving…", enabled: false,
                            action: { _ in })
        default:
            // idle, saved (immediately re-armable), disarmed-but-granted.
            return PillMode(icon: "circle.fill", label: "record",
                            action: { $0.record() })
        }
    }

    var body: some View {
        let mode = self.mode
        FlatPillButton(action: { mode.action(store) }) {
            HStack(spacing: 9) {
                if let icon = mode.icon {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .bold))
                }
                Text(mode.label)
                    .font(.custom("Inter", size: 14, relativeTo: .body))
                    .fontWeight(.semibold)
            }
            // Optical centering: Inter's cap height sits low in the capsule.
            .offset(y: -1)
            .foregroundStyle(.white.opacity(mode.enabled ? 1 : 0.75))
            .padding(.horizontal, 26)
            .frame(height: 44)
            .background(pillFill(mode), in: Capsule())
            .contentShape(Capsule())
        }
        .disabled(!mode.enabled)
        .accessibilityLabel(mode.label)
    }

    private func pillFill(_ mode: PillMode) -> Color {
        if mode.neutral {
            return GSTheme.card.opacity(mode.enabled ? 1 : 0.7)
        }
        return mode.enabled ? GSTheme.accent : GSTheme.accent.opacity(0.45)
    }
}

#Preview("GS face v2") {
    GSFaceV2()
        .environmentObject(PrototypeStateStore.shared)
        .padding(30)
        .background(Color.black)
}

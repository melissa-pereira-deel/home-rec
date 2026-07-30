import SwiftUI

/// Glass v2 — the Glass concept's foundation kept whole (frosted panel, flat
/// record pill, notice slot, shelf, onboarding sheet) with exactly two changes
/// on the recorder screen:
///
/// 1. The waveform card is replaced by the Pocket Operator's LCD panel,
///    showing the same capture on the PO's phosphor bed (`GLWaveLCD`).
/// 2. The brand mark sits beside the wordmark in the header.
///
/// The library is untouched — `GLLibrary` is `GSLibrary`, so an expanded take
/// still opens the familiar bar waveform and player. The LCD is a *live
/// capture* treatment, not a new language for stored takes.
struct GLFace: View {
    @EnvironmentObject private var store: PrototypeStateStore
    @State private var showSettings = false

    var body: some View {
        ZStack {
            GSTheme.backdrop
            panel
                .padding(22)
                .blur(radius: store.showOnboarding ? 12 : 0)
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

    // MARK: - Header: mark + wordmark

    private var header: some View {
        // 8pt gap = the site's 10/24 lockup ratio at a 20pt mark.
        HStack(spacing: 8) {
            brandMark
            GSBrand.wordmark(size: 13)
                .foregroundStyle(.white.opacity(0.95))
            Spacer()
            GSTheme.mono(store.selectedFormat.rawValue + " · 48kHz")
            settingsButton
        }
    }

    /// The site's mark, drawn. 20pt against the 13pt wordmark holds the
    /// lockup ratio homerec.app uses in its nav (24 / 15).
    private var brandMark: some View {
        GSBrandMark(size: 20)
    }

    // MARK: - Settings

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
        .disabled(locked)
        .help("New recordings are saved as \(format.rawValue.uppercased()). This can't change while recording.")
        .accessibilityLabel("format \(format.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Centerpiece: timer + LCD panel + the flat record pill

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

            lcdPanel

            GSFlatRecordButton()
        }
    }

    private var timerValue: TimeInterval {
        switch store.transport {
        case .saved(let recording): recording.duration
        case .recording, .stopping: store.elapsed
        default: store.lastTakeDuration ?? store.elapsed
        }
    }

    /// Same four states the Glass waveform card carried — live, frozen,
    /// materialised, at rest — spoken in segments instead of bars.
    @ViewBuilder
    private var lcdPanel: some View {
        switch store.transport {
        case .recording:
            GLWaveLCD(samples: store.liveSamples, scrolling: true)
        case .stopping:
            // The last live frame held and dimmed, as in Glass: the capture
            // must not blank in the gap between recording and saved.
            GLWaveLCD(samples: store.liveSamples, scrolling: true, intensity: 0.45)
        case .saved(let recording):
            GLWaveLCD(samples: recording.samples, scrolling: false)
                .transition(.opacity)
        default:
            // At rest, Glass's flat 0.05 waveform — the screen is on and
            // ready, not blank.
            GLWaveLCD(samples: Array(repeating: 0.05, count: 96), scrolling: false)
        }
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

#Preview("GL face") {
    GLFace()
        .environmentObject(PrototypeStateStore.shared)
        .padding(30)
        .background(Color.black)
}

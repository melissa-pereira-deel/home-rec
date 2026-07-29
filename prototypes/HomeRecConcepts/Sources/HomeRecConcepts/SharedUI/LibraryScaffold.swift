import SwiftUI

/// The shared library structure every concept skins: rows with identity
/// waveforms and monospace metadata, an expanded inline player (waveform,
/// timecode chip, tick-ruler scrub, version stack), chip filters, and the
/// lowercase empty state. The untitled.stream DNA, as shared code.
struct LibraryScaffold<Header: View>: View {
    @EnvironmentObject private var store: PrototypeStateStore
    let style: LibraryStyle
    var chips: [LibraryChip] = []
    @ViewBuilder let header: () -> Header

    @State private var activeChip = 0

    var body: some View {
        VStack(spacing: 12) {
            header()
            if !chips.isEmpty { chipRow }
            if filtered.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { recording in
                            if store.selectedRecordingID == recording.id {
                                expandedRow(recording)
                            } else {
                                row(recording)
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }

    private var filtered: [FakeRecording] {
        guard !chips.isEmpty else { return store.library }
        return store.library.filter(chips[activeChip].matches)
    }

    // MARK: - Chips

    private var chipRow: some View {
        HStack(spacing: 6) {
            ForEach(Array(chips.enumerated()), id: \.offset) { index, chip in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { activeChip = index }
                } label: {
                    Text(chip.label)
                        .font(.custom("Inter", size: 12, relativeTo: .caption))
                        .foregroundStyle(
                            index == activeChip ? style.title : style.meta
                        )
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(
                            index == activeChip
                                ? AnyShapeStyle(style.rowFill)
                                : AnyShapeStyle(style.rowFill.opacity(0.35)),
                            in: Capsule()
                        )
                        .overlay(Capsule().strokeBorder(style.rowStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Rows

    private func row(_ recording: FakeRecording) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                store.select(recording)
            }
        } label: {
            HStack(spacing: 12) {
                BarWaveform(samples: recording.samples, accent: style.thumb, progress: nil)
                    .frame(width: 96, height: 28)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        style.titleText(recording.name)
                            .lineLimit(1)
                        if recording.versionCount > 1 {
                            style.metaText("v\(recording.versionCount)", size: 9)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .overlay(Capsule().strokeBorder(style.meta.opacity(0.5), lineWidth: 1))
                        }
                    }
                    style.metaText(recording.specLine)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    style.metaText(Formatters.relative(recording.date))
                    style.metaText(Formatters.timecode(recording.duration))
                        .opacity(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(style.rowFill, in: RoundedRectangle(cornerRadius: style.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .strokeBorder(style.rowStroke, lineWidth: 1)
            )
            .shadow(color: style.rowShadow, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded player

    private func expandedRow(_ recording: FakeRecording) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title row: tap to collapse.
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    store.deselect()
                }
            } label: {
                HStack(spacing: 6) {
                    style.titleText(recording.name, size: 14)
                    Spacer()
                    style.metaText(Formatters.relative(recording.date))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            style.metaText(recording.specLine)

            // Player: waveform + floating timecode + scrub ruler.
            VStack(spacing: 8) {
                BarWaveform(
                    samples: recording.samples,
                    accent: style.accent,
                    progress: store.playbackProgress
                )
                .frame(height: 72)
                .overlay(alignment: .top) {
                    TimecodeChip(
                        time: store.playbackProgress * recording.duration,
                        progress: store.playbackProgress
                    )
                    .offset(y: -8)
                }
                TickRuler(
                    value: Binding(
                        get: { store.playbackProgress },
                        set: { store.scrub(to: $0) }
                    ),
                    accent: style.accent,
                    tickColor: style.meta,
                    onEditingChanged: { editing in
                        editing ? store.beginScrub() : store.endScrub()
                    }
                )
            }

            // Transport: flat pill, same register as the Glass record button.
            HStack(spacing: 12) {
                FlatPillButton(action: { store.togglePlayback(for: recording) }) {
                    HStack(spacing: 7) {
                        Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(store.isPlaying ? "pause" : "play")
                            .font(.custom("Inter", size: 12, relativeTo: .caption))
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(style.accentLabel)
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                    .background(style.accent, in: Capsule())
                    .contentShape(Capsule())
                }
                style.metaText(
                    Formatters.timecode(store.playbackProgress * recording.duration)
                        + " / " + Formatters.timecode(recording.duration)
                )
                Spacer()
            }

            if recording.versionCount > 1 {
                versionStack(recording)
            }
        }
        .padding(14)
        .background(style.rowFill, in: RoundedRectangle(cornerRadius: style.cornerRadius + 2))
        .overlay(
            RoundedRectangle(cornerRadius: style.cornerRadius + 2)
                .strokeBorder(style.accent.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: style.rowShadow, radius: 6, y: 3)
    }

    /// Older takes stacked under the active one, untitled-style.
    private func versionStack(_ recording: FakeRecording) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            style.metaText("versions", size: 9)
                .opacity(0.7)
            ForEach((1...recording.versionCount).reversed(), id: \.self) { version in
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(style.meta.opacity(0.35))
                        .frame(width: 10, height: 1)
                    style.metaText("v\(version)")
                    style.metaText(
                        Formatters.timecode(fakeVersionDuration(recording, version: version))
                    )
                    .opacity(0.7)
                    if version == recording.versionCount {
                        style.metaText("active", size: 9)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .overlay(Capsule().strokeBorder(style.accent.opacity(0.6), lineWidth: 1))
                            .foregroundStyle(style.accent)
                    }
                    Spacer()
                }
                .padding(.leading, 4)
            }
        }
        .padding(.top, 2)
    }

    /// Deterministic fake durations for older versions.
    private func fakeVersionDuration(_ recording: FakeRecording, version: Int) -> TimeInterval {
        guard version < recording.versionCount else { return recording.duration }
        let wobble = LevelSynth.rand(UInt64(recording.name.count &+ version &* 37))
        return max(5, recording.duration * (0.7 + 0.5 * wobble))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            style.titleText("nothing here yet.")
            style.metaText("record something.")
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// Flat pill control — the untitled/Spotify register shared by the Glass
/// record button and the library transport: subtle scale on hover (1.03)
/// and press (0.97), slight darken on press, no chrome.
struct FlatPillButton<Label: View>: View {
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(FlatPillPressStyle())
        .scaleEffect(hovering ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.12), value: hovering)
        .onHover { hovering = $0 }
    }
}

struct FlatPillPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

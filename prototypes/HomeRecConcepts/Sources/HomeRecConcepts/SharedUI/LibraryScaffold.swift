import SwiftUI

/// The shared library structure every concept skins: rows with identity
/// waveforms and monospace metadata, an expanded inline player (waveform,
/// timecode chip, tick-ruler scrub), chip filters, and the
/// lowercase empty state. The untitled.stream DNA, as shared code.
struct LibraryScaffold<Header: View>: View {
    @EnvironmentObject private var store: PrototypeStateStore
    let style: LibraryStyle
    var showsChips: Bool = false
    @ViewBuilder let header: () -> Header

    var body: some View {
        VStack(spacing: 12) {
            header()
            if showsChips { chipRow }
            if filtered.isEmpty {
                store.library.isEmpty ? AnyView(emptyState) : AnyView(noMatchesState)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(filtered) { recording in
                                Group {
                                    if store.pendingDeleteID == recording.id {
                                        deleteConfirmRow(recording)
                                    } else if store.selectedRecordingID == recording.id {
                                        expandedRow(recording)
                                    } else {
                                        row(recording)
                                    }
                                }
                                .id(recording.id)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    .onChange(of: store.scrollTargetID) { _, target in
                        guard let target else { return }
                        proxy.scrollTo(target, anchor: .center)
                    }
                    .onAppear {
                        // Target may have been set before this scaffold mounted
                        // (screen switch + scroll in the same store update).
                        guard let target = store.scrollTargetID else { return }
                        DispatchQueue.main.async {
                            proxy.scrollTo(target, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private var filtered: [FakeRecording] {
        showsChips ? store.filteredLibrary : store.library
    }

    // MARK: - Chips

    private var chipRow: some View {
        HStack(spacing: 6) {
            ForEach(Array(LibraryFilter.chips.enumerated()), id: \.offset) { _, chip in
                let isActive = store.libraryFilter == chip
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        store.libraryFilter = chip
                    }
                } label: {
                    Text(chip.label)
                        .font(.custom("Inter", size: 12, relativeTo: .caption))
                        .foregroundStyle(isActive ? style.title : style.meta)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(
                            isActive
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
                        if store.renamingID == recording.id {
                            LibraryRenameField(recording: recording, style: style)
                        } else {
                            style.titleText(store.displayName(for: recording))
                                .lineLimit(1)
                        }
                    }
                    style.metaText(recording.specLine)
                        .lineLimit(1)
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
        .contextMenu {
            Button("Reveal in Finder") { /* fake */ }
            Button("Rename") { store.renamingID = recording.id }
            Button("Copy path") { /* fake */ }
            Divider()
            Button("Delete", role: .destructive) {
                store.pendingDeleteID = recording.id
            }
        }
    }

    /// Inline destructive confirm — the row morphs; no NSAlert (capturable,
    /// and stays in the glass register).
    private func deleteConfirmRow(_ recording: FakeRecording) -> some View {
        HStack(spacing: 10) {
            style.titleText("delete \"\(store.displayName(for: recording))\"?")
                .lineLimit(1)
            Spacer(minLength: 8)
            FlatPillButton(action: { store.delete(id: recording.id) }) {
                Text("delete")
                    .font(.custom("Inter", size: 11, relativeTo: .caption))
                    .fontWeight(.semibold)
                    .foregroundStyle(style.accentLabel)
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(style.accent, in: Capsule())
                    .contentShape(Capsule())
            }
            FlatPillButton(action: { store.pendingDeleteID = nil }) {
                Text("keep")
                    .font(.custom("Inter", size: 11, relativeTo: .caption))
                    .fontWeight(.semibold)
                    .foregroundStyle(style.title)
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(style.rowFill.opacity(0.8), in: Capsule())
                    .overlay(Capsule().strokeBorder(style.rowStroke, lineWidth: 1))
                    .contentShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(style.rowFill, in: RoundedRectangle(cornerRadius: style.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .strokeBorder(style.accent.opacity(0.5), lineWidth: 1)
        )
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
                    style.titleText(store.displayName(for: recording), size: 14)
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
                        progress: store.playbackProgress,
                        duration: recording.duration
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
                // Policy C: playback during a capture is monitoring — the
                // app excludes its own audio from the stream, so it is
                // provably not in the recording. Say so.
                if store.transport.isRecording, store.isPlaying {
                    style.metaText("monitoring · not recorded", size: 9)
                        .fixedSize()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .overlay(Capsule().strokeBorder(style.meta.opacity(0.4), lineWidth: 1))
                }
                Spacer()
            }

            // One-time explainer, first playback during a capture.
            if store.transport.isRecording, store.isPlaying,
               !store.monitorExplainerDismissed {
                HStack(spacing: 8) {
                    style.metaText(
                        "playback here is monitoring only — home rec excludes its own audio from the capture, so it won't be in your recording.",
                        size: 10
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button {
                        store.monitorExplainerDismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(style.meta)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("dismiss")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(style.rowFill.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
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

    /// A filtered-out library is NOT an empty library — different state,
    /// different words, and a way back.
    private var noMatchesState: some View {
        VStack(spacing: 10) {
            Spacer()
            style.titleText("no \(store.libraryFilter.label) takes.")
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    store.libraryFilter = .all
                }
            } label: {
                style.metaText("show all", size: 11)
                    .underline()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// Inline rename: title becomes a text field; return commits, escape cancels.
private struct LibraryRenameField: View {
    @EnvironmentObject private var store: PrototypeStateStore
    let recording: FakeRecording
    let style: LibraryStyle

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $draft)
            .textFieldStyle(.plain)
            .font(.custom("Inter", size: 13, relativeTo: .body))
            .foregroundStyle(style.title)
            .focused($focused)
            .onAppear {
                draft = recording.name
                focused = true
            }
            .onSubmit { store.rename(id: recording.id, to: draft) }
            .onExitCommand { store.renamingID = nil }
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
            // Scale the visual only — the hit region must stay constant or
            // the pill jitters at its own boundary.
            label()
                .scaleEffect(hovering ? 1.03 : 1.0)
                .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .buttonStyle(FlatPillPressStyle())
        .onHover { isHovering in
            if isHovering, !hovering { NSCursor.pointingHand.push() }
            if !isHovering, hovering { NSCursor.pop() }
            hovering = isHovering
        }
        .onDisappear {
            if hovering {
                NSCursor.pop()
                hovering = false
            }
        }
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

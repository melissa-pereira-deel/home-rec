import SwiftUI

/// The specimen sheet: every token, primitive, component and state in one
/// scrollable surface.
///
/// This is how the kit is reviewed and how it is verified. A component that
/// isn't in the gallery is a component nobody has looked at in every state it
/// can reach — so when you add one, add it here in the same commit.
///
/// ```swift
/// WindowGroup { GlassKitGallery() }
/// ```
public struct GlassKitGallery: View {
    public init() {}

    public var body: some View {
        ZStack {
            GlassBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: GlassSpacing.xxxl) {
                    header
                    GalleryColorSection()
                    GalleryTypeSection()
                    GallerySpaceSection()
                    GalleryElevationSection()
                    GalleryMotionSection()
                    GalleryPrimitivesSection()
                    GalleryTransportSection()
                    GalleryTimecodeSection()
                    GalleryWaveformSection()
                    GalleryLibrarySection()
                    GalleryNoticeSection()
                    GalleryOnboardingSection()
                    GalleryPatternSection()
                }
                .padding(GlassSpacing.xxl)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .glassThemeAdaptingToContrast()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: GlassSpacing.sm) {
            Text(GlassKit.name)
                .glassText(.wordmark, color: .textPrimary)
            GlassMetaLabel("version \(GlassKit.version) · specimen sheet · dark only, by intent")
        }
    }
}

// MARK: - Chrome

/// A titled chapter of the sheet.
struct GalleryChapter<Content: View>: View {
    let title: String
    var note: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: GlassSpacing.md) {
            VStack(alignment: .leading, spacing: GlassSpacing.xs) {
                Text(title)
                    .glassText(.appTitle, color: .textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let note {
                    Text(note)
                        .glassText(.captionSmall, color: .textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            GlassDivider()
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GlassSpacing.xl)
        .glassSurface(.panel)
    }
}

/// One labelled specimen.
struct GallerySpecimen<Content: View>: View {
    let label: String
    var note: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: GlassSpacing.sm) {
            HStack(spacing: GlassSpacing.s) {
                GlassMetaLabel(label)
                if let note {
                    GlassMetaLabel(note, role: .metaSmall)
                        .opacity(0.7)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tokens · colour

struct GalleryColorSection: View {
    @Environment(\.glassTheme) private var theme

    var body: some View {
        GalleryChapter(
            title: "Colour",
            note: "Roles, not names. Contrast measured against the card surface (#1C1C1E); on the lighter panel every ratio drops ~12% and still clears AA for its use."
        ) {
            VStack(spacing: GlassSpacing.s) {
                ForEach(GlassColorSpec.all) { spec in
                    HStack(spacing: GlassSpacing.md) {
                        RoundedRectangle(cornerRadius: GlassRadius.control, style: .continuous)
                            .fill(theme.colors[spec.role])
                            .frame(width: 44, height: 28)
                            .overlay {
                                RoundedRectangle(cornerRadius: GlassRadius.control, style: .continuous)
                                    .strokeBorder(theme.colors.line, lineWidth: theme.metrics.hairline)
                            }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(spec.role.rawValue).glassText(.caption, color: .textPrimary)
                            GlassMetaLabel(spec.usage, role: .metaSmall)
                        }
                        Spacer(minLength: GlassSpacing.s)
                        VStack(alignment: .trailing, spacing: 1) {
                            GlassMetaLabel(spec.value)
                            GlassMetaLabel(
                                spec.contrastOnCard.map { String(format: "%.1f:1", $0) } ?? "—",
                                role: .metaSmall
                            )
                            .opacity(0.7)
                        }
                    }
                    .padding(.horizontal, GlassSpacing.md)
                    .padding(.vertical, GlassSpacing.s)
                    .glassSurface(.inner)
                }
            }
        }
    }
}

// MARK: - Tokens · type

struct GalleryTypeSection: View {
    @Environment(\.glassTheme) private var theme

    var body: some View {
        GalleryChapter(
            title: "Type",
            note: "Three registers: Inter for language, SF Mono for machine-produced data, Archivo for the wordmark. Sizes scale with Dynamic Type except where a role caps itself."
        ) {
            VStack(alignment: .leading, spacing: GlassSpacing.md) {
                ForEach(GlassTextRole.allCases, id: \.self) { role in
                    let style = theme.typography.style(role)
                    VStack(alignment: .leading, spacing: GlassSpacing.xxs) {
                        Text(sample(for: role))
                            .glassText(role, color: .textPrimary)
                            .lineLimit(1)
                        GlassMetaLabel(
                            "\(role.rawValue) · \(Int(style.size))pt · \(weightName(style.weight)) · "
                                + (style.family.name ?? "mono")
                                + (style.maxScale < 2 ? " · max ×\(String(format: "%.1f", style.maxScale))" : "")
                                + (style.tracking != 0 ? " · tracking \(style.tracking)" : ""),
                            role: .metaSmall
                        )
                    }
                }
            }
        }
    }

    private func sample(for role: GlassTextRole) -> String {
        switch role {
        case .wordmark, .appTitle: "home rec"
        case .timer: "1:12:03"
        case .timerCompact: "0:08.7"
        case .meta, .metaSmall: "48kHz · 16-bit · wav · 26.4MB"
        case .timecodeChip: "0:18.3"
        case .control, .controlCompact: "record"
        default: "kitchen radio, morning"
        }
    }

    private func weightName(_ weight: Font.Weight) -> String {
        switch weight {
        case .light: "light"
        case .medium: "medium"
        case .semibold: "semibold"
        case .bold: "bold"
        default: "regular"
        }
    }
}

// MARK: - Tokens · space + radius

struct GallerySpaceSection: View {
    @Environment(\.glassTheme) private var theme

    var body: some View {
        GalleryChapter(
            title: "Space & radius",
            note: "A dense band (2–14) for content rhythm and an architectural band (18–28) for containers. Nested radii stay concentric: outer radius minus the padding between them."
        ) {
            VStack(alignment: .leading, spacing: GlassSpacing.md) {
                GallerySpecimen(label: "spacing scale") {
                    VStack(alignment: .leading, spacing: GlassSpacing.xs) {
                        ForEach(GlassSpacing.all, id: \.name) { step in
                            HStack(spacing: GlassSpacing.s) {
                                GlassMetaLabel(step.name, role: .metaSmall)
                                    .frame(width: 40, alignment: .leading)
                                Rectangle()
                                    .fill(theme.colors.accent)
                                    .frame(width: step.value, height: 8)
                                GlassMetaLabel("\(Int(step.value))pt", role: .metaSmall)
                                    .opacity(0.7)
                            }
                        }
                    }
                }
                GallerySpecimen(label: "radii") {
                    HStack(spacing: GlassSpacing.m) {
                        ForEach(GlassRadius.all, id: \.name) { radius in
                            VStack(spacing: GlassSpacing.xs) {
                                RoundedRectangle(cornerRadius: radius.value, style: .continuous)
                                    .fill(theme.colors.surfaceCard)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: radius.value, style: .continuous)
                                            .strokeBorder(theme.colors.lineStrong, lineWidth: theme.metrics.hairline)
                                    }
                                    .frame(width: 62, height: 48)
                                GlassMetaLabel("\(radius.name) \(Int(radius.value))", role: .metaSmall)
                            }
                        }
                        VStack(spacing: GlassSpacing.xs) {
                            Capsule()
                                .fill(theme.colors.surfaceCard)
                                .overlay { Capsule().strokeBorder(theme.colors.lineStrong, lineWidth: theme.metrics.hairline) }
                                .frame(width: 62, height: 48)
                            GlassMetaLabel("pill", role: .metaSmall)
                        }
                    }
                }
                GallerySpecimen(label: "hit targets", note: "28pt minimum, grown invisibly under smaller visuals") {
                    HStack(spacing: GlassSpacing.m) {
                        GlassMetaLabel("mini pill 26pt visual / 28pt target", role: .metaSmall)
                        GlassPillButton("keep", variant: .neutral, size: .mini) {}
                        GlassIconButton(systemImage: "xmark", accessibilityLabel: "dismiss") {}
                    }
                }
            }
        }
    }
}

// MARK: - Tokens · elevation + material

struct GalleryElevationSection: View {
    @Environment(\.glassTheme) private var theme

    var body: some View {
        GalleryChapter(
            title: "Elevation & material",
            note: "Depth is carried by shadow, edge-light and material together. A level that changes only one of the three reads as a bug."
        ) {
            VStack(alignment: .leading, spacing: GlassSpacing.md) {
                GallerySpecimen(label: "elevation") {
                    HStack(spacing: GlassSpacing.l) {
                        ForEach(GlassElevation.allCases, id: \.self) { level in
                            VStack(spacing: GlassSpacing.xs) {
                                RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous)
                                    .fill(theme.colors.surfaceCard)
                                    .frame(width: 92, height: 52)
                                    .glassElevation(level)
                                GlassMetaLabel(level.rawValue, role: .metaSmall)
                            }
                        }
                    }
                }
                GallerySpecimen(label: "surfaces") {
                    VStack(spacing: GlassSpacing.s) {
                        ForEach(Array(GlassSurfaceSpecimen.all.enumerated()), id: \.offset) { _, specimen in
                            HStack {
                                GlassMetaLabel(specimen.name)
                                Spacer()
                            }
                            .padding(GlassSpacing.md)
                            .glassSurface(specimen.style)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Tokens · motion

struct GalleryMotionSection: View {
    @State private var isToggled = false
    @Environment(\.glassTheme) private var theme

    var body: some View {
        GalleryChapter(
            title: "Motion",
            note: "Motion makes a state change legible and does nothing else. Under Reduce Motion, position and scale are removed and opacity is kept — the change still reads, it just doesn't travel."
        ) {
            VStack(alignment: .leading, spacing: GlassSpacing.md) {
                ForEach(GlassMotionToken.allCases, id: \.self) { token in
                    HStack(spacing: GlassSpacing.md) {
                        GlassMetaLabel(token.rawValue).frame(width: 92, alignment: .leading)
                        Circle()
                            .fill(theme.colors.accent)
                            .frame(width: 12, height: 12)
                            .offset(x: isToggled ? 120 : 0)
                            .glassAnimation(token, value: isToggled)
                        Spacer()
                        GlassMetaLabel(describe(token), role: .metaSmall).opacity(0.7)
                    }
                }
                GlassPillButton("play motion", variant: .neutral, size: .mini) { isToggled.toggle() }
                GlassDivider()
                GallerySpecimen(label: "transport timings", note: "state durations, not curves") {
                    VStack(alignment: .leading, spacing: GlassSpacing.xxs) {
                        GlassMetaLabel("arming ≥ \(Int(GlassTransportTiming.minimumArming * 1000))ms", role: .metaSmall)
                        GlassMetaLabel("stopping ≥ \(Int(GlassTransportTiming.minimumStopping * 1000))ms", role: .metaSmall)
                        GlassMetaLabel("saved dwell \(String(format: "%.1f", GlassTransportTiming.savedDwell))s — armed throughout", role: .metaSmall)
                    }
                }
            }
        }
    }

    private func describe(_ token: GlassMotionToken) -> String {
        switch token {
        case .press: "0.10s easeOut"
        case .hover: "0.12s easeOut"
        case .quick: "0.15s easeOut"
        case .swap: "0.18s easeOut"
        case .reveal: "0.20s easeOut"
        case .expand: "spring 0.35 / 0.80"
        case .materialize: "spring 0.40 / 0.75"
        case .playhead: "linear 1/30s"
        }
    }
}

// MARK: - Primitives

struct GalleryPrimitivesSection: View {
    @State private var chipSelection = "wav"

    var body: some View {
        GalleryChapter(
            title: "Primitives",
            note: "Atoms. Every one is style-driven — none of them knows what screen it is on."
        ) {
            VStack(alignment: .leading, spacing: GlassSpacing.l) {
                ForEach(GlassPillSize.allCases, id: \.self) { size in
                    GallerySpecimen(label: "pill · \(size.rawValue)") {
                        HStack(spacing: GlassSpacing.m) {
                            GlassPillButton("record", systemImage: "circle.fill", variant: .solid, size: size) {}
                            GlassPillButton("neutral", variant: .neutral, size: size) {}
                            GlassPillButton("ghost", variant: .ghost, size: size) {}
                            GlassPillButton("warn", variant: .solidTinted(GlassColors.standard.statusWarning), size: size) {}
                            GlassPillButton("disabled", variant: .solid, size: size) {}.disabled(true)
                            GlassPillButton("disabled", variant: .neutral, size: size) {}.disabled(true)
                        }
                    }
                }

                GallerySpecimen(label: "chip", note: "hover and selected states are live") {
                    VStack(alignment: .leading, spacing: GlassSpacing.s) {
                        GlassFilterChipBar(
                            options: [
                                .init(id: "all", label: "all"),
                                .init(id: "wav", label: "wav"),
                                .init(id: "m4a", label: "m4a"),
                                .init(id: "flac", label: "flac"),
                                .init(id: "week", label: "this week"),
                            ],
                            selection: $chipSelection
                        )
                        HStack(spacing: GlassSpacing.sm) {
                            GlassChip("wav", isSelected: true) {}
                            GlassChip(
                                "flac",
                                isSelected: false,
                                help: GlassTransportPermissions.formatLockReason(.recording(startedAt: .now))
                            ) {}
                            .disabled(true)
                            GlassMetaLabel("locked during capture · disabled with a reason, never hidden", role: .metaSmall)
                        }
                    }
                }

                GallerySpecimen(label: "badge · pulse dot") {
                    HStack(spacing: GlassSpacing.m) {
                        GlassBadge("wav")
                        GlassBadge("active", tint: .textAccent)
                        GlassBadge("new", style: .filled, tint: .accent)
                        GlassMonitoringBadge()
                        GlassPulseDot()
                        GlassPulseDot(isAnimating: false)
                    }
                }

                GallerySpecimen(label: "labels") {
                    VStack(alignment: .leading, spacing: GlassSpacing.sm) {
                        GlassEyebrow("recent")
                        GlassMetaLabel("48kHz · 16-bit · wav · 26.4MB")
                        Text("kitchen radio, morning").glassText(.body, color: .textPrimary)
                        GlassDivider()
                    }
                }

                GallerySpecimen(label: "icon button · nav link", note: "≥28pt targets") {
                    HStack(spacing: GlassSpacing.l) {
                        GlassIconButton(
                            systemImage: "slider.horizontal.3",
                            accessibilityLabel: "settings",
                            accessibilityHint: "Format and save location"
                        ) {}
                        GlassIconButton(systemImage: "xmark", accessibilityLabel: "dismiss") {}
                        GlassIconButton(systemImage: "play.fill", accessibilityLabel: "play") {}.disabled(true)
                        GlassNavLink("all takes →") {}
                        GlassNavLink("← record") {}
                    }
                }
            }
        }
    }
}

// MARK: - Transport

struct GalleryTransportSection: View {
    var body: some View {
        GalleryChapter(
            title: "Transport control",
            note: "One enum, nine presentations. Label, icon, fill and enablement are a pure function of state — there is no way to render a combination that can't happen."
        ) {
            VStack(alignment: .leading, spacing: GlassSpacing.md) {
                ForEach(Array(GlassTransportState.specimens.enumerated()), id: \.offset) { _, specimen in
                    let presentation = specimen.state.presentation()
                    HStack(spacing: GlassSpacing.l) {
                        VStack(alignment: .leading, spacing: 1) {
                            GlassMetaLabel(specimen.name)
                            GlassMetaLabel(
                                "\(presentation.intent.rawValue) · \(presentation.isEnabled ? "enabled" : "disabled")",
                                role: .metaSmall
                            )
                            .opacity(0.7)
                        }
                        .frame(width: 200, alignment: .leading)
                        GlassTransportControl(state: specimen.state) { _ in }
                        Spacer(minLength: 0)
                    }
                }
                GlassDivider()
                GalleryTransportDemo()
            }
        }
    }
}

/// A live run of the state machine, timings and all — the fastest way to see
/// that `saved` really is re-armable and that `arming` is really visible.
@MainActor
struct GalleryTransportDemo: View {
    @State private var state: GlassTransportState = .idle
    @State private var lastTakeDuration: TimeInterval = 0

    var body: some View {
        GallerySpecimen(label: "live machine", note: "press it — arming 250ms, saving 450ms, saved dwell 1.4s") {
            TimelineView(.animation(minimumInterval: 1.0 / 10.0, paused: !state.isCapturing)) { context in
                let elapsed = state.isRecording
                    ? GlassTransportMachine.elapsed(in: state, now: context.date)
                    : lastTakeDuration

                VStack(alignment: .leading, spacing: GlassSpacing.md) {
                    GlassTimecodeDisplay(time: elapsed, isLive: state.isRecording)
                    GlassTransportControl(state: state) { intent in run(intent) }
                    GlassRecordingBar(
                        state: state,
                        elapsed: elapsed,
                        samples: GlassSampleWaveforms.live(count: 60),
                        onStop: { run(.stopRecording) }
                    )
                }
            }
        }
    }

    private func run(_ intent: GlassTransportIntent) {
        switch intent {
        case .startRecording:
            apply(.primaryPressed)
            Task {
                try? await Task.sleep(for: .seconds(GlassTransportTiming.minimumArming))
                apply(.captureStarted(at: .now))
            }
        case .stopRecording:
            lastTakeDuration = GlassTransportMachine.elapsed(in: state)
            apply(.primaryPressed)
            Task {
                try? await Task.sleep(for: .seconds(GlassTransportTiming.minimumStopping))
                apply(.captureFinalized)
                try? await Task.sleep(for: .seconds(GlassTransportTiming.savedDwell))
                apply(.savedDwellElapsed)
            }
        case .openSystemSettings:
            apply(.permissionChanged(.openingSettings))
            Task {
                try? await Task.sleep(for: .seconds(2))
                apply(.permissionGranted)
            }
        case .revealInFinder, .none:
            break
        }
    }

    private func apply(_ event: GlassTransportEvent) {
        guard let next = GlassTransportMachine.next(from: state, on: event) else { return }
        state = next
    }
}

// MARK: - Timecode

struct GalleryTimecodeSection: View {
    var body: some View {
        GalleryChapter(
            title: "Timecode",
            note: "Width class is pinned to the recording's duration, so a moving readout never changes character count. VoiceOver hears \u{201C}one hour twelve minutes\u{201D}, not \u{201C}one twelve oh three\u{201D}."
        ) {
            VStack(alignment: .leading, spacing: GlassSpacing.md) {
                GallerySpecimen(label: "display · live") {
                    GlassTimecodeDisplay(time: 8.7, isLive: true)
                }
                GallerySpecimen(label: "display · dwelling on last take") {
                    GlassTimecodeDisplay(time: 154, isLive: false)
                }
                GallerySpecimen(label: "display · past an hour") {
                    GlassTimecodeDisplay(time: 4323, isLive: true)
                }
                GallerySpecimen(label: "width classes") {
                    VStack(alignment: .leading, spacing: GlassSpacing.xxs) {
                        ForEach(GlassTimecodeWidthClass.allCases, id: \.self) { widthClass in
                            GlassMetaLabel(
                                "\(widthClass.rawValue) · \(GlassTimecode.string(4323, widthClass: widthClass)) · \(widthClass.characterCount) chars"
                            )
                        }
                    }
                }
                GallerySpecimen(label: "chip · clamps at both edges, stem stays true") {
                    VStack(spacing: GlassSpacing.m) {
                        ForEach([0.0, 0.42, 1.0], id: \.self) { progress in
                            GlassTimecodeChip(time: 4323 * progress, progress: progress, duration: 4323)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Waveform

struct GalleryWaveformSection: View {
    @State private var scrub = 0.42

    var body: some View {
        GalleryChapter(
            title: "Waveform & scrubbing",
            note: "A take's waveform is its identity: the thumbnail and the player are the same shape at two sizes, sampled nearest-neighbour so small sizes stay distinctive."
        ) {
            VStack(alignment: .leading, spacing: GlassSpacing.md) {
                GallerySpecimen(label: "player · progress") {
                    GlassWaveform(samples: GlassSampleWaveforms.identity(seed: 23), progress: scrub)
                        .frame(height: 72)
                }
                GallerySpecimen(label: "scrub ruler", note: "exposed to VoiceOver as a Slider") {
                    GlassScrubRuler(
                        value: $scrub,
                        accessibilityValue: { GlassTimecode.spoken($0 * 154) }
                    )
                }
                GallerySpecimen(label: "thumbnail · identity") {
                    HStack(spacing: GlassSpacing.m) {
                        ForEach([23, 41, 77, 91], id: \.self) { seed in
                            GlassWaveform(
                                samples: GlassSampleWaveforms.identity(seed: UInt64(seed)),
                                style: .thumbnail,
                                tint: .textPrimary
                            )
                            .frame(width: 96, height: 28)
                        }
                    }
                }
                GallerySpecimen(label: "live · accumulating") {
                    GlassLiveWaveform(samples: GlassSampleWaveforms.live(count: 60))
                        .frame(height: 44)
                }
                GallerySpecimen(label: "stopping · frozen and dimmed, never a flat line") {
                    GlassLiveWaveform(samples: GlassSampleWaveforms.live(count: 60), opacity: 0.45)
                        .frame(height: 44)
                }
                GallerySpecimen(label: "idle") {
                    GlassWaveform(samples: GlassWaveform.idleSamples(), style: .thumbnail, tint: .textPrimary)
                        .frame(height: 44)
                }
            }
        }
    }
}

// MARK: - Library

struct GalleryLibrarySection: View {
    @State private var progress = 0.44
    @State private var filter = "all"

    var body: some View {
        GalleryChapter(
            title: "Library",
            note: "Rows, player, filters, and the two empty states — which are two states, not one."
        ) {
            VStack(alignment: .leading, spacing: GlassSpacing.md) {
                ForEach(Array(GlassTakeRowMode.specimens.enumerated()), id: \.offset) { index, specimen in
                    GallerySpecimen(label: "row · \(specimen.name)") {
                        GlassTakeRow(
                            take: GlassSampleTakes.all[min(index, GlassSampleTakes.all.count - 1)],
                            mode: specimen.mode,
                            actions: GlassTakeRowActions(contextActions: [
                                .init("Reveal in Finder") {},
                                .init("Rename") {},
                                .init("Copy path") {},
                                .init("Delete", isDestructive: true) {},
                            ])
                        )
                    }
                }

                GallerySpecimen(label: "row · long name truncates, never wraps") {
                    GlassTakeRow(take: GlassSampleTakes.all[4])
                }

                GallerySpecimen(label: "player") {
                    GlassTakePlayer(
                        take: GlassSampleTakes.all[1],
                        progress: $progress,
                        isPlaying: true,
                        onPlayPause: {}
                    )
                }

                GallerySpecimen(label: "player · monitoring during a capture") {
                    GlassTakePlayer(
                        take: GlassSampleTakes.all[1],
                        progress: $progress,
                        isPlaying: true,
                        isMonitoring: true,
                        showsMonitoringExplainer: true,
                        onPlayPause: {}
                    )
                }

                GallerySpecimen(label: "filters") {
                    GlassFilterChipBar(
                        options: [
                            .init(id: "all", label: "all"),
                            .init(id: "wav", label: "wav"),
                            .init(id: "m4a", label: "m4a"),
                            .init(id: "flac", label: "flac"),
                            .init(id: "week", label: "this week"),
                        ],
                        selection: $filter
                    )
                }

                GallerySpecimen(label: "empty · nothing here yet") {
                    GlassEmptyState.nothingYet().frame(height: 72)
                }
                GallerySpecimen(label: "empty · nothing matches", note: "different sentence, and a way out") {
                    GlassEmptyState.noMatches(filterLabel: "m4a") {}.frame(height: 72)
                }
            }
        }
    }
}

// MARK: - Notices

struct GalleryNoticeSection: View {
    var body: some View {
        GalleryChapter(
            title: "Notices & recording bar",
            note: "Rows on the surface, never alerts — a menu-bar-only user never sees an alert. One slot, priority-ordered: error → warning → blocked → info."
        ) {
            VStack(alignment: .leading, spacing: GlassSpacing.md) {
                ForEach(GlassNoticeKind.allCases, id: \.self) { kind in
                    GallerySpecimen(label: "notice · \(kind)") {
                        GlassNoticeRow(sample(for: kind))
                    }
                }

                GallerySpecimen(label: "slot · three notices queued, error takes it") {
                    GlassNoticeSlot(notices: GlassNoticeKind.allCases.map(sample(for:))) {
                        GlassEyebrow("recent")
                    }
                }

                ForEach(Array(barStates.enumerated()), id: \.offset) { _, entry in
                    GallerySpecimen(label: "recording bar · \(entry.name)") {
                        GlassRecordingBar(
                            state: entry.state,
                            elapsed: entry.elapsed,
                            samples: GlassSampleWaveforms.live(count: 60),
                            onStop: {}
                        )
                    }
                }
            }
        }
    }

    private var barStates: [(name: String, state: GlassTransportState, elapsed: TimeInterval)] {
        [
            ("arming", .arming, 0),
            ("recording", .recording(startedAt: .now), 73.1),
            ("stopping", .stopping, 73.4),
        ]
    }

    private func sample(for kind: GlassNoticeKind) -> GlassNotice {
        switch kind {
        case .error:
            GlassNotice(
                id: "startFailed",
                kind: .error,
                message: "Home Rec couldn't start recording. Make sure some audio is playing, then try again.",
                actions: [.init("Try again") {}]
            )
        case .warning:
            GlassNotice(
                id: "longRecording",
                kind: .warning,
                message: "You've been recording for a while. Long recordings use a lot of disk space — about 10 MB per minute.",
                actions: [.init("Stop") {}, .init("Keep recording", emphasis: .secondary) {}],
                isDismissible: false
            )
        case .blocked:
            GlassNotice(
                id: "translocated",
                kind: .blocked,
                message: "Home Rec can't record from the disk image. Quit, drag it to your Applications folder, and open it from there.",
                isDismissible: false
            )
        case .info:
            GlassNotice(
                id: "saveFallback",
                kind: .info,
                message: "Your chosen save folder isn't available, so this recording is going to your Desktop instead. Recording continues.",
                actions: [.init("Choose folder…", emphasis: .secondary) {}]
            )
        }
    }
}

// MARK: - Onboarding

struct GalleryOnboardingSection: View {
    var body: some View {
        GalleryChapter(
            title: "Onboarding",
            note: "The conditional slot is a fixed 76pt in both states, so a permission landing mid-card never moves the primary button out from under the cursor."
        ) {
            VStack(alignment: .leading, spacing: GlassSpacing.md) {
                GallerySpecimen(label: "needs permission") {
                    GlassOnboardingCard(
                        state: .needsPermission(isOpeningSettings: false),
                        onOpenSettings: {},
                        onPrimary: {}
                    )
                }
                GallerySpecimen(label: "opening settings", note: "the published state the shipping app never bound") {
                    GlassOnboardingCard(
                        state: .needsPermission(isOpeningSettings: true),
                        onOpenSettings: {},
                        onPrimary: {}
                    )
                }
                GallerySpecimen(label: "granted") {
                    GlassOnboardingCard(state: .granted, onOpenSettings: {}, onPrimary: {})
                }
            }
        }
    }
}

// MARK: - Patterns

struct GalleryPatternSection: View {
    var body: some View {
        GalleryChapter(
            title: "Patterns",
            note: "The rules that aren't pixels. Encoded as code so a screen can ask instead of guessing."
        ) {
            VStack(alignment: .leading, spacing: GlassSpacing.l) {
                GallerySpecimen(label: "interaction table", note: "GlassTransportPermissions") {
                    VStack(alignment: .leading, spacing: GlassSpacing.xxs) {
                        HStack(spacing: GlassSpacing.m) {
                            GlassMetaLabel("state").frame(width: 190, alignment: .leading)
                            GlassMetaLabel("record").frame(width: 56, alignment: .leading)
                            GlassMetaLabel("stop").frame(width: 48, alignment: .leading)
                            GlassMetaLabel("play").frame(width: 48, alignment: .leading)
                            GlassMetaLabel("format").frame(width: 56, alignment: .leading)
                            GlassMetaLabel("⌘Q guard")
                        }
                        ForEach(Array(GlassTransportState.specimens.enumerated()), id: \.offset) { _, specimen in
                            HStack(spacing: GlassSpacing.m) {
                                GlassMetaLabel(specimen.name, role: .metaSmall)
                                    .frame(width: 190, alignment: .leading)
                                mark(GlassTransportPermissions.canRecord(specimen.state)).frame(width: 56, alignment: .leading)
                                mark(GlassTransportPermissions.canStop(specimen.state)).frame(width: 48, alignment: .leading)
                                mark(GlassTransportPermissions.canPlay(specimen.state)).frame(width: 48, alignment: .leading)
                                mark(GlassTransportPermissions.canChangeFormat(specimen.state)).frame(width: 56, alignment: .leading)
                                mark(GlassTransportPermissions.shouldGuardQuit(specimen.state))
                            }
                        }
                    }
                }

                GallerySpecimen(label: "recording visibility invariant", note: ".glassRecordingVisible(…)") {
                    VStack(spacing: GlassSpacing.s) {
                        GlassTakeRow(take: GlassSampleTakes.all[0])
                        GlassTakeRow(take: GlassSampleTakes.all[2])
                    }
                    .glassRecordingVisible(
                        state: .recording(startedAt: .now),
                        elapsed: 73.1,
                        samples: GlassSampleWaveforms.live(count: 60),
                        onStop: {}
                    )
                }

                GallerySpecimen(label: "monitoring policy", note: "playback during capture is allowed, and said out loud") {
                    VStack(alignment: .leading, spacing: GlassSpacing.s) {
                        GlassMonitoringBadge()
                        GlassMonitoringExplainer(onDismiss: {})
                    }
                }
            }
        }
    }

    private func mark(_ value: Bool) -> some View {
        GlassMetaLabel(value ? "✓" : "✕", color: value ? .statusSuccess : .textTertiary)
    }
}

#Preview("GlassKit gallery") {
    GlassKitGallery()
        .frame(width: 860, height: 900)
}

import SwiftUI

// MARK: - Data

/// The minimum a library row needs to know about a recording.
///
/// A protocol rather than a concrete type so a host can conform its own model
/// and skip a mapping layer — and so the kit never owns, invents, or assumes
/// anything about where takes come from.
public protocol GlassTakeRepresentable: Identifiable {
    /// The take's name, as a person would write it.
    var title: String { get }
    /// The machine's description: `48kHz · 16-bit · wav · 26.4MB`. Set in
    /// mono and truncated, never wrapped.
    var metadata: String { get }
    var duration: TimeInterval { get }
    /// Pre-formatted age (`2h`, `3d`, `11w`). Formatting is app policy —
    /// `GlassRelativeDate` implements the kit's quiet register if you want it.
    var timestamp: String { get }
    /// Downsampled amplitudes, 0…1. The take's identity: keep it stable, or
    /// rows stop being recognisable between launches.
    var waveform: [Float] { get }
    /// Number of versions in this take's stack. `1` hides the badge.
    var versionCount: Int { get }
}

/// A ready-made value type conforming to `GlassTakeRepresentable`.
public struct GlassTakeSummary: GlassTakeRepresentable, Identifiable, Hashable {
    public var id: String
    public var title: String
    public var metadata: String
    public var duration: TimeInterval
    public var timestamp: String
    public var waveform: [Float]
    public var versionCount: Int

    public init(
        id: String,
        title: String,
        metadata: String,
        duration: TimeInterval,
        timestamp: String,
        waveform: [Float],
        versionCount: Int = 1
    ) {
        self.id = id
        self.title = title
        self.metadata = metadata
        self.duration = duration
        self.timestamp = timestamp
        self.waveform = waveform
        self.versionCount = versionCount
    }
}

/// Relative dates in the kit's register: `2h`, `3d`, `11w`. Terse because the
/// column is 3 characters wide and the exact minute never mattered.
public enum GlassRelativeDate {
    public static func string(for date: Date, now: Date = .now) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<3600: return "\(max(1, Int(seconds / 60)))m"
        case ..<86_400: return "\(Int(seconds / 3600))h"
        case ..<604_800: return "\(Int(seconds / 86_400))d"
        default: return "\(Int(seconds / 604_800))w"
        }
    }
}

// MARK: - Mode

/// What a row is currently doing. Mutually exclusive by construction: a row
/// cannot be renaming *and* confirming a delete, and modelling it as one value
/// means it can never try.
public enum GlassTakeRowMode: Equatable {
    case idle
    /// The subject of the screen — expanded, or about to be.
    case selected
    /// Selected and playing. Distinct from `selected` because the row shows a
    /// live indicator and announces itself differently.
    case playing
    /// Inline rename. Return commits, Escape cancels.
    case renaming
    /// Inline destructive confirm. The row *morphs* rather than presenting a
    /// system alert: the confirmation stays in the register of the thing it is
    /// confirming, and it can't be dismissed by clicking somewhere unrelated.
    case confirmingDelete

    var isActive: Bool { self == .selected || self == .playing }
}

// MARK: - Actions

/// The row's callbacks. A struct with defaults rather than eight initialiser
/// arguments, so a read-only list is one line and a full-featured one is
/// still readable.
public struct GlassTakeRowActions {
    public var onActivate: () -> Void
    public var onRenameCommit: (String) -> Void
    public var onRenameCancel: () -> Void
    public var onDeleteConfirm: () -> Void
    public var onDeleteCancel: () -> Void
    public var contextActions: [GlassTakeRowContextAction]

    public init(
        onActivate: @escaping () -> Void = {},
        onRenameCommit: @escaping (String) -> Void = { _ in },
        onRenameCancel: @escaping () -> Void = {},
        onDeleteConfirm: @escaping () -> Void = {},
        onDeleteCancel: @escaping () -> Void = {},
        contextActions: [GlassTakeRowContextAction] = []
    ) {
        self.onActivate = onActivate
        self.onRenameCommit = onRenameCommit
        self.onRenameCancel = onRenameCancel
        self.onDeleteConfirm = onDeleteConfirm
        self.onDeleteCancel = onDeleteCancel
        self.contextActions = contextActions
    }
}

public struct GlassTakeRowContextAction: Identifiable {
    public let id = UUID()
    public let title: String
    public let isDestructive: Bool
    public let action: () -> Void

    public init(_ title: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isDestructive = isDestructive
        self.action = action
    }
}

// MARK: - Row

/// A library row: identity waveform, name, machine metadata, age, duration.
///
/// The column order is fixed and load-bearing. Waveform first because it is
/// how you find a take you can't name; name second; the two right-hand
/// columns are *age over duration*, both mono, both right-aligned, so the
/// list scans as a table without drawing one.
public struct GlassTakeRow<Take: GlassTakeRepresentable>: View {
    private let take: Take
    private let mode: GlassTakeRowMode
    private let actions: GlassTakeRowActions

    @Environment(\.glassTheme) private var theme
    @State private var isHovering = false
    @State private var renameDraft = ""
    @FocusState private var isRenameFocused: Bool

    public init(
        take: Take,
        mode: GlassTakeRowMode = .idle,
        actions: GlassTakeRowActions = GlassTakeRowActions()
    ) {
        self.take = take
        self.mode = mode
        self.actions = actions
    }

    public var body: some View {
        Group {
            switch mode {
            case .confirmingDelete: deleteConfirmation
            case .renaming: renameRow
            default: standardRow
            }
        }
        .glassAnimation(.expand, value: mode)
    }

    // MARK: Standard

    private var standardRow: some View {
        Button(action: actions.onActivate) {
            content
                .padding(.horizontal, GlassSpacing.md)
                .padding(.vertical, GlassSpacing.m - 1)
                .glassSurface(surface)
                .overlay(alignment: .leading) {
                    if isHovering && mode == .idle {
                        // Hover is a *hairline*, not a fill: a filled hover on
                        // a translucent row would read as selection, and this
                        // list already has a selected state.
                        RoundedRectangle(cornerRadius: GlassRadius.card, style: .continuous)
                            .strokeBorder(theme.colors.lineStrong, lineWidth: theme.metrics.hairline)
                    }
                }
        }
        .buttonStyle(.plain)
        .glassHover($isHovering)
        .glassAnimation(.hover, value: isHovering)
        .contextMenu { contextMenu }
        // One VoiceOver stop for the whole row. Reading a waveform, a name, a
        // spec line, an age and a duration as five separate elements makes a
        // 50-item library unnavigable.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(accessibilityTraits)
        .accessibilityHint(mode.isActive ? "" : "Opens the player for this take.")
    }

    private var content: some View {
        HStack(spacing: GlassSpacing.md) {
            GlassWaveform(
                samples: take.waveform,
                style: .thumbnail,
                tint: mode.isActive ? .accent : .textPrimary
            )
            .frame(
                width: theme.metrics.waveformThumbnailSize.width,
                height: theme.metrics.waveformThumbnailSize.height
            )
            .opacity(mode.isActive ? 1 : 0.8)

            VStack(alignment: .leading, spacing: GlassSpacing.xxs + 1) {
                HStack(spacing: GlassSpacing.sm) {
                    Text(take.title)
                        .glassText(.body, color: .textPrimary)
                        .lineLimit(1)
                    if take.versionCount > 1 {
                        GlassBadge("v\(take.versionCount)")
                    }
                    if mode == .playing {
                        GlassBadge("playing", tint: .textAccent)
                    }
                }
                GlassMetaLabel(take.metadata)
            }

            Spacer(minLength: GlassSpacing.s)

            VStack(alignment: .trailing, spacing: GlassSpacing.xxs + 1) {
                GlassMetaLabel(take.timestamp)
                GlassMetaLabel(
                    GlassTimecode.string(take.duration, matching: take.duration)
                )
                .opacity(0.7)
            }
        }
    }

    private var surface: GlassSurfaceStyle {
        mode.isActive ? .rowActive(tint: theme.colors.accent) : .row
    }

    // MARK: Rename

    /// Inline rename. The field replaces the title in place — the row doesn't
    /// grow, nothing below it moves, and the take you are renaming stays where
    /// your eye already is.
    private var renameRow: some View {
        HStack(spacing: GlassSpacing.md) {
            GlassWaveform(samples: take.waveform, style: .thumbnail, tint: .textPrimary)
                .frame(
                    width: theme.metrics.waveformThumbnailSize.width,
                    height: theme.metrics.waveformThumbnailSize.height
                )
            VStack(alignment: .leading, spacing: GlassSpacing.xxs + 1) {
                TextField("", text: $renameDraft)
                    .textFieldStyle(.plain)
                    .glassText(.body, color: .textPrimary)
                    .focused($isRenameFocused)
                    .onSubmit { actions.onRenameCommit(renameDraft) }
                    .onExitCommand { actions.onRenameCancel() }
                    .accessibilityLabel("Take name")
                GlassMetaLabel(take.metadata)
            }
            Spacer(minLength: GlassSpacing.s)
        }
        .padding(.horizontal, GlassSpacing.md)
        .padding(.vertical, GlassSpacing.m - 1)
        .glassSurface(.rowActive(tint: theme.colors.lineStrong))
        .onAppear {
            renameDraft = take.title
            isRenameFocused = true
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Delete

    /// The destructive confirm. Accent border and an accent `delete` pill; the
    /// safe choice (`keep`) is neutral and sits second, so the muscle-memory
    /// click lands on the reversible option.
    private var deleteConfirmation: some View {
        HStack(spacing: GlassSpacing.m) {
            Text("delete \u{201C}\(take.title)\u{201D}?")
                .glassText(.body, color: .textPrimary)
                .lineLimit(1)
            Spacer(minLength: GlassSpacing.s)
            GlassPillButton("delete", variant: .solid, size: .mini, action: actions.onDeleteConfirm)
            GlassPillButton("keep", variant: .neutral, size: .mini, action: actions.onDeleteCancel)
        }
        .padding(.horizontal, GlassSpacing.md)
        .padding(.vertical, GlassSpacing.md)
        .glassSurface(.rowActive(tint: theme.colors.accent))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Delete \(take.title)?")
    }

    // MARK: Context menu

    @ViewBuilder
    private var contextMenu: some View {
        ForEach(actions.contextActions) { action in
            if action.isDestructive {
                Divider()
                Button(action.title, role: .destructive, action: action.action)
            } else {
                Button(action.title, action: action.action)
            }
        }
    }

    // MARK: Accessibility

    private var accessibilityLabel: String {
        var parts = [take.title, GlassTimecode.spoken(take.duration), take.metadata, take.timestamp]
        if take.versionCount > 1 { parts.append("\(take.versionCount) versions") }
        if mode == .playing { parts.append("playing") }
        return parts.joined(separator: ", ")
    }

    private var accessibilityTraits: AccessibilityTraits {
        var traits: AccessibilityTraits = [.isButton]
        if mode.isActive { _ = traits.insert(.isSelected) }
        if mode == .playing { _ = traits.insert(.startsMediaSession) }
        return traits
    }
}

#Preview("Take row — every state") {
    GlassPreviewStage {
        VStack(spacing: GlassSpacing.s) {
            ForEach(Array(GlassTakeRowMode.specimens.enumerated()), id: \.offset) { index, specimen in
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
    }
}

extension GlassTakeRowMode {
    static let specimens: [(name: String, mode: GlassTakeRowMode)] = [
        ("idle", .idle),
        ("selected", .selected),
        ("playing", .playing),
        ("renaming", .renaming),
        ("confirmingDelete", .confirmingDelete),
    ]
}

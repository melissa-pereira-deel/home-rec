import SwiftUI

/// The primary control: one pill whose label, icon, fill and enablement are a
/// pure function of `GlassTransportState`.
///
/// ```swift
/// GlassTransportControl(state: model.transport) { intent in
///     switch intent {
///     case .startRecording:    model.record()
///     case .stopRecording:     model.stop()
///     case .openSystemSettings: model.openSettings()
///     case .revealInFinder:    model.revealApp()
///     case .none:              break
///     }
/// }
/// ```
///
/// The control never mutates state and never guesses. If a press should be
/// refused — a disk-full refusal, for instance — the host refuses it and
/// publishes a notice; the pill must not pre-emptively disable itself for a
/// condition it can't verify, because a disabled control with no explanation
/// is the worst state in the system.
public struct GlassTransportControl: View {
    private let state: GlassTransportState
    private let size: GlassPillSize
    private let copy: GlassTransportCopy
    private let action: (GlassTransportIntent) -> Void

    public init(
        state: GlassTransportState,
        size: GlassPillSize = .large,
        copy: GlassTransportCopy = .standard,
        action: @escaping (GlassTransportIntent) -> Void
    ) {
        self.state = state
        self.size = size
        self.copy = copy
        self.action = action
    }

    public var body: some View {
        let presentation = state.presentation(copy: copy)
        GlassPillButton(
            presentation.label,
            systemImage: presentation.symbolName,
            emphasis: presentation.isAccented ? .primary : .blocked,
            size: size,
            isLoading: presentation.isBusy
        ) {
            action(presentation.intent)
        }
        // A busy control is *not* disabled: "arming…" is the app working, not
        // the app refusing. Only genuinely unavailable states disable.
        .disabled(!presentation.isEnabled && !presentation.isBusy)
        // The label changes identity between states, so SwiftUI would
        // cross-fade a "record" → "stop" swap as two unrelated views. Keying
        // on the label makes the change a single, deliberate transition.
        .glassAnimation(.quick, value: presentation.label)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityHint(presentation.accessibilityHint ?? "")
    }
}

#Preview("Transport control — every state") {
    GlassPreviewStage {
        VStack(alignment: .leading, spacing: GlassSpacing.md) {
            ForEach(Array(GlassTransportState.specimens.enumerated()), id: \.offset) { _, specimen in
                HStack(spacing: GlassSpacing.l) {
                    Text(specimen.name)
                        .glassText(.meta, color: .textTertiary)
                        .frame(width: 150, alignment: .leading)
                    GlassTransportControl(state: specimen.state) { _ in }
                }
            }
        }
    }
}

// MARK: - Specimens

public extension GlassTransportState {
    /// Every state, named — used by the gallery and previews so a reviewer can
    /// see the whole machine at once rather than trusting that it was covered.
    static let specimens: [(name: String, state: GlassTransportState)] = [
        ("idle", .idle),
        ("arming", .arming),
        ("recording", .recording(startedAt: .now)),
        ("stopping", .stopping),
        ("saved", .saved),
        ("permission · notDetermined", .blockedByPermission(.notDetermined)),
        ("permission · denied", .blockedByPermission(.denied)),
        ("permission · openingSettings", .blockedByPermission(.openingSettings)),
        ("blockedByInstall", .blockedByInstall),
    ]
}

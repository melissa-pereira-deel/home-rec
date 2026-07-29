import SwiftUI

/// Notice surface for the Glass face. When something needs attention the
/// shelf yields its slot to this row — errors, the long-recording warning,
/// or the translocation block. All copy is VERBATIM from shipping.
/// Priority: error > long-recording > translocation.
struct GSErrorRow: View {
    @EnvironmentObject private var store: PrototypeStateStore

    /// Whether any notice wants the slot (drives the shelf swap in GSFaceV2).
    static func isActive(_ store: PrototypeStateStore) -> Bool {
        store.activeError != nil
            || store.longRecordingWarningVisible
            || store.translocationBlocked
    }

    var body: some View {
        Group {
            if let error = store.activeError {
                errorContent(error)
            } else if store.longRecordingWarningVisible {
                longRecordingContent
            } else if store.translocationBlocked {
                translocationContent
            }
        }
        .transition(.opacity)
    }

    // MARK: - Error + recovery

    private func errorContent(_ error: FakeRecorderError) -> some View {
        noticeCard(tint: GSTheme.accent) {
            VStack(alignment: .leading, spacing: 8) {
                messageText(error.message)
                HStack(spacing: 8) {
                    if let recovery = error.recoveryLabel {
                        miniPill(recovery, tint: GSTheme.accent) {
                            store.performRecovery()
                        }
                    }
                    miniPill("dismiss", tint: .white.opacity(0.25)) {
                        store.dismissError()
                    }
                    Spacer()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("recording problem")
        .accessibilityValue(error.message)
    }

    // MARK: - Long-recording warning (shipping "Still recording" alert)

    private var longRecordingContent: some View {
        noticeCard(tint: GSTheme.warnAmber) {
            VStack(alignment: .leading, spacing: 8) {
                messageText("You've been recording for a while. Long recordings use a lot of disk space — about 10 MB per minute.")
                HStack(spacing: 8) {
                    miniPill("Keep recording", tint: .white.opacity(0.25)) {
                        store.dismissLongRecordingWarning()
                    }
                    miniPill("Stop", tint: GSTheme.warnAmber) {
                        store.dismissLongRecordingWarning()
                        store.stop()
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Translocation block (terminal, no dismiss)

    private var translocationContent: some View {
        noticeCard(tint: .white.opacity(0.3)) {
            messageText("Home Rec can't record from the disk image. Quit, drag it to your Applications folder, and open it from there.")
        }
    }

    // MARK: - Chrome

    private func noticeCard(tint: Color, @ViewBuilder content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(GSTheme.card.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(tint.opacity(0.5), lineWidth: 1)
            )
    }

    private func messageText(_ text: String) -> some View {
        Text(text)
            .font(.custom("Inter", size: 11, relativeTo: .caption))
            .foregroundStyle(.white.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func miniPill(_ label: String, tint: Color, action: @escaping () -> Void) -> some View {
        FlatPillButton(action: action) {
            Text(label)
                .font(.custom("Inter", size: 11, relativeTo: .caption))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(tint, in: Capsule())
                .contentShape(Capsule())
        }
    }
}

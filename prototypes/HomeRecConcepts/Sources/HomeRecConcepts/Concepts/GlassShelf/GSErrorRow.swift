import SwiftUI

/// Notice surface for the Glass face. When something needs attention the
/// shelf yields its slot to this row — errors, the long-recording warning,
/// or the translocation block. All copy is VERBATIM from shipping.
/// Priority: error > long-recording > translocation.
///
/// Neutral by construction: the card is the same surface as every other card
/// and severity is carried by a small icon. A coloured border here put a
/// second red on a panel that already has the record pill, and made a
/// recoverable error read as a failure state. The primary action is a
/// near-white fill and always leads — never the dismiss.
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
        noticeCard(icon: "exclamationmark.circle.fill", iconColor: GSTheme.accent) {
            VStack(alignment: .leading, spacing: 8) {
                messageText(error.message)
                HStack(spacing: 8) {
                    if let recovery = error.recoveryLabel {
                        miniPill(recovery, prominent: true) {
                            store.performRecovery()
                        }
                    }
                    miniPill("dismiss", prominent: false) {
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
        noticeCard(icon: "exclamationmark.triangle.fill", iconColor: GSTheme.warnAmber) {
            VStack(alignment: .leading, spacing: 8) {
                messageText("You've been recording for a while. Long recordings use a lot of disk space — about 10 MB per minute.")
                HStack(spacing: 8) {
                    // Stop is the recommended action, so it leads.
                    miniPill("Stop", prominent: true) {
                        store.dismissLongRecordingWarning()
                        store.stop()
                    }
                    miniPill("Keep recording", prominent: false) {
                        store.dismissLongRecordingWarning()
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Translocation block (terminal, no dismiss)

    private var translocationContent: some View {
        noticeCard(icon: "hand.raised.fill", iconColor: GSTheme.textDim) {
            messageText("Home Rec can't record from the disk image. Quit, drag it to your Applications folder, and open it from there.")
        }
    }

    // MARK: - Chrome

    private func noticeCard(
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(iconColor)
                // Onto the first line's cap height; the glyph box is taller
                // than the 11pt caption beside it.
                .padding(.top, 1)
                .accessibilityHidden(true)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(GSTheme.card.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func messageText(_ text: String) -> some View {
        Text(text)
            .font(.custom("Inter", size: 11, relativeTo: .caption))
            .foregroundStyle(.white.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Emphasis is fill luminance — not hue, and not an outline.
    ///
    /// Neither pill is stroked. A 1px border is the first thing lost to a dim
    /// monitor, greyscale or a resized screenshot, and outline-vs-fill reads
    /// as two *kinds* of object rather than two ranks of one. Both are light
    /// greys; the recommended action is simply the brighter of the two, which
    /// survives all of the above. See `GlassButtonEmphasis` in GlassKit — this
    /// is the same rule, hand-rolled for the prototype.
    private func miniPill(
        _ label: String,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        FlatPillButton(action: action) {
            Text(label)
                .font(.custom("Inter", size: 11, relativeTo: .caption))
                .fontWeight(.semibold)
                // Dark ink on both: 17:1 on the near-white, 13:1 on the grey.
                .foregroundStyle(Color(red: 0.051, green: 0.051, blue: 0.059))
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(
                    prominent
                        ? Color(red: 0.949, green: 0.949, blue: 0.961)   // #F2F2F5
                        : Color(red: 0.761, green: 0.761, blue: 0.792),  // #C2C2CA
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
    }
}

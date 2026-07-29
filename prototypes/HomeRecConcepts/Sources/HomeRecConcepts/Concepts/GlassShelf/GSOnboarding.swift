import SwiftUI

/// Cosmetic reskin of the shipping OnboardingView (HomeRec/HomeRec/
/// OnboardingView.swift). Flow, logic, element order, sizing, and every
/// string are IDENTICAL — the conditional CTA slot keys off
/// `permissionStatus == .granted` exactly as shipping does, and the grant
/// landing mid-sheet flips it live. Only the visual register changes.
///
/// Presented as an in-stage overlay (not a real .sheet) so snapshot capture
/// sees it; the shipping app would keep its `.sheet` presentation.
struct GSOnboarding: View {
    @EnvironmentObject private var store: PrototypeStateStore

    private var granted: Bool { store.permissionStatus == .granted }

    var body: some View {
        ZStack {
            // Scrim over the face.
            Color.black.opacity(0.45)
            card
        }
    }

    private var card: some View {
        VStack(spacing: 20) {
            appIcon

            Text("Welcome to Home Rec")
                .font(.custom("Archivo", size: 22, relativeTo: .title))
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.95))

            Text("Home Rec captures your Mac's audio output and saves it as a lossless WAV file — perfect for grabbing exactly what you're hearing.")
                .font(.custom("Inter", size: 13, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                bullet("lock.shield", "Home Rec needs Screen Recording permission to capture audio.")
                bullet("eye.slash", "It only captures audio — never your screen.")
                bullet("list.bullet", "macOS lists Home Rec under Screen & System Audio Recording — not the \u{201C}System Audio Recording Only\u{201D} list below it.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Conditional CTA slot — the exact shipping branch.
            if granted {
                Label("You're ready to record", systemImage: "checkmark.circle.fill")
                    .font(.custom("Archivo", size: 14, relativeTo: .headline))
                    .foregroundStyle(.green)
            } else {
                FlatPillButton(action: { store.simulateOpenSystemSettings() }) {
                    Text(store.isOpeningSystemSettings ? "opening settings…" : "Open System Settings")
                        .font(.custom("Inter", size: 13, relativeTo: .body))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(store.isOpeningSystemSettings ? 0.7 : 1))
                        .padding(.horizontal, 20)
                        .frame(height: 36)
                        .background(
                            GSTheme.card.opacity(store.isOpeningSystemSettings ? 0.7 : 1),
                            in: Capsule()
                        )
                        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
                        .contentShape(Capsule())
                }
                .disabled(store.isOpeningSystemSettings)
            }

            Spacer(minLength: 0)

            FlatPillButton(action: { store.completeOnboarding() }) {
                Text(granted ? "Get started" : "Done")
                    .font(.custom("Inter", size: 14, relativeTo: .body))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .frame(height: 40)
                    .background(GSTheme.accent, in: Capsule())
                    .contentShape(Capsule())
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 420, height: 440)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 30, y: 18)
    }

    /// Prototype substitute for `NSApp.applicationIconImage` (the SwiftPM
    /// process has the generic icon) — noted in the spec's mapping table.
    private var appIcon: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(red: 0.05, green: 0.05, blue: 0.05))
            .frame(width: 72, height: 72)
            .overlay(
                Image(systemName: "waveform")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(GSTheme.accent)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text)
                .font(.custom("Inter", size: 12, relativeTo: .caption))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(GSTheme.textDim)
        }
    }
}

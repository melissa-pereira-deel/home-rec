import SwiftUI

/// Reskin of the shipping OnboardingView (HomeRec/HomeRec/OnboardingView.swift).
/// Flow, logic, and element ORDER are identical — icon → title → supporting
/// copy → permission info → conditional slot → primary CTA, with the grant
/// landing mid-sheet flipping the slot live, exactly as shipping does.
///
/// COPY IS REVISED (product direction 2026-07-29): the original strings read
/// as a text wall, so the card now carries ~60% fewer words. The macOS
/// settings-list gotcha ("Screen & System Audio Recording", not the
/// audio-only list) appears only in the not-granted state, attached to the
/// action that sends you there. Spec badge for this screen: `proposed`.
///
/// The conditional slot has a FIXED height in both states so the live flip
/// never moves the primary CTA — no flexible Spacers anywhere on the card.
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
        VStack(spacing: 0) {
            appIcon
            gap(14)

            // Wordmark, not a greeting — the card opens into the app it names.
            GSBrand.wordmark(size: 26)
                .foregroundStyle(.white.opacity(0.95))
            gap(8)

            Text("Records what your Mac is playing. Lossless WAV.")
                .font(.custom("Inter", size: 13, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
            gap(24)

            permissionRow
            gap(16)

            conditionalSlot
            gap(18)

            primaryCTA
        }
        // 430pt total: the face is a fixed, clipped 450×450, so the card
        // keeps a 10pt scrim margin top/bottom (the spec's 460 would crop).
        .padding(EdgeInsets(top: 28, leading: 32, bottom: 26, trailing: 32))
        .frame(width: 420, height: 430)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        // Under the material: a dark tint so the face's controls don't bleed
        // through the glass as ghost bands behind the card's own pills.
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 30, y: 18)
    }

    /// The real brand mark (homerec.app apple-touch-icon), no border overlay —
    /// a stroked box here reads as a button. Fallback draws the same mark.
    private var appIcon: some View {
        Group {
            if let icon = BrandAssets.appIcon {
                // The touch icon carries an opaque white canvas around the
                // rounded-square artwork (browser convention). Overscan the
                // canvas margin out of the frame, then clip at the artwork's
                // own corner radius (7/30.5 of its width) to drop the white.
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 67.2, height: 67.2)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14.7, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.05, green: 0.05, blue: 0.05))
                    .overlay(Circle().fill(GSTheme.accent).frame(width: 18, height: 18))
            }
        }
        .frame(width: 64, height: 64)
        .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
    }

    /// The one inset container on the card: the permission ask and its
    /// reassurance live together, because the worry they answer is one worry.
    private var permissionRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            VStack(alignment: .leading, spacing: 3) {
                Text("Needs Screen Recording permission")
                    .font(.custom("Inter", size: 13, relativeTo: .body))
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.92))
                Text("Audio only — your screen is never recorded.")
                    .font(.custom("Inter", size: 12, relativeTo: .caption))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .lineLimit(1)
            Spacer(minLength: 0)   // fills the row, not the card
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }

    /// Fixed-height slot: the exact shipping branch, sized identically in
    /// both states so granting mid-sheet never moves the CTA below it.
    private var conditionalSlot: some View {
        ZStack {
            if granted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("Ready to record")
                        .font(.custom("Inter", size: 13, relativeTo: .body))
                        .fontWeight(.medium)
                }
                .foregroundStyle(GSTheme.okGreen)
                .transition(.opacity)
            } else {
                VStack(spacing: 8) {
                    settingsButton
                    Text("Look under \u{201C}Screen & System Audio Recording\u{201D} — not the audio-only list.")
                        .font(.custom("Inter", size: 11, relativeTo: .caption2))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .frame(maxWidth: 300)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity)
            }
        }
        .frame(height: 76)
        .animation(.easeOut(duration: 0.2), value: granted)
    }

    private var settingsButton: some View {
        FlatPillButton(action: { store.simulateOpenSystemSettings() }) {
            Text(store.isOpeningSystemSettings ? "opening…" : "open System Settings")
                .font(.custom("Inter", size: 13, relativeTo: .body))
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(height: 36)
                .background(.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                .contentShape(Capsule())
                .opacity(store.isOpeningSystemSettings ? 0.6 : 1)
        }
        .disabled(store.isOpeningSystemSettings)
    }

    private var primaryCTA: some View {
        FlatPillButton(action: { store.completeOnboarding() }) {
            Text(granted ? "get started" : "done")
                .font(.custom("Inter", size: 14, relativeTo: .body))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 32)
                .frame(height: 44)
                .background(GSTheme.accent, in: Capsule())
                .contentShape(Capsule())
                .shadow(color: GSTheme.accent.opacity(0.3), radius: 14, y: 4)
        }
        .keyboardShortcut(.defaultAction)
    }

    private func gap(_ height: CGFloat) -> some View {
        Color.clear.frame(height: height)
    }
}

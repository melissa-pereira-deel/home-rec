//
//  OnboardingView.swift
//  HomeRec
//
//  One-screen first-run guide: what Home Rec does, why it needs Screen
//  Recording permission (audio only), and a live "you're ready" confirmation
//  once permission is granted. (BL-041)
//

import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject var viewModel: RecorderViewModel

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)

            Text("Welcome to Home Rec")
                .font(.custom("Archivo", size: 22, relativeTo: .title))
                .fontWeight(.semibold)

            // Names what you can record *from*, not what formats exist: the
            // format picker is discoverable, the fact that the source is
            // yours to choose is not. This is the only screen a first-run
            // user is guaranteed to read.
            //
            // Imperative on purpose. "Record …" makes the reader the subject,
            // so the sentence needs no name for the app and no pronoun that
            // could attach to the wrong noun. It also fixes an inaccuracy:
            // the old phrasing hung "or a microphone" off "what your Mac is
            // playing", and a microphone is not something your Mac plays.
            Text("Record everything your Mac plays, a single app, or a microphone. Recordings go straight to your Desktop.")
                .font(.custom("Inter-Regular", size: 13, relativeTo: .body))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                // macOS is the subject of these three, which is both accurate
                // and useful: it answers why an audio recorder is asking for a
                // screen permission, and it tells the reader these prompts come
                // from their operating system. It also avoids a pronoun — "it"
                // would sit next to "permission" and could be read as a claim
                // about the permission, and "the app" would collide with "a
                // single app" one line above.
                //
                // `.fixedSize` on every line: without it the longest truncates
                // mid-word, and it is the line naming the permission the app
                // cannot work without.
                Label("macOS requires Screen Recording permission to capture audio.", systemImage: "lock.shield")
                    .fixedSize(horizontal: false, vertical: true)
                // The reassurance keeps its own icon and stays second, because
                // the crossed-out eye is read before any of the words are, and
                // it is what answers the alarm the line above sets off.
                Label("Only audio is ever recorded, never your screen.", systemImage: "eye.slash")
                    .fixedSize(horizontal: false, vertical: true)
                // The screen-recording rationale above used to be the whole
                // permission story. It stopped being true when microphone
                // capture shipped, and a welcome screen that implies there is
                // one permission makes the second prompt feel like an ambush.
                // "A second permission" states the count outright, which is the
                // whole of that warning.
                Label("A microphone needs a second permission, requested only when you choose one.", systemImage: "mic")
                    .fixedSize(horizontal: false, vertical: true)
                // Where to actually find it. Without this the line above sends
                // people to the audio-only list, which doesn't contain Home Rec.
                Label(PermissionKind.screenCapture.navigationHint, systemImage: "list.bullet")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.custom("Inter-Regular", size: 12, relativeTo: .caption))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Live permission status (re-detected automatically when you return).
            if viewModel.permissionStatus == .granted {
                Label("You're ready to record", systemImage: "checkmark.circle.fill")
                    .font(.custom("Archivo", size: 14, relativeTo: .headline))
                    .foregroundColor(.green)
            } else {
                // Neutral, not accent: granting permission is the step before
                // recording, not recording itself.
                GlassPillButton(
                    "Open System Settings",
                    emphasis: .primaryNeutral,
                    size: .medium
                ) {
                    viewModel.openSystemSettings()
                }
            }

            Spacer(minLength: 0)

            GlassPillButton(
                viewModel.permissionStatus == .granted ? "Get started" : "Done",
                emphasis: .primary,
                size: .medium
            ) {
                viewModel.completeOnboarding()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        // Width fixed, height from the content. The height used to be pinned at
        // 440 and the content had quietly outgrown it — the "Get started" button
        // was cut off by the bottom edge. A number that has to be re-tuned every
        // time this copy changes will be wrong again the next time it does, and
        // this copy has changed twice already.
        .frame(width: 420)
        // Same ground as every other surface. A sheet gets its own window, so it
        // needs the treatment applied here rather than inheriting the presenter's.
        .background(GlassWindowGround())
        .glassThemeAdaptingToContrast()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(RecorderViewModel())
}

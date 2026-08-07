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

            // Kept to one sentence deliberately: this is the only screen a
            // first-run user is guaranteed to read, so it names what the app
            // records rather than listing formats. The format picker is
            // discoverable; the fact that you can pick a *source* is not.
            Text("Home Rec records what your Mac is playing — everything, a single app, or a microphone — and saves it straight to your Desktop.")
                .font(.custom("Inter-Regular", size: 13, relativeTo: .body))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                // Wrap rather than truncate. These two were the only lines here
                // without it, and the first is long enough to lose its last
                // words — on the one screen a first-run user is guaranteed to
                // read, and precisely where it names the permission the app
                // cannot work without.
                Label("Home Rec needs Screen Recording permission to capture audio.", systemImage: "lock.shield")
                    .fixedSize(horizontal: false, vertical: true)
                Label("It only captures audio — never your screen.", systemImage: "eye.slash")
                    .fixedSize(horizontal: false, vertical: true)
                // The screen-recording rationale above used to be the whole
                // permission story. It stopped being true when microphone
                // capture shipped, and a welcome screen that implies there is
                // one permission makes the second prompt feel like an ambush.
                Label("Recording a microphone asks for its own permission, only when you choose one.", systemImage: "mic")
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
        // A sheet is already inset within the window that presents it, so it gets
        // the flat ground rather than a second mesh competing with the one behind.
        .background(GlassFlatGround())
        .glassThemeAdaptingToContrast()
    }
}

#Preview {
    OnboardingView()
        .environmentObject(RecorderViewModel())
}

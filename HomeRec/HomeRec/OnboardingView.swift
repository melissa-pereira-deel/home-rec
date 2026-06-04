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

            Text("Home Rec captures your Mac's audio output and saves it as a lossless WAV file — perfect for grabbing exactly what you're hearing.")
                .font(.custom("Inter-Regular", size: 13, relativeTo: .body))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Label("Home Rec needs Screen Recording permission to capture audio.", systemImage: "lock.shield")
                Label("It only captures audio — never your screen.", systemImage: "eye.slash")
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
                Button("Open System Settings") {
                    viewModel.openSystemSettings()
                }
                .controlSize(.large)
            }

            Spacer(minLength: 0)

            Button(viewModel.permissionStatus == .granted ? "Get started" : "Done") {
                viewModel.completeOnboarding()
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 420, height: 440)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(RecorderViewModel())
}

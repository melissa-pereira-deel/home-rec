//
//  RecorderView.swift
//  HomeRec
//
//  Main UI for the audio recorder
//

import SwiftUI

struct RecorderView: View {

    @EnvironmentObject var viewModel: RecorderViewModel

    /// Label for the primary button, which carries whichever action stands between
    /// the user and recording: move the app, grant permission, or record/stop.
    private var mainButtonTitle: String {
        if viewModel.installLocationBlocksRecording { return "Reveal in Finder" }
        if viewModel.permissionStatus != .granted { return "Open System Settings" }
        return viewModel.isRecording ? "Stop recording" : "Start recording"
    }

    var body: some View {
        VStack(spacing: 24) {
            // App Logo + Status grouped closer together
            VStack(spacing: 0) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 84, height: 84)
                    .padding(.bottom, 32)

                StatusBar(
                isRecording: viewModel.isRecording,
                duration: viewModel.formattedDuration,
                statusText: viewModel.statusText
                )
            }

            // Live Waveform
            if viewModel.isRecording {
                WaveformView(samples: viewModel.waveformSamples)
                    .stroke(Color.red.opacity(0.7), lineWidth: 1.5)
                    .frame(height: 60)
                    .animation(.easeOut(duration: 0.1), value: viewModel.waveformSamples)
            }

            // Soft install-location note (BL-082): shown only for the dismissible
            // tier. The hard block takes over the window's content below instead —
            // it is a block, not a note, and it replaces the permission flow.
            if viewModel.installLocation.noticeIsDismissible,
               let notice = viewModel.installNotice {
                HStack(spacing: 8) {
                    Text(notice)
                        .font(.custom("Inter-Regular", size: 11, relativeTo: .caption))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        viewModel.dismissInstallLocationNotice()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }
            }

            // Permission guidance (inline, above button).
            //
            // The trust line and the navigation line do different jobs and must not
            // be collapsed: "only captures audio" is true and worth saying, but on
            // its own it sends people to the "System Audio Recording Only" list,
            // where Home Rec isn't. The hint names the section that actually holds
            // it. See PermissionKind.navigationHint.
            // A translocated bundle can't hold a permission grant, so the permission
            // guidance below would send the user down a path that silently fails
            // (BL-082a). This window is the canonical surface for the block — the
            // floating panel stands down while it is up (BL-086).
            if viewModel.installLocationBlocksRecording, let message = viewModel.installNotice {
                // Verbatim from InstallLocation.explanation — one sentence, one
                // source, every surface (see the comment there).
                Text(message)
                    .font(.custom("Inter-Regular", size: 13, relativeTo: .body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if viewModel.permissionStatus != .granted {
                VStack(spacing: 6) {
                    Text("Grant Screen Recording permission to get started.")
                        .font(.custom("Inter-Regular", size: 13, relativeTo: .body))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text(PermissionKind.screenCapture.navigationHint)
                        .font(.custom("Inter-Regular", size: 11, relativeTo: .caption))
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Primary action + contextual Reveal, grouped tighter than the rest.
            VStack(spacing: 16) {
                // Main Control Button
                Button(action: {
                    if viewModel.installLocationBlocksRecording {
                        viewModel.revealAppInFinder()
                    } else if viewModel.permissionStatus != .granted {
                        viewModel.openSystemSettings()
                    } else {
                        Task {
                            await viewModel.toggleRecording()
                        }
                    }
                }) {
                    HStack {
                        if viewModel.canRecord {
                            Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                                .font(.system(size: 24))
                        }
                        Text(mainButtonTitle)
                            .font(.custom("Archivo", size: 15, relativeTo: .body))
                            .fontWeight(.medium)
                    }
                    .frame(width: 220, height: 50)
                    .foregroundColor(.white)
                    .background(viewModel.canRecord ? Color.red : Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("r", modifiers: .command)

                // Reveal in Finder — contextual action, only after a recording.
                if viewModel.lastRecordingURL != nil, !viewModel.isRecording {
                    Button(action: {
                        viewModel.revealInFinder()
                    }) {
                        HStack {
                            Image(systemName: "folder")
                            Text("Reveal in Finder")
                                .font(.custom("Inter-Regular", size: 13, relativeTo: .body))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("o", modifiers: .command)
                }
            }

            Spacer()

            // Settings shelf (bottom): quiet, native pop-ups, visually separated
            // from the action controls by a faint divider. Two sibling controls
            // (save destination + output format) share the ShelfMenu chrome and
            // sit a touch tighter to each other (6pt) than to the divider (10pt),
            // so they read as one unit. Hidden for the whole of a take — the
            // settings are captured at start and cannot change until it ends.
            if viewModel.showsSettingsShelf {
                VStack(spacing: 10) {
                    Divider()
                        .frame(width: 300)
                        .opacity(0.15)

                    VStack(spacing: 6) {
                        // Save destination (BL-010).
                        ShelfMenu(
                            title: "Saving to \(viewModel.saveLocationName)",
                            help: viewModel.saveLocationPath,
                            accessibilityLabel: "Save location",
                            accessibilityValue: viewModel.saveLocationName
                        ) {
                            Button("Choose folder…") {
                                viewModel.chooseSaveLocation()
                            }
                            if viewModel.hasCustomSaveLocation {
                                Button("Reset to Desktop") {
                                    viewModel.resetSaveLocation()
                                }
                            }
                        }

                        // Output format (BL-015). Offers only formats with a working
                        // encoder (`AudioFormat.available`); the active one is checked.
                        ShelfMenu(
                            title: "Recording as \(viewModel.selectedFormat.shortName)",
                            help: "New recordings are saved as \(viewModel.selectedFormat.displayName). This can't change while recording.",
                            accessibilityLabel: "Recording format",
                            accessibilityValue: viewModel.selectedFormat.displayName
                        ) {
                            ForEach(AudioFormat.available, id: \.self) { format in
                                Button {
                                    viewModel.setFormat(format)
                                } label: {
                                    if format == viewModel.selectedFormat {
                                        Label(format.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(format.displayName)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(40)
        .frame(width: 450, height: 450)
        .alert("Something went wrong", isPresented: $viewModel.showError) {
            if let recovery = viewModel.recoverySuggestion {
                Button(recovery.label) {
                    viewModel.performRecovery()
                }
            }
            Button("OK", role: .cancel) {
                viewModel.showError = false
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .alert("Still recording", isPresented: $viewModel.showLongRecordingWarning) {
            Button("Keep recording", role: .cancel) {
                viewModel.showLongRecordingWarning = false
            }
            Button("Stop") {
                Task { await viewModel.stopRecording() }
            }
        } message: {
            Text("You've been recording for a while. Long recordings use a lot of disk space — about 10 MB per minute.")
        }
        .sheet(isPresented: $viewModel.showOnboarding) {
            OnboardingView()
                .environmentObject(viewModel)
        }
        // No permission probe here (BL-085). Showing this window activates the app,
        // and the view model's activation observer already re-probes when permission
        // is missing — so a probe here was redundant, and the authoritative one it
        // used to call can raise a system prompt merely because a window appeared.
        //
        // The window reports its own existence instead (BL-086): it is the canonical
        // surface for the install-location block, so while it is up the floating
        // panel must stand down, and when it goes away the panel is all that is left.
        .onAppear { viewModel.mainWindowDidAppear() }
        .onDisappear { viewModel.mainWindowDidDisappear() }
    }
}

/// Status bar showing recording indicator and duration
struct StatusBar: View {
    let isRecording: Bool
    let duration: String
    let statusText: String

    var body: some View {
        VStack(spacing: 12) {
            // Recording Indicator
            HStack(spacing: 12) {
                // Pulsing red dot
                if isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.4), lineWidth: 4)
                                .scaleEffect(isRecording ? 1.5 : 1.0)
                                .opacity(isRecording ? 0.0 : 1.0)
                                .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: isRecording)
                        )
                }

                Text(statusText)
                    .font(.custom("Archivo", size: 18, relativeTo: .headline))
                    .fontWeight(.medium)
                    .foregroundColor(isRecording ? .red : .primary)
            }

            // Duration Display
            if isRecording {
                Text(duration)
                    .font(.custom("Archivo", size: 34, relativeTo: .largeTitle))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        }
    }
}

#Preview {
    RecorderView()
        .environmentObject(RecorderViewModel())
}

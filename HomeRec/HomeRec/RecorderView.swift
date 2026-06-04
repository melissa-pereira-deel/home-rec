//
//  RecorderView.swift
//  HomeRec
//
//  Main UI for the audio recorder
//

import SwiftUI

struct RecorderView: View {

    @EnvironmentObject var viewModel: RecorderViewModel

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

            // Permission guidance (inline, above button)
            if viewModel.permissionStatus != .granted {
                VStack(spacing: 6) {
                    Text("Grant Screen Recording permission to get started.")
                        .font(.custom("Inter-Regular", size: 13, relativeTo: .body))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Home Rec only captures audio — not your screen.")
                        .font(.custom("Inter-Regular", size: 11, relativeTo: .caption))
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }

            // Primary action + contextual Reveal, grouped tighter than the rest.
            VStack(spacing: 16) {
                // Main Control Button
                Button(action: {
                    if viewModel.permissionStatus != .granted {
                        viewModel.openSystemSettings()
                    } else {
                        Task {
                            await viewModel.toggleRecording()
                        }
                    }
                }) {
                    HStack {
                        if viewModel.permissionStatus == .granted {
                            Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                                .font(.system(size: 24))
                        }
                        Text(viewModel.permissionStatus != .granted ? "Open System Settings" : (viewModel.isRecording ? "Stop recording" : "Start recording"))
                            .font(.custom("Archivo", size: 15, relativeTo: .body))
                            .fontWeight(.medium)
                    }
                    .frame(width: 220, height: 50)
                    .foregroundColor(.white)
                    .background(viewModel.permissionStatus != .granted ? Color.gray.opacity(0.3) : Color.red)
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
            // so they read as one unit. Hidden entirely while recording — both
            // settings are locked once capture starts.
            if !viewModel.isRecording {
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
        .onAppear {
            Task {
                await viewModel.checkPermission()
            }
        }
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

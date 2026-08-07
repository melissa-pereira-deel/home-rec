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
            // Header, from the Glass v2 concept: brand on the left, the
            // machine-measured facts and settings on the right. The lockup is
            // also now the only place the app's name appears — the titlebar is
            // hidden — and it replaces the old 84pt centred icon, which would
            // otherwise state the brand twice on one face.
            HStack(spacing: 10) {
                GlassBrandLockup(size: .compact)

                Spacer()

                // The sample rate is fixed by the capture pipeline
                // (AudioRecorder.sampleRate matches the ScreenCaptureKit
                // config), so this states it rather than measuring it.
                GlassMetaLabel("\(viewModel.selectedFormat.shortName.lowercased()) · 48kHz")

                // Same control, same gating as the old bottom shelf: hidden for
                // the whole of a take, because the settings it opens are
                // captured at start and cannot change until the take ends.
                if viewModel.showsSettingsShelf {
                    SettingsPopover()
                }
            }
            // The header belongs to the window's chrome, not to the face, so it
            // escapes the face's 40pt inset toward the edges — stated as an
            // offset from that inset so the two cannot drift apart — and sits
            // just below the traffic-light band rather than 40pt under it. The
            // xl margin is the concept face's own header inset.
            .padding(.horizontal, GlassSpacing.xl - 40)
            .padding(.top, GlassSpacing.s)

            Spacer(minLength: 0)

            StatusBar(
                isRecording: viewModel.isRecording,
                duration: viewModel.formattedDuration,
                statusText: viewModel.statusText
            )

            // Live Waveform
            //
            // The explicit animation this used to carry is gone. `[Float]` is not
            // `VectorArithmetic`, so the shape's `animatableData` never witnessed
            // the protocol requirement and nothing was ever interpolated — the
            // modifier only bought a 200-element equality check on every frame.
            // At roughly 47 frames a second the frame rate is the smoothing.
            if viewModel.isRecording {
                GlassLiveWaveform(
                    samples: RecorderWaveformAdapter.magnitudes(
                        viewModel.waveformSamples,
                        bucketedTo: RecorderWaveformAdapter.mainWindowBarCount
                    )
                )
                .frame(height: 60)
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

                    // The glyph stays 9pt; the *target* grows to the 28pt floor.
                    // A bare 9pt glyph was a dismiss control roughly the size of
                    // the text beside it, which is a miss waiting to happen.
                    GlassIconButton(
                        systemImage: "xmark",
                        accessibilityLabel: "Dismiss",
                        symbolSize: 9
                    ) {
                        viewModel.dismissInstallLocationNotice()
                    }
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
                // `canRecord` is exactly "this button is about to record or stop".
                // When it is false the same control carries a corrective action
                // instead — reveal the app, or open Settings — and those have no
                // business wearing the accent, which in this app means recording
                // or failure and nothing else. They take the neutral fill rather
                // than grey: grey is the system's *disabled* costume, and this is
                // the one thing on the surface the user can actually do.
                GlassPillButton(
                    mainButtonTitle,
                    systemImage: viewModel.canRecord
                        ? (viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                        : nil,
                    emphasis: viewModel.canRecord ? .primary : .primaryNeutral,
                    size: .large
                ) {
                    if viewModel.installLocationBlocksRecording {
                        viewModel.revealAppInFinder()
                    } else if viewModel.permissionStatus != .granted {
                        viewModel.openSystemSettings()
                    } else {
                        Task {
                            await viewModel.toggleRecording()
                        }
                    }
                }
                .frame(width: 220)
                .keyboardShortcut("r", modifiers: .command)

                // Reveal in Finder — contextual action, only after a recording.
                if viewModel.lastRecordingURL != nil, !viewModel.isRecording {
                    // The outline this used to draw is gone on purpose: rank is
                    // carried by fill alone, and the stroke is reserved for the
                    // focus ring so that keyboard focus has something to say that
                    // nothing else is already saying.
                    GlassPillButton(
                        "Reveal in Finder",
                        systemImage: "folder",
                        emphasis: .tertiary,
                        size: .small
                    ) {
                        viewModel.revealInFinder()
                    }
                    .keyboardShortcut("o", modifiers: .command)
                }
            }

            Spacer()
        }
        // No top edge in this set: the header now owns the distance to the
        // titlebar band, and a blanket top inset would push it back down.
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
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

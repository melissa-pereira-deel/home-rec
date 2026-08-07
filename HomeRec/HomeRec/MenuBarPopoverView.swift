//
//  MenuBarPopoverView.swift
//  HomeRec
//
//  Compact popover UI shown from the menu bar icon.
//

import SwiftUI

struct MenuBarPopoverView: View {

    @EnvironmentObject var viewModel: RecorderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: logo, with secondary actions collected under "•••" (BL-110)
            HStack(alignment: .top) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)

                Spacer()

                OverflowMenuButton()
            }

            // Status row
            HStack(spacing: 8) {
                if viewModel.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }

                Text(viewModel.statusText)
                    .font(.custom("Archivo", size: 17, relativeTo: .headline))
                    .fontWeight(.medium)
                    .foregroundColor(viewModel.isRecording ? .red : .primary)

                Spacer()

                if viewModel.isRecording {
                    Text(viewModel.formattedDuration)
                        .font(.custom("Archivo", size: 15, relativeTo: .body))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
            }

            // Inline error with recovery action
            if case .error = viewModel.state, let message = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Text(message)
                        .font(.custom("Inter-Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let recovery = viewModel.recoverySuggestion {
                        GlassPillButton(
                            recovery.label,
                            emphasis: .secondary,
                            size: .mini
                        ) {
                            viewModel.performRecovery()
                        }
                    }
                }
            }

            // Mini waveform (only while recording)
            if viewModel.isRecording {
                GlassLiveWaveform(
                    samples: RecorderWaveformAdapter.magnitudes(
                        viewModel.waveformSamples,
                        bucketedTo: RecorderWaveformAdapter.popoverBarCount
                    )
                )
                .frame(height: 36)
            }

            // Primary action. A red "Start recording" on an app that cannot record
            // is a false affordance, so when the bundle is translocated (BL-082a)
            // the button carries the corrective action instead — and the popover
            // explains the block itself rather than spawning the floating panel
            // out of a transient surface (BL-086).
            //
            // The status row above and this explanation are title and body, not a
            // duplication: the row compresses the action, this states the fact and
            // the procedure. Accent fill rather than grey — grey is the system's
            // *disabled* costume, and this is the only thing on the surface the
            // user can do. Red is unavailable; it means "record" in this app.
            if viewModel.installLocationBlocksRecording, let message = viewModel.installNotice {
                Text(message)
                    .font(.custom("Inter-Regular", size: 12, relativeTo: .caption))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // The neutral fill is what the system accent was standing in for
                // here: primary rank without borrowing the record red for an
                // action that cannot record.
                GlassPillButton(
                    "Reveal in Finder",
                    emphasis: .primaryNeutral,
                    size: .medium,
                    isFullWidth: true
                ) {
                    viewModel.revealAppInFinder()
                }
            } else {
                GlassPillButton(
                    viewModel.isRecording ? "Stop recording" : "Start recording",
                    systemImage: viewModel.isRecording ? "stop.circle.fill" : "record.circle",
                    emphasis: .primary,
                    size: .medium,
                    isFullWidth: true
                ) {
                    Task {
                        await viewModel.toggleRecording()
                    }
                }
            }

            // Last recording info. Hidden while blocked: its "Reveal" targets the
            // recording, and the block's "Reveal in Finder" targets the app bundle
            // — two near-identical affordances with different targets, 40pt apart
            // on a 280pt surface. The file stays where it is; only the row waits.
            if let url = viewModel.lastRecordingURL,
               !viewModel.isRecording,
               !viewModel.installLocationBlocksRecording {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.secondary)
                    Text(url.lastPathComponent)
                        .font(.custom("Archivo", size: 12, relativeTo: .caption))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)

                    Spacer()

                    GlassPillButton(
                        "Reveal",
                        emphasis: .tertiary,
                        size: .mini
                    ) {
                        viewModel.revealInFinder()
                    }
                }
            }

        }
        .padding(16)
        .frame(width: 280)
        // The same ground as the window, deliberately. This was a flat opaque
        // fill first, reasoning that an NSPopover already draws its own vibrancy
        // and a second material would read as mud. What an opaque fill actually
        // does is *cover* that vibrancy, so the popover came out visibly darker
        // than the window it belongs to — the app looking like two apps.
        .background(GlassWindowGround())
        .glassThemeAdaptingToContrast()
    }
}

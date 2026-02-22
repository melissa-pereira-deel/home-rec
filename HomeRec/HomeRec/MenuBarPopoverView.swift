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
            // App logo
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)

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

            // Mini waveform (only while recording)
            if viewModel.isRecording {
                WaveformView(samples: viewModel.waveformSamples)
                    .stroke(Color.red.opacity(0.7), lineWidth: 1.5)
                    .frame(height: 36)
                    .animation(.easeOut(duration: 0.1), value: viewModel.waveformSamples)
            }

            // Record / Stop button
            Button(action: {
                Task {
                    await viewModel.toggleRecording()
                }
            }) {
                HStack {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                    Text(viewModel.isRecording ? "Stop Recording" : "Start Recording")
                        .font(.custom("Archivo", size: 13, relativeTo: .body))
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(.white)
                .background(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // Last recording info
            if let url = viewModel.lastRecordingURL, !viewModel.isRecording {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.secondary)
                    Text(url.lastPathComponent)
                        .font(.custom("Archivo", size: 12, relativeTo: .caption))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Reveal") {
                        viewModel.revealInFinder()
                    }
                    .font(.custom("Inter-Regular", size: 12, relativeTo: .caption))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Footer row
            HStack {
                Button("Show Window") {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.title == "Home Rec" || $0.contentView is NSHostingView<AnyView> }) {
                        window.makeKeyAndOrderFront(nil)
                    } else {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
                .buttonStyle(.borderless)
                .font(.custom("Inter-Regular", size: 12, relativeTo: .caption))

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.custom("Inter-Regular", size: 12, relativeTo: .caption))
                .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}

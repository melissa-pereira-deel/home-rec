//
//  RecoveryView.swift
//  HomeRec
//
//  BL-140: the Recover Recordings window. Deliberately plain — a list, a size,
//  a date, and the actions. The feature's value is that it exists and tells the
//  truth, not that it looks clever.
//

import SwiftUI
import AppKit

struct RecoveryView: View {
    @ObservedObject var viewModel: RecoveryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(minWidth: 460, minHeight: 260)
        // The ground is what the empty state stands on. When there is a list it
        // paints over this, and that is left alone on purpose: List draws its own
        // selection and separators, and clearing its background to show the ground
        // through would cost those for no gain the user can see.
        .background(GlassWindowGround())
        .glassThemeAdaptingToContrast()
        .onAppear { viewModel.refresh() }
        .alert("Couldn't do that", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
            Text("Nothing to recover — you're all caught up.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List(viewModel.recordings) { recording in
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(recording.displayName)
                        .font(.system(.body, design: .default))
                    Text("\(viewModel.dateText(recording)) · \(viewModel.sizeText(recording))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !recording.isRepairable {
                        // Say so rather than offering a button that can't help.
                        Text("Too short to recover — no audio reached the disk.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if recording.isRepairable {
                    // Neutral rather than accent: repairing a take is not
                    // recording one, and the accent stays reserved.
                    GlassPillButton(
                        "Recover",
                        emphasis: .primaryNeutral,
                        size: .small
                    ) {
                        viewModel.recover(recording)
                    }
                }
                Menu {
                    Button("Reveal in Finder") { viewModel.revealInFinder(recording) }
                    Button("Move to Trash", role: .destructive) { viewModel.moveToTrash(recording) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.vertical, 4)
        }
    }
}

/// Hosts `RecoveryView` in a normal window. A menu-bar app has no scene to push
/// this into, so it owns its window directly — and keeps a single instance so
/// repeated menu clicks focus the existing window instead of stacking copies.
@MainActor
final class RecoveryWindowController {
    static let shared = RecoveryWindowController()
    private var window: NSWindow?
    private var viewModel: RecoveryViewModel?

    func show(inProgressURL: @escaping @MainActor () -> URL?) {
        NSApp.activate(ignoringOtherApps: true)

        if let window, let viewModel {
            viewModel.refresh()   // the folder may have changed since it was opened
            window.makeKeyAndOrderFront(nil)
            return
        }

        let viewModel = RecoveryViewModel(
            scanner: RecoveryScanner(saveLocation: SaveLocationManager()),
            inProgressURL: inProgressURL
        )
        self.viewModel = viewModel

        let hosting = NSHostingController(rootView: RecoveryView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Recover Recordings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 520, height: 320))
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}

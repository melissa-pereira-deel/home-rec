//
//  MenuBarController.swift
//  HomeRec
//
//  Manages the NSStatusItem (menu bar icon) and NSPopover for the compact UI.
//

import AppKit
import SwiftUI
import Combine

class MenuBarController: NSObject {

    private var statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellable: AnyCancellable?

    init(viewModel: RecorderViewModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        // Configure popover
        let popoverView = MenuBarPopoverView()
            .environmentObject(viewModel)
        popover.contentViewController = NSHostingController(rootView: popoverView)
        popover.contentSize = NSSize(width: 280, height: 240)
        popover.behavior = .transient

        // Configure status bar button
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Home Rec")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        // Observe isRecording to swap icon
        cancellable = viewModel.$isRecording
            .receive(on: RunLoop.main)
            .sink { [weak self] isRecording in
                guard let button = self?.statusItem.button else { return }
                if isRecording {
                    let image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
                    image?.isTemplate = false
                    button.image = image
                    // Tint the button with red using a content tint color
                    button.contentTintColor = .red
                } else {
                    let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Home Rec")
                    image?.isTemplate = true
                    button.image = image
                    button.contentTintColor = nil
                }
            }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Make the popover window key so it can receive input
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

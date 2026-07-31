//
//  MenuBarController.swift
//  HomeRec
//
//  Manages the NSStatusItem (menu bar icon) and NSPopover for the compact UI.
//

import AppKit
import SwiftUI
import Combine

@MainActor
class MenuBarController: NSObject {

    private var statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellable: AnyCancellable?
    /// Held so the overflow menu can be rebuilt from live state on every open.
    private let viewModel: RecorderViewModel
    /// Warmed only by a deliberate Per-App submenu open — never at launch.
    private let appListCache = PerAppListCache()
    /// Retained for the lifetime of the controller: `NSMenu.delegate` is weak.
    private var perAppDelegate: PerAppMenuDelegate?

    init(viewModel: RecorderViewModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.viewModel = viewModel
        super.init()

        // The single write path for the capture source. Checkmarks are derived
        // from the selection at build time, so nothing else may set it.
        OverflowMenu.onSelectSource = { [weak viewModel] source in
            viewModel?.setCaptureSource(source)
        }
        OverflowMenu.onRequestPermission = { [weak viewModel] in
            viewModel?.openSystemSettings()
        }
        // One factory for both surfaces — the popover's "•••" and the status
        // item's right-click render the identical menu, delegate included.
        OverflowMenu.makeConfiguredMenu = { [weak self] in
            self?.makeOverflowMenu() ?? OverflowMenu.makeNSMenu()
        }

        // BL-140: the recovery window must never offer the file being written
        // right now — a live recording is unfinalized by definition.
        // `lastRecordingURL` is set at start and deliberately survives stop, so
        // gating on `isRecording` is what makes it mean "in progress".
        OverflowMenu.currentRecordingURL = { [weak viewModel] in
            guard let viewModel, viewModel.isRecording else { return nil }
            return viewModel.lastRecordingURL
        }

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
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            // Right-clicks reach the action only if explicitly opted into; the
            // default is left-click alone (BL-110).
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Observe recording state to swap icon
        cancellable = viewModel.$state
            .map { $0 == .recording }
            .removeDuplicates()
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

    /// Route a status-item click: the overflow menu on right/control-click, the
    /// popover otherwise (BL-110).
    @objc private func handleStatusItemClick(_ sender: AnyObject?) {
        let event = NSApp.currentEvent
        let showsMenu = Self.shouldShowOverflowMenu(
            type: event?.type ?? .leftMouseUp,
            modifiers: event?.modifierFlags ?? []
        )
        if showsMenu {
            showOverflowMenu()
        } else {
            togglePopover(sender)
        }
    }

    /// Whether a status-item click should open the overflow menu instead of the
    /// popover. Control-click counts as a right-click, per macOS convention.
    ///
    /// Static and pure so the routing rule can be tested without synthesising a
    /// real `NSEvent` or standing up a live status item.
    static func shouldShowOverflowMenu(
        type: NSEvent.EventType,
        modifiers: NSEvent.ModifierFlags
    ) -> Bool {
        if type == .rightMouseUp { return true }
        return type == .leftMouseUp && modifiers.contains(.control)
    }

    /// Snapshot of everything the menu renders from, read fresh on every open.
    ///
    /// Nothing here touches ScreenCaptureKit: `apps` comes from the in-memory
    /// cache, which only a deliberate Per-App submenu open ever fills. That is
    /// what keeps a plain right-click free of permission prompts.
    private func currentContext() -> OverflowContext {
        let selected = viewModel.audioSource.selectedSource
        var selectedAppName: String?
        if case .app(let bundleID) = selected {
            selectedAppName = viewModel.audioSource.knownAppName(forBundleID: bundleID)
        }
        // Devices are enumerated eagerly, unlike apps: it is synchronous, cheap,
        // and raises no permission dialog, so there is nothing to defer.
        let devices = viewModel.audioSource.availableInputDevices()
        var selectedMicName: String?
        if case .mic(let uid) = selected {
            selectedMicName = devices.first { $0.uid == uid }?.name
        }

        return OverflowContext(
            selectedSource: selected,
            allowsCaptureSourceChange: viewModel.state.allowsCaptureSourceChange,
            permissionGranted: viewModel.permissionStatus == .granted,
            apps: appListCache.apps,
            selectedAppName: selectedAppName,
            inputDevices: devices,
            selectedMicName: selectedMicName
        )
    }

    /// Build the menu for right now, and attach the delegate that fills the
    /// Per-App submenu lazily when (and only when) it is opened.
    private func makeOverflowMenu() -> NSMenu {
        let context = currentContext()
        let menu = OverflowMenu.makeNSMenu(context)

        let delegate = PerAppMenuDelegate(
            cache: appListCache,
            source: viewModel.audioSource,
            makeContext: { [weak self] in self?.currentContext() ?? OverflowContext() }
        )
        // Retained here because `NSMenu.delegate` is weak.
        perAppDelegate = delegate
        // Attached to the *submenu only*, so opening the root menu enumerates
        // nothing. The capture-source section is absent entirely while recording,
        // in which case there is no submenu to find.
        menu.items
            .first { $0.identifier?.rawValue == OverflowMenu.perAppItemIdentifier }?
            .submenu?.delegate = delegate

        return menu
    }

    private func showOverflowMenu() {
        // The popover and the menu would otherwise overlap on screen.
        if popover.isShown {
            popover.performClose(nil)
        }

        // Attaching the menu is what gives the status item its standard
        // highlighted-while-open appearance. It has to come straight back off:
        // while a menu is attached AppKit routes every click to it and never
        // fires the button's action, which would strand the left-click popover.
        statusItem.menu = makeOverflowMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Make the popover window key so it can receive input
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

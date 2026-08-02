//
//  OverflowMenu.swift
//  HomeRec
//
//  The menu-bar overflow menu (BL-110). Secondary actions live here instead of
//  as flat buttons in the popover, which keeps the popover free for the primary
//  record/waveform surface as more features land.
//
//  Two surfaces present this menu — the "•••" button in the popover and a
//  right-click on the status item — so `entries` is the single definition both
//  render from. Adding a row in one place adds it to both.
//

import AppKit
import SwiftUI

/// One selectable row in the overflow menu.
struct OverflowAction: Identifiable {
    /// Stable across copy changes, so tests can assert an action still exists
    /// without breaking every time a title is reworded.
    let id: String
    let title: String
    /// Character for a ⌘-based shortcut ("q" → ⌘Q), or nil for no shortcut.
    /// Every shortcut in this menu is ⌘-based, so the modifier stays implicit —
    /// that's what lets one definition feed both SwiftUI's `.keyboardShortcut`
    /// and `NSMenuItem.keyEquivalent` without a translation layer between them.
    let commandKey: Character?
    /// Shown on hover in the AppKit menu. Used sparingly — only where the row's
    /// purpose isn't self-evident from its title (BL-140's recovery entry).
    let toolTip: String?
    /// Whether this row shows a checkmark. Always *derived* from the context at
    /// build time (`row.source == context.selectedSource`), never stored.
    let isChecked: Bool
    let isEnabled: Bool
    /// Marks a row as a member of the one-of-N capture-source group.
    ///
    /// Exists so the mid-recording assertion can be written over the builder's
    /// *output* — "no source row survives in a locked context" — instead of over
    /// a hardcoded list of ids, which would silently pass when BL-130 adds a mic
    /// row and nobody remembers to extend the list.
    let isSourceRow: Bool
    let perform: @MainActor () -> Void

    init(
        id: String,
        title: String,
        commandKey: Character? = nil,
        toolTip: String? = nil,
        isChecked: Bool = false,
        isEnabled: Bool = true,
        isSourceRow: Bool = false,
        perform: @escaping @MainActor () -> Void
    ) {
        self.id = id
        self.title = title
        self.commandKey = commandKey
        self.toolTip = toolTip
        self.isChecked = isChecked
        self.isEnabled = isEnabled
        self.isSourceRow = isSourceRow
        self.perform = perform
    }
}

/// A row that opens a nested menu.
///
/// Its contents are enumerated at runtime, which under BL-111's root-row rule is
/// exactly what earns a submenu: one root row per *kind* of source, so the shape
/// of the menu never changes because an app launched or a device was plugged in.
struct OverflowSubmenu: Identifiable {
    let id: String
    /// Folds the current selection into the row — "Ableton Live" rather than
    /// "App" — so the root answers "what am I recording?" without opening it.
    let title: String
    let isChecked: Bool
    let isEnabled: Bool
    let isSourceRow: Bool
    /// Built lazily on open. `nil` here would mean "nothing to show"; the builder
    /// always supplies at least one row (a notice) so a submenu is never an
    /// empty dead end that reads as a bug.
    let entries: [OverflowEntry]

    init(
        id: String,
        title: String,
        isChecked: Bool = false,
        isEnabled: Bool = true,
        isSourceRow: Bool = true,
        entries: [OverflowEntry]
    ) {
        self.id = id
        self.title = title
        self.isChecked = isChecked
        self.isEnabled = isEnabled
        self.isSourceRow = isSourceRow
        self.entries = entries
    }
}

indirect enum OverflowEntry {
    case action(OverflowAction)
    case separator
    /// A styled group title. Rendered with `NSMenuItem.sectionHeader(title:)`,
    /// which applies system styling itself — so the title is passed in sentence
    /// case, not pre-uppercased.
    case sectionHeader(String)
    case submenu(OverflowSubmenu)
    /// A non-clickable explanatory row. Used only where the user is standing on a
    /// blocked path and is actively asking why.
    case disabledNotice(String)
}

@MainActor
enum OverflowMenu {

    /// Writes the user's capture-source choice. Set once at startup by
    /// `MenuBarController`. The single write path — checkmarks are derived from
    /// the selection, so nothing else may set it.
    static var onSelectSource: @MainActor (AudioSource) -> Void = { _ in }

    /// Stable identifier stamped onto the Per-App submenu row, so the controller
    /// can attach its delegate without matching on the row's title (which now
    /// changes to reflect the selection).
    static let perAppItemIdentifier = "sourcePerApp"

    /// Builds the fully-configured menu — current context, submenu delegate and
    /// all. Set once at startup by `MenuBarController`, which owns the app-list
    /// cache the delegate fills.
    ///
    /// Both surfaces call this, so "the popover menu matches the right-click
    /// menu" stops being a property to test and becomes the same object.
    static var makeConfiguredMenu: @MainActor () -> NSMenu = { makeNSMenu() }

    /// The menu's contents for `context`, in display order.
    ///
    /// A pure function of the snapshot: same context in, same rows out, no I/O.
    /// That is what lets the whole menu — including sections BL-130 and BL-131
    /// will add — be tested without AppKit, a live status item, or permission.
    static func entries(_ context: OverflowContext) -> [OverflowEntry] {
        captureSourceEntries(context) + appActionEntries(context)
    }

    /// The capture-source section, or nothing at all.
    ///
    /// **Hidden, not greyed, while a recording is running.** The app already
    /// settled this: `RecorderView` hides the whole settings shelf during a take
    /// ("both settings are locked once capture starts"), and having two different
    /// rules for locked settings would be worse than either rule. The user's
    /// question — "why is this grey?" — never arises, and the state stays legible
    /// where it belongs: a red menu-bar icon and a source-aware status line.
    static func captureSourceEntries(_ context: OverflowContext) -> [OverflowEntry] {
        guard context.allowsCaptureSourceChange else { return [] }

        return [
            .sectionHeader("Capture Source"),
            .action(OverflowAction(
                id: "sourceSystemAll",
                title: "All System Audio",
                isChecked: context.selectedSource == .systemAll,
                isSourceRow: true,
                perform: { onSelectSource(.systemAll) }
            )),
            .submenu(perAppSubmenu(context)),
            .submenu(microphoneSubmenu(context)),
            .separator
        ]
    }

    /// The microphone root row (BL-130).
    ///
    /// A submenu for the same reason Per-App is one — its contents are
    /// enumerated at runtime — so plugging in an interface changes what is
    /// *behind* the row, never the shape of the section.
    ///
    /// Unlike Per-App this needs **no permission gate**: enumerating input
    /// devices raises no dialog and returns real names even with microphone
    /// access still undetermined. Only capturing prompts. Do not copy the
    /// Per-App gate here — its rationale does not apply, and a pasted-in reason
    /// rots into a mystery.
    static func microphoneSubmenu(_ context: OverflowContext) -> OverflowSubmenu {
        let selectedUID: String? = {
            if case .mic(let uid) = context.selectedSource { return uid }
            return nil
        }()
        let devices = context.inputDevices
        let liveName = devices.first { $0.uid == selectedUID }?.name

        var entries: [OverflowEntry] = []
        if selectedUID != nil, liveName == nil {
            // Chosen in an earlier session and since unplugged. Same reasoning as
            // the app case: without this row the section shows zero checkmarks
            // and silently implies system audio.
            entries.append(.action(OverflowAction(
                id: "sourceMicNotAvailable",
                title: "\(context.selectedMicName ?? "Microphone") (not connected)",
                isChecked: true,
                isEnabled: false,
                isSourceRow: true,
                perform: {}
            )))
            entries.append(.separator)
        }

        if devices.isEmpty {
            entries.append(.disabledNotice("No microphones found"))
        } else {
            entries.append(contentsOf: devices.map { device in
                OverflowEntry.action(OverflowAction(
                    id: "sourceMic:\(device.uid)",
                    title: device.name,
                    isChecked: device.uid == selectedUID,
                    isSourceRow: true,
                    perform: { onSelectSource(.mic(deviceUID: device.uid)) }
                ))
            })
        }

        let title: String
        if let liveName {
            title = liveName
        } else if selectedUID != nil {
            title = context.selectedMicName ?? "Microphone"
        } else {
            title = "Microphone"
        }

        return OverflowSubmenu(
            id: "sourceMicrophone",
            title: title,
            isChecked: selectedUID != nil,
            entries: entries
        )
    }

    /// One root row for the whole per-app *kind*, whose title carries the current
    /// choice. Runtime-enumerated contents always live behind a submenu, so
    /// launching an app can never reshape the menu the user is looking at.
    static func perAppSubmenu(_ context: OverflowContext) -> OverflowSubmenu {
        let selectedBundleID: String? = {
            if case .app(let bundleID) = context.selectedSource { return bundleID }
            return nil
        }()

        return OverflowSubmenu(
            id: "sourcePerApp",
            title: selectedAppTitle(context, selectedBundleID: selectedBundleID),
            isChecked: selectedBundleID != nil,
            entries: perAppEntries(context, selectedBundleID: selectedBundleID)
        )
    }

    private static func selectedAppTitle(
        _ context: OverflowContext,
        selectedBundleID: String?
    ) -> String {
        guard let selectedBundleID else { return "App" }
        // Prefer the live name, fall back to the remembered one, and only show a
        // bundle ID when neither exists — it is ugly, but inventing a name is
        // worse and showing nothing loses the selection entirely.
        if let running = context.apps?.first(where: { $0.bundleID == selectedBundleID }) {
            return running.applicationName
        }
        return context.selectedAppName ?? selectedBundleID
    }

    private static func perAppEntries(
        _ context: OverflowContext,
        selectedBundleID: String?
    ) -> [OverflowEntry] {
        // Permission first, and it is a hard gate: without it we must not call
        // `SCShareableContent` at all, so merely *hovering* this submenu cannot
        // raise a system dialog. An enabled row beats a disabled one here — the
        // user is asking "why can't I?" and this answers it *and* fixes it.
        guard context.permissionGranted else {
            return [.action(OverflowAction(
                id: "sourcePermissionNeeded",
                title: "Allow Screen Recording…",
                perform: { onRequestPermission() }
            ))]
        }

        var entries: [OverflowEntry] = []

        // A selection that isn't running still has to render, checked, or the
        // menu emits zero checkmarks and silently implies "All System Audio"
        // while `startRecording` fails with `.appNotRunning`.
        let isRunning = context.apps?.contains { $0.bundleID == selectedBundleID } ?? false
        if let selectedBundleID, !isRunning {
            let name = context.selectedAppName ?? selectedBundleID
            entries.append(.action(OverflowAction(
                id: "sourceAppNotRunning",
                title: "\(name) (not running)",
                isChecked: true,
                isEnabled: false,
                isSourceRow: true,
                perform: {}
            )))
            entries.append(.separator)
        }

        guard let apps = context.apps else {
            // Cache is cold and nothing has probed yet. Saying "no apps are open"
            // here would be a claim we have not earned.
            entries.append(.disabledNotice("Looking for open apps…"))
            return entries
        }

        guard !apps.isEmpty else {
            entries.append(.disabledNotice("No other apps are open"))
            return entries
        }

        entries.append(contentsOf: apps.map { app in
            .action(OverflowAction(
                id: "sourceApp:\(app.bundleID)",
                title: app.applicationName,
                isChecked: app.bundleID == selectedBundleID,
                isSourceRow: true,
                perform: { onSelectSource(.app(bundleID: app.bundleID)) }
            ))
        })
        return entries
    }

    /// Opens System Settings at the Screen Recording pane. Set by
    /// `MenuBarController`, which has the view model that owns the navigation.
    static var onRequestPermission: @MainActor () -> Void = {}

    /// Runs a Sparkle update check (BL-034). Set once at startup by
    /// `MenuBarController`, which owns the updater.
    ///
    /// Another entry in the static-closure set TD-010 wants retired. Added here
    /// rather than inventing a fifth mechanism for one row: `OverflowContext` is
    /// `Equatable` and so cannot carry a closure, and a singleton updater would
    /// be worse debt than the pattern already in use.
    static var onCheckForUpdates: @MainActor () -> Void = {}

    /// Why "Check for Updates…" is greyed, or `nil` when it is live.
    ///
    /// A pure function so the precedence between the two independent reasons is
    /// assertable rather than buried in a ternary inside a row builder.
    static func updateRowTooltip(_ context: OverflowContext) -> String? {
        if !context.allowsUpdateInstall {
            return "Installing an update restarts Home Rec, which would end the recording."
        }
        if !context.updaterIsUsable {
            // Deliberately does not say why — the causes are all misconfigured
            // builds the user cannot act on. Point at the thing they *can* do.
            return "Home Rec can't check for updates right now. You can download the latest version from homerec.app."
        }
        return nil
    }

    /// The app-level actions — always present.
    ///
    /// Takes the context only for the update row's enabled state. Everything else
    /// here is context-free and stays that way.
    static func appActionEntries(_ context: OverflowContext) -> [OverflowEntry] {
        [
            .action(OverflowAction(id: "showWindow", title: "Show Window", perform: showMainWindow)),
            .separator,
            .action(OverflowAction(
                id: "recoverRecordings",
                title: "Recover Recordings…",
                toolTip: "Useful if you forgot to save a recording, or if Home Rec crashed mid-recording.",
                perform: showRecovery
            )),
            .separator,
            .action(OverflowAction(id: "exportDiagnostics", title: "Export Diagnostics…", perform: Diagnostics.exportReport)),
            .action(OverflowAction(id: "reportProblem", title: "Report a Problem", perform: Diagnostics.reportProblem)),
            .action(OverflowAction(id: "about", title: "About Home Rec", perform: showAbout)),
            // Greyed rather than hidden while recording — deliberately unlike the
            // capture-source rows above. Those are *settings*, and the app already
            // settled that locked settings disappear with the shelf. This is an
            // app-level action that is permanently present in every other state;
            // making it vanish mid-take would read as a bug, and the tooltip can
            // explain a grey row where nothing can explain an absent one.
            .action(OverflowAction(
                id: "checkForUpdates",
                title: "Check for Updates…",
                // Recording wins the explanation when both apply: it is the one
                // the user caused and the one that clears on its own.
                toolTip: updateRowTooltip(context),
                isEnabled: context.allowsUpdateInstall && context.updaterIsUsable,
                perform: { onCheckForUpdates() }
            )),
            .separator,
            .action(OverflowAction(id: "quit", title: "Quit Home Rec", commandKey: "q") {
                NSApp.terminate(nil)
            })
        ]
    }

    /// Every action the builder emits for `context`, **including inside
    /// submenus**, separators and headers dropped.
    ///
    /// Recursing matters: the mid-recording lock and one-checkmark invariants are
    /// asserted over this, and a per-app row that stayed clickable would hide
    /// inside a submenu where a top-level-only walk could never see it.
    static func actions(_ context: OverflowContext = OverflowContext()) -> [OverflowAction] {
        flatten(entries(context))
    }

    private static func flatten(_ entries: [OverflowEntry]) -> [OverflowAction] {
        entries.flatMap { entry -> [OverflowAction] in
            switch entry {
            case .action(let action):
                return [action]
            case .submenu(let submenu):
                // The submenu's own row is an action-like source row in its own
                // right (it carries the checkmark), so include it as well as its
                // contents.
                let parent = OverflowAction(
                    id: submenu.id,
                    title: submenu.title,
                    isChecked: submenu.isChecked,
                    isEnabled: submenu.isEnabled,
                    isSourceRow: submenu.isSourceRow,
                    perform: {}
                )
                return [parent] + flatten(submenu.entries)
            case .separator, .sectionHeader, .disabledNotice:
                return []
            }
        }
    }

    // MARK: - Action implementations

    private static func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // The main window is the WindowGroup titled "Home Rec" (see `HomeRecApp`).
        // Matching on title is the only stable handle AppKit has on a SwiftUI
        // scene's window, and the app deliberately outlives its closure, so the
        // window may legitimately be absent here.
        NSApp.windows.first { $0.title == "Home Rec" }?.makeKeyAndOrderFront(nil)
    }

    /// Supplies the file being written right now, so the recovery window never
    /// offers the live recording — which is unfinalized by definition. Set once
    /// at startup by `MenuBarController`; nil when nothing is recording.
    /// (BL-111 will replace this with a proper menu context.)
    static var currentRecordingURL: @MainActor () -> URL? = { nil }

    private static func showRecovery() {
        RecoveryWindowController.shared.show(inProgressURL: currentRecordingURL)
    }

    private static func showAbout() {
        // Activate first: as a menu-bar app Home Rec is often not frontmost, and
        // the panel would otherwise open behind whatever the user is working in.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

// MARK: - AppKit rendering

/// Retains a menu action's closure for the lifetime of its `NSMenuItem`.
/// AppKit's target/action can't invoke a Swift closure directly, and
/// `NSMenuItem.target` doesn't retain, so the item holds this box in
/// `representedObject` to keep it alive.
private final class OverflowActionTarget: NSObject {
    private let perform: @MainActor () -> Void

    init(perform: @escaping @MainActor () -> Void) {
        self.perform = perform
    }

    @objc func fire(_ sender: Any?) {
        // Menu actions are always delivered on the main thread by AppKit.
        MainActor.assumeIsolated { perform() }
    }
}

@MainActor
extension OverflowMenu {

    /// Render `context` as a real `NSMenu`.
    ///
    /// Both surfaces — the status item's right-click and the popover's "•••" —
    /// now call this. They used to render the same list twice, once as `NSMenu`
    /// and once as a SwiftUI `Menu`, and parity between them was an assertion.
    /// It is now an identity.
    static func makeNSMenu(_ context: OverflowContext = OverflowContext()) -> NSMenu {
        let menu = NSMenu()
        populate(menu, with: entries(context))
        return menu
    }

    /// Fill `menu` with `entries`, replacing whatever it held.
    ///
    /// Separate from `makeNSMenu` because the per-app submenu is refreshed
    /// **in place while it is open** — see `PerAppMenuDelegate`.
    static func populate(_ menu: NSMenu, with entries: [OverflowEntry]) {
        menu.removeAllItems()
        for entry in entries {
            switch entry {
            case .separator:
                menu.addItem(.separator())

            case .sectionHeader(let title):
                // Applies system styling itself, so the title is passed in
                // sentence case rather than pre-uppercased.
                menu.addItem(.sectionHeader(title: title))

            case .disabledNotice(let title):
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)

            case .action(let action):
                menu.addItem(makeItem(for: action))

            case .submenu(let submenu):
                let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
                item.state = submenu.isChecked ? .on : .off
                item.isEnabled = submenu.isEnabled
                // Carries the builder's stable id, so a caller can find this row
                // to attach a delegate without matching on user-visible copy.
                item.identifier = NSUserInterfaceItemIdentifier(submenu.id)
                let child = NSMenu(title: submenu.title)
                populate(child, with: submenu.entries)
                item.submenu = child
                menu.addItem(item)
            }
        }
    }

    private static func makeItem(for action: OverflowAction) -> NSMenuItem {
        let item = NSMenuItem(
            title: action.title,
            // A disabled row must have no action, or AppKit's automatic menu
            // enabling can re-enable it behind us.
            action: action.isEnabled ? #selector(OverflowActionTarget.fire(_:)) : nil,
            // NSMenuItem defaults its modifier mask to command, matching the
            // command-only shortcuts `OverflowAction` models.
            keyEquivalent: action.commandKey.map(String.init) ?? ""
        )
        item.toolTip = action.toolTip
        item.state = action.isChecked ? .on : .off
        item.isEnabled = action.isEnabled
        if action.isEnabled {
            let target = OverflowActionTarget(perform: action.perform)
            item.target = target
            item.representedObject = target
        }
        return item
    }
}

// MARK: - The popover's "•••" affordance

/// Pops the same `NSMenu` the status item's right-click does.
///
/// ⚠️ This deliberately is **not** a SwiftUI `Menu`. SwiftUI evaluates a
/// `Menu`'s content ViewBuilder **eagerly** — measured: the closure body runs
/// with zero clicks, before the menu is ever opened — and offers no supported
/// open hook. A capture-source picker built inside one would therefore call
/// `SCShareableContent` on *popover appearance*: a zero-click permission dialog,
/// the exact bug class BL-085 removed. A plain `Button` that builds the menu in
/// its action keeps enumeration behind a real click.
struct OverflowMenuButton: View {

    var body: some View {
        Button {
            // Built in the action, never in the view body: that timing is the
            // whole point of this type.
            let menu = OverflowMenu.makeConfiguredMenu()
            // Screen coordinates: passing `in: nil` avoids needing a host view,
            // which SwiftUI does not hand out.
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                // The glyph alone is a thin hit target; pad it out to a
                // comfortable click area without drawing any visible chrome.
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("More options")
        .accessibilityLabel("More options")
    }
}

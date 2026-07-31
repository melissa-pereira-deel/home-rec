//
//  OverflowMenuTests.swift
//  HomeRecTests
//
//  BL-110: the overflow menu is defined once and rendered by two surfaces
//  (the popover's "•••" Menu and the status item's right-click NSMenu). These
//  guard the two invariants that matter: no action reachable in v1.0 goes
//  missing, and the two surfaces stay identical.
//

import Testing
import AppKit
@testable import HomeRec

@MainActor
struct OverflowMenuTests {

    /// A context in which the capture-source section is absent, so these tests
    /// keep asserting exactly the app-level action set they were written for.
    /// The section's own behaviour lives in `CaptureSourceMenuTests`.
    private var recordingContext: OverflowContext {
        OverflowContext(allowsCaptureSourceChange: false)
    }

    /// Every action that was a flat popover button before BL-110, plus the
    /// standard app-menu pair. Losing any of these is a user-facing regression.
    @Test("Menu still offers every action that was reachable in v1.0")
    func retainsPreviouslyReachableActions() {
        let ids = Set(OverflowMenu.actions(recordingContext).map(\.id))
        #expect(ids.isSuperset(of: ["showWindow", "exportDiagnostics", "reportProblem", "quit"]))
    }

    @Test("Quit is bound to ⌘Q")
    func quitHasCommandQ() throws {
        let quit = try #require(OverflowMenu.actions(recordingContext).first { $0.id == "quit" })
        #expect(quit.commandKey == "q")
    }

    @Test("Quit is the only shortcut-bound action for now")
    func onlyQuitHasAShortcut() {
        let shortcutBound = OverflowMenu.actions(recordingContext).filter { $0.commandKey != nil }.map(\.id)
        #expect(shortcutBound == ["quit"])
    }

    @Test("Action ids are unique — they key test assertions and must not collide")
    func actionIDsAreUnique() {
        let ids = OverflowMenu.actions(recordingContext).map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("No action ships with an empty title")
    func everyActionHasATitle() {
        #expect(OverflowMenu.actions(recordingContext).allSatisfy { !$0.title.isEmpty })
    }

    // MARK: - The AppKit twin matches the shared definition

    @Test("NSMenu renders exactly the shared entries, in order, separators included")
    func nsMenuMatchesEntries() {
        let context = recordingContext
        let items = OverflowMenu.makeNSMenu(context).items
        let entries = OverflowMenu.entries(context)

        #expect(items.count == entries.count)

        for (item, entry) in zip(items, entries) {
            switch entry {
            case .separator:
                #expect(item.isSeparatorItem)
            case .action(let action):
                #expect(item.isSeparatorItem == false)
                #expect(item.title == action.title)
                #expect(item.keyEquivalent == action.commandKey.map(String.init) ?? "")
            case .sectionHeader(let title):
                #expect(item.title == title)
            case .disabledNotice(let title):
                #expect(item.title == title)
                #expect(item.isEnabled == false)
            case .submenu(let submenu):
                #expect(item.title == submenu.title)
                #expect(item.submenu != nil)
            }
        }
    }

    @Test("Every enabled NSMenu action item is wired to a target — no dead rows")
    func nsMenuItemsAreWired() {
        let actionItems = OverflowMenu.makeNSMenu(recordingContext).items
            .filter { !$0.isSeparatorItem && $0.isEnabled && $0.submenu == nil }
        #expect(actionItems.isEmpty == false)
        // `NSMenuItem.target` does not retain, so a missing retain elsewhere would
        // surface here as a nil target and a silently unresponsive row.
        #expect(actionItems.allSatisfy { $0.target != nil && $0.action != nil })
    }

    // MARK: - Click routing

    @Test("Right-click opens the overflow menu")
    func rightClickShowsMenu() {
        #expect(MenuBarController.shouldShowOverflowMenu(type: .rightMouseUp, modifiers: []))
    }

    @Test("Control-click opens the overflow menu (macOS convention)")
    func controlClickShowsMenu() {
        #expect(MenuBarController.shouldShowOverflowMenu(type: .leftMouseUp, modifiers: .control))
    }

    @Test("Plain left-click does not open the menu — it belongs to the popover")
    func leftClickShowsPopover() {
        #expect(MenuBarController.shouldShowOverflowMenu(type: .leftMouseUp, modifiers: []) == false)
    }

    @Test("Other modifiers on a left-click still open the popover")
    func otherModifiersShowPopover() {
        for modifier in [NSEvent.ModifierFlags.command, .option, .shift] {
            #expect(MenuBarController.shouldShowOverflowMenu(type: .leftMouseUp, modifiers: modifier) == false)
        }
    }
}

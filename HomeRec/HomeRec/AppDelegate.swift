//
//  AppDelegate.swift
//  HomeRec
//
//  App delegate to keep the app alive when the main window is closed
//  and hold the menu bar controller reference.
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    var menuBarController: MenuBarController?

    /// Decides whether a quit may proceed, and finishes the open take if not
    /// (BL-174). Wired alongside `menuBarController`.
    var terminationCoordinator: TerminationCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // The design system is dark-only by intent — it has no light palette and
        // is not getting one — so the app stops following the system setting.
        //
        // This one line is also the only way to reach the surfaces SwiftUI can't
        // style: the capture-source menu, the alerts, and Sparkle's update
        // dialogs are all AppKit. Without it, a light-mode user gets a deep
        // blue-black window with a light grey menu hanging off it — the
        // half-migrated look this is meant to avoid, arriving through the back
        // door. Forcing the appearance is what buys those surfaces, not what
        // costs them.
        //
        // Two things this deliberately does not reach, and must not: the menu
        // bar icon follows the *menu bar's* appearance rather than the app's
        // (a dark-forced template image disappears on a light menu bar), and
        // the open/save panels run out of process in the sandbox, so they stay
        // on the system setting whatever we do here.
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// Finish the open take before quitting (BL-174).
    ///
    /// This is the only place that catches *every* way out: ⌘Q, the app menu's
    /// Quit, the overflow menu's Quit row, the Dock menu, and logout. Fixing only
    /// the overflow row would have left the keystroke — the common path — still
    /// severing the file, because SwiftUI's stock `.appTermination` command group
    /// is intact and never routes through our menu.
    ///
    /// AppKit calls this on the main thread; `assumeIsolated` states that rather
    /// than hopping, which would return after the reply was already needed. Same
    /// pattern as `OverflowMenu`'s menu callbacks.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            // No coordinator means we cannot tell whether a take is open. Quit
            // rather than hang: an app that will not quit is a worse failure than
            // a take that needed recovery, and this is the branch a wiring
            // mistake lands on.
            guard let terminationCoordinator else { return .terminateNow }
            return terminationCoordinator.shouldTerminate()
        }
    }
}

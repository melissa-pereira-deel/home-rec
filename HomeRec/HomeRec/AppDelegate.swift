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
}

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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

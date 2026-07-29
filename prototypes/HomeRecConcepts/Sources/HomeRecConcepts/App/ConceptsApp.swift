import SwiftUI
import AppKit

/// Pure-UI concept prototype for the Home Rec redesign.
/// Runs unbundled via `swift run` — the app-delegate adaptor promotes the
/// process to a regular, focused app so the stage window fronts immediately.
@main
struct ConceptsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        Self.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup("Home Rec — Concepts") {
            StageView()
        }
        .windowResizability(.contentSize)
    }

    /// Same mechanism as the shipping app (`HomeRecApp.registerCustomFonts`),
    /// pointed at `Bundle.module` since SwiftPM owns the resources here.
    private static func registerBundledFonts() {
        for name in ["Archivo-Variable", "Inter"] {
            guard let url = Bundle.module.url(
                forResource: name, withExtension: "ttf", subdirectory: "Fonts"
            ) else {
                NSLog("ConceptsApp: missing font resource \(name).ttf")
                continue
            }
            var errorRef: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &errorRef) {
                let description = (errorRef?.takeRetainedValue()).map(String.init(describing:)) ?? "unknown"
                NSLog("ConceptsApp: failed to register \(name).ttf — \(description)")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unbundled executables launch as background processes; promote and front.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
        SnapshotDriver.runIfRequested()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

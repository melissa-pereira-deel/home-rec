//
//  HomeRecApp.swift
//  HomeRec
//
//  Created by Melissa de Britto Pereira on 10/01/26.
//

import SwiftUI
import CoreText

@main
struct HomeRecApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = RecorderViewModel()

    init() {
        // Register custom fonts from the app bundle
        Self.registerCustomFonts()

        // Test debug logging at app launch
        DebugLogger.log("🚀 HomeRec app launched!")
        print("🚀 HomeRec app launched!")
    }

    private static func registerCustomFonts() {
        let fontFiles = ["Archivo-Variable", "Inter"]
        for fontName in fontFiles {
            guard let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf") else {
                print("⚠️ \(fontName).ttf not found in bundle")
                continue
            }
            var errorRef: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &errorRef) {
                let error = errorRef?.takeRetainedValue()
                print("⚠️ Failed to register \(fontName) font: \(error?.localizedDescription ?? "unknown")")
            } else {
                print("✅ \(fontName) font registered successfully")
            }
        }
    }

    var body: some Scene {
        WindowGroup("Home Rec") {
            RecorderView()
                .environmentObject(viewModel)
                .onAppear {
                    // Wire up the menu bar controller with the shared view model
                    if appDelegate.menuBarController == nil {
                        appDelegate.menuBarController = MenuBarController(viewModel: viewModel)
                    }
                }
        }
        .windowResizability(.contentSize)
    }
}

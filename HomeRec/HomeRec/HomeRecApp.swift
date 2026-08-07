//
//  HomeRecApp.swift
//  HomeRec
//
//  Created by Melissa de Britto Pereira on 10/01/26.
//

import SwiftUI
import CoreText
import os

@main
struct HomeRecApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = RecorderViewModel()

    init() {
        // Register custom fonts from the app bundle
        Self.registerCustomFonts()
    }

    private static func registerCustomFonts() {
        let fontFiles = ["Archivo-Variable", "Inter"]
        for fontName in fontFiles {
            guard let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf") else {
                Log.recorder.error("Font resource not found in bundle: \(fontName, privacy: .public).ttf")
                continue
            }
            var errorRef: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &errorRef) {
                let error = errorRef?.takeRetainedValue()
                Log.recorder.error("Failed to register font \(fontName, privacy: .public): \(error?.localizedDescription ?? "unknown", privacy: .public)")
            }
        }
    }

    var body: some Scene {
        WindowGroup("Home Rec") {
            // Flat ground, not the design system's mesh backdrop.
            //
            // The mesh exists so that a frosted panel has tonal variation to
            // sample — over flat black, a translucent panel is just a grey
            // rectangle. This window has no panel: it is one centred column
            // straight on the window background. With nothing sampling it, the
            // mesh stops reading as depth and starts reading as blue wallpaper,
            // which is a lot of colour for a window whose job is to stay out of
            // the way. If the layout ever grows a real glass panel, the mesh
            // earns its place and `GlassBackdrop()` goes back here.
            //
            // The ground is a sibling of RecorderView rather than a modifier on
            // it, and that placement is load-bearing. RecorderViewModel is an
            // ObservableObject, so publishing a waveform frame invalidates every
            // view that reads it — the whole of RecorderView's body, roughly 47
            // times a second while recording. Out here the ground reads the theme
            // and nothing else, so it stays out of that.
            RecorderView()
                .environmentObject(viewModel)
                .onAppear {
                    // Wire up the menu bar controller with the shared view model
                    if appDelegate.menuBarController == nil {
                        appDelegate.menuBarController = MenuBarController(viewModel: viewModel)
                    }
                }
                // `.background` rather than a ZStack sibling, and the distinction
                // is load-bearing twice over. A background is sized *by* its
                // content and never the other way round, so the window keeps the
                // fixed 450×450 that `.windowResizability(.contentSize)` depends
                // on — as a ZStack sibling the ground is a Color, which is
                // infinitely flexible, and the window becomes freely resizable
                // with the controls stranded in the middle of it. It also still
                // sits outside RecorderView's body, so the ~47×/sec waveform
                // republish never drags the ground through a redraw.
                .background(GlassWindowGround())
                .glassThemeAdaptingToContrast()
        }
        .windowResizability(.contentSize)
        // No titlebar band: the glass runs to the window's top edge and the
        // traffic lights float on it. This is SwiftUI's own lever — the AppKit
        // route (`titlebarAppearsTransparent` + `.fullSizeContentView`) gets
        // reasserted from under us on scene updates, so the band kept coming
        // back. The title *text* goes with it; the app's name is carried by the
        // brand lockup in the header, which is where the Glass concept puts it.
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Welcome to Home Rec") {
                    NSApp.activate(ignoringOtherApps: true)
                    viewModel.showOnboardingAgain()
                }
            }
        }
    }
}

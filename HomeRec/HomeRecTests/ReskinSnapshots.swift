//
//  ReskinSnapshots.swift
//  HomeRecTests
//
//  Renders every visual state to a PNG, so someone can look at all of them.
//
//  This is not a snapshot *test*: nothing here asserts, and it can never fail a
//  build. On a deliberate visual change every reference image would differ, so
//  golden-image comparison would produce pure churn and be deleted within a
//  release. What it does instead is remove the *cost* of looking.
//
//  The states worth checking are the ones nobody checks, because reaching them
//  means denying a permission, running from a mounted DMG, or killing a take
//  mid-write. Each is minutes of setup, several are destructive, and the run log
//  shows the result: they are never exercised. A state that renders dark text on
//  a dark ground therefore ships, and the person who finds it is someone whose
//  recording just failed.
//
//  Here they are built directly from a stubbed view model and photographed. One
//  command, a folder of images, a minute of flipping through them — including
//  the high-contrast palette, which is checked by injecting the environment
//  value rather than by asking anyone to toggle a system setting.
//
//  Opt-in, because it writes files:
//
//      TEST_RUNNER_HR_SNAPSHOT=/tmp/reskin xcodebuild test \
//        -project HomeRec/HomeRec.xcodeproj -scheme HomeRec \
//        -destination 'platform=macOS' \
//        -only-testing:HomeRecTests/ReskinSnapshots
//
//  ⚠️ The `TEST_RUNNER_` prefix is required and is silently load-bearing. Tests
//  run in their own process and do not inherit the shell's environment;
//  xcodebuild forwards only variables carrying that prefix, stripping it on the
//  way. Set plain `HR_SNAPSHOT` and everything passes, cheerfully, writing
//  nothing.
//
//  Unset, every case skips. `cacheDisplay` is used rather than a screen grab, so
//  this needs no Screen Recording permission and no window ever appears.
//

import Testing
import SwiftUI
import AppKit
@testable import HomeRec

@MainActor
struct ReskinSnapshots {

    // MARK: - Where the images go

    /// Nil when `HR_SNAPSHOT` is unset, which is what makes every case skip.
    private static var outputDirectory: URL? {
        guard let path = ProcessInfo.processInfo.environment["HR_SNAPSHOT"],
              !path.isEmpty else { return nil }
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - Rendering

    /// Renders `view` at `size` and writes `<name>.png`.
    ///
    /// `cacheDisplay` draws the layer tree straight into a bitmap, so the view
    /// never has to be on screen and no capture permission is involved. The
    /// window is offscreen and closed immediately; nothing flashes.
    private func write(
        _ name: String,
        size: CGSize,
        contrast: ColorSchemeContrast,
        @ViewBuilder _ view: () -> some View
    ) {
        guard let directory = Self.outputDirectory else { return }

        // The ground is applied here because in the app it lives on the window
        // (HomeRecApp), not inside these views — without it every snapshot is
        // white-on-white and proves nothing about the thing being checked.
        //
        // Flat ground, not the real `GlassWindowGround`: that one blurs the
        // desktop through a non-opaque window, and an offscreen window has no
        // desktop behind it. Flat is deterministic and slightly conservative —
        // the shipped glass is a touch lighter. Whether text survives over a
        // *real* desktop stays a human check, and is in manual-acceptance.md.
        // The palette is injected directly rather than adapted from the
        // environment. Two things block the obvious routes:
        // `EnvironmentValues.colorSchemeContrast` is read-only, and setting
        // `NSAppearance(named: .accessibilityHighContrastDarkAqua)` on the
        // hosting view does *not* make SwiftUI report `.increased` — measured:
        // the record pill rendered the identical RGB either way, so the
        // "increased contrast" images were showing the standard palette.
        //
        // Injecting the theme is therefore the only lever that actually changes
        // anything here. The cost is that it proves the *palette* is legible,
        // not that `glassThemeAdaptingToContrast()` fires — the wiring itself
        // stays a human check with the real system setting.
        let root = view()
            .background(GlassFlatGround())
            .glassTheme(contrast == .increased ? .highContrast : .standard)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = CGRect(origin: .zero, size: size)

        // Stands in for the global dark pin in AppDelegate, which no test
        // process runs.
        let appearance = NSAppearance(named: .darkAqua)
        hosting.appearance = appearance

        // A real window backs the view so materials resolve; never ordered front.
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = appearance
        window.contentView = hosting
        window.layoutIfNeeded()
        // SwiftUI lays out asynchronously; without draining the loop the first
        // frame can be captured half-built.
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        let suffix = contrast == .increased ? "-increased-contrast" : ""
        if let png = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
            try? png.write(to: directory.appendingPathComponent("\(name)\(suffix).png"))
        }

        window.contentView = nil
    }

    // MARK: - Stubbed state

    private static let windowSize = CGSize(width: 450, height: 450)
    private static let popoverSize = CGSize(width: 280, height: 240)

    /// Local stand-in for the suite's `private` TestError.
    private struct SnapshotError: Error {
        let message: String
        var localizedDescription: String { message }
    }

    private func makeViewModel(
        permission: PermissionStatus = .granted,
        install: InstallLocation = .applications,
        controller: MockRecordingControlling? = nil
    ) -> RecorderViewModel {
        RecorderViewModel(
            controller: controller ?? MockRecordingControlling(),
            permissions: MockPermissionProviding(permission),
            clock: ManualClock(),
            saveLocation: MockSaveLocationProviding(
                directory: URL(fileURLWithPath: "/Users/me/Desktop")
            ),
            installLocation: MockInstallLocationProviding(install),
            // A scratch suite, or the images inherit whatever format the person
            // running this happens to have selected — the snapshots would drift
            // between machines and quietly stop being comparable.
            defaults: Self.scratchDefaults
        )
    }

    private static let scratchDefaults: UserDefaults = {
        let suite = UserDefaults(suiteName: "com.mdebritto.HomeRec.snapshots")!
        suite.removePersistentDomain(forName: "com.mdebritto.HomeRec.snapshots")
        return suite
    }()

    /// Puts a view model into `.recording` with the given samples.
    ///
    /// `state` is `private(set)`, and deliberately so — driving it through the
    /// real entry point means these images show states the app can actually
    /// reach, not ones only a test could construct.
    private func recording(samples: [Float]) async -> RecorderViewModel {
        let viewModel = makeViewModel()
        await viewModel.startRecording()
        viewModel.waveformSamples = samples
        return viewModel
    }

    private func errored(_ detail: String) async -> RecorderViewModel {
        let controller = MockRecordingControlling()
        controller.startError = SnapshotError(message: detail)
        let viewModel = makeViewModel(controller: controller)
        await viewModel.startRecording()
        return viewModel
    }

    /// A recognisably musical envelope, so a broken level mapping is obvious at
    /// a glance rather than needing to be measured.
    ///
    /// Deliberately quiet: peaks at 0.05 (≈ −26 dBFS), which is the region a
    /// linear mapping rendered as the 2pt minimum bar — silence, to the eye —
    /// and which the decibel curve has to make visible. A loud fixture would
    /// look fine either way and prove nothing.
    private func quietSamples(count: Int = 200) -> [Float] {
        (0..<count).map { index in
            let position = Double(index) / Double(count)
            let envelope = 0.5 + 0.5 * sin(position * .pi * 6)
            let syllable = 0.35 + 0.65 * abs(sin(position * .pi * 23))
            return Float(0.05 * envelope * syllable)
        }
    }

    private func loudSamples(count: Int = 200) -> [Float] {
        quietSamples(count: count).map { $0 * 12 }
    }

    // MARK: - Cases

    @Test("Main window, every state", arguments: [ColorSchemeContrast.standard, .increased])
    func mainWindow(contrast: ColorSchemeContrast) async {
        guard Self.outputDirectory != nil else { return }

        // Ready — the resting face.
        let ready = makeViewModel()
        write("window-01-ready", size: Self.windowSize, contrast: contrast) {
            RecorderView().environmentObject(ready)
        }

        // Recording, quiet material. The regression case: at this level a
        // linear mapping drew a flat dotted line.
        let quiet = await recording(samples: quietSamples())
        write("window-02-recording-quiet", size: Self.windowSize, contrast: contrast) {
            RecorderView().environmentObject(quiet)
        }

        // Recording, loud material — the top of the range still fits.
        let loud = await recording(samples: loudSamples())
        write("window-03-recording-loud", size: Self.windowSize, contrast: contrast) {
            RecorderView().environmentObject(loud)
        }

        // Recording true silence: every bar at the 2pt floor. Must stay
        // distinguishable from the quiet case above, or the floor is lying.
        let silent = await recording(samples: Array(repeating: 0, count: 200))
        write("window-04-recording-silent", size: Self.windowSize, contrast: contrast) {
            RecorderView().environmentObject(silent)
        }

        // Permission not granted — the button carries "Open System Settings"
        // and must not wear the record accent.
        let denied = makeViewModel(permission: .denied)
        write("window-05-permission-denied", size: Self.windowSize, contrast: contrast) {
            RecorderView().environmentObject(denied)
        }

        let undetermined = makeViewModel(permission: .notDetermined)
        write("window-06-permission-undetermined", size: Self.windowSize, contrast: contrast) {
            RecorderView().environmentObject(undetermined)
        }

        // Running from the mounted DMG: recording refused outright.
        let translocated = makeViewModel(install: .translocated)
        write("window-07-install-blocked", size: Self.windowSize, contrast: contrast) {
            RecorderView().environmentObject(translocated)
        }

        // Outside /Applications — the dismissible note, not the hard block.
        let elsewhere = makeViewModel(
            install: .elsewhere(URL(fileURLWithPath: "/Users/me/Downloads/Home Rec.app"))
        )
        write("window-08-install-notice", size: Self.windowSize, contrast: contrast) {
            RecorderView().environmentObject(elsewhere)
        }

        // Error, with a recovery action offered.
        let failed = await errored("no capture device")
        write("window-09-error", size: Self.windowSize, contrast: contrast) {
            RecorderView().environmentObject(failed)
        }
    }

    /// Standard palette only, unlike the main window.
    ///
    /// `MenuBarPopoverView` calls `.glassThemeAdaptingToContrast()` on itself —
    /// it is hosted by AppKit, so that is the only place the injection can go —
    /// which overrides anything set from outside and resolves back to
    /// `.standard`. Emitting an "increased contrast" image here would show the
    /// standard palette under a name that says otherwise, which is worse than
    /// not emitting one. Same for the sheets below.
    @Test("Menu-bar popover, every state", arguments: [ColorSchemeContrast.standard])
    func popover(contrast: ColorSchemeContrast) async {
        guard Self.outputDirectory != nil else { return }

        let ready = makeViewModel()
        write("popover-01-ready", size: Self.popoverSize, contrast: contrast) {
            MenuBarPopoverView().environmentObject(ready)
        }

        let live = await recording(samples: quietSamples())
        write("popover-02-recording", size: Self.popoverSize, contrast: contrast) {
            MenuBarPopoverView().environmentObject(live)
        }

        let failed = await errored("the selected app is not running")
        write("popover-03-error", size: Self.popoverSize, contrast: contrast) {
            MenuBarPopoverView().environmentObject(failed)
        }

        let blocked = makeViewModel(install: .translocated)
        write("popover-04-install-blocked", size: Self.popoverSize, contrast: contrast) {
            MenuBarPopoverView().environmentObject(blocked)
        }
    }

    @Test("Sheets and panels", arguments: [ColorSchemeContrast.standard])
    func sheets(contrast: ColorSchemeContrast) {
        guard Self.outputDirectory != nil else { return }

        let granted = makeViewModel()
        write("sheet-01-onboarding-granted", size: CGSize(width: 420, height: 440), contrast: contrast) {
            OnboardingView().environmentObject(granted)
        }

        let notGranted = makeViewModel(permission: .notDetermined)
        write("sheet-02-onboarding-ungranted", size: CGSize(width: 420, height: 440), contrast: contrast) {
            OnboardingView().environmentObject(notGranted)
        }


        write("sheet-03-install-panel", size: CGSize(width: 340, height: 180), contrast: contrast) {
            InstallLocationNoticeView(
                message: InstallLocation.translocated.explanation ?? "",
                onReveal: {},
                onDismiss: {}
            )
        }
    }
}

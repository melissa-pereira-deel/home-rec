import AppKit
import SwiftUI

/// How a snapshot run is configured and where it reads its switches from.
@available(macOS 15.0, *)
public struct StageSnapshotConfiguration {
    /// Environment variable holding the output directory. Setting it is what
    /// turns an ordinary launch into a capture run — no separate executable,
    /// no test target, and therefore no second copy of the stage to keep in
    /// sync with the one people actually review.
    public var directoryEnvironmentKey: String
    /// Environment variable holding a substring filter over scenario ids.
    public var filterEnvironmentKey: String
    /// Environment variable holding a comma-separated tag filter.
    public var tagEnvironmentKey: String
    /// Window to capture, matched by title. Matching by title rather than
    /// taking the first visible window matters: a popover, sheet, or tooltip is
    /// its own `NSWindow` and would otherwise be captured instead of the stage.
    public var windowTitle: String?
    /// Wait before the first capture, for the window to appear and lay out.
    public var initialSettle: Duration
    /// Quit when the run finishes. True is right for CI; false lets you watch
    /// a run happen, which is the fastest way to debug a wrong `settle`.
    public var terminatesWhenFinished: Bool

    public init(
        windowTitle: String? = nil,
        directoryEnvironmentKey: String = "STAGE_SNAPSHOT",
        filterEnvironmentKey: String = "STAGE_SNAPSHOT_FILTER",
        tagEnvironmentKey: String = "STAGE_SNAPSHOT_TAGS",
        initialSettle: Duration = .milliseconds(700),
        terminatesWhenFinished: Bool = true
    ) {
        self.windowTitle = windowTitle
        self.directoryEnvironmentKey = directoryEnvironmentKey
        self.filterEnvironmentKey = filterEnvironmentKey
        self.tagEnvironmentKey = tagEnvironmentKey
        self.initialSettle = initialSettle
        self.terminatesWhenFinished = terminatesWhenFinished
    }
}

@available(macOS 15.0, *)
public struct StageSnapshotReport {
    public var written: [URL] = []
    /// Scenario ids skipped by a filter.
    public var skipped: [String] = []
    /// Scenario ids whose capture failed, with the reason.
    public var failed: [(id: String, reason: String)] = []

    public var summary: String {
        "StageKit snapshot: \(written.count) written, \(skipped.count) skipped, \(failed.count) failed"
    }
}

/// Drives a stage through a list of scenarios and writes a PNG per scenario.
///
/// ## Why `cacheDisplay` and not a screen capture
///
/// `NSView.cacheDisplay(in:to:)` asks the view hierarchy to draw itself into a
/// bitmap. It needs no Screen Recording permission, does not care whether the
/// window is frontmost or even on screen, and cannot catch a passing menu or
/// notification in the frame. That makes it the only capture route that works
/// unattended on a fresh machine and in CI — which is precisely when you want
/// a hundred design states rendered without a human present.
///
/// The trade-off: it renders the AppKit layer tree, so anything drawn outside
/// this window (menus, popovers, tooltips, sheets in separate windows) is not
/// included. Prototype state that must be captured belongs inside the window.
@available(macOS 15.0, *)
@MainActor
public enum StageSnapshot {
    /// Starts a run if the configured environment variable is set, otherwise
    /// returns immediately. Call it unconditionally from your app delegate's
    /// `applicationDidFinishLaunching`.
    public static func runIfRequested<Model>(
        driver: StageDriver<Model>,
        scenarios: [StageScenario<Model>],
        configuration: StageSnapshotConfiguration = StageSnapshotConfiguration()
    ) {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment[configuration.directoryEnvironmentKey], !path.isEmpty else { return }
        let filter = environment[configuration.filterEnvironmentKey]
        let tags = environment[configuration.tagEnvironmentKey]?
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        Task { @MainActor in
            let report = await run(
                driver: driver,
                scenarios: scenarios,
                outputDirectory: URL(fileURLWithPath: path),
                filter: filter,
                tags: tags,
                configuration: configuration
            )
            NSLog("%@", report.summary)
            for failure in report.failed {
                NSLog("StageKit snapshot failed: %@ — %@", failure.id, failure.reason)
            }
            if configuration.terminatesWhenFinished {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    /// Runs the scenarios and returns what happened. Separated from
    /// ``runIfRequested(driver:scenarios:configuration:)`` so a consumer can
    /// drive a run from a test or a menu item.
    @discardableResult
    public static func run<Model>(
        driver: StageDriver<Model>,
        scenarios: [StageScenario<Model>],
        outputDirectory: URL,
        filter: String? = nil,
        tags: [String]? = nil,
        configuration: StageSnapshotConfiguration = StageSnapshotConfiguration()
    ) async -> StageSnapshotReport {
        var report = StageSnapshotReport()
        do {
            try FileManager.default.createDirectory(
                at: outputDirectory, withIntermediateDirectories: true
            )
        } catch {
            report.failed.append((id: "<setup>", reason: error.localizedDescription))
            return report
        }

        try? await Task.sleep(for: configuration.initialSettle)

        for scenario in scenarios {
            if let filter, !filter.isEmpty, !scenario.id.contains(filter) {
                report.skipped.append(scenario.id)
                continue
            }
            if let tags, !tags.isEmpty, tags.allSatisfy({ !scenario.tags.contains($0) }) {
                report.skipped.append(scenario.id)
                continue
            }

            driver.apply(scenario)
            // Applying happens synchronously; the sleep is what lets SwiftUI
            // run the transaction, and lets an animated prototype reach the
            // moment this scenario meant to document.
            try? await Task.sleep(for: scenario.settle)

            let url = outputDirectory.appendingPathComponent("\(scenario.id).png")
            switch capture(to: url, windowTitle: configuration.windowTitle) {
            case .success:
                report.written.append(url)
            case .failure(let reason):
                report.failed.append((id: scenario.id, reason: reason))
            }
        }
        return report
    }

    public enum CaptureResult {
        case success
        case failure(String)
    }

    /// Captures a window's content view to a PNG at native backing scale.
    @discardableResult
    public static func capture(to url: URL, windowTitle: String? = nil) -> CaptureResult {
        guard let window = targetWindow(titled: windowTitle) else {
            return .failure("no visible window\(windowTitle.map { " titled \"\($0)\"" } ?? "")")
        }
        return capture(window: window, to: url)
    }

    @discardableResult
    public static func capture(window: NSWindow, to url: URL) -> CaptureResult {
        guard let view = window.contentView else { return .failure("window has no content view") }
        guard view.bounds.width > 0, view.bounds.height > 0 else {
            return .failure("content view has zero size")
        }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            return .failure("could not allocate bitmap")
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            return .failure("PNG encoding failed")
        }
        do {
            try data.write(to: url)
            return .success
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    /// Preferred window: exact title match, then the key window, then any
    /// visible one.
    public static func targetWindow(titled title: String?) -> NSWindow? {
        let windows = NSApplication.shared.windows
        if let title {
            if let match = windows.first(where: { $0.title == title && $0.isVisible }) {
                return match
            }
        }
        if let key = NSApplication.shared.keyWindow, key.isVisible { return key }
        return windows.first { $0.isVisible }
    }
}

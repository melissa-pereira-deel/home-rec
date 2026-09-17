//
//  Diagnostics.swift
//  HomeRec
//
//  Builds a shareable diagnostics report from the app's unified-logging
//  entries and provides a "Report a Problem" path — so a non-developer can
//  send actionable info instead of hunting for a log file. (BL-042)
//

import Foundation
import OSLog
import AppKit
import UniformTypeIdentifiers

enum Diagnostics {
    static let subsystem = "com.mdebritto.homerec"
    static let issueBaseURL = "https://github.com/melissa-pereira-deel/home-rec/issues/new"

    @MainActor private static var updaterStartupFailure: CapturedUpdaterStartupFailure?

    private struct CapturedUpdaterStartupFailure: Equatable {
        let domain: String
        let code: Int
        let description: String
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    static var systemVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    /// Capture a startup failure Sparkle reported before it could run any checks.
    @MainActor
    static func recordUpdaterStartupFailure(_ error: Error) {
        let nsError = error as NSError
        updaterStartupFailure = CapturedUpdaterStartupFailure(
            domain: nsError.domain,
            code: nsError.code,
            description: nsError.localizedDescription
        )
    }

    #if DEBUG
    /// Clears captured updater state so tests can keep report output deterministic.
    @MainActor
    static func clearUpdaterStartupFailure() {
        updaterStartupFailure = nil
    }
    #endif

    /// A shareable diagnostics report: environment header + recent app log entries.
    @MainActor
    static func report(date: Date = Date()) -> String {
        var lines = [
            "Home Rec Diagnostics",
            "App version: \(appVersion)",
            "macOS: \(systemVersion)",
            "Generated: \(ISO8601DateFormatter().string(from: date))",
            "",
            "Recent log entries:"
        ]
        lines.append(contentsOf: recentLogLines())
        if let updaterStartupFailure {
            lines.append(contentsOf: [
                "",
                "Updater startup failure:",
                "Domain: \(updaterStartupFailure.domain)",
                "Code: \(updaterStartupFailure.code)",
                "Description: \(updaterStartupFailure.description)"
            ])
        }
        return lines.joined(separator: "\n")
    }

    /// Recent entries from this app's subsystem (best-effort; last hour).
    static func recentLogLines(limit: Int = 500) -> [String] {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let start = store.position(date: Date().addingTimeInterval(-3600))
            let entries = try store.getEntries(at: start)
            let lines = entries.compactMap { entry -> String? in
                guard let log = entry as? OSLogEntryLog, log.subsystem == subsystem else { return nil }
                return "[\(log.category)] \(log.composedMessage)"
            }
            return lines.isEmpty ? ["(no recent log entries)"] : Array(lines.suffix(limit))
        } catch {
            return ["(could not read logs: \(error.localizedDescription))"]
        }
    }

    /// Prefilled "Report a Problem" GitHub issue URL including version info.
    static func reportIssueURL() -> URL? {
        var components = URLComponents(string: issueBaseURL)
        let body = """
        Describe the problem:


        ---
        App version: \(appVersion)
        macOS: \(systemVersion)
        """
        components?.queryItems = [
            URLQueryItem(name: "title", value: "Home Rec issue"),
            URLQueryItem(name: "body", value: body)
        ]
        return components?.url
    }
}

// MARK: - UI actions

@MainActor
extension Diagnostics {
    /// Present a save panel and write the diagnostics report to disk.
    static func exportReport() {
        let panel = NSSavePanel()
        panel.title = "Export Diagnostics"
        panel.nameFieldStringValue = "HomeRec-Diagnostics.txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try report().write(to: url, atomically: true, encoding: .utf8)
        } catch {
            Log.recorder.error("Failed to write diagnostics: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Open the prefilled GitHub issue page in the default browser.
    static func reportProblem() {
        guard let url = reportIssueURL() else { return }
        NSWorkspace.shared.open(url)
    }
}

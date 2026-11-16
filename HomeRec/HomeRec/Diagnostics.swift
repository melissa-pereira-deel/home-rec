//
//  Diagnostics.swift
//  HomeRec
//
//  Builds a shareable diagnostics report from the app's unified-logging
//  entries and provides a "Report a Problem" path — so a non-developer can
//  send actionable info instead of hunting for a log file. (BL-042)
//
//  The report goes by email, not as a GitHub issue (BL-141): the people this
//  app is for will not open a GitHub account to tell us something broke, and
//  with no telemetry this is the only way they can tell us at all.
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

    /// Where "Report a Problem" sends its email. A forwarding alias, which is
    /// why it can be built into the app and published in this repository.
    static let supportAddress = "support@homerec.app"

    /// The longest `mailto:` link handed to the system. Webmail handlers and
    /// some mail apps truncate or refuse longer ones, so the log is cut to fit.
    static let maxEmailURLLength = 2000

    /// How many of the newest log lines the email starts from, before trimming
    /// to fit. Export Diagnostics carries the full log.
    private static let emailLogLineLimit = 40

    /// A `mailto:` link to `supportAddress`, prefilled with versions and the
    /// newest log entries, cut from the oldest end to fit `maxEmailURLLength`.
    ///
    /// The home folder's path is replaced with `~`: unlike an exported file,
    /// this leaves the Mac, and the path names the user's account.
    static func reportEmailURL(
        appVersion: String,
        systemVersion: String,
        logLines: [String],
        homeDirectory: String = NSHomeDirectory()
    ) -> URL? {
        let subject = "Home Rec problem report"
        var tail = logLines.suffix(emailLogLineLimit).map { redactingHome($0, homeDirectory) }
        var trimmed = logLines.count > tail.count
        while true {
            let body = emailBody(
                appVersion: appVersion,
                systemVersion: systemVersion,
                logLines: tail,
                trimmed: trimmed
            )
            let link = "mailto:\(supportAddress)?subject=\(mailtoEncoded(subject))&body=\(mailtoEncoded(body))"
            if link.count <= maxEmailURLLength || tail.isEmpty {
                return URL(string: link)
            }
            tail.removeFirst()
            trimmed = true
        }
    }

    private static func emailBody(
        appVersion: String,
        systemVersion: String,
        logLines: [String],
        trimmed: Bool
    ) -> String {
        var lines = [
            "Describe the problem:",
            "",
            "",
            "---",
            "App version: \(appVersion)",
            "macOS: \(systemVersion)",
            "",
            "Recent log entries:"
        ]
        lines.append(contentsOf: logLines.isEmpty ? ["(no recent log entries)"] : logLines)
        if trimmed {
            lines.append("(Earlier entries left out. For the full log, choose Export Diagnostics… in the Home Rec menu and attach the file.)")
        }
        lines.append(contentsOf: ["", "Prefer GitHub? \(issueBaseURL)"])
        // RFC 6068: line breaks in a mailto body are CRLF.
        return lines.joined(separator: "\r\n")
    }

    /// Percent-encodes for a `mailto:` field. `urlQueryAllowed` leaves `&`, `=`,
    /// `+`, `?` and `#` alone, which would end the body at the first `&` and
    /// turn `+` into a space in some mail apps.
    private static func mailtoEncoded(_ text: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    private static func redactingHome(_ text: String, _ homeDirectory: String) -> String {
        guard !homeDirectory.isEmpty else { return text }
        return text.replacingOccurrences(of: homeDirectory + "/", with: "~/")
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

    /// Opens a prefilled email to `supportAddress`. When nothing can open it,
    /// the full report is copied with the address, and the user is told.
    ///
    /// The three effects are injected so both outcomes are testable without a
    /// mail app or a pasteboard.
    static func reportProblem(
        opening open: (URL) -> Bool,
        copying copy: (String) -> Void,
        onNoMailApp: () -> Void
    ) {
        if let url = reportEmailURL(
            appVersion: appVersion,
            systemVersion: systemVersion,
            logLines: recentLogLines()
        ), open(url) {
            return
        }
        Log.recorder.info("No app opened the report email; copying the report instead")
        copy("To: \(supportAddress)\n\n" + redactingHome(report(), NSHomeDirectory()))
        onNoMailApp()
    }

    /// "Report a Problem": email first, GitHub for those who prefer it (BL-141).
    static func reportProblem() {
        reportProblem(
            opening: { NSWorkspace.shared.open($0) },
            copying: { text in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            },
            onNoMailApp: showNoMailAppAlert
        )
    }

    private static func showNoMailAppAlert() {
        let alert = NSAlert()
        alert.messageText = "No email app is set up"
        alert.informativeText = "The report is copied. Paste it into an email to \(supportAddress)."
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Report on GitHub Instead")
        if alert.runModal() == .alertSecondButtonReturn, let url = reportIssueURL() {
            NSWorkspace.shared.open(url)
        }
    }
}

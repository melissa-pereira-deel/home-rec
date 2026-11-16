//
//  Diagnostics.swift
//  HomeRec
//
//  Builds shareable diagnostics from the app’s unified log.
//

import Foundation
import OSLog
import AppKit
import UniformTypeIdentifiers

enum Diagnostics {
    static let subsystem = "com.mdebritto.homerec"
    static let issueBaseURL = "https://github.com/melissa-pereira-deel/home-rec/issues/new"

    @MainActor private static var updaterStartupFailure: CapturedUpdaterStartupFailure?

    private struct CapturedUpdaterStartupFailure {
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
    static func report(
        date: Date = Date(),
        logLines: [String]? = nil,
        homeDirectory: String = NSHomeDirectory()
    ) -> String {
        let sanitize = reportSanitizer(homeDirectory: homeDirectory)
        return ([
            "Home Rec Diagnostics",
            "App version: \(sanitize(appVersion))",
            "macOS: \(sanitize(systemVersion))",
            "Generated: \(ISO8601DateFormatter().string(from: date))"
        ] + updaterLines(sanitize: sanitize) + logSection((logLines ?? recentLogLines()).map(sanitize)))
            .joined(separator: "\n")
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

    private static let emailLogLineLimit = 40

    /// Keeps the newest log entries that fit the percent-encoded mailto budget.
    @MainActor
    static func reportEmailURL(
        appVersion: String,
        systemVersion: String,
        logLines: [String],
        homeDirectory: String = NSHomeDirectory()
    ) -> URL? {
        let sanitize = reportSanitizer(homeDirectory: homeDirectory)
        let header = [
            "Describe the problem:",
            "",
            "",
            "---",
            "App version: \(bounded(sanitize(appVersion), to: 160))",
            "macOS: \(bounded(sanitize(systemVersion), to: 160))"
        ] + updaterLines(sanitize: sanitize)
        var tail = logLines.suffix(emailLogLineLimit).map { bounded(sanitize($0), to: 450) }
        var trimmed = logLines.count > tail.count
        let linkPrefix = "mailto:\(supportAddress)?subject=\(mailtoEncoded("Home Rec problem report"))&body="
        while true {
            var lines = header + logSection(tail)
            if trimmed {
                lines.append("(Earlier entries left out. Choose Copy Diagnostic Report or Export Diagnostics… for more context.)")
            }
            // RFC 6068 requires CRLF for mailto body line breaks.
            let link = linkPrefix + mailtoEncoded(lines.joined(separator: "\r\n"))
            if link.utf8.count <= maxEmailURLLength {
                return URL(string: link)
            }
            guard !tail.isEmpty else { return nil }
            tail.removeFirst()
            trimmed = true
        }
    }

    private static func logSection(_ entries: [String]) -> [String] {
        ["", "Recent log entries:"] + (entries.isEmpty ? ["(no recent log entries)"] : entries)
    }

    @MainActor
    private static func updaterLines(sanitize: (String) -> String) -> [String] {
        guard let failure = updaterStartupFailure else { return [] }
        return [
            "",
            "Updater startup failure:",
            "Domain: \(bounded(sanitize(failure.domain), to: 140))",
            "Code: \(failure.code)",
            "Description: \(bounded(sanitize(failure.description), to: 360))"
        ]
    }

    /// Keeps entries intact when possible and truncates on character boundaries.
    private static func bounded(_ text: String, to encodedByteLimit: Int) -> String {
        let ellipsis = "…"
        let ellipsisSize = mailtoEncoded(ellipsis).utf8.count
        var encodedSize = 0
        var prefixEnd = text.startIndex
        for index in text.indices {
            encodedSize += mailtoEncoded(String(text[index])).utf8.count
            if encodedSize > encodedByteLimit {
                return String(text[..<prefixEnd]) + ellipsis
            }
            if encodedSize <= encodedByteLimit - ellipsisSize {
                prefixEnd = text.index(after: index)
            }
        }
        return text
    }

    /// Percent-encodes for a `mailto:` field. `urlQueryAllowed` leaves `&`, `=`,
    /// `+`, `?` and `#` alone, which would end the body at the first `&` and
    /// turn `+` into a space in some mail apps.
    private static func mailtoEncoded(_ text: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    private static func reportSanitizer(homeDirectory: String) -> (String) -> String {
        let home = homeDirectory.replacingOccurrences(of: #"/+$"#, with: "", options: .regularExpression)
        let path = NSRegularExpression.escapedPattern(for: home)
        // Match descendants and standalone paths while preserving sibling names.
        let boundary = #"(?=$|[/\s"'<>\x{2019}\x{201D}\x{60},:;!?()\[\]{}]|\.(?:$|\s))"#
        let homePattern = home.isEmpty ? nil : try? NSRegularExpression(pattern: path + boundary)
        return { text in
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let redacted = homePattern?.stringByReplacingMatches(in: text, range: range, withTemplate: "~") ?? text
            return redacted.replacingOccurrences(of: #"[\r\n]+"#, with: " ", options: .regularExpression)
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

    static func reportProblem() {
        let alert = NSAlert()
        alert.messageText = "Report a Problem"
        alert.informativeText = "Open a draft to \(supportAddress), copy diagnostics to share, or open a GitHub issue with your version information."
        alert.addButton(withTitle: "Open Email Draft")
        alert.addButton(withTitle: "Copy Diagnostic Report")
        alert.addButton(withTitle: "Report on GitHub")
        alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1B}"

        NSApp.activate()
        while true {
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                if let url = reportEmailURL(
                    appVersion: appVersion,
                    systemVersion: systemVersion,
                    logLines: recentLogLines()
                ), NSWorkspace.shared.open(url) {
                    return
                }
                alert.informativeText = "The email draft couldn’t open. Copy the report to email it to \(supportAddress), or report the problem on GitHub."
            case .alertSecondButtonReturn:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(report(), forType: .string)
                return
            case .alertThirdButtonReturn:
                if let url = reportIssueURL() {
                    NSWorkspace.shared.open(url)
                }
                return
            default:
                return
            }
        }
    }
}

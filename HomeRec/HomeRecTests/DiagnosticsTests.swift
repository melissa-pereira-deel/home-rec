//
//  DiagnosticsTests.swift
//  HomeRecTests
//
//  BL-042: the diagnostics report and "Report a Problem" URL carry the
//  environment info needed to act on a user report.
//

import Testing
import Foundation
@testable import HomeRec

@MainActor
struct DiagnosticsTests {

    @Test("Report includes app + macOS version")
    func reportIncludesEnvironment() {
        let report = Diagnostics.report()
        #expect(report.contains("Home Rec Diagnostics"))
        #expect(report.contains(Diagnostics.appVersion))
        #expect(report.contains(Diagnostics.systemVersion))
        #expect(report.contains("Recent log entries:"))
    }

    @Test("Report-a-Problem URL is valid and prefilled with version info")
    func reportIssueURLIsPrefilled() throws {
        let url = try #require(Diagnostics.reportIssueURL())
        #expect(url.absoluteString.contains("github.com/melissa-pereira-deel/home-rec/issues/new"))

        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let body = components.queryItems?.first { $0.name == "body" }?.value ?? ""
        #expect(body.contains("App version:"))
        #expect(body.contains("macOS:"))
        #expect(components.queryItems?.contains { $0.name == "title" } == true)
    }
}

/// "Report a Problem" by email, for people without a GitHub account (BL-141).
@MainActor
struct ReportByEmailTests {

    private func url(
        logLines: [String] = ["[recorder] Recording started", "[capture] Capture started"],
        home: String = "/Users/someone"
    ) throws -> URL {
        try #require(Diagnostics.reportEmailURL(
            appVersion: "1.2.0 (10200)",
            systemVersion: "Version 26.1 (Build 25B78)",
            logLines: logLines,
            homeDirectory: home
        ))
    }

    private func field(_ name: String, of url: URL) throws -> String {
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        return try #require(components.queryItems?.first { $0.name == name }?.value)
    }

    @Test("The report is an email to the support address, with a subject")
    func addressedToSupport() throws {
        let url = try url()
        #expect(url.scheme == "mailto")
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == "support@homerec.app")
        #expect(try field("subject", of: url).contains("Home Rec"))
    }

    @Test("The body carries the app version, macOS version and recent log entries")
    func bodyCarriesDiagnostics() throws {
        let body = try field("body", of: url())
        #expect(body.contains("1.2.0 (10200)"))
        #expect(body.contains("Version 26.1 (Build 25B78)"))
        #expect(body.contains("[recorder] Recording started"))
        #expect(body.contains("[capture] Capture started"))
    }

    @Test("The GitHub route is still offered, for people who use it")
    func keepsGitHubRoute() throws {
        #expect(try field("body", of: url()).contains(Diagnostics.issueBaseURL))
    }

    /// `URLComponents` leaves `&`, `=` and `+` unescaped in a query, which
    /// would cut the body short at the first `&` and turn `+` into a space in
    /// some mail apps.
    @Test("Characters that mean something in a URL survive into the body intact")
    func reservedCharactersRoundTrip() throws {
        let line = "[file] a&b=c+d #e ?f 100% done"
        let url = try url(logLines: [line])
        #expect(try field("body", of: url).contains(line))
        #expect(try field("subject", of: url).contains("Home Rec"), "the body leaked into a second field")
    }

    @Test("Line breaks are CRLF, as mailto requires")
    func crlfLineBreaks() throws {
        let body = try field("body", of: url())
        #expect(body.contains("\r\n"))
        #expect(!body.replacingOccurrences(of: "\r\n", with: "").contains("\n"))
    }

    @Test("The home folder's path is not sent")
    func homeFolderRedacted() throws {
        let body = try field("body", of: url(logLines: ["[recovery] Scanned /Users/someone/Desktop/take.wav"]))
        #expect(!body.contains("/Users/someone"))
        #expect(body.contains("~/Desktop/take.wav"))
    }

    /// Mail apps and webmail handlers truncate or refuse long `mailto:` URLs.
    /// The newest log lines are the ones that explain a problem just seen.
    @Test("A long log is cut from the oldest end to keep the link openable")
    func longLogTrimmedOldestFirst() throws {
        let lines = (1...400).map { "[recorder] entry \($0) with some detail to take up room" }
        let url = try url(logLines: lines)
        #expect(url.absoluteString.count <= Diagnostics.maxEmailURLLength)
        let body = try field("body", of: url)
        #expect(body.contains("entry 400 "), "the newest line was dropped")
        #expect(!body.contains("entry 1 "), "the oldest line was kept")
        #expect(body.contains("Export Diagnostics"), "nothing says where the rest is")
    }

    @Test("With a mail app, the email opens and nothing else happens")
    func opensMailApp() throws {
        var opened: [URL] = []
        var copied: [String] = []
        var alerted = 0
        Diagnostics.reportProblem(
            opening: { opened.append($0); return true },
            copying: { copied.append($0) },
            onNoMailApp: { alerted += 1 }
        )
        #expect(opened.count == 1)
        #expect(opened.first?.scheme == "mailto")
        #expect(copied.isEmpty)
        #expect(alerted == 0)
    }

    @Test("Without a mail app, the report is copied with the address, and the user is told")
    func fallsBackToClipboard() throws {
        var copied: [String] = []
        var alerted = 0
        Diagnostics.reportProblem(
            opening: { _ in false },
            copying: { copied.append($0) },
            onNoMailApp: { alerted += 1 }
        )
        let text = try #require(copied.first)
        #expect(text.contains("support@homerec.app"))
        #expect(text.contains(Diagnostics.appVersion))
        #expect(alerted == 1)
    }
}

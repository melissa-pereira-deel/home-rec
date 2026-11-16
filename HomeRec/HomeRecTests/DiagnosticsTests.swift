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

    @Test("Embedded line breaks are normalized before building the email")
    func crlfLineBreaks() throws {
        let body = try field("body", of: url(logLines: ["one\rtwo\nthree\r\nfour"]))
        #expect(body.contains("one two three four"))
        let fields = body.replacingOccurrences(of: "\r\n", with: "")
        #expect(!fields.contains("\r"))
        #expect(!fields.contains("\n"))
    }

    @Test("Email and clipboard redact exact home paths and descendants")
    func homeFolderRedacted() throws {
        let logs = ["Scanned /Users/someone", "Opened '/Users/someone/Desktop/take.wav'",
                    "Other account /Users/someone-else/recordings"]
        let body = try field("body", of: url(logLines: logs))
        let report = Diagnostics.report(logLines: logs, homeDirectory: "/Users/someone/")
        for text in [body, report] {
            #expect(text.contains("Scanned ~"))
            #expect(text.contains("'~/Desktop/take.wav'"))
            #expect(text.contains("/Users/someone-else/recordings"))
            #expect(!text.contains("Scanned /Users/someone"))
            #expect(!text.contains("'/Users/someone/"))
        }
    }

    /// Mail apps and webmail handlers truncate or refuse long `mailto:` URLs.
    /// The newest log lines are the ones that explain a problem just seen.
    @Test("A long log is cut from the oldest end to keep the link openable")
    func longLogTrimmedOldestFirst() throws {
        let lines = (1...400).map { "[recorder] entry \($0) with some detail to take up room" }
        let url = try url(logLines: lines)
        #expect(url.absoluteString.utf8.count <= Diagnostics.maxEmailURLLength)
        let body = try field("body", of: url)
        #expect(body.contains("entry 400 "), "the newest line was dropped")
        #expect(!body.contains("entry 1 "), "the oldest line was kept")
        #expect(body.contains("Export Diagnostics"), "nothing says where the rest is")
    }

    @Test("An oversized newest entry is shortened before dropping older context")
    func oversizedNewestEntry() throws {
        let link = try url(logLines: ["previous context", "newest entry " + String(repeating: "🧑🏽‍💻", count: 2_000)])
        let body = try field("body", of: link)
        #expect(body.contains("previous context"))
        #expect(body.contains("newest entry "))
        #expect(body.contains("…"))
        #expect(link.absoluteString.utf8.count <= Diagnostics.maxEmailURLLength)
    }

    @Test("Updater startup failure appears in email and copied reports with bounded details")
    func capturesUpdaterContext() throws {
        Diagnostics.clearUpdaterStartupFailure()
        defer { Diagnostics.clearUpdaterStartupFailure() }
        Diagnostics.recordUpdaterStartupFailure(NSError(
            domain: "Sparkle /Users/someone\r\n" + String(repeating: "D", count: 500),
            code: 101,
            userInfo: [NSLocalizedDescriptionKey: "Failed to read /Users/someone/config\n" + String(repeating: "🙂", count: 500)]
        ))
        let link = try url(logLines: ["newest context"])
        let body = try field("body", of: link)
        let rawReport = Diagnostics.report(logLines: ["newest context"], homeDirectory: "/Users/someone")
        for text in [body, rawReport] {
            #expect(text.contains("Updater startup failure:"))
            #expect(text.contains("Domain: Sparkle ~ "))
            #expect(text.contains("Code: 101"))
            #expect(text.contains("Description: Failed to read ~/config "))
            #expect(text.contains("newest context"))
            #expect(!text.contains("/Users/someone"))
            #expect(!text.contains(String(repeating: "D", count: 500)))
            #expect(!text.contains(String(repeating: "🙂", count: 500)))
        }
        let issue = try #require(Diagnostics.reportIssueURL())
        let issueBody = try field("body", of: issue)
        #expect(!issueBody.contains("Updater startup failure"))
        #expect(!issueBody.contains("Recent log entries"))
        #expect(link.absoluteString.utf8.count <= Diagnostics.maxEmailURLLength)
    }

    @Test("Two thousand seeded cases fit the encoded byte budget and retain the newest entry")
    func randomizedEmailURLs() throws {
        var seed: UInt64 = 48
        func sample(_ upperBound: Int) -> Int {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Int((seed >> 32) % UInt64(upperBound))
        }
        let fragments = ["x", "ä", "🧑🏽‍💻", "&b=c+d % # ?", "\r\n", "/Users/someone/"]
        for iteration in 0..<2_000 {
            let log = (0..<sample(45)).map { index in
                "\(index) " + String(repeating: fragments[sample(fragments.count)], count: sample(180))
            }
            let newest = "newest-\(iteration) "
                + String(repeating: fragments[sample(fragments.count)], count: sample(600))
            let link = try url(logLines: log + [newest])
            let body = try field("body", of: link)
            let components = try #require(URLComponents(url: link, resolvingAgainstBaseURL: false))
            #expect(link.absoluteString.utf8.count <= Diagnostics.maxEmailURLLength)
            #expect(components.queryItems?.map(\.name) == ["subject", "body"])
            #expect(body.contains("newest-\(iteration)"))
            #expect(!body.contains("/Users/someone"))
        }
    }
}

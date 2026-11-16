//
//  RecoveredRecordingsTests.swift
//  HomeRecTests
//
//  A recording the user has recovered stays recovered after a relaunch
//  (BL-140a). What is remembered is that file, not its path: a file that has
//  gone is forgotten, and a new file at the same path is offered again.
//

import Testing
import Foundation
@testable import HomeRec

@MainActor
struct RecoveredRecordingsTests {

    /// A scratch folder holding real files, and a settings domain of its own.
    /// The test host is the app itself, so the standard domain would be the
    /// developer's own settings.
    @MainActor
    private struct Fixture {
        let directory: URL
        let defaultsName = "RecoveredRecordingsTests-\(UUID().uuidString)"
        let defaults: UserDefaults

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("RecoveredRecordingsTests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defaults = try #require(UserDefaults(suiteName: defaultsName))
        }

        @discardableResult
        func makeFile(_ name: String) throws -> URL {
            let url = directory.appendingPathComponent(name)
            // The scanner recognizes a top-level movie fragment.
            try (Data([0, 0, 0, 8]) + Data("moof".utf8)).write(to: url)
            return url
        }

        /// What a fresh launch of the app would build.
        func launch() -> RecoveryViewModel {
            RecoveryViewModel(
                scanner: RecoveryScanner(saveLocation: MockSaveLocationProviding(directory: directory)),
                recoveredStore: RecoveredRecordingsStore(defaults: defaults)
            )
        }

        /// The paths actually written to settings, read without the store's
        /// own pruning.
        func persistedPaths() throws -> Set<String> {
            guard let data = defaults.data(forKey: RecoveredRecordingsStore.defaultsKey) else { return [] }
            return Set(try PropertyListDecoder().decode([String: FileIdentity].self, from: data).keys)
        }

        func cleanup() {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: defaultsName)
        }
    }

    private func names(_ viewModel: RecoveryViewModel) -> [String] {
        viewModel.recordings.map(\.displayName)
    }

    // MARK: - Survives a relaunch

    @Test("A recovered recording is not offered again after a relaunch")
    func recoveredStaysRecoveredAfterRelaunch() throws {
        let f = try Fixture()
        defer { f.cleanup() }
        try f.makeFile("recording_a.m4a")
        try f.makeFile("recording_b.m4a")

        let first = f.launch()
        first.refresh()
        let a = try #require(first.recordings.first { $0.displayName == "recording_a.m4a" })
        first.recover(a)
        #expect(names(first) == ["recording_b.m4a"])

        let relaunched = f.launch()
        relaunched.refresh()
        // Only the recovered one is remembered; the other is still offered.
        #expect(names(relaunched) == ["recording_b.m4a"])
        #expect(relaunched.errorMessage == nil)
    }

    @Test("Recovering a second recording keeps the first one remembered")
    func recoveriesAccumulateAcrossLaunches() throws {
        let f = try Fixture()
        defer { f.cleanup() }
        try f.makeFile("recording_a.m4a")
        try f.makeFile("recording_b.m4a")

        let first = f.launch()
        first.refresh()
        first.recover(try #require(first.recordings.first { $0.displayName == "recording_a.m4a" }))

        let second = f.launch()
        second.refresh()
        second.recover(try #require(second.recordings.first { $0.displayName == "recording_b.m4a" }))

        let third = f.launch()
        third.refresh()
        #expect(third.recordings.isEmpty)
        #expect(try f.persistedPaths().count == 2)
    }

    // MARK: - Does not grow without bound

    @Test("A recovered recording that has since gone is forgotten at launch")
    func goneFilesArePrunedOnLoad() throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let a = try f.makeFile("recording_a.m4a")
        try f.makeFile("recording_b.m4a")

        let first = f.launch()
        first.refresh()
        for recording in first.recordings { first.recover(recording) }
        #expect(try f.persistedPaths().count == 2)

        try FileManager.default.removeItem(at: a)
        let relaunched = f.launch()
        relaunched.refresh()

        #expect(relaunched.recordings.isEmpty)
        #expect(try f.persistedPaths() == [f.directory.appendingPathComponent("recording_b.m4a").standardizedFileURL.path])
    }

    @Test("The store forgets entries whose file has gone, and keeps the rest")
    func storePrunesOnLoad() throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let kept = try f.makeFile("recording_kept.m4a")
        let gone = try f.makeFile("recording_gone.m4a")
        let store = RecoveredRecordingsStore(defaults: f.defaults)
        let keptIdentity = try #require(FileIdentity(atPath: kept.path))
        store.save([
            kept.path: keptIdentity,
            gone.path: try #require(FileIdentity(atPath: gone.path)),
        ])
        try FileManager.default.removeItem(at: gone)

        let loaded = RecoveredRecordingsStore(defaults: f.defaults).load()

        #expect(loaded == [kept.path: keptIdentity])
        #expect(try f.persistedPaths() == [kept.path])
    }

    // MARK: - A new file at the same path

    @Test("A file deleted and recreated at the same path is offered again after a relaunch")
    func recreatedFileIsOfferedAfterRelaunch() throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let url = try f.makeFile("recording_reused.m4a")

        let first = f.launch()
        first.refresh()
        first.recover(try #require(first.recordings.first))
        #expect(first.recordings.isEmpty)

        // A later take interrupted at the same name: a different file.
        try FileManager.default.removeItem(at: url)
        try f.makeFile("recording_reused.m4a")

        let relaunched = f.launch()
        relaunched.refresh()
        #expect(names(relaunched) == ["recording_reused.m4a"])
        // The stale entry can never match again, so it is not kept either.
        #expect(try f.persistedPaths().isEmpty)
    }

    @Test("A file deleted and recreated at the same path is offered again in the same session")
    func recreatedFileIsOfferedInSession() throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let url = try f.makeFile("recording_reused.m4a")

        let viewModel = f.launch()
        viewModel.refresh()
        viewModel.recover(try #require(viewModel.recordings.first))
        #expect(viewModel.recordings.isEmpty)

        try FileManager.default.removeItem(at: url)
        try f.makeFile("recording_reused.m4a")
        viewModel.refresh()

        #expect(names(viewModel) == ["recording_reused.m4a"])
    }

    @Test("A file's identity tells it apart from a new file at the same path")
    func identityDistinguishesRecreatedFile() throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let url = try f.makeFile("recording_x.m4a")
        let original = try #require(FileIdentity(atPath: url.path))

        // Stable for the same file, including after it is written to again.
        try Data("moof moof".utf8).write(to: url, options: [])
        #expect(FileIdentity(atPath: url.path) == original)

        try FileManager.default.removeItem(at: url)
        #expect(FileIdentity(atPath: url.path) == nil)

        try f.makeFile("recording_x.m4a")
        let recreated = try #require(FileIdentity(atPath: url.path))
        #expect(recreated != original)
    }
}

//
//  LastRecordingTests.swift
//  HomeRecTests
//
//  The last recording outlives the launch that made it (BL-143). It is
//  remembered once its file has closed, and only shown again while that file
//  is still where it was saved.
//

import Testing
import Foundation
@testable import HomeRec

@MainActor
struct LastRecordingTests {

    /// A scratch folder holding real files, and a settings domain of its own.
    /// The test host is the app itself, so the standard domain would be the
    /// developer's own settings.
    @MainActor
    private struct Fixture {
        let directory: URL
        let defaultsName = "LastRecordingTests-\(UUID().uuidString)"
        let defaults: UserDefaults

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("LastRecordingTests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defaults = try #require(UserDefaults(suiteName: defaultsName))
        }

        func makeFile(_ name: String) throws -> URL {
            let url = directory.appendingPathComponent(name)
            try Data("RIFF".utf8).write(to: url)
            return url
        }

        /// What a fresh launch would read.
        func relaunchedStore() -> LastRecordingStore {
            LastRecordingStore(defaults: defaults)
        }

        func makeViewModel(_ controller: MockRecordingControlling) -> RecorderViewModel {
            RecorderViewModel(
                controller: controller,
                permissions: MockPermissionProviding(.granted),
                clock: ManualClock(),
                audioSource: MockAudioSourceProviding(),
                lastRecordingStore: LastRecordingStore(defaults: defaults)
            )
        }

        func cleanup() {
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: defaultsName)
        }
    }

    // MARK: - The store

    @Test("A saved recording is read back by the next launch")
    func storeRoundTrip() throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let url = try f.makeFile("take.wav")

        LastRecordingStore(defaults: f.defaults).save(url)

        #expect(f.relaunchedStore().load() == url)
    }

    @Test("A recording moved or deleted since is not offered, and is forgotten")
    func storeDropsMissingFile() throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let url = try f.makeFile("take.wav")
        LastRecordingStore(defaults: f.defaults).save(url)
        try FileManager.default.removeItem(at: url)

        #expect(f.relaunchedStore().load() == nil)

        // Forgotten, not just hidden: putting a file back at that path later
        // must not revive a row the user already saw disappear.
        try Data("RIFF".utf8).write(to: url)
        #expect(f.relaunchedStore().load() == nil)
    }

    // MARK: - The view model

    @Test("A stopped take is the last recording after a relaunch")
    func stoppedTakeSurvivesRelaunch() async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let controller = MockRecordingControlling()
        controller.fileURL = try f.makeFile("take.wav")

        let first = f.makeViewModel(controller)
        await first.startRecording()
        await first.stopRecording()
        #expect(first.state == .idle)

        let relaunched = f.makeViewModel(MockRecordingControlling())
        #expect(relaunched.lastRecordingURL == controller.fileURL)
    }

    @Test("A take that is still open is not remembered over the last closed one")
    func openTakeIsNotRemembered() async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let controller = MockRecordingControlling()
        let closed = try f.makeFile("closed.wav")
        controller.fileURL = closed
        let viewModel = f.makeViewModel(controller)
        await viewModel.startRecording()
        await viewModel.stopRecording()

        // The next take is still recording when the app goes away. Its file
        // has not been closed, so it belongs to Recovery, not to this row.
        controller.fileURL = try f.makeFile("open.wav")
        await viewModel.startRecording()
        #expect(viewModel.state == .recording)

        #expect(f.relaunchedStore().load() == closed)
    }

    @Test("A failed take is remembered once its file has closed, not before")
    func failedTakeRememberedAfterTeardown() async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let controller = MockRecordingControlling()
        controller.fileURL = try f.makeFile("failed.wav")
        let viewModel = f.makeViewModel(controller)
        let gate = Gate()
        defer { gate.release() }
        controller.onFinalizeHold = { await gate.wait() }

        await viewModel.startRecording()
        controller.emitStreamError("stream died")
        await waitUntil("the failed take's teardown to be in flight") { gate.isWaiting }
        #expect(f.relaunchedStore().load() == nil, "remembered while the file was still open")

        gate.release()
        await waitUntil("teardown to finish") { viewModel.allowsProcessTermination }
        #expect(f.relaunchedStore().load() == controller.fileURL)
    }

    @Test("A launch whose last recording has gone shows no row")
    func relaunchWithMissingFileShowsNothing() async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let url = try f.makeFile("take.wav")
        LastRecordingStore(defaults: f.defaults).save(url)
        try FileManager.default.removeItem(at: url)

        let viewModel = f.makeViewModel(MockRecordingControlling())

        #expect(viewModel.lastRecordingURL == nil)
    }

    /// Only the missing-file path is exercised: with the file present this
    /// opens a real Finder window.
    @Test("Reveal on a recording that has gone takes the row away")
    func revealMissingFileDropsRow() async throws {
        let f = try Fixture()
        defer { f.cleanup() }
        let controller = MockRecordingControlling()
        controller.fileURL = try f.makeFile("take.wav")
        let viewModel = f.makeViewModel(controller)
        await viewModel.startRecording()
        await viewModel.stopRecording()
        try FileManager.default.removeItem(at: controller.fileURL)

        viewModel.revealInFinder()

        #expect(viewModel.lastRecordingURL == nil)
        try Data("RIFF".utf8).write(to: controller.fileURL)
        #expect(f.relaunchedStore().load() == nil, "the row came back on the next launch")
    }

    @Test("Without a store nothing is remembered")
    func noStoreRemembersNothing() async {
        let controller = MockRecordingControlling()
        let viewModel = RecorderViewModel(
            controller: controller,
            permissions: MockPermissionProviding(.granted),
            clock: ManualClock(),
            audioSource: MockAudioSourceProviding()
        )
        #expect(viewModel.lastRecordingURL == nil)
        await viewModel.startRecording()
        await viewModel.stopRecording()
        #expect(viewModel.lastRecordingURL == controller.fileURL, "this launch still shows it")
    }
}

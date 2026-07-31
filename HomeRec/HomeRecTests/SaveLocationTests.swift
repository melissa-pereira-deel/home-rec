//
//  SaveLocationTests.swift
//  HomeRecTests
//
//  BL-010: SaveLocationManager persistence + always-valid resolution (Desktop
//  fallback), and RecordingController file-path generation against the chosen
//  directory with collision safety.
//

import Testing
import Foundation
@testable import HomeRec

@MainActor
struct SaveLocationTests {

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "savelocation-test-\(UUID().uuidString)")!
    }

    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("savelocation-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var desktop: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    // MARK: - Persistence

    @Test("No persisted value resolves to the Desktop")
    func defaultsToDesktop() {
        let manager = SaveLocationManager(defaults: isolatedDefaults())
        #expect(manager.configuredDirectory == nil)
        #expect(manager.resolvedDirectory == desktop)
        #expect(manager.isConfiguredLocationUnavailable == false)
    }

    @Test("A set location persists across manager instances")
    func persistsAcrossInstances() {
        let defaults = isolatedDefaults()
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        SaveLocationManager(defaults: defaults).setSaveDirectory(dir)

        let reloaded = SaveLocationManager(defaults: defaults)
        #expect(reloaded.configuredDirectory?.path == dir.path)
        #expect(reloaded.resolvedDirectory.path == dir.path)
    }

    @Test("reset() clears the custom location back to Desktop")
    func resetReturnsToDesktop() {
        let defaults = isolatedDefaults()
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let manager = SaveLocationManager(defaults: defaults)
        manager.setSaveDirectory(dir)
        manager.reset()

        #expect(manager.configuredDirectory == nil)
        #expect(manager.resolvedDirectory == desktop)
    }

    // MARK: - Fallback (never lose a recording)

    @Test("A missing configured folder falls back to Desktop but is kept (keep & warn)")
    func missingFolderFallsBack() {
        let defaults = isolatedDefaults()
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString)", isDirectory: true)

        let manager = SaveLocationManager(defaults: defaults)
        manager.setSaveDirectory(missing)

        #expect(manager.resolvedDirectory == desktop)        // fell back
        #expect(manager.isConfiguredLocationUnavailable)      // flagged for a warning
        #expect(manager.configuredDirectory?.path == missing.path)  // but kept (not cleared)
    }

    @Test("A path that is a file (not a directory) falls back to Desktop")
    func fileWhereDirectoryExpectedFallsBack() throws {
        let defaults = isolatedDefaults()
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-dir-\(UUID().uuidString).txt")
        try Data("x".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let manager = SaveLocationManager(defaults: defaults)
        manager.setSaveDirectory(file)

        #expect(manager.resolvedDirectory == desktop)
        #expect(manager.isConfiguredLocationUnavailable)
    }

    @Test("A read-only folder falls back to Desktop")
    func readOnlyFolderFallsBack() throws {
        let defaults = isolatedDefaults()
        let dir = makeTempDirectory()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
            try? FileManager.default.removeItem(at: dir)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path)

        let manager = SaveLocationManager(defaults: defaults)
        manager.setSaveDirectory(dir)

        #expect(manager.resolvedDirectory != dir)   // not writable → fell back
        #expect(manager.isConfiguredLocationUnavailable)
    }

    // MARK: - File-path generation (RecordingController)

    @Test("generateFilePath uses the resolved save directory")
    func filePathUsesChosenDirectory() {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let controller = RecordingController(
            captureManager: MockAudioCapturing(),
            audioRecorder: MockAudioFileWriting(),
            saveLocation: MockSaveLocationProviding(directory: dir),
            audioSource: MockAudioSourceProviding()
        )
        let url = controller.generateFilePath(format: .wav)
        #expect(url.deletingLastPathComponent().path == dir.path)
        #expect(url.lastPathComponent.hasPrefix("recording_"))
        #expect(url.pathExtension == "wav")
    }

    @Test("generateFilePath never returns an existing file (collision-safe)")
    func filePathAvoidsCollision() throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let controller = RecordingController(
            captureManager: MockAudioCapturing(),
            audioRecorder: MockAudioFileWriting(),
            saveLocation: MockSaveLocationProviding(directory: dir),
            audioSource: MockAudioSourceProviding()
        )

        let first = controller.generateFilePath(format: .wav)
        try Data().write(to: first)               // occupy that name
        let second = controller.generateFilePath(format: .wav)

        #expect(second.path != first.path)
        #expect(FileManager.default.fileExists(atPath: second.path) == false)
    }
}

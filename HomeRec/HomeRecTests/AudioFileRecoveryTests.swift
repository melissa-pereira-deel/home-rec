//
//  AudioFileRecoveryTests.swift
//  HomeRecTests
//
//  BL-140: each format's "was this finalized?" detector and its repair.
//
//  Fixtures are generated at runtime by the REAL encoders rather than committed
//  as binaries: a "crash snapshot" is simply the file copied aside while the
//  encoder is still open, which is exactly what a force-quit leaves on disk.
//  That keeps the fixtures honest (they can never drift from the encoders) and
//  sidesteps Xcode's synchronized-group resource-bundling fragility, which
//  BL-051 already ran into.
//

import Testing
import Foundation
import AVFoundation
@testable import HomeRec

@MainActor
struct AudioFileRecoveryTests {

    private let sampleRate: Double = 48_000
    private let channels = 2
    /// Comfortably more than one FLAC packet (4608) and one M4A fragment (1s).
    private let bufferCount = 120
    private let framesPerBuffer = 1_024

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("recovery-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func buffer(_ index: Int) -> AVAudioPCMBuffer {
        SampleBufferFixtures.makePCMBuffer(
            channels: channels, frames: framesPerBuffer,
            sampleRate: sampleRate, interleaved: false
        ) { ch, frame in
            let n = index * self.framesPerBuffer + frame
            let v = Float(sin(Double(n) * 0.02)) * 0.4
            return ch == 0 ? v : -v * 0.5
        }
    }

    /// Writes one recording twice: finalized, and snapshotted mid-write.
    /// The snapshot is taken *before* `finalize()`, so it is byte-for-byte what a
    /// crash would leave behind.
    private func makePair(_ format: AudioFormat, in dir: URL) async throws -> (finalized: URL, crashed: URL) {
        let finalized = dir.appendingPathComponent("recording_final.\(format.fileExtension)")
        let live = dir.appendingPathComponent("recording_live.\(format.fileExtension)")
        let crashed = dir.appendingPathComponent("recording_crashed.\(format.fileExtension)")

        // Scoped so the finalized encoder is released before the second one opens.
        do {
            let encoder = try format.makeEncoder()
            try encoder.createFile(at: finalized, sampleRate: sampleRate, channels: channels)
            for i in 0..<bufferCount { try encoder.writeBuffer(buffer(i)) }
            try encoder.finalize()
        }

        let live_ = try format.makeEncoder()
        try live_.createFile(at: live, sampleRate: sampleRate, channels: channels)
        for i in 0..<bufferCount { try live_.writeBuffer(buffer(i)) }

        // M4A flushes fragments on AVFoundation's own queue, so the snapshot needs
        // to be taken after at least one fragment interval or it contains no
        // `moof` to detect. MUST yield rather than block: these tests are
        // @MainActor and `M4AEncoder.finalize()` waits on a semaphore, so a
        // blocking sleep here deadlocks the whole suite.
        if format == .m4a { try await Task.sleep(nanoseconds: 1_600_000_000) }

        try FileManager.default.copyItem(at: live, to: crashed)
        try? live_.finalize()

        return (finalized, crashed)
    }

    // MARK: - Detection

    @Test("A finalized file is never reported as unfinalized",
          arguments: [AudioFormat.wav, .m4a, .flac])
    func finalizedIsNotFlagged(_ format: AudioFormat) async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let pair = try await makePair(format, in: dir)
        let recovery = try #require(format.recovery)
        #expect(try recovery.isUnfinalized(at: pair.finalized) == false)
    }

    @Test("A crash-interrupted file IS reported as unfinalized",
          arguments: [AudioFormat.wav, .m4a, .flac])
    func crashedIsFlagged(_ format: AudioFormat) async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let pair = try await makePair(format, in: dir)
        let recovery = try #require(format.recovery)
        #expect(try recovery.isUnfinalized(at: pair.crashed) == true)
    }

    // MARK: - Repair

    @Test("Repairing a crashed WAV yields a readable file with the real duration")
    func repairsWAV() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let pair = try await makePair(.wav, in: dir)
        let beforeIdentity = try #require(FileIdentity(atPath: pair.crashed.path))
        let repairedIdentity = try #require(try WAVWriter.repair(at: pair.crashed, expectedIdentity: beforeIdentity))
        #expect(repairedIdentity == FileIdentity(atPath: pair.crashed.path))
        #expect(repairedIdentity != beforeIdentity)

        #expect(try WAVWriter.isUnfinalized(at: pair.crashed) == false)
        let file = try AVAudioFile(forReading: pair.crashed)
        #expect(file.length > 0)
        // The header now describes every byte actually on disk.
        let size = try #require(FileManager.default.attributesOfItem(atPath: pair.crashed.path)[.size] as? Int)
        #expect(Int(file.length) == (size - WAVWriter.headerByteCount) / (channels * 2))
    }

    /// The headline BL-140 result: a crashed FLAC is unopenable as found, and a
    /// 38-byte header patch makes it decode. The audio itself is never touched.
    @Test("Repairing a crashed FLAC turns an unopenable file into a decodable one")
    func repairsFLAC() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let pair = try await makePair(.flac, in: dir)

        // Before: no player can open it.
        #expect((try? AVAudioFile(forReading: pair.crashed)) == nil)

        let before = try Data(contentsOf: pair.crashed)
        let beforeIdentity = try #require(FileIdentity(atPath: pair.crashed.path))
        let repairedIdentity = try #require(try FLACEncoder.repair(at: pair.crashed, expectedIdentity: beforeIdentity))
        #expect(repairedIdentity == FileIdentity(atPath: pair.crashed.path))
        #expect(repairedIdentity != beforeIdentity)
        let after = try Data(contentsOf: pair.crashed)

        // After: it opens, and carries real audio.
        let file = try AVAudioFile(forReading: pair.crashed)
        #expect(file.length > 0)
        #expect(file.fileFormat.sampleRate == sampleRate)
        #expect(file.fileFormat.channelCount == AVAudioChannelCount(channels))

        // Only the 38-byte STREAMINFO region changed — the audio payload is
        // untouched, which is what makes this a recovery rather than a re-encode.
        #expect(before.count == after.count)
        #expect(before.suffix(from: 42) == after.suffix(from: 42))
        #expect(before.prefix(4) == after.prefix(4))
    }

    @Test("A crashed M4A already plays, and repair leaves it alone")
    func m4aNeedsNoRepair() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let pair = try await makePair(.m4a, in: dir)
        let before = try Data(contentsOf: pair.crashed)

        // BL-016's fragments mean it is playable as found.
        let file = try AVAudioFile(forReading: pair.crashed)
        #expect(file.length > 0)

        try M4AEncoder.repair(at: pair.crashed)
        #expect(try Data(contentsOf: pair.crashed) == before)
    }

    // MARK: - Not-repairable edge

    /// Measured: `AVAudioFile` buffers the FLAC **header** as well as the audio, so
    /// a take interrupted before the first flush leaves a **0-byte** file — not the
    /// 42-byte header stub a `close()`d short take produces. There is nothing to
    /// detect and nothing to recover, and the honest behaviour is to not offer it.
    @Test("A crashed FLAC too short to have flushed anything is never offered")
    func shortFLACIsNotOffered() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let live = dir.appendingPathComponent("recording_tiny.flac")
        let crashed = dir.appendingPathComponent("recording_tiny_crashed.flac")
        let encoder = FLACEncoder()
        try encoder.createFile(at: live, sampleRate: sampleRate, channels: channels)
        try encoder.writeBuffer(buffer(0))          // 1024 frames — under one packet
        try FileManager.default.copyItem(at: live, to: crashed)
        try? encoder.finalize()

        let size = try #require(FileManager.default.attributesOfItem(atPath: crashed.path)[.size] as? Int)
        #expect(size == 0, "expected an unflushed FLAC to be empty on disk")

        // Unparseable rather than "unfinalized" — and the scanner must skip it
        // rather than listing a file it cannot help with.
        #expect((try? FLACEncoder.isUnfinalized(at: crashed)) == nil)

        let scanner = RecoveryScanner(saveLocation: MockSaveLocationProviding(directory: dir))
        #expect(scanner.scan(excluding: nil).isEmpty)
    }

    // MARK: - Scanner

    @Test("The scanner lists crashed recordings and ignores finalized ones")
    func scannerListsOnlyUnfinalized() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let pair = try await makePair(.wav, in: dir)
        let scanner = RecoveryScanner(saveLocation: MockSaveLocationProviding(directory: dir))
        let found = scanner.scan(excluding: nil)

        // Compare by name: `contentsOfDirectory` returns paths that differ from a
        // hand-built URL by symlink standardization (/var vs /private/var).
        #expect(found.map(\.displayName) == [pair.crashed.lastPathComponent])
        #expect(found.first?.format == .wav)
        #expect(found.first?.isRepairable == true)
        #expect((found.first?.byteCount ?? 0) > 0)
    }

    /// A live recording is unfinalized *by definition*; offering it would invite
    /// the user to "recover" the file currently being written.
    @Test("The in-progress recording is never listed")
    func scannerExcludesInProgress() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let pair = try await makePair(.wav, in: dir)
        let scanner = RecoveryScanner(saveLocation: MockSaveLocationProviding(directory: dir))

        #expect(scanner.scan(excluding: pair.crashed).isEmpty)
    }

    @Test("Files this app didn't write are ignored")
    func scannerIgnoresForeignFiles() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Right extension, wrong provenance — a truncated WAV from another app
        // would otherwise look exactly like one of ours mid-crash.
        try Data(repeating: 0, count: 500).write(to: dir.appendingPathComponent("someone-elses.wav"))
        try Data("RIFF".utf8).write(to: dir.appendingPathComponent("recording_broken.txt"))

        let scanner = RecoveryScanner(saveLocation: MockSaveLocationProviding(directory: dir))
        #expect(scanner.scan(excluding: nil).isEmpty)
    }

    // MARK: - Atomicity

    @Test("A failed repair never leaves a half-patched file behind")
    func repairIsAtomic() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let pair = try await makePair(.flac, in: dir)
        try FLACEncoder.repair(at: pair.crashed)

        // No temp artefacts survive a successful repair either.
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasPrefix(".homerec-repair-") }
        #expect(leftovers.isEmpty)
    }

    // MARK: - Recovered items stop being offered

    /// The regression this guards: M4A repair is intentionally a no-op, so a
    /// recovered M4A still *detects* as unfinalized. Without an explicit
    /// handled-set the row would survive its own recovery and the Recover button
    /// would look broken. Found by manual testing, not by the suite.
    @Test("A recovered recording stops being listed, even when repair is a no-op")
    func recoveredItemsDisappear() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let pair = try await makePair(.m4a, in: dir)
        // Precondition: it really is still unfinalized after "repair".
        try M4AEncoder.repair(at: pair.crashed)
        #expect(try M4AEncoder.isUnfinalized(at: pair.crashed) == true)

        let viewModel = RecoveryViewModel(
            scanner: RecoveryScanner(saveLocation: MockSaveLocationProviding(directory: dir))
        )
        viewModel.refresh()
        let target = try #require(viewModel.recordings.first)

        viewModel.recover(target)

        #expect(viewModel.recordings.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    /// The same no-op repair, across a relaunch: the real scanner still detects
    /// the file as unfinalized, so only the remembered action can keep it out.
    @Test("A recovered M4A is still not listed after a relaunch")
    func recoveredM4AStaysRecoveredAfterRelaunch() async throws {
        let dir = tempDir()
        let defaultsName = "AudioFileRecoveryTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        defer {
            try? FileManager.default.removeItem(at: dir)
            defaults.removePersistentDomain(forName: defaultsName)
        }

        _ = try await makePair(.m4a, in: dir)
        let scanner = RecoveryScanner(saveLocation: MockSaveLocationProviding(directory: dir))

        let first = RecoveryViewModel(
            scanner: scanner, recoveredStore: RecoveredRecordingsStore(defaults: defaults)
        )
        first.refresh()
        first.recover(try #require(first.recordings.first))
        #expect(first.recordings.isEmpty)

        let relaunched = RecoveryViewModel(
            scanner: scanner, recoveredStore: RecoveredRecordingsStore(defaults: defaults)
        )
        relaunched.refresh()
        #expect(relaunched.hasScanned)
        #expect(relaunched.recordings.isEmpty)
    }

    @Test("A stale Recover or Trash row leaves a replacement take untouched",
          arguments: [false, true])
    func staleActionLeavesReplacementUntouched(moveToTrash: Bool) async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let pair = try await makePair(.wav, in: dir)
        let scanner = RecoveryScanner(saveLocation: MockSaveLocationProviding(directory: dir))
        let viewModel = RecoveryViewModel(scanner: scanner)
        viewModel.refresh()
        let stale = try #require(viewModel.recordings.first)

        let replacement = try Data(contentsOf: pair.crashed)
        // Atomic write creates a new file with the same interrupted bytes and path.
        try replacement.write(to: pair.crashed, options: .atomic)
        let replacementIdentity = try #require(FileIdentity(atPath: pair.crashed.path))
        try #require(replacementIdentity != stale.identity)

        if moveToTrash {
            viewModel.moveToTrash(stale)
        } else {
            viewModel.recover(stale)
        }

        #expect(try Data(contentsOf: pair.crashed) == replacement)
        #expect(viewModel.recordings.map(\.identity) == [replacementIdentity])
        #expect(viewModel.errorMessage == AudioFileRecoveryError.recordingChanged.errorDescription)
    }

    @Test("A stale row is refreshed when the same WAV finishes in place")
    func staleRowRefreshesWhenFileFinalizesInPlace() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let pair = try await makePair(.wav, in: dir)
        let scanner = RecoveryScanner(saveLocation: MockSaveLocationProviding(directory: dir))
        let viewModel = RecoveryViewModel(scanner: scanner)
        viewModel.refresh()
        let stale = try #require(viewModel.recordings.first)

        let finalized = try Data(contentsOf: pair.finalized)
        try finalized.write(to: pair.crashed)
        try #require(FileIdentity(atPath: pair.crashed.path) == stale.identity)
        viewModel.moveToTrash(stale)

        #expect(try Data(contentsOf: pair.crashed) == finalized)
        #expect(viewModel.recordings.isEmpty)
        #expect(viewModel.errorMessage == AudioFileRecoveryError.recordingChanged.errorDescription)
    }

    @Test("A malformed extended M4A box size stops bounded traversal")
    func malformedExtendedM4ASize() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("recording_malformed.m4a")
        let firstBox = Data([0, 0, 0, 8]) + Data("ftyp".utf8)
        let oversizedBox = Data([0, 0, 0, 1]) + Data("free".utf8)
            + Data([0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff])
        try (firstBox + oversizedBox).write(to: url)
        #expect(try M4AEncoder.isUnfinalized(at: url) == false)
    }

    // MARK: - Format wiring

    @Test("Every implemented format has a recovery handler")
    func implementedFormatsHaveRecovery() {
        for format in AudioFormat.available {
            #expect(format.recovery != nil, "\(format) is selectable but has no recovery handler")
        }
        #expect(AudioFormat.mp3.recovery == nil)
    }
}

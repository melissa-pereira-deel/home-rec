//
//  M4AEncoderTests.swift
//  HomeRecTests
//
//  BL-012: drive M4AEncoder (through the AudioFileEncoder protocol) with a
//  synthetic Float32 PCM stream and assert the produced .m4a is a valid,
//  decodable AAC file with the right channel count and a duration matching the
//  input. AAC is lossy, so we assert decodability + duration tolerance, never
//  bytes (the format-agnostic hook noted in AudioFileEncoderTests).
//

import Testing
import Foundation
import AVFoundation
import AppKit
import Combine
import os
@testable import HomeRec

/// `.serialized` for the same reason as `EncoderFormatGuardTests`: `finalize()`
/// blocks on a semaphore, and parallel blocking waits starve Swift's cooperative
/// thread pool on a low-core CI runner (BL-147).
@Suite(.serialized)
@MainActor
struct M4AEncoderTests {

    private let inputSampleRate: Double = 48_000
    private let channels = 2
    private let bufferCount = 48
    private let framesPerBuffer = 1_024   // 48 × 1024 = 49,152 frames ≈ 1.024 s

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("m4a-test-\(UUID().uuidString).m4a")
    }

    /// A non-interleaved Float32 buffer (what the real pipeline feeds), filled
    /// with a mild non-zero signal.
    private func buffer(_ index: Int) -> AVAudioPCMBuffer {
        SampleBufferFixtures.makePCMBuffer(
            channels: channels, frames: framesPerBuffer,
            sampleRate: inputSampleRate, interleaved: false
        ) { ch, frame in
            let n = index * self.framesPerBuffer + frame
            let v = Float(sin(Double(n) * 0.02)) * 0.4
            return ch == 0 ? v : -v
        }
    }

    private func encodeStream(to url: URL) throws {
        let encoder: any AudioFileEncoder = M4AEncoder()
        try encoder.createFile(at: url, sampleRate: inputSampleRate, channels: channels)
        for i in 0..<bufferCount {
            try encoder.writeBuffer(buffer(i))
        }
        try encoder.finalize()
    }

    @Test("Encodes a synthetic stream to a valid, decodable stereo .m4a")
    func producesValidM4A() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try encodeStream(to: url)

        // File exists and has real content.
        let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        #expect(size > 0)

        // Decodable as audio, stereo.
        let file = try AVAudioFile(forReading: url)
        #expect(file.fileFormat.channelCount == AVAudioChannelCount(channels))

        // Duration matches the input within tolerance (AAC adds encoder
        // priming/padding, so allow a small delta rather than exact equality).
        let expected = Double(bufferCount * framesPerBuffer) / inputSampleRate
        let actual = Double(file.length) / file.fileFormat.sampleRate
        #expect(abs(actual - expected) < 0.15)
    }

    @Test("Output is AAC at the configured 44.1kHz")
    func outputIsAAC44k() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        try encodeStream(to: url)

        let file = try AVAudioFile(forReading: url)
        #expect(file.fileFormat.sampleRate == 44_100)
    }

    @Test("finalize before createFile throws")
    func finalizeBeforeCreateThrows() {
        let encoder: any AudioFileEncoder = M4AEncoder()
        #expect(throws: M4AEncoderError.notOpen) {
            try encoder.finalize()
        }
    }

    // MARK: - BL-016 crash durability

    /// The M4A analogue of `WAVWriterTests.periodicHeaderMakesFilePlayableWithoutFinalize`.
    /// Before BL-016 the `moov` atom was written only at `finishWriting`, so a
    /// crash or force-quit mid-recording lost the entire take. Fragmenting makes
    /// the file periodically valid on disk.
    ///
    /// Unlike the WAV test this cannot be fully synchronous: the fragment is
    /// flushed by AVFoundation's own encoding queue. So we poll for the file to
    /// become readable with a hard ceiling — it fails rather than hangs, and
    /// never sleeps for a fixed duration.
    @Test("A partial M4A is playable without finalize (crash safety)")
    func partialFileIsPlayableWithoutFinalize() async throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let encoder: any AudioFileEncoder = M4AEncoder()
        try encoder.createFile(at: url, sampleRate: inputSampleRate, channels: channels)

        // Write comfortably more than one fragment interval of audio.
        let seconds = M4AEncoder.fragmentIntervalSeconds * 3
        let needed = Int((inputSampleRate * seconds) / Double(framesPerBuffer))
        for i in 0..<needed {
            try encoder.writeBuffer(buffer(i))
        }

        // Deliberately DO NOT finalize — simulate a crash / force-quit, taking a
        // snapshot exactly as the file sits on disk right now.
        let partial = url.deletingLastPathComponent()
            .appendingPathComponent("partial-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: partial) }

        // Wall-clock deadline, not an iteration count: each pass also copies a
        // growing file and attempts an open, so a fixed loop count understates
        // the real ceiling on a loaded CI runner. Breaks on first success
        // (typically pass 1–2), so the headroom is free when the test passes.
        var recovered: AVAudioFramePosition = 0
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            try? FileManager.default.removeItem(at: partial)
            try? FileManager.default.copyItem(at: url, to: partial)
            if let f = try? AVAudioFile(forReading: partial), f.length > 0 {
                recovered = f.length
                break
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(recovered > 0, "a partial M4A must be readable without finalize")

        // Finalizing normally must still produce the complete file. Assert the
        // exact expected length rather than only "longer than the fragment" —
        // the latter becomes a coin flip if fragmentIntervalSeconds ever divides
        // the written duration evenly.
        try encoder.finalize()
        let full = try AVAudioFile(forReading: url)
        #expect(full.length >= recovered)
        let expectedSeconds = Double(needed * framesPerBuffer) / inputSampleRate
        let actualSeconds = Double(full.length) / full.fileFormat.sampleRate
        #expect(abs(actualSeconds - expectedSeconds) < 0.15)
    }

    // MARK: - TD-014: finalize must be bounded

    @Test("The finalize budget fits inside the quit bound, floor included")
    func finalizeBudgetFitsTheQuitBound() {
        let quitBound = Double(TerminationCoordinator.defaultTimeout.components.seconds)

        #expect(M4AEncoder.finalizeBudget > 0, "an unbounded finalize is TD-014 itself")
        #expect(
            M4AEncoder.finalizeBudget <= quitBound,
            "finalize may wait \(M4AEncoder.finalizeBudget)s but ⌘Q is bounded at \(quitBound)s"
        )
        // The floor is reserved *out of* the budget, not added to it, so the
        // worst case is the budget itself. If someone changes the deadline to
        // `now + finalizeBudget` again, the two together exceed the quit bound.
        #expect(
            M4AEncoder.minimumFinishWait < M4AEncoder.finalizeBudget,
            "the reserved floor must leave the drain some budget to use"
        )
    }

    @Test("A saved M4A with a shortened tail is distinguishable from a failed write")
    func incompleteTakeIsItsOwnError() {
        #expect(M4AEncoderError.incompleteTake != M4AEncoderError.writeFailed)
        let described = M4AEncoderError.incompleteTake.errorDescription
        #expect(described?.isEmpty == false, "the error a user may see must say something")
        #expect(described != M4AEncoderError.writeFailed.errorDescription)

        let advice = M4AEncoderError.incompleteTake.recoverySuggestion
        #expect(advice?.isEmpty == false, "an error must carry what to do about it")
        #expect(
            advice?.localizedCaseInsensitiveContains("repair") == false,
            "a fragmented M4A plays as found; `repair(at:)` is a no-op for it"
        )
    }

    private nonisolated final class HeldFinish: Sendable {
        private struct State: Sendable {
            var callback: (@Sendable () -> Void)?
            var released = false
        }

        private let state = OSAllocatedUnfairLock(initialState: State())
        var isHeld: Bool { state.withLock { $0.callback != nil } }

        func hold(_ callback: @escaping @Sendable () -> Void) {
            let released = state.withLock { state in
                if state.released { return true }
                state.callback = callback
                return false
            }
            if released { callback() }
        }

        func release() {
            let callback = state.withLock { state in
                state.released = true
                let callback = state.callback
                state.callback = nil
                return callback
            }
            callback?()
        }
    }

    @Test("A delayed writer keeps its file, recovery exclusion and Sparkle gate until it closes",
          arguments: [false, true])
    func delayedWriterRetainsOwnership(failedTake: Bool) async throws {
        let hold = HeldFinish()
        defer { hold.release() }
        let directory = tempURL().deletingPathExtension()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let domain = "M4AFinishTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = LastRecordingStore(defaults: defaults)
        let capture = MockAudioCapturing()
        let location = MockSaveLocationProviding(directory: directory)
        let source = MockAudioSourceProviding()
        let controller = RecordingController(
            captureManager: capture,
            audioRecorder: AudioRecorder(encoderFactory: { _ in
                M4AEncoder(finalizeWait: 0.1, deliverFinish: hold.hold)
            }),
            saveLocation: location, audioSource: source
        )
        let model = RecorderViewModel(
            controller: controller, permissions: MockPermissionProviding(.granted),
            clock: ManualClock(), saveLocation: location, audioSource: source,
            installLocation: MockInstallLocationProviding(), defaults: defaults,
            notificationCenter: NotificationCenter(), lastRecordingStore: store
        )
        model.setFormat(.m4a)
        await model.startRecording()
        let url = try #require(controller.recordingURL)
        for i in 0..<10 { #expect(capture.simulateAudioBuffer(buffer(i))) }

        var installs = 0
        let sparkle = RelaunchPostponement(isSafeToInstall: { model.allowsProcessTermination })
        let subscription = model.allowsProcessTerminationPublisher
            .receive(on: RunLoop.main)
            .sink { if $0 { sparkle.release() } }
        defer { subscription.cancel() }
        #expect(sparkle.postpone { installs += 1 })

        let stop: Task<Void, Never>?
        if failedTake {
            capture.simulateStreamError("Capture was interrupted")
            stop = nil
        } else {
            stop = Task { await model.stopRecording() }
        }
        await waitUntil("AVFoundation to reach its held finish callback") { hold.isHeld }

        // This deadline is longer than the encoder's synchronous wait. The
        // callback is withheld throughout, exercising the asynchronous handoff.
        var quitReplies: [Bool] = []
        let quit = TerminationCoordinator(
            timeout: .milliseconds(200),
            isSafeToQuit: { model.allowsProcessTermination },
            drain: { await model.finishForTermination() },
            reply: { quitReplies.append($0) }
        )
        #expect(quit.shouldTerminate() == .terminateLater)
        #expect(quit.shouldTerminate() == .terminateLater)
        await waitUntil("explicit Quit to reach its deadline") { quitReplies.count > 0 }
        #expect(quitReplies == [true])
        #expect(controller.recordingURL == url)
        #expect(model.recordingURLProvider() == url)
        #expect(store.load() == nil)
        #expect(!model.allowsProcessTermination)
        #expect(installs == 0)
        #expect(FileManager.default.fileExists(atPath: url.path))

        hold.release()
        await stop?.value
        await waitUntil("the callback to release the parked update") { installs > 0 }
        sparkle.release()
        #expect(installs == 1)
        #expect(quitReplies == [true])
        #expect(controller.recordingURL == nil)
        #expect(store.load() == url)
        #expect(try AVAudioFile(forReading: url).length > 0)
    }

    /// The happy path must not have paid for the bound: a normal finalize over a
    /// small file returns in a fraction of the budget, nowhere near it.
    @Test("A normal finalize returns well inside the budget")
    func normalFinalizeIsFast() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let encoder = M4AEncoder()
        try encoder.createFile(at: url, sampleRate: inputSampleRate, channels: channels)
        for i in 0..<bufferCount {
            try encoder.writeBuffer(buffer(i))
        }

        let started = Date()
        try encoder.finalize()
        let elapsed = Date().timeIntervalSince(started)

        #expect(
            elapsed < M4AEncoder.finalizeBudget / 2,
            "finalize took \(elapsed)s of a \(M4AEncoder.finalizeBudget)s budget — the bound is being leaned on, not spared"
        )
    }
}

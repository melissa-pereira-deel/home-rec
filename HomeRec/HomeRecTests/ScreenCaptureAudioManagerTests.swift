//
//  ScreenCaptureAudioManagerTests.swift
//  HomeRecTests
//
//  The real `ScreenCaptureAudioManager`'s sample path, under Thread Sanitizer
//  (TD-013). Its state is written on the main actor and read on the queue
//  ScreenCaptureKit delivers buffers on; these tests run both sides at once.
//
//  No `SCStream` is built. Doing so needs a display from `SCShareableContent`,
//  which needs Screen Recording permission (absent on CI) and can raise the
//  system prompt on a developer's Mac. Buffers enter through `processSample`,
//  the handler's body, on the manager's own `audioQueue`. What this cannot
//  reach is ScreenCaptureKit's delivery itself, and `didStopWithError`.
//

import Testing
import Foundation
import AVFoundation
import CoreMedia
import ScreenCaptureKit
@testable import HomeRec

@MainActor
struct ScreenCaptureAudioManagerTests {

    /// Counts deliveries. Touched only on `audioQueue`, inside the callback,
    /// and read back through `audioQueue.sync`, so the tests add no race of
    /// their own for TSan to find.
    private final class Tally: @unchecked Sendable {
        var count = 0
    }

    private func buffer(frames: Int = 480) -> CMSampleBuffer {
        SampleBufferFixtures.interleaved(frames: frames) { _, _ in 0.25 }
    }

    /// Hands `count` buffers to the handler on its real queue, without waiting.
    private func feed(_ manager: ScreenCaptureAudioManager, _ count: Int, of type: SCStreamOutputType = .audio) {
        let sample = buffer()
        for _ in 0..<count {
            manager.audioQueue.async { manager.processSample(sample, of: type) }
        }
    }

    private func flush(_ manager: ScreenCaptureAudioManager) {
        manager.audioQueue.sync {}
    }

    @Test("Tearing a session down while buffers arrive leaves nothing delivered after it")
    func teardownWhileBuffersFlow() async {
        let manager = ScreenCaptureAudioManager()
        let delivered = Tally()
        manager.prepareSession { _ in delivered.count += 1 }

        // In flight on the capture queue while the main actor tears down,
        // with nothing ordering the two: the overlap a stop really has.
        feed(manager, 200)
        await manager.cleanup()
        flush(manager)
        let atTeardown = manager.audioQueue.sync { delivered.count }
        #expect(atTeardown <= 200)

        feed(manager, 10)
        flush(manager)
        #expect(manager.audioQueue.sync { delivered.count } == atTeardown,
                "a buffer after cleanup reached the session's callback")
    }

    @Test("A new session's buffers go to the new callback, not the previous one")
    func newSessionReplacesCallback() async {
        let manager = ScreenCaptureAudioManager()
        let first = Tally()
        let second = Tally()
        manager.prepareSession { _ in first.count += 1 }

        // The previous take's buffers are still arriving as the next is set up.
        feed(manager, 200)
        manager.prepareSession { _ in second.count += 1 }
        flush(manager)
        let firstAtSwitch = manager.audioQueue.sync { first.count }
        let secondAtSwitch = manager.audioQueue.sync { second.count }

        feed(manager, 10)
        flush(manager)
        #expect(manager.audioQueue.sync { first.count } == firstAtSwitch,
                "the previous session kept receiving the new session's buffers")
        #expect(manager.audioQueue.sync { second.count } == secondAtSwitch + 10)
        await manager.cleanup()
    }

    @Test("Video samples are ignored")
    func screenSamplesIgnored() async {
        let manager = ScreenCaptureAudioManager()
        let delivered = Tally()
        manager.prepareSession { _ in delivered.count += 1 }

        feed(manager, 5, of: .screen)
        flush(manager)

        #expect(manager.audioQueue.sync { delivered.count } == 0)
        await manager.cleanup()
    }

    @Test("A buffer the converter rejects is dropped, and the next one still arrives")
    func rejectedBufferDropped() async {
        let manager = ScreenCaptureAudioManager()
        let delivered = Tally()
        manager.prepareSession { _ in delivered.count += 1 }

        let empty = buffer(frames: 0)
        manager.audioQueue.async { manager.processSample(empty, of: .audio) }
        flush(manager)
        #expect(manager.audioQueue.sync { delivered.count } == 0)

        feed(manager, 1)
        flush(manager)
        #expect(manager.audioQueue.sync { delivered.count } == 1)
        await manager.cleanup()
    }
}

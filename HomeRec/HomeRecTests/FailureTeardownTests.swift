//
//  FailureTeardownTests.swift
//  HomeRecTests
//
//  A take that fails enters `.error` at once, then reports the outcome
//  after its file has closed. Until that has finished the encoder is still
//  open, and `.error` alone must not be read as "nothing to lose" (BL-171c).
//

import Testing
import Foundation
import Combine
@testable import HomeRec

@MainActor
struct FailureTeardownTests {

    private func makeViewModel() -> (RecorderViewModel, MockRecordingControlling) {
        let controller = MockRecordingControlling()
        let viewModel = RecorderViewModel(
            controller: controller,
            permissions: MockPermissionProviding(.granted),
            clock: ManualClock(),
            audioSource: MockAudioSourceProviding()
        )
        return (viewModel, controller)
    }

    /// Starts a take, fails it, and returns with its teardown parked on `gate`.
    private func failTakeHoldingTeardown(
        _ viewModel: RecorderViewModel,
        _ controller: MockRecordingControlling,
        gate: Gate,
        fail: (MockRecordingControlling) -> Void
    ) async {
        controller.onFinalizeHold = { await gate.wait() }
        await viewModel.startRecording()
        #expect(viewModel.state == .recording)
        fail(controller)
        await waitUntil("the failed take's teardown to be in flight") { gate.isWaiting }
    }

    // MARK: - The process may not end while a failed take is still closing

    @Test("A failed take blocks process termination until its file has closed",
          arguments: ["stream", "write"])
    func teardownBlocksTermination(kind: String) async {
        let (viewModel, controller) = makeViewModel()
        let gate = Gate()
        defer { gate.release() }
        await failTakeHoldingTeardown(viewModel, controller, gate: gate) {
            kind == "stream" ? $0.emitStreamError("stream died") : $0.emitWriteError()
        }

        guard case .error = viewModel.state else {
            Issue.record("expected .error, got \(viewModel.state)")
            return
        }
        #expect(viewModel.state.allowsUpdateInstall, "the state alone says yes — that is the gap")
        #expect(!viewModel.allowsProcessTermination, "the encoder is still open")

        let errorState = viewModel.state
        gate.release()
        await waitUntil("termination to be allowed once teardown ends") {
            viewModel.allowsProcessTermination
        }
        #expect(viewModel.state == errorState, "teardown ending is not a state change")
    }

    /// Sparkle parks a downloaded update while termination is refused, and it
    /// is released only by this stream. The state does not change when a failed
    /// take finishes closing, so a stream derived from `state` alone never
    /// reports it and the update stays parked.
    @Test("The gate reopens when teardown ends, with no state change to announce it")
    func gateStreamReportsTeardownEnding() async {
        let (viewModel, controller) = makeViewModel()
        var seen: [Bool] = []
        let subscription = viewModel.allowsProcessTerminationPublisher.sink { seen.append($0) }
        defer { subscription.cancel() }

        let gate = Gate()
        defer { gate.release() }
        await failTakeHoldingTeardown(viewModel, controller, gate: gate) {
            $0.emitStreamError("stream died")
        }
        #expect(seen.last == false, "held closed through the failure, got \(seen)")

        gate.release()
        await waitUntil("the stream to report the reopened gate") { seen.last == true }
        #expect(seen == [true, false, true], "idle, then closed from start to closed file: \(seen)")
    }

    @Test("Quitting mid-teardown waits for the failed take to close")
    func terminationDrainsFailureTeardown() async {
        let (viewModel, controller) = makeViewModel()
        let gate = Gate()
        defer { gate.release() }
        await failTakeHoldingTeardown(viewModel, controller, gate: gate) {
            $0.emitWriteError(.sizeLimitReached)
        }

        var drained = false
        let drain = Task {
            await viewModel.finishForTermination()
            drained = true
        }
        await settle()
        #expect(!drained, "the quit drain returned while the file was still open")

        gate.release()
        await drain.value
        #expect(drained)
        #expect(controller.finalizeCount == 1)
    }

    @Test("A failed WAV close presents one error instead of claiming the take was saved")
    func failedSizeLimitCloseReportsFailureOnce() async {
        let (viewModel, controller) = makeViewModel()
        let gate = Gate()
        defer { gate.release() }
        var alerts = 0
        let observation = viewModel.$showError.sink { if $0 { alerts += 1 } }
        defer { observation.cancel() }

        struct CannotClose: LocalizedError {
            var errorDescription: String? { "Cannot close WAV" }
        }
        controller.finalizeError = CannotClose()
        await failTakeHoldingTeardown(viewModel, controller, gate: gate) {
            $0.emitWriteError(.sizeLimitReached)
        }
        #expect(alerts == 0)
        gate.release()
        await waitUntil("the close failure to surface") { viewModel.allowsProcessTermination }
        #expect(viewModel.state == .error(.stopFailed("Cannot close WAV")))
        #expect(alerts == 1)
    }

    @Test("Quit prevents a retry already waiting on the previous writer")
    func quitAbortsWaitingRetry() async {
        let (viewModel, controller) = makeViewModel()
        let gate = Gate()
        defer { gate.release() }
        await failTakeHoldingTeardown(viewModel, controller, gate: gate) {
            $0.emitStreamError("Capture disconnected")
        }
        let retry = Task { await viewModel.startRecording() }
        await waitUntil("retry to wait for teardown") { viewModel.state == .starting }
        var draining = false
        let quit = Task {
            draining = true
            await viewModel.finishForTermination()
        }
        await waitUntil("explicit quit to start draining") { draining }
        gate.release()
        await retry.value
        await quit.value
        #expect(controller.startCount == 1)
        #expect(viewModel.state == .idle)
        #expect(viewModel.allowsProcessTermination)
    }

    @Test("An error with nothing left open does not hold the process")
    func settledErrorAllowsTermination() async {
        let (viewModel, controller) = makeViewModel()
        await viewModel.startRecording()
        controller.emitStreamError("stream died")
        await waitUntil("teardown to finish") { controller.finalizeCount == 1 }
        await settle()

        #expect(viewModel.allowsProcessTermination)
        await viewModel.finishForTermination()
        #expect(controller.finalizeCount == 1, "nothing to drain twice")
    }

    // MARK: - A failure while starting or stopping is held, then applied

    /// Both handlers used to return unless the state was exactly `.recording`.
    /// A stream that died while the take was still starting was dropped, and
    /// the app went on to show a running timer over a dead stream.
    @Test("A failure reported while the take is starting ends it, instead of being dropped",
          arguments: ["stream", "write"])
    func failureDuringStartSurfaces(kind: String) async {
        let (viewModel, controller) = makeViewModel()
        controller.onStart = {
            kind == "stream"
                ? controller.emitStreamError("died while starting")
                : controller.emitWriteError(.other("refused while starting"))
        }

        await viewModel.startRecording()

        let expected: RecordingState = kind == "stream"
            ? .error(.streamFailed("died while starting"))
            : .error(.writeFailed("refused while starting"))
        #expect(viewModel.state == expected)
        await waitUntil("the take that did start to be finalized") { controller.finalizeCount == 1 }
        await waitUntil("its teardown to finish") { viewModel.allowsProcessTermination }
        #expect(viewModel.showError)
    }

    @Test("A failure reported while the take is stopping is shown once the stop lands",
          arguments: ["stream", "write"])
    func failureDuringStopSurfaces(kind: String) async {
        let (viewModel, controller) = makeViewModel()
        await viewModel.startRecording()
        controller.onStop = {
            kind == "stream"
                ? controller.emitStreamError("died while stopping")
                : controller.emitWriteError(.other("refused while stopping"))
        }

        await viewModel.stopRecording()

        let expected: RecordingState = kind == "stream"
            ? .error(.streamFailed("died while stopping"))
            : .error(.writeFailed("refused while stopping"))
        #expect(viewModel.state == expected, "the take ended early and the user was told nothing")
        #expect(controller.stopCount == 1)
        #expect(controller.finalizeCount == 0, "the stop already closed the file; nothing to finalize twice")
        #expect(viewModel.allowsProcessTermination)
    }

    // MARK: - …and only to the take it belongs to

    @Test("When the start itself fails, its error is the one shown, and the next take is clean")
    func startErrorWinsOverHeldFailure() async {
        let (viewModel, controller) = makeViewModel()
        controller.startError = RecorderError.startFailed("nope")
        controller.onStart = { controller.emitStreamError("died while starting") }

        await viewModel.startRecording()

        guard case .error(.startFailed) = viewModel.state else {
            Issue.record("expected the start's own error, got \(viewModel.state)")
            return
        }
        #expect(controller.finalizeCount == 0, "a failed start rolls itself back")

        controller.startError = nil
        controller.onStart = nil
        await viewModel.startRecording()
        #expect(viewModel.state == .recording, "the held failure leaked into the next take")
    }

    @Test("When the stop itself fails, its error is the one shown, and the next take is clean")
    func stopErrorWinsOverHeldFailure() async {
        let (viewModel, controller) = makeViewModel()
        await viewModel.startRecording()
        controller.stopError = RecorderError.stopFailed("finalize failed")
        controller.onStop = { controller.emitStreamError("died while stopping") }

        await viewModel.stopRecording()

        guard case .error(.stopFailed) = viewModel.state else {
            Issue.record("expected the stop's own error, got \(viewModel.state)")
            return
        }

        controller.stopError = nil
        controller.onStop = nil
        await viewModel.startRecording()
        #expect(viewModel.state == .recording, "the held failure leaked into the next take")
    }

    /// A retry waits in `.starting` for the failed take to close. A second
    /// report from that draining take lands in `.starting` too, and belongs to
    /// the old take, not the one about to begin.
    @Test("A second report from a draining take does not stop the retry")
    func drainingTakeCannotFailTheRetry() async {
        let (viewModel, controller) = makeViewModel()
        let gate = Gate()
        defer { gate.release() }
        await failTakeHoldingTeardown(viewModel, controller, gate: gate) {
            $0.emitStreamError("stream died")
        }

        let retry = Task { await viewModel.startRecording() }
        await waitUntil("the retry to park in .starting") { viewModel.state == .starting }
        controller.emitWriteError(.other("the draining take's last word"))

        gate.release()
        await retry.value

        #expect(viewModel.state == .recording)
        #expect(controller.finalizeCount == 1, "only the first take was finalized")
    }
}

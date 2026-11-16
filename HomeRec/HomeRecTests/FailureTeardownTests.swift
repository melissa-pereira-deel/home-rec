//
//  FailureTeardownTests.swift
//  HomeRecTests
//
//  A take that fails enters `.error` at once, so the alert is not held up, and
//  closes its file afterwards. Until that has finished the encoder is still
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
}

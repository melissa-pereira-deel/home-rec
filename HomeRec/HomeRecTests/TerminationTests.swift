//
//  TerminationTests.swift
//  HomeRecTests
//
//  BL-174: ⌘Q during a take must finish the recording, not sever it.
//
//  Before this, `AppDelegate` had no `applicationShouldTerminate` at all, so
//  AppKit terminated immediately with the encoder still open: a WAV whose header
//  under-reports its length, an M4A with no `moov` atom, a FLAC that will not
//  open until repaired. Crash recovery exists for *unexpected* termination; it
//  should not be what catches someone pressing Quit.
//
//  The doubles here are local rather than in `Mocks.swift` on purpose: the
//  suspendable stop is specific to driving the timeout branch, and the shared
//  mocks are already carrying enough.
//

import Testing
import Foundation
import AppKit
@testable import HomeRec

@MainActor
struct TerminationTests {

    // MARK: - Doubles

    /// A drain whose completion the test controls, so the timeout branch can be
    /// driven without waiting on anything real.
    ///
    /// ⚠️ `finished` is a latch, not a convenience. The first version stored only
    /// the continuation, so `finish()` was a **no-op if the drain task had not yet
    /// reached `withCheckedContinuation`** — and a test that waited a fixed 30 ms
    /// for it to get there passed locally and failed on CI, where the actor is
    /// contended. That is an ordering bug in the double, not a flaky test, and
    /// lengthening the wait would have hidden it rather than fixed it.
    private final class ControllableDrain {
        private(set) var callCount = 0
        private var resume: (() -> Void)?
        private var finished = false
        /// When false, `run()` never returns until `finish()` is called.
        var completesImmediately = true

        func run() async {
            callCount += 1
            guard !completesImmediately, !finished else { return }
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                // `finish()` may already have happened — resume immediately
                // rather than parking a continuation nobody will ever resume.
                if finished {
                    c.resume()
                } else {
                    resume = { c.resume() }
                }
            }
        }

        func finish() {
            finished = true
            resume?()
            resume = nil
        }
    }

    private final class ReplyRecorder {
        private(set) var replies: [Bool] = []
        var count: Int { replies.count }
        func record(_ value: Bool) { replies.append(value) }
    }

    private func makeCoordinator(
        safe: @escaping @MainActor () -> Bool,
        drain: ControllableDrain,
        recorder: ReplyRecorder,
        timeout: Duration = .seconds(5)
    ) -> TerminationCoordinator {
        TerminationCoordinator(
            timeout: timeout,
            isSafeToQuit: safe,
            drain: { await drain.run() },
            reply: { recorder.record($0) }
        )
    }

    // MARK: - The decision

    @Test("An open take defers termination instead of quitting immediately")
    func openTakeDefersTermination() async {
        let drain = ControllableDrain()
        let recorder = ReplyRecorder()
        let coordinator = makeCoordinator(safe: { false }, drain: drain, recorder: recorder)

        // This is the regression. Before BL-174 there was no
        // `applicationShouldTerminate`, so AppKit's answer was `.terminateNow`
        // and the file was severed mid-write.
        #expect(coordinator.shouldTerminate() == .terminateLater)

        await waitUntil("the drain to finish and reply") { recorder.count == 1 }
        #expect(drain.callCount == 1)
        #expect(recorder.replies == [true])
    }

    @Test("Nothing open quits immediately, with no drain and no added latency")
    func idleQuitsImmediately() {
        let drain = ControllableDrain()
        let recorder = ReplyRecorder()
        let coordinator = makeCoordinator(safe: { true }, drain: drain, recorder: recorder)

        #expect(coordinator.shouldTerminate() == .terminateNow)
        #expect(drain.callCount == 0)
        // `.terminateNow` is the answer itself — AppKit is not waiting on a reply.
        #expect(recorder.count == 0)
    }

    // MARK: - The bound

    @Test("A drain that never finishes still quits, once the bound expires")
    func stuckDrainStillQuits() async {
        let drain = ControllableDrain()
        drain.completesImmediately = false
        let recorder = ReplyRecorder()
        let coordinator = makeCoordinator(
            safe: { false }, drain: drain, recorder: recorder, timeout: .milliseconds(20)
        )

        #expect(coordinator.shouldTerminate() == .terminateLater)

        // The drain is still suspended; only the bound can get us out.
        await waitUntil("the bound to expire and quit anyway") { recorder.count == 1 }
        #expect(recorder.replies == [true])

        drain.finish()   // let the suspended drain unwind
    }

    @Test("The reply is sent exactly once when the drain and the bound race")
    func replyIsSentExactlyOnce() async {
        let drain = ControllableDrain()
        drain.completesImmediately = false
        let recorder = ReplyRecorder()
        let coordinator = makeCoordinator(
            safe: { false }, drain: drain, recorder: recorder, timeout: .milliseconds(10)
        )

        #expect(coordinator.shouldTerminate() == .terminateLater)
        await waitUntil("the bound to fire") { recorder.count == 1 }

        // Now let the drain complete too. Both paths have now run; replying a
        // second time to AppKit traps, so this must stay at one.
        drain.finish()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(recorder.count == 1, "replied \(recorder.count) times; AppKit traps on the second")
    }

    @Test("A second quit while already finishing does not start a second drain")
    func secondQuitIsIgnoredWhileDraining() async {
        let drain = ControllableDrain()
        drain.completesImmediately = false
        let recorder = ReplyRecorder()
        let coordinator = makeCoordinator(
            safe: { false }, drain: drain, recorder: recorder, timeout: .seconds(30)
        )

        #expect(coordinator.shouldTerminate() == .terminateLater)
        #expect(coordinator.shouldTerminate() == .terminateLater)

        // Wait for the drain to actually start rather than guessing at a delay —
        // on a contended actor a fixed sleep is a race, and this one failed on CI
        // for exactly that reason.
        await waitUntil("the drain to start") { drain.callCount > 0 }
        #expect(drain.callCount == 1, "a second ⌘Q started a second drain")

        drain.finish()
        await waitUntil("the single reply") { recorder.count == 1 }
        #expect(recorder.count == 1)
    }

    @Test("The drain completing before it starts is still observed")
    func drainFinishedBeforeItStartsStillReplies() async {
        // The exact ordering that failed on CI. `finish()` used to store nothing
        // when no continuation was parked yet, so a drain task that had not been
        // scheduled by the time the test called `finish()` would park forever and
        // the reply would never come — reported as a 10s `waitUntil` timeout.
        //
        // Driven deterministically here rather than by hoping the scheduler
        // reproduces it: finish first, then let the coordinator run the drain.
        let drain = ControllableDrain()
        drain.completesImmediately = false
        let recorder = ReplyRecorder()
        let coordinator = makeCoordinator(
            safe: { false }, drain: drain, recorder: recorder, timeout: .seconds(30)
        )

        drain.finish()   // before shouldTerminate() has spawned anything
        #expect(coordinator.shouldTerminate() == .terminateLater)

        // Must not need the 30s bound to get here.
        await waitUntil("the reply despite the inverted ordering") { recorder.count == 1 }
        #expect(recorder.replies == [true])
    }

    @Test("An unknown state quits rather than hanging")
    func unwiredCoordinatorQuits() {
        // Deliberately the opposite default from `UpdaterController`, which
        // answers `false` when the view model is gone. There, "unknown" must mean
        // "don't replace the binary". Here it must mean "let the user quit" — an
        // app that cannot be quit is worse than a take that needed recovery.
        let drain = ControllableDrain()
        let recorder = ReplyRecorder()
        let viewModel: RecorderViewModel? = nil
        let coordinator = makeCoordinator(
            safe: { viewModel?.state.allowsUpdateInstall ?? true },
            drain: drain, recorder: recorder
        )

        #expect(coordinator.shouldTerminate() == .terminateNow)
    }

    // MARK: - Per-state drain behaviour

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

    @Test("Recording drains through the normal stop path")
    func recordingDrains() async {
        let (viewModel, controller) = makeViewModel()
        await viewModel.startRecording()
        #expect(viewModel.state == .recording)

        await viewModel.finishForTermination()

        #expect(controller.stopCount == 1)
        #expect(viewModel.state == .idle)
    }

    @Test("Idle needs no drain")
    func idleNeedsNoDrain() async {
        let (viewModel, controller) = makeViewModel()
        #expect(viewModel.state == .idle)

        await viewModel.finishForTermination()

        #expect(controller.stopCount == 0)
        #expect(viewModel.state == .idle)
    }

    @Test("An errored take needs no drain — the file is already closed")
    func errorNeedsNoDrain() async {
        let (viewModel, controller) = makeViewModel()
        controller.startError = RecorderError.startFailed("nope")
        await viewModel.startRecording()
        guard case .error = viewModel.state else {
            Issue.record("expected .error, got \(viewModel.state)")
            return
        }

        await viewModel.finishForTermination()
        #expect(controller.stopCount == 0)
    }

    @Test("The quit gate agrees with the update gate about what is unsafe")
    func quitGateMatchesUpdateGate() {
        // Both answer "may we end this process?". `.stopping` is included in
        // both for the same reason: it is when the file is being finalized, the
        // single worst moment to terminate — not the safest, as it reads.
        #expect(RecordingState.idle.allowsUpdateInstall == true)
        #expect(RecordingState.error(.diskFull).allowsUpdateInstall == true)
        #expect(RecordingState.starting.allowsUpdateInstall == false)
        #expect(RecordingState.recording.allowsUpdateInstall == false)
        #expect(RecordingState.stopping.allowsUpdateInstall == false)
        #expect(RecordingState.recovering.allowsUpdateInstall == false)
    }
}

//
//  RecordingStateTests.swift
//  HomeRecTests
//
//  Pure state-machine tests for RecordingState transitions (BL-006).
//  No hardware or permission required.
//

import Testing
@testable import HomeRec

@MainActor
struct RecordingStateTests {

    /// Representative instance of each state. Index order is used by the matrix below.
    /// 0 idle · 1 starting · 2 recording · 3 stopping · 4 error · 5 recovering
    private let states: [RecordingState] = [
        .idle, .starting, .recording, .stopping, .error(.startFailed("boom")), .recovering
    ]

    /// The complete set of legal transitions, expressed as `[fromIndex, toIndex]`.
    /// This is an independent specification of the transition table.
    private let legalPairs: Set<[Int]> = [
        [0, 1],                  // idle → starting
        [1, 2], [1, 4], [1, 0],  // starting → recording / error / idle
        [2, 3], [2, 4], [2, 5],  // recording → stopping / error / recovering
        [3, 0], [3, 4],          // stopping → idle / error
        [4, 0], [4, 1],          // error → idle / starting
        [5, 2], [5, 3], [5, 4],  // recovering → recording / stopping / error
    ]

    @Test("Every (from, to) pair matches the legal transition table")
    func transitionMatrixIsExhaustivelyCorrect() {
        for (from, fromState) in states.enumerated() {
            for (to, toState) in states.enumerated() {
                let shouldBeLegal = legalPairs.contains([from, to])
                #expect(
                    fromState.canTransition(to: toState) == shouldBeLegal,
                    "transition \(from) → \(to) expected legal=\(shouldBeLegal)"
                )
            }
        }
    }

    @Test("idle cannot jump straight to stopping")
    func idleCannotStop() {
        #expect(RecordingState.idle.canTransition(to: .stopping) == false)
    }

    @Test("a recording can be stopped or fail, but cannot restart")
    func recordingTransitions() {
        #expect(RecordingState.recording.canTransition(to: .stopping))
        #expect(RecordingState.recording.canTransition(to: .error(.stopFailed("x"))))
        #expect(RecordingState.recording.canTransition(to: .starting) == false)
        #expect(RecordingState.recording.canTransition(to: .recording) == false)
    }

    @Test("an error state can be retried (→ starting) or cleared (→ idle)")
    func errorRecoveryPaths() {
        let errorState = RecordingState.error(.startFailed("x"))
        #expect(errorState.canTransition(to: .starting))
        #expect(errorState.canTransition(to: .idle))
        #expect(errorState.canTransition(to: .recording) == false)
    }

    @Test("RecorderError exposes plain-language messages without leaking technical detail")
    func errorMessagesArePlainLanguage() {
        let start = RecorderError.startFailed("ECONNREFUSED 0x80010001")
        // The raw detail must not appear in the user-facing message…
        #expect(start.message.contains("ECONNREFUSED") == false)
        // …but is retained for logs/diagnostics.
        #expect(start.detail == "ECONNREFUSED 0x80010001")
        #expect(start.message.isEmpty == false)
    }

    @Test("RecorderError maps to the right recovery action")
    func errorRecoveryMapping() {
        #expect(RecorderError.startFailed("x").recovery == .tryAgain)
        #expect(RecorderError.streamFailed("x").recovery == .openSettings)
        #expect(RecorderError.stopFailed("x").recovery == nil)
        #expect(RecorderError.diskFull.recovery == nil)
        #expect(RecoverySuggestion.openSettings.label == "Open settings")
        #expect(RecoverySuggestion.tryAgain.label == "Try again")
    }
}

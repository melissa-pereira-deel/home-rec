//
//  AsyncWaiting.swift
//  HomeRecTests
//
//  BL-156: deadline-bounded waits for tests that must let another task make
//  progress before asserting.
//
//  These replace `for _ in 0..<2000 where condition { await Task.yield() }`,
//  which was the shape used at 45 sites across seven files and which fails in
//  two ways at once.
//
//  It measures the wrong quantity. These suites are `@MainActor` and Swift
//  Testing runs suites in parallel, so every yield re-enqueues the test behind
//  whatever else is contending for the actor. How many yields it takes for the
//  task under test to reach its third poll is a function of machine load, not
//  of the work being tested — so the budget that is ample on an idle laptop is
//  not ample on a loaded CI runner.
//
//  And it fails silently. The loop exits when the budget runs out exactly as it
//  exits on success, so the *following* `#expect` reports a logic failure for
//  what was a scheduling timeout. That is how commit 66d0702 — three added
//  lines of CHANGELOG.md, no source change — turned CI red on
//  `backgroundGrantIsDetectedWithoutInteraction`, and took the Release-build
//  gate down with it, since the job is sequential.
//
//  Bounding by wall-clock time instead means a loaded runner takes longer and
//  still passes, and a genuine hang is reported as the timeout it is.
//

import Testing
import Foundation

/// Waits until `condition` holds, bounded by elapsed time rather than by a
/// number of yields, and records a timeout against the *caller* if it never
/// does.
///
/// `description` completes the sentence "timed out waiting for…", so phrase it
/// as the thing being awaited: `"the watcher's third probe"`.
///
/// On timeout this records an issue and returns rather than trapping, so the
/// assertions that follow still run — a test whose wait timed out usually has
/// something further to say about *what* state it reached instead.
@MainActor
func waitUntil(
    _ description: String,
    timeout: Duration = .seconds(10),
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () -> Bool
) async {
    // Fast path. An uncontended actor settles in a handful of yields, and
    // staying off the clock keeps the common case as quick as the loops this
    // replaces.
    for _ in 0..<200 {
        if condition() { return }
        await Task.yield()
    }

    // Contended path. Yielding only re-enqueues behind the contention, whereas
    // sleeping actually frees the actor for the task we are waiting on — so
    // under the load that caused the flake, this is the part that makes
    // progress.
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(1))
    }

    if condition() { return }
    Issue.record(
        "Timed out after \(timeout) waiting for: \(description)",
        sourceLocation: sourceLocation
    )
}

/// Lets already-scheduled work run when there is no condition to wait *for* —
/// i.e. immediately before asserting that something did **not** happen.
///
/// A negative assertion cannot be waited into truth, so this is a best effort
/// by construction and no timeout would help. Where a positive fact proves the
/// path ran at all, `waitUntil` that fact first and let this cover only the
/// gap; a negative check with no such pairing passes just as well when the code
/// under test never executed.
@MainActor
func settle() async {
    for _ in 0..<200 { await Task.yield() }
    // A real suspension, so work sitting behind a contended actor gets a turn
    // that yielding alone would not give it.
    try? await Task.sleep(for: .milliseconds(5))
    for _ in 0..<200 { await Task.yield() }
}

# Home Rec architecture review

Reviewed 2026-09-05 at commit `2f9c42dd92dad72cb7e1d29ce555c2ee48967e53`. Source references below are relative to `home-rec/`. This is a static code review, not evidence that hardware capture, power-loss recovery, or performance has been exercised on this machine. Confidence is high in the control-flow findings; timing-dependent impact still needs deterministic regression tests and selected hardware checks.

## Assessment

The architecture fits a small, local-first Mac recorder. Keep the native app and its existing protocol seams. A rewrite, service backend, generalized plug-in framework, or broad modularization would add more coordination cost than value. The next investment should close recording-lifecycle gaps so that “ready,” “recording,” and “safe to quit/update” describe actual resource ownership. The most consequential risks sit between otherwise well-tested components.

The app is SwiftUI plus AppKit for menu/window integration. A shared `RecorderViewModel` coordinates permissions, selection and presentation. `RecordingController` opens an encoder, configures ScreenCaptureKit, and manages capture. `ScreenCaptureAudioManager` converts incoming samples to a canonical 48 kHz stereo Float32 format; `AudioRecorder` queues encoding and waveform work; `AudioFormat` selects WAV, AAC/M4A or FLAC. Recovery is format-specific. Preferences live in UserDefaults and recordings are ordinary local files. Sparkle is the principal network-facing dependency.

## Decisions worth preserving

- **Protocol boundaries match real side effects.** `AudioCapturing`, `AudioFileWriting`, `RecordingControlling`, permissions, clocks and save-location providers make orchestration testable without audio hardware. The shared source/save providers are resolved once in `RecorderViewModel.swift:195–204`, preventing UI and recorder from silently using different selections.
- **One canonical audio contract.** `AudioCapturing.swift:14–15` makes the format explicit; `ScreenCaptureAudioManager.swift:263–293` normalizes at the source boundary. Each encoder checks its own input assumptions. This is an effective containment boundary for adding new hardware and formats.
- **Format metadata and recovery evolve together.** `AudioFormat.swift:55–86` centrally maps availability, encoder and recovery. Preserve exhaustive switches when introducing MP3; availability should require a measured interruption/recovery policy as well as successful encoding.
- **Encoder work is serialized.** `AudioRecorder.swift:86–122` confines the encoder and drains queued buffers before finalization. This is a reasonable design for the present throughput; it needs clearer actor isolation and asynchronous completion, not an entire streaming framework.
- **Durability is a product concern.** WAV checkpoints, M4A fragments and atomic recovery are materially valuable. `AudioFileRecovery.swift:51–63` explicitly contracts atomic repair. Keep golden crash snapshots in the format acceptance contract.
- **Secondary features have a separate failure domain.** The unshipped monitoring implementation explicitly keeps monitoring errors from terminating recordings (`MonitorController.swift:7–19`, `65–75`). Preserve that boundary when the hardware spike passes; the presence of code is not evidence that the feature is shipped.

## Prioritized findings

### P1 — Error presentation currently releases the session before teardown completes

`RecorderViewModel.handleStreamFailure` enters `.error` immediately, then launches an unawaited task to finalize the previous take (`RecorderViewModel.swift:756–763`). `.error` allows another start and permits update installation (`RecordingState.swift:162–167`, `188–190`). `MenuBarController.swift:39–40` passes that state-derived permission to Sparkle.

Consequently a quick retry or pending update can overlap the old take's cleanup. A retry can replace the shared encoder/capture stream, after which the old finalizer may operate on the replacement resources. This is a concrete reentrancy window; its frequency has not been measured. Stream failures during `.starting` or `.stopping` are ignored by the same handler, which deserves deliberate semantics rather than an incidental guard.

**Change:** Keep a session in a non-restartable, non-terminable state until teardown finishes; display the error immediately through a separate presentation value. Give sessions an identity and ignore stale callbacks. Derive “may restart / repair this file / install update / quit” from whether the session still owns resources. Use one idempotent stop/finalize path.

**Proof:** Suspend failure cleanup in a fake capture source; assert a retry and update remain blocked, then unblock cleanup and assert the next take survives. Inject a late callback from the old session and prove it cannot stop the new session.

### P1 — Start/stop are not complete transactions

The controller opens the file before the two awaited capture operations (`RecordingController.swift:75–85`). If setup/start throws, there is no rollback; `currentRecordingURL` is not assigned until line 87. On normal stop, a thrown `stopCapture()` exits before recorder finalization and cleanup (`94–115`). The implementation handles an encoder-finalize error carefully but not a capture-stop error. Its deinitializer only attempts cleanup if `captureManager.capturing` is true (`180–188`), so it cannot guarantee cleanup after a failed start.

**Change:** Track session resources from file creation onward; unwind partially acquired resources on every start failure and always attempt all teardown stages. Preserve the primary error and record secondary cleanup failures. Publish `.error` only after the ownership state is safe, as above. An explicitly empty failed-start file can be removed under a documented policy; preserve any file containing audio.

**Proof:** Cover failure at encoder creation, capture setup, capture start, capture stop, and encoder finalization. Each case must leave no open capture/encoder, preserve the intended partial file, and allow a subsequent start. Existing `RecordingControllerTests.swift:80–114` covers finalize failure and clean stop, but not these other failure stages.

### P1 — A moving waveform does not prove audio is being saved

`AudioRecorder.swift:142–151` publishes waveform samples before calling `try? encoder.writeBuffer`. Persistent write failures therefore do not stop capture or surface to the UI. `M4AEncoder.swift:129–147` throws and logs append rejection, but that error is swallowed by its caller. This weakens the user-facing claim in `CHANGELOG.md:37` that the failure is reported when it happens: a log entry is not an in-app recording failure.

Disk checks only occur before recording (`RecordingController.swift:66–70`). The default WAV writer also uses nonthrowing legacy `FileHandle.write` calls (`WAVWriter.swift:146`, `165`, `192`, `209`) despite declaring throwing operations, so failure handling must be checked all the way to the actual I/O call.

**Change:** Add a first-fatal-write-error channel, stop accepting new audio once it fires, and finalize the partial take through the common lifecycle path. Report once rather than logging each rejected buffer. Use throwing writes and track accepted frames/bytes. Distinguish “no input signal” from “input arrived but could not be saved.”

**Proof:** Use an encoder that succeeds for N buffers then throws; verify a visible error, one failure notification, preserved partial output, and no apparent successful recording afterwards. Exercise a destination that becomes unavailable mid-take.

### P1/P2 — File ownership is weaker than the UI's “recording” flag

Recovery excludes only `lastRecordingURL` while `viewModel.isRecording` is true (`MenuBarController.swift:58–65`). An encoder is already open during `.starting`, remains open while `.stopping`, and can remain open during the asynchronous error cleanup above. Those windows return no excluded URL. `RecoveryViewModel.swift:44–67` also trusts previously listed recordings when repairing or trashing them, without a fresh ownership check.

Ordinary Quit directly calls `NSApp.terminate` (`OverflowMenu.swift:388–390`); `AppDelegate.swift:11–38` has no termination handler that waits for finalization. Crash recovery is useful but should not be the normal quit path, especially for FLAC, which needs repair after interruption.

**Change:** Expose the currently owned output URL from file creation through final release, and recheck it at scan, repair and trash time. Use the same session-completion mechanism for normal Quit and update relaunch. A short graceful drain should precede termination; preserve emergency interruption recovery as a fallback.

### P2 — Make actor and queue ownership enforceable

`AudioCapturing` and `AudioFileWriting` are `@MainActor` protocols (`AudioCapturing.swift:16`, `AudioFileWriting.swift:13`), while the capture delegate and processing queue consume mutable callbacks and converter/encoder state. `ScreenCaptureAudioManager.swift:75–77` explicitly acknowledges the remaining TD-009 race. `audioNormalizer` is reset during setup (`97`), read on the sample queue (`285`), and `audioCallback` is written during setup/cleanup (`93`, `225`) and read during sample delivery (`293`). The callback property in `AudioRecorder` is likewise read from the processing queue and set through the main-actor-facing lifecycle.

The project uses default MainActor isolation but Swift 5 language mode (`HomeRec/HomeRec.xcodeproj/project.pbxproj:432–436`, `479–483`); that is not a complete strict-concurrency guarantee.

**Change:** Document and implement one owner for control state and one owner for sample processing. Keep delegate-to-worker handoffs explicit and immutable where possible; tear down/drain the sample handler before mutating its session-owned converter and callbacks. Introduce strict concurrency checking in measured stages and use Thread Sanitizer plus real start/stop/device-change stress. Do not paper over isolation issues with blanket unchecked Sendable annotations.

### P2 — Long recordings expose boundedness and responsiveness gaps

- `AudioRecorder.stopRecording` synchronously waits for its processing queue (`107–122`) from the main-actor control path. M4A finalization polls for up to approximately five seconds and then waits on a semaphore without a timeout (`M4AEncoder.swift:154–173`). The UI can freeze while saving, and the final wait has no explicit bound.
- Both the recording dispatch queue (`AudioRecorder.swift:99`) and M4A pending sample array (`M4AEncoder.swift:128–149`) can grow if encoding/storage falls behind. A failure policy or budget is absent. Establish queue depth/oldest-buffer age limits and fail clearly rather than silently dropping recorded audio.
- WAV byte counts are UInt32 and increment without a size guard (`WAVWriter.swift:60`, `147`, `220`). At 48,000 × 2 × 2 bytes/s, the roughly 4 GiB RIFF limit arrives around **6 h 13 min**. The arithmetic can overflow rather than produce a controlled stop. Add a limit or segmented/RF64 policy before promising unattended long takes; test the boundary using injected counters instead of a six-hour fixture.
- Recovery runs on MainActor (`RecoveryViewModel.swift:14`, `50–54`) and its atomic patch loads the entire recording into memory (`AudioFileRecovery.swift:88–98`). Multi-hour WAV repair can block the UI and consume gigabytes. Copy the original to a same-volume temporary file in bounded chunks, patch the header there, then atomically replace off the UI executor, with progress and cancellation before replacement.

These do not justify changing every component at once. Fix asynchronous stop, controlled size/backpressure limits, and streamed recovery as separate reviewable changes.

## Architectural opportunities after reliability work

1. **A small session owner, not a generalized workflow engine.** The controller should own immutable source/format/destination/session ID and the full acquisition/teardown lifecycle. The view model renders progress/errors and delegates commands. This makes pause/resume, monitoring and future unattended work safer to add.
2. **Separate slow application state from waveform display.** `HomeRecApp.swift:51–56` already documents whole-view invalidation around 47 times per second. A small waveform observable or bounded latest-sample stream can isolate this without migrating all state management. Measure first; this is below data safety in priority.
3. **Extract permission coordination opportunistically.** `RecorderViewModel.swift` is roughly 900 lines and mixes recording, permissions, installation location, AppKit presentation, preference storage and timing. The current injected seams are good. Move cohesive permission/watch behavior out when that area next changes; avoid a broad cleanup PR that obscures reliability fixes.
4. **Keep a short architecture decision record beside the source.** Record native/local-only scope, canonical PCM, lifecycle ownership, concurrency boundaries, format durability, and what requires physical-hardware evidence. Inline comments contain substantial history but some refer to private reports or already-completed backlog states. Public, current decision summaries will give agents more reliable context than repeatedly reconstructing intentions from comments.

## Recommended implementation order

First close session teardown, error propagation and resource ownership, including normal Quit. Next enforce concurrency boundaries and asynchronous finalization. Then address long-file limits, recovery memory use and backpressure. Only then expand session complexity with pause, live monitoring or automation. UI performance and view-model extraction should remain small measured improvements, not prerequisites for shipping safety fixes.

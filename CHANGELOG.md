# Changelog

All notable changes to Home Rec will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Recover Recordings** — A new item in the menu-bar menu. If Home Rec was force-quit, crashed, or your Mac lost power mid-recording, the take is usually still on disk — but until now nothing told you that, and depending on the format it might not open when you double-clicked it. Home Rec now finds those interrupted recordings, shows you what it found with the size and time, and repairs them so they play. It only lists files it can prove were interrupted, never the recording you're making right now, and never touches a recording that finished normally. Repairs are written atomically, so an interruption during recovery leaves you with either the original or a working file — never a broken one. Recordings too short to have reached the disk are listed as such rather than promising a recovery that isn't possible. (BL-140)
- **FLAC recording** — A third format, alongside WAV and M4A. Like WAV it's lossless — no audio is discarded to make the file smaller — but the files are substantially smaller: measured around 0.6× the size of the equivalent WAV on speech- and music-like content, and far smaller on simple material. It also captures at 24-bit, where Home Rec's WAV files are 16-bit, so it preserves slightly more of the original signal. Pick it from the format selector. **One caveat worth knowing:** unlike WAV and M4A, a FLAC recording interrupted by a crash or force-quit cannot be played back, because the format only writes the information a player needs at the moment you press stop. If surviving an interruption matters more to you than file size, stay on WAV. (BL-013)
- **Choose which app to record** — Home Rec has always captured everything your Mac plays. The menu-bar menu now has a **Capture Source** section where you can pick a single running app instead, so recording a track out of Ableton no longer also catches a Slack ping or a browser tab. The list is limited to apps that actually have audio, so it stays short and readable instead of listing every window you have open — Home Rec asks the system which apps hold audio rather than guessing from what kind of app it looks like. Your choice is remembered between launches, and the status line names it — "Ready to record Ableton Live" — so you can see what you're about to capture without opening anything. If the app you picked isn't running, the menu says so and Home Rec tells you before you press record rather than after. The section is hidden while a recording is in progress, since the source can't change mid-take. (BL-100, BL-111)
- **Record from a microphone** — The Capture Source section also lists your input devices, so Home Rec can record a mic instead of what your Mac is playing — for voiceover, an interview, or a quick demo. Devices appear under the names macOS gives them, so a USB interface shows up as itself. Your choice is remembered, and if the device is unplugged the menu says so rather than quietly falling back to something else. macOS asks for microphone permission the first time you record from one; unlike Screen Recording, that prompt can be shown again if you decline. Recording a mic captures the mic only — mic and system audio together in one file is deliberately not supported in this release. (BL-130)

### Fixed
- **A recording can no longer be written in a format its own file header contradicts** — Home Rec has always assumed captured audio arrives at 48 kHz in stereo, and that held only because system-audio capture is pinned to exactly that. Nothing enforced it. Had audio ever arrived in another shape, it would have been written anyway: a mono input in a stereo-declared WAV plays back at half speed an octave down, and a 44.1 kHz input plays about 8.8% fast — in both cases a finished, ordinary-looking file that simply sounds wrong, with no error at any point. Captured audio is now converted to one canonical format before it reaches a file, and WAV and M4A refuse a buffer that still disagrees rather than writing it. FLAC already refused. System-audio recording is unaffected: it was already in the right format and is passed through untouched. This matters now because microphone input, which arrives in whatever format the device itself uses, is being built on top of it. (BL-112)
- **Failures caused by your capture source now say so** — If the app you picked had quit, or the microphone was unplugged, Home Rec said "make sure some audio is playing, then try again" and offered a **Try again** button. Neither could help: the app was still closed, the mic still unplugged, and retrying failed identically. Each cause now reports itself, and the retry button is gone where retrying cannot work.
- **Denied microphone access no longer leaves you stuck in a loop** — Declining the microphone prompt produced the same generic error and the same **Try again** button — but macOS does not re-ask once you have declined, so trying again failed instantly, forever. Home Rec now says microphone permission is missing and takes you to the Microphone pane in System Settings.
- **The welcome screen describes the app you actually have** — It still said Home Rec captures your Mac's output as a lossless WAV, which stopped being the whole story when per-app capture, microphone input and FLAC shipped. It also implied there was only one permission to grant. Both corrected.
- **The recording settings stay hidden for the whole of a take** — Save location, format and capture source are locked once you press record, and the settings row hides to show that. It was reappearing briefly while a recording was starting and stopping, offering changes that could no longer take effect for the take in progress. (BL-111)
- **An M4A write failure is no longer invisible until you press stop** — When the encoder refused a buffer, the refusal was discarded and recording continued as though nothing had happened; the problem surfaced only at the end, as a lost take with no indication of when or why it broke. A refused write is now reported when it happens. (BL-112)

---

## [1.0.2] - 2026-07-31

> A one-fix patch. M4A recordings interrupted by a crash, force-quit, or power
> loss were left completely unopenable — the whole take gone. WAV was never
> affected. If you record in M4A, this is worth updating for; nothing else in the
> app changes.

### Fixed
- **An M4A recording interrupted by a crash or force-quit is no longer lost** — WAV recordings have always survived an abrupt exit: the file's header is rewritten every fraction of a second, so whatever was captured stays playable. M4A never got the same treatment. Its index was written only when you pressed stop, so if Home Rec was force-quit or the Mac lost power mid-recording, the file left on disk was **completely unreadable** — not truncated, not partial, simply unopenable, with the entire take gone. M4A now flushes a recoverable checkpoint every second, so an interrupted recording plays back with everything up to the last second intact. Measured before and after: a mid-recording copy went from unreadable to recovering 1.97 s of a 2.9 s take. Files are roughly 6% larger as a result. WAV is unchanged, and recordings you stop normally are unaffected. (BL-016)
- **A recording that fails to save when you press stop now tells you** — If finalising the file failed, the error was discarded and Home Rec returned to idle as though the save had succeeded, leaving a corrupt or missing file with no indication anything was wrong. Pressing stop now surfaces such a failure as a visible error. (Recordings cut short by a capture failure still report the capture failure itself, which is the more useful diagnosis.) (BL-016)

---

## [1.0.1] - 2026-07-26

> A permission-funnel patch. Everything here is about the gap between downloading
> Home Rec and successfully granting it permission — the point where first-time
> users were silently getting stuck. No change to recording, formats, or output.
> The v1.1 feature wave (per-app capture, mic input, monitoring) is separate.

### Added
- **Permission granting that guides you and notices the grant** — Granting Screen Recording is a hard gate: until it's done, Home Rec can't record anything. Previously "Open System Settings" fired off a URL and left you there. Now the main window tells you **which section to look under**, and Home Rec watches for the grant while you're in System Settings — the moment you flip the toggle, the app is ready, no relaunch and no checking back required. An earlier iteration of this shipped the guidance as a separate floating panel; testing showed it duplicated the main window and stacked a third dialog on top of macOS's own prompt, so the window carries it alone. (BL-081, BL-088)
- **Menu-bar overflow menu** — Secondary actions (Show Window, Export Diagnostics, Report a Problem, About, Quit) moved out of the popover footer into a native menu, reachable from a "•••" button in the popover or by **right-clicking the menu bar icon**. The popover keeps its primary surface — record button, live waveform, last recording — with four flat buttons and a divider removed. Adds **About Home Rec**, which previously had no entry point. (BL-110)
- **Warning when Home Rec is running from the disk image** — Opening Home Rec by double-clicking it *on the mounted DMG*, rather than dragging it to Applications first, makes macOS run it from a randomised temporary path. Permission granted to that copy is tied to the throwaway path and silently disappears on the next launch — the one situation that genuinely looks like "the app isn't in the permission list". Home Rec now detects this, refuses to record rather than walking you into a grant that cannot survive, and shows only the move instruction — with a Reveal in Finder button — instead of the usual permission prompt and "grant permission" screen, which in that situation would send you down a path that silently fails. Running from anywhere else that isn't `/Applications` (a custom folder, `~/Applications`) is left alone apart from a dismissible note — that's a legitimate choice and permission works fine there. (BL-082a)

### Changed
- **The disk-image warning is stated once, where you're looking** — Opening Home Rec from the mounted DMG showed the same instruction twice at the same moment: in the main window and again in a floating panel beside it. One problem stated twice reads as two problems. The window now carries it alone; the floating panel appears only when there's no window to carry it (Home Rec running purely from the menu bar), so the app is never silently stuck with no explanation. The menu-bar popover, which previously offered a red "Start recording" button on an app that cannot record, now explains the block and offers Reveal in Finder instead. (BL-086)
- **Home Rec no longer asks macOS for permission when you haven't asked for anything** — Every permission check ran through an API that can raise the system permission dialog, and four of the five places it ran from had no user behind them: app launch, every window appearance, every time the app regained focus, and once a second while the guide was open. Launch now uses a silent check instead, window appearance doesn't check at all, and the focus re-check is skipped entirely once permission is granted — which is every launch for anyone already set up. The dialog now appears when you click Record or Open System Settings, and not otherwise. (BL-085)
- **"Open System Settings" now lands you on a list Home Rec is actually in** — An app only appears in Screen & System Audio Recording once it has asked macOS for the permission, and that list doesn't refresh while it's open. Home Rec was asking and opening the pane in the same instant, so on a fresh install the pane could render before the app had joined the list — leaving you to add it manually with the "+" button, which is exactly the problem the guide exists to prevent. It now completes the request before opening the pane. If permission turns out to already be granted, Settings isn't opened at all. (BL-087)
- **The permission dialog no longer appears at launch on a fresh install** — The focus re-check that notices when you've granted permission in System Settings was also firing on launch itself, so a newly installed, ungranted Home Rec could raise the system permission dialog before you'd clicked anything. It now waits until you've actually gone looking for the permission — clicked Record, or Open System Settings — and coming back still re-detects the grant exactly as before. (BL-085)
- **The grant is noticed even when Home Rec is hidden behind System Settings** — macOS throttles background apps whose windows are covered, which is exactly the situation while you're granting permission. Home Rec now tells the system it's doing something you asked for, so it keeps watching and the window is ready the moment you flip the toggle — no clicking back to wake it up. The opt-out is released as soon as the grant lands or the watch times out, so nothing is held in the background afterwards. (BL-088)
- **Grant detection is bounded** — Watching for the grant stops on its own after about ten minutes rather than probing indefinitely; returning to the app or clicking Open System Settings again resumes it naturally. (BL-085, BL-088)
- **Permission copy now says where to actually look** — macOS 15+ splits this permission into "Screen & System Audio Recording" and "System Audio Recording Only". Home Rec appears in the **first**, because it captures audio through ScreenCaptureKit. Our own reassurance — "only captures audio, not your screen" — was true and sent people to the second list, where the app isn't, making it look unlisted. The reassurance stays; a separate line now names the correct section *and* the one it's easy to confuse it with. (BL-081)
- **Permission checks no longer race each other** — Focus-change re-probes and the new guide polling could overlap, and the slower result won: a stale "denied" could land after a fresh "granted", leaving the app insisting permission was missing seconds after you granted it. Probes are now single-flighted, so overlapping callers share one result. (BL-081)

### Fixed
- **Removed a stray `Info.plist` shipped inside the app bundle** — `HomeRec/Info.plist` was never wired into the build (`INFOPLIST_FILE` was unset and `GENERATE_INFOPLIST_FILE` was on), so Xcode synthesised the real one and ignored it — but the file *was* still copied into `Contents/Resources/`, meaning every build including v1.0 shipped a second, inert plist that macOS never reads. Deleted, along with two keys it contained that never reached the product. Added `InfoPlistTests`, which assert against the **built product** rather than the repo — the distinction the defect turned on. (BL-084)
- **Guide polling could outlive the guide** — Closing the panel via its titlebar button bypassed the dismiss path, and the polling loop retained its own model, so the cleanup meant to stop it could never run. Both fixed; covered by tests. (BL-081)

### Internal
- **Capture callback unified on `AVAudioPCMBuffer`** — `AudioCapturing` now delivers `AVAudioPCMBuffer` instead of `CMSampleBuffer`, converted once at the ScreenCaptureKit boundary. Core Audio Taps deliver `AudioBufferList` and `AVAudioEngine` delivers `AVAudioPCMBuffer`, so unifying on one type now means later capture sources are an implementation swap rather than a protocol change. No behaviour change; golden-file test unchanged. (BL-099)
- **Per-application capture groundwork** — New `AudioSource` (`.systemAll` / `.app(bundleID:)`) and `AudioSourceManager`, which persists the choice, enumerates running apps, and validates a source before recording starts so an unrunnable app fails pre-flight with no partial file. `ScreenCaptureAudioManager` builds a per-process `SCContentFilter` when an app is selected. **No user-facing picker yet** — the menu UI and validation against real DAWs are still outstanding. The all-system-audio path is byte-for-byte unchanged. (BL-100)
- **`PermissionProviding` generalised** — Every method now takes a `PermissionKind` (defaulted, so existing call sites are untouched), and the Settings section names, deep-link anchor, and navigation copy live together on `PermissionKind` because they change as a unit. Microphone permission (BL-130) slots in without touching the seam again. (BL-081)

---

## [1.0.0] - 2026-06-04

> First public release. Signed, notarized `.dmg` at
> [releases/latest](https://github.com/melissa-pereira-deel/home-rec/releases/latest).

### Changed
- **Sentence-case button labels** — Main and menu-bar buttons now use sentence case ("Stop recording", "Start recording", "Choose folder…", "Keep recording", "Export diagnostics…", "Report a problem", "Show window", "Get started", "Open settings", "Try again") for a softer, less shouty feel. Proper nouns stay capitalized (Finder, Home Rec, System Settings, Desktop, OK).

### Added
- **GitHub Releases publishing workflow** — `scripts/build-dmg.sh` now outputs a **versionless** `HomeRec.dmg` so the GitHub `releases/latest/download/HomeRec.dmg` URL stays stable across releases (the version is visible inside the bundle and on the release page itself). The script also emits a `HomeRec.dmg.sha256` sidecar for download integrity verification, and replaces the misleading `spctl --type install` check with a `stapler validate` + mount/`spctl --type execute` round-trip (the real Gatekeeper check). New `docs/distribution/releasing.md` documents the per-release flow (`git tag → push → gh release create`). (BL-036)
- **Download CTA + correct system requirements on the website + README** — `home-rec-website.html` download buttons now link to `https://github.com/melissa-pereira-deel/home-rec/releases/latest/download/HomeRec.dmg`. `README.md` gets a top-level "Download (recommended)" section pointing at the same URL plus the `.sha256` sidecar and release notes. Also fixed: system requirements now correctly say "macOS 15 (Sequoia) or later" (was "macOS 12.3+" in three places — incorrect, the binary's `MACOSX_DEPLOYMENT_TARGET` is `15.0` and would refuse to launch on 12.3). README badge updated to `Version-1.0` and `Swift-6.0+`. (BL-037) — *the website HTML stays local per `.gitignore`; uploaded to the website host separately*
- **Privacy Policy + Terms of Use pages** — New `privacy.html` and `terms.html` next to the website. Privacy is a transparency-first plain-language statement (app makes no network calls, no telemetry, no analytics; only third parties are GitHub, Buy Me a Coffee, and the static host); terms cover the website, point at Apache 2.0 as the app's EULA, and surface a "you are responsible for local recording laws" clause. (BL-038, BL-039) — *files kept local per `.gitignore`*
- **Website footer attribution aligned with the signing identity** — `home-rec-website.html` footer now reads `© 2026 Melissa de Britto · published under the The Building Blocks Co. brand` (matches `LICENSE`/`NOTICE`/`Developer ID Application: Melissa Pereira`). "The Building Blocks Co." is consistently framed as a brand/imprint, not a separate legal entity. Privacy and Terms links added. (BL-095 Path A) — *file kept local per `.gitignore`*
- **Choose where recordings are saved** — Recordings no longer always go to the Desktop: a quiet "Saving to <Folder>" pop-up menu at the bottom of the main window (Choose Folder… / Reset to Desktop) sets the destination. The choice persists across launches. If the chosen folder is later missing or unwritable (e.g. an unplugged drive), Home Rec falls back to the Desktop, keeps your choice, and tells you — a recording is never lost. (BL-010)
- **Distribution: notarized `.dmg`** — `scripts/build-dmg.sh` runs end-to-end and produces a Gatekeeper-accepted, notarized `Home Rec X.Y.Z.dmg` (universal x86_64 + arm64, Hardened Runtime, signed with `Developer ID Application: Melissa Pereira (S3J47F2UXA)`, stapled notarization tickets on both the `.app` and the `.dmg`). Real-run hardening landed in the script: force macOS destination on the multi-platform target, strip iCloud `com.apple.FinderInfo` xattrs after export, derive the DMG filename from `MARKETING_VERSION`, set the volume icon. `docs/distribution/build.md` and `notarization.md` document Release settings and one-time Keychain/notarytool setup. No secrets are committed; `dist/` is git-ignored. (BL-030, BL-031, BL-032, BL-033)
- **CI pipeline** — A GitHub Actions workflow (`.github/workflows/ci.yml`) runs the unit-test suite under Thread Sanitizer on every push to `main` and on PRs (UI tests excluded — they need TCC permission). Requires a one-time check that the runner's Xcode matches the project SDK and that the signing approach lets the test host launch. (BL-050)
- **First-run onboarding** — A one-screen welcome sheet on first launch explains what Home Rec does and why it needs Screen Recording permission (audio only, never the screen), with an "Open Settings" button and a live "you're ready" confirmation once permission is granted (re-detected automatically). Shown once (persisted) and re-openable from the Help menu. (BL-041)
- **Disk-space + long-recording guardrails** — Home Rec now refuses to start a recording when the destination volume has less than ~100 MB free (showing a clear message instead of producing a doomed file), and warns once a single recording passes 30 minutes (offering to stop), since WAV uses ~10 MB/min. The menu bar icon already indicates an active recording at all times. (BL-043)
- **Diagnostics export + "Report a Problem"** — A menu-bar action gathers recent `os.Logger` entries (via `OSLogStore`) plus app/macOS version into a shareable text file (saved via a save panel), and "Report a Problem" opens a prefilled GitHub issue with version info — replacing the old hunt-for-a-Desktop-log workflow. (BL-042)
- **Human-readable errors with recovery actions** — Error states now show plain-language messages (no raw system error strings) plus a concrete next step where one exists: stream failures offer "Open Settings", start failures offer "Try Again". Shown in the main window alert and inline in the menu bar popover. Technical detail is retained for logs/diagnostics only. (BL-044)
- **Live permission re-detection** — The app now re-probes Screen Recording permission whenever it regains focus (`NSApplication.didBecomeActiveNotification`), so granting permission in System Settings takes effect immediately — no quit-and-relaunch. Previously the #1 first-run failure: users granted permission, returned, clicked Record, and nothing happened. (BL-040)
- **Stream-failure detection & recovery** — When the capture stream stops unexpectedly (permission revoked, display sleep, another capturer), the failure now propagates from `ScreenCaptureAudioManager` → `RecordingController` → `RecorderViewModel`, which transitions to `.error` and **finalizes the partial WAV** so audio captured before the failure is preserved and playable. Previously the UI kept showing "Recording" while nothing was written. (BL-020)
- **`RecordingState` state machine** — A single source of truth for the recording lifecycle (`idle`/`starting`/`recording`/`stopping`/`error`/`recovering`), owned by `RecorderViewModel`. Illegal transitions (e.g. `idle → stopping`) are rejected by `canTransition(to:)`, making "UI shows recording while nothing is written" unrepresentable. (BL-006)
- **Unit tests** — `RecordingStateTests` (transition matrix), `WAVWriterTests` (data integrity + crash-safe header), `AudioRecorderTests` (no-drops + 20× cycles under Thread Sanitizer), `StreamFailureTests`, and `RecorderViewModelTests` (lifecycle, permission gating, error handling, clock-driven duration, stream-failure). 30 tests, no hardware, deterministic (no sleeps), TSan-clean. (BL-006, BL-004, BL-024, BL-020, BL-022, BL-005)

### Fixed
- **App name now shows as "Home Rec"** — The Dock tile, macOS app menu, and About read **"Home Rec"** via `CFBundleDisplayName` (`INFOPLIST_KEY_CFBundleDisplayName`; the pre-existing `PRODUCT_BUNDLE_DISPLAY_NAME` was a no-op — not a real build setting). The Finder/Desktop **file label** follows the bundle's filename, so the distributed app ships as **`Home Rec.app`** (renamed from the build product at packaging time in `scripts/build-dmg.sh`). The Xcode target/scheme and bundle identifier (`com.mdebritto.HomeRec`) stay "HomeRec" — so the test host (`TEST_HOST` references `HomeRec.app`) and tests are unaffected. (BL-070)
- **Audio-state data races** — All access to the WAV writer is now confined to `AudioRecorder`'s serial processing queue: buffers are handed off without reading writer state on the capture thread, start/stop assign the writer on the queue, and stop runs after all in-flight buffers (FIFO) so no trailing audio is dropped and the writer is finalized exactly once. Verified Thread-Sanitizer-clean across a record/stop cycle and a 20× start/stop loop. (BL-024)
- **Crash/force-quit could leave an unreadable recording** — `WAVWriter` now rewrites the header in place every ~32 buffers (~0.7s), so a file killed mid-recording still has a valid, non-zero data size and plays back. `finalize()` continues to write the authoritative header on a clean stop. (BL-022)
- **Dependency-injection seams** — Introduced protocols `AudioCapturing`, `AudioFileWriting`, `RecordingControlling`, and `PermissionProviding`, plus a `DurationClock` abstraction (with `SystemDurationClock`). The core recording types and the view model now accept these via initializers (defaulting to the real implementations), so the workflow can be exercised with mocks and a fake clock — no audio hardware or Screen Recording permission required. (BL-003)

### Changed
- **Audio hot path decomposed into testable units** — extracted `AudioSampleConverter` (CMSampleBuffer→PCM, incl. de-interleave) and `WaveformDownsampler` from the monolithic `AudioRecorder.processSampleBuffer`, which is now a thin orchestrator. Behavior is byte-identical, guarded by a new golden-file test (interleaved + non-interleaved inputs produce the same WAV bytes). Sets up the format-export (BL-011) and vectorization (BL-060) work. (BL-007, BL-051)
- **Larger app logo in the main window** — bumped from 64×64 to 84×84 pt for better visual balance.
- **Logging moved to `os.Logger`** — Replaced the file-based `DebugLogger`, `NSLog`, and `print` diagnostics with the unified logging system under subsystem `com.mdebritto.homerec` (categories: `capture`, `recorder`, `file`, `permission`). Lifecycle events are logged at `.debug`/`.info`; failures at `.error` so they remain diagnosable from a shipped build via Console.app. (BL-001)
- **No logging on the audio hot path** — Removed all logging from `AudioRecorder.processSampleBuffer` and the ScreenCaptureKit output callback, which ran per audio buffer (~47×/sec) on the capture thread and risked the very dropouts the app exists to prevent.
- **`PermissionManager` is now instance-based** — Converted its static methods to instance methods conforming to `PermissionProviding` (no behavior change). (BL-003)
- **Duration timer uses an injected clock** — `RecorderViewModel` drives the duration display through `DurationClock` instead of a hard-wired `Timer`, enabling deterministic time in tests. (BL-003)
- **View model drives the state machine** — `RecorderViewModel.isRecording` is now derived from `state` (no longer a stored flag); start/stop/error are explicit transitions, and `statusText` reflects every state. (BL-006)
- **`AudioRecorder` no longer keeps a standalone `isRecording` flag** — its recording status is derived from whether a file writer is active, removing one of the duplicated booleans that could desync. (BL-006)
- **`WAVWriterError` is now `Equatable`** — enables precise error-path assertions in tests (no behavior change). (BL-004)

### Removed
- **`DebugLogger`** — Retired entirely. It opened/seeked/wrote/closed a `FileHandle` plus a synchronous `print()` on every call and dumped `~/Desktop/AudioRecorderDebug.log` in all builds, leaking absolute paths and cluttering the user's Desktop.

### Files Modified
| File | Change |
|------|--------|
| `Log.swift` | New — `os.Logger` definitions for the four subsystem categories |
| `DebugLogger.swift` | Deleted |
| `AudioRecorder.swift` | Removed all logging from `processSampleBuffer`/`processAudioSample`; lifecycle log on start; `import os` |
| `ScreenCaptureAudioManager.swift` | Removed per-buffer logging from the output callback; lifecycle/error logs via `Log.capture`; `import os` |
| `RecordingController.swift` | Replaced step-by-step logs with concise lifecycle logs; removed per-sample log in capture callback; `import os` |
| `RecorderViewModel.swift` | Replaced `DebugLogger` with `Log.recorder` error logging; `import os`; inject `RecordingControlling`/`PermissionProviding`/`DurationClock`; removed `Timer` and `deinit` |
| `HomeRecApp.swift` | Dropped app-launch test log; font-registration failures now log via `os.Logger`; `import os` |
| `AudioCapturing.swift`, `AudioFileWriting.swift`, `RecordingControlling.swift`, `PermissionProviding.swift`, `Clock.swift` | New — DI protocols + `SystemDurationClock` (BL-003) |
| `PermissionManager.swift` | Static methods → instance methods conforming to `PermissionProviding` (BL-003) |
| `RecordingController.swift` | Conforms to `RecordingControlling`; injects `AudioCapturing`/`AudioFileWriting` (BL-003) |
| `AudioRecorder.swift` | Conforms to `AudioFileWriting`; removed redundant `deinit` (BL-003); dropped standalone `isRecording` flag, derive from writer (BL-006); confined writer access to the serial queue (BL-024) |
| `ScreenCaptureAudioManager.swift` | Conforms to `AudioCapturing` (BL-003); publishes `onStreamError` on `didStopWithError` (BL-020) |
| `RecordingState.swift` | New — `RecordingState` + `RecorderError` (+ `streamFailed`, BL-020; plain `message`/`detail`/`recovery` + `RecoverySuggestion`, BL-044) + transition rules (BL-006) |
| `RecorderView.swift`, `MenuBarPopoverView.swift` | Error alert/inline error use recovery actions (BL-044) |
| `Diagnostics.swift` | New — diagnostics report (OSLogStore) + export panel + Report-a-Problem URL (BL-042) |
| `DiskSpace.swift` | New — free-space threshold + long-recording threshold (BL-043) |
| `RecordingController.swift` | `RecordingControllerError.insufficientDiskSpace`; free-space precheck on start (BL-043) |
| `RecorderView.swift` | Long-recording warning alert (BL-043); onboarding sheet (BL-041) |
| `OnboardingView.swift` | New — first-run welcome sheet (BL-041) |
| `RecorderViewModel.swift` | Onboarding state via injected `UserDefaults`; `completeOnboarding`/`showOnboardingAgain` (BL-041) |
| `HomeRecApp.swift` | Help menu "Welcome to Home Rec" command (BL-041) |
| `.github/workflows/ci.yml` | New — GitHub Actions unit tests under TSan (BL-050) |
| `MenuBarPopoverView.swift` | Help row: Export Diagnostics… / Report a Problem (BL-042) |
| `RecorderViewModel.swift` | Owns `RecordingState`; transitions + state-derived `isRecording`/`statusText` (BL-006); `handleStreamFailure` wiring (BL-020); re-probes permission on app activation (BL-040); save-location display/picker/reset + fallback notice (BL-010) |
| `SaveLocationProviding.swift` | New — `SaveLocationManager` (UserDefaults-persisted path, Desktop fallback) (BL-010) |
| `RecordingController.swift` | `generateFilePath()` uses the resolved save directory, collision-safe (BL-010) |
| `MenuBarController.swift` | Observes `$state` (mapped to recording) instead of `$isRecording` (BL-006) |
| `WAVWriter.swift` | `WAVWriterError` made `Equatable` (BL-004); periodic in-place header rewrite for crash safety (BL-022) |
| `AudioCapturing.swift`, `RecordingControlling.swift` | Added `onStreamError`; `RecordingControlling.finalizeAfterFailure()` (BL-020) |
| `RecordingController.swift` | Forwards capture `onStreamError`; `finalizeAfterFailure()` preserves partial WAV (BL-020) |
| `HomeRecTests/RecordingStateTests.swift`, `WAVWriterTests.swift`, `AudioRecorderTests.swift`, `StreamFailureTests.swift`, `RecorderViewModelTests.swift`, `Mocks.swift` | New — Swift Testing suites + test doubles (BL-006, BL-004, BL-024, BL-020, BL-022, BL-005) |

---

## [0.3.2] - 2026-03-01 - Screen Recording Permission Fix

### Changed
- **Permission check uses SCShareableContent** — Replaced deprecated `CGPreflightScreenCaptureAccess()` with an `SCShareableContent` probe that both checks permission status and registers the app in System Settings > Screen Recording
- **Permission request uses SCShareableContent** — Replaced `CGRequestScreenCaptureAccess()` with the same probe; on denial, opens System Settings directly (the app now reliably appears in the permission list)
- **Async permission flow** — `PermissionManager.checkPermission()` is now `async`; `RecorderViewModel` and `RecorderView` updated accordingly

### Fixed
- **App not appearing in Screen Recording list** — When built from Xcode (DerivedData path), the old `CGRequestScreenCaptureAccess()` did not always register the app. The `SCShareableContent` probe reliably registers the app on first launch.

### Removed
- `CGPreflightScreenCaptureAccess` usage (deprecated since macOS 15.1)
- `CGRequestScreenCaptureAccess` usage
- `PermissionManager.registerAndOpenSettings()` (superseded by SCShareableContent probe at launch)

### Files Modified
| File | Change |
|------|--------|
| `PermissionManager.swift` | Replaced CG-based APIs with `SCShareableContent` probe; `checkPermission()` now async; removed `registerAndOpenSettings()` |
| `RecorderViewModel.swift` | `checkPermission()` now async; `init()` wraps call in `Task`; `openSystemSettings()` calls `openSystemPreferences()` directly |
| `RecorderView.swift` | `.onAppear` wraps `checkPermission()` in `Task` |

---

## [0.3.1] - 2026-02-22 - Build Fixes & Permission UX

### Fixed
- **Main actor isolation error** — Added `@MainActor` to `MenuBarController` to fix compiler error when accessing `$isRecording` from `RecorderViewModel`
- **Swift 6 deinit warning** — Refactored `RecordingController.deinit` to capture managers as local variables, avoiding `self` capture in a closure that outlives deinitialization
- **Deployment target warning** — Lowered `MACOSX_DEPLOYMENT_TARGET` from 26.1 to 15.0 across all targets (within Xcode's supported range of 10.13–15.5.99)

### Improved
- **Permission registration on first click** — "Open System Settings" button now calls `CGRequestScreenCaptureAccess()` before opening Settings, so the app appears in the Screen Recording permission list immediately — no need to attempt a recording first
- **Installation guide** — Added Prerequisites section to README with Apple Developer account requirement and step-by-step Xcode code signing instructions for less technical users

### Files Modified
| File | Change |
|------|--------|
| `MenuBarController.swift` | Added `@MainActor` annotation |
| `RecordingController.swift` | Refactored `deinit` to avoid capturing `self` |
| `PermissionManager.swift` | Added `registerAndOpenSettings()` method |
| `RecorderViewModel.swift` | Updated `openSystemSettings()` to use new registration method; removed unused computed properties |
| `RecorderView.swift` | Updated main button to show icon only for Start/Stop states |
| `project.pbxproj` | `MACOSX_DEPLOYMENT_TARGET` 26.1 → 15.0 (6 occurrences) |
| `README.md` | Added Prerequisites and code signing setup to Installation |

---

## [0.3.0] - 2026-02-21 - Menu Bar Integration

### Added
- **Menu Bar Icon** — Persistent `NSStatusItem` in the macOS menu bar with SF Symbol icons (`waveform` idle, `record.circle.fill` red when recording)
- **Menu Bar Popover** — Compact 280pt-wide popover UI accessible from the menu bar icon, featuring:
  - Status row with recording indicator dot, status text, and duration
  - Mini waveform visualization (36pt height, reuses `WaveformView`)
  - Full-width Record/Stop button
  - Last recording filename with "Reveal" in Finder shortcut
  - "Show Window" and "Quit" footer actions
- **App stays alive on window close** — Closing the main window no longer quits the app; the menu bar icon persists for background recording
- **Shared ViewModel** — Both the main window and menu bar popover share a single `RecorderViewModel`; recording from either surface updates both instantly

### Changed
- **ViewModel ownership lifted to App level** — `RecorderViewModel` is now created as `@StateObject` in `SystemAudioRecorderApp` and passed via `.environmentObject()` instead of being owned by `RecorderView`
- **RecorderView uses `@EnvironmentObject`** — Switched from `@StateObject` to `@EnvironmentObject` for shared state

### Technical Details
- `AppDelegate` returns `false` from `applicationShouldTerminateAfterLastWindowClosed` to keep the app alive
- `MenuBarController` uses Combine to observe `isRecording` and swap the status bar icon between idle (template) and recording (red, non-template)
- `NSPopover` with `.transient` behavior dismisses on outside click
- New files auto-discovered by Xcode via `PBXFileSystemSynchronizedRootGroup` — no pbxproj edits needed

### Files Created
| File | Purpose |
|------|---------|
| `AppDelegate.swift` | Keeps app alive on window close, holds MenuBarController |
| `MenuBarController.swift` | NSStatusItem + NSPopover + icon state via Combine |
| `MenuBarPopoverView.swift` | Compact SwiftUI popover with waveform, controls, actions |

### Files Modified
| File | Change |
|------|--------|
| `SystemAudioRecorderApp.swift` | Added `@NSApplicationDelegateAdaptor`, `@StateObject` viewModel, `.environmentObject()`, MenuBarController wiring |
| `RecorderView.swift` | `@StateObject` → `@EnvironmentObject` |

---

## [0.2.0] - 2026-02-21 - Live Waveform & UI Polish

### Added
- **Live Waveform Visualization** — Real-time oscilloscope-style waveform displayed during recording, driven by downsampled amplitude data from the audio capture pipeline
- **WaveformView.swift** — New SwiftUI `Shape` that renders audio amplitude as an animated line path
- **Waveform data pipeline** — `AudioRecorder` extracts ~200 amplitude samples per buffer, averaged across channels, dispatched through `RecordingController` to the view model

### Changed
- **App logo replaces title** — The app icon image now appears in the main window where the "Home Rec" text used to be
- **Record button is always red** — Previously toggled between blue (idle) and red (recording); now consistently red for brand identity
- **Window height increased** — From 400pt to 450pt to accommodate the waveform display

### Improved
- **Project structure reorganized** — Documentation moved from 14 loose files in root to organized `docs/` subdirectories:
  - `docs/debug-reports/` — Investigation and debug reports
  - `docs/project-management/` — Action plans, completed tasks, roadmap
  - `docs/research/` — Feasibility studies, specs, implementation guides
- **README updated** for open-source readiness with contributing guidelines, license placeholder, and accurate project structure

### Technical Details
- Waveform extraction runs on the existing background processing queue — no new threads
- Amplitude data is downsampled (every Nth sample) and mono-averaged before dispatch to main queue
- `WaveformView` conforms to `Shape` with `animatableData` for smooth SwiftUI transitions
- No impact on existing WAV recording functionality

### Files Modified
| File | Change |
|------|--------|
| `AudioRecorder.swift` | Added `onWaveformData` callback + amplitude extraction |
| `RecordingController.swift` | Wired waveform callback through |
| `RecorderViewModel.swift` | Added `@Published waveformSamples` |
| `RecorderView.swift` | App logo, waveform display, red button, taller window |

### Files Created
| File | Purpose |
|------|---------|
| `WaveformView.swift` | SwiftUI Shape for waveform line rendering |

---

## [0.1.0] - 2026-01-11 - MVP Release

### 🎉 Initial Release
First working version of SystemAudioRecorder - successfully captures and records system audio to WAV files.

### ✅ Features Implemented
- **System Audio Capture** - Records audio from any application using ScreenCaptureKit
- **WAV File Export** - Saves recordings as 48kHz stereo PCM WAV files
- **SwiftUI Interface** - Clean, minimal UI with Start/Stop controls
- **Permission Management** - Automatic Screen Recording permission handling
- **Live Duration Display** - Real-time recording timer with MM:SS format
- **Automatic File Naming** - Timestamp-based filenames (recording_YYYY-MM-DD_HH-MM-SS.wav)
- **Desktop Integration** - One-click "Reveal in Finder" button
- **Status Indicators** - Visual recording status with pulsing red dot animation

### 🔧 Technical Implementation

#### Architecture
- **ScreenCaptureKit API** - Modern macOS 12.3+ system audio capture
- **SwiftUI** - Native macOS UI framework
- **Async/Await** - Modern Swift concurrency for stream management
- **CMSampleBuffer Processing** - Direct Core Media buffer handling
- **Background Queue Processing** - Non-blocking audio data conversion

#### Core Components Created
1. `PermissionManager.swift` - TCC permission handling
2. `ScreenCaptureAudioManager.swift` - SCStream lifecycle management
3. `AudioRecorder.swift` - CMSampleBuffer to PCM conversion
4. `WAVWriter.swift` - WAV file format writing with proper headers
5. `RecordingController.swift` - Orchestrates the recording workflow
6. `RecorderViewModel.swift` - SwiftUI state management (@MainActor)
7. `RecorderView.swift` - Main UI with StatusBar component
8. `DebugLogger.swift` - File-based debug logging utility

### 🐛 Critical Bugs Fixed

#### Bug #1: Permission Reset After Every Rebuild
- **Symptom:** Screen Recording permission lost on each app rebuild
- **Root Cause:** Debug configuration using ad-hoc code signing
- **Fix:** Updated project.pbxproj to use Apple Development certificate
- **Impact:** Permission now persists across rebuilds (stable Team ID)
- **Files Modified:** `SystemAudioRecorder.xcodeproj/project.pbxproj` (lines 391, 527)

#### Bug #2: Audio Buffer List Error -12737
- **Symptom:** Files created but remained 44 bytes (header only, no audio data)
- **Root Cause:** `AudioBufferList` size mismatch - used fixed size instead of querying required size
- **Error Code:** kAudio_ParamError (-12737)
- **Fix:** Two-step process:
  1. Query required buffer size via `CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer`
  2. Allocate exact size using `UnsafeMutableRawPointer.allocate()`
- **Impact:** Audio samples now successfully extracted and written to WAV
- **Files Modified:** `AudioRecorder.swift` (lines 183-230)

#### Bug #3: ScreenCaptureKit Stream Failed to Start
- **Symptom:** "Start stream failed" error despite correct audio configuration
- **Root Cause:** ScreenCaptureKit requires BOTH video and audio output handlers
- **Fix:** Added screen output handler with minimal 100x100 video config (ignored)
- **Impact:** Stream now starts successfully and captures audio
- **Files Modified:** `ScreenCaptureAudioManager.swift` (lines 103-118)

#### Bug #4: App Sandbox Blocking File Creation
- **Symptom:** "Failed to create WAV file" error
- **Root Cause:** App Sandbox enabled, blocking Desktop writes
- **Fix:** Disabled App Sandbox in project settings
- **Impact:** Files now successfully created on Desktop
- **Files Modified:** `SystemAudioRecorder.xcodeproj/project.pbxproj`

### 📊 Debug Infrastructure
- Added comprehensive DebugLogger utility writing to `~/Desktop/AudioRecorderDebug.log`
- Traces execution through entire recording pipeline
- Logs CMSampleBuffer processing steps for troubleshooting
- Essential for diagnosing the -12737 error

### ⚙️ Configuration Changes
- **Code Signing:** Apple Development (was: ad-hoc)
- **Team ID:** Stable (Apple Development certificate)
- **App Sandbox:** Disabled (for Desktop file access)
- **Deployment Target:** macOS 12.3+ (ScreenCaptureKit requirement)
- **Audio Format:** 48kHz, 2 channels, PCM 16-bit

### 📝 Known Limitations
1. No user choice for save location (always Desktop)
2. No audio format options (48kHz stereo only)
3. No recording duration limit
4. ~~No audio level monitoring/visualization~~ (resolved in v0.2.0)
5. No error recovery if stream fails mid-recording
6. Debug logging always enabled (performance impact)
7. No unit or integration tests

### 🚀 Performance
- **Memory:** ~90MB during recording (needs profiling)
- **CPU:** Low usage on background queue (needs measurement)
- **Audio Quality:** Lossless PCM capture at 48kHz/16-bit
- **Dropouts:** None observed in testing (needs extended testing)

### 📦 Dependencies
- macOS 12.3+ (ScreenCaptureKit)
- Swift 5.9+
- Xcode 15+
- Screen Recording permission (TCC)

### 🔐 Permissions Required
- **Screen Recording** - Required for ScreenCaptureKit audio capture
- Automatically requested on first run
- Can be manually enabled in System Settings > Privacy & Security > Screen Recording

### 📁 File Structure
```
SystemAudioRecorder/
├── SystemAudioRecorder/
│   ├── AudioRecorder.swift
│   ├── AudioTapManager.swift (unused legacy)
│   ├── ContentView.swift (unused)
│   ├── DebugLogger.swift
│   ├── PermissionManager.swift
│   ├── RecorderView.swift
│   ├── RecorderViewModel.swift
│   ├── RecordingController.swift
│   ├── ScreenCaptureAudioManager.swift
│   ├── SystemAudioRecorderApp.swift
│   └── WAVWriter.swift
├── SystemAudioRecorderTests/
└── SystemAudioRecorderUITests/
```

### 🎯 MVP Success Criteria Met
- ✅ Record system audio from any application
- ✅ Save as WAV file on Desktop
- ✅ Automatic timestamp-based filenames
- ✅ Start/Stop controls functional
- ✅ Duration display updates in real-time
- ✅ Files play correctly in Music app
- ✅ Permission handling works
- ⏳ Zero audio dropouts (needs extended testing)
- ⏳ Performance metrics (needs profiling)

### 🔄 Migration Notes
- No previous version to migrate from
- Fresh installation only

### 👥 Contributors
- Development: Melissa de Britto
- AI Assistant: Claude (Anthropic)

---

## Upcoming
- Custom save location picker
- Multiple audio format support (MP3, M4A, FLAC)
- Error recovery for stream failures
- Conditional debug logging

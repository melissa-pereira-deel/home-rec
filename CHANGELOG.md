# Changelog

All notable changes to Home Rec will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

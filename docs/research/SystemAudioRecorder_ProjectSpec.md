# System Audio Recorder - Complete Project Specification
## MVP: Record System Audio to WAV File

---

## 📋 Table of Contents
1. [Project Overview](#project-overview)
2. [Product Vision & Goals](#product-vision)
3. [MVP Scope](#mvp-scope)
4. [Architecture](#architecture)
5. [User Stories & Use Cases](#user-stories)
6. [Technical Requirements](#technical-requirements)
7. [Development Phases](#development-phases)
8. [Testing Strategy](#testing-strategy)
9. [Acceptance Criteria](#acceptance-criteria)
10. [Claude Code Development Guide](#claude-code-guide)

---

## 1. Project Overview {#project-overview}

### What We're Building

**System Audio Recorder** is a native macOS application that captures audio output from the system (any application playing audio) and saves it as high-quality WAV files locally on the user's Mac Studio.

### Target Platform
- **OS:** macOS 14.2+ (Sonoma or later)
- **Hardware:** Mac Studio (Apple Silicon M1/M2)
- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (with CLI fallback option)

### Key Features (MVP)
1. ✅ Capture system audio output in real-time
2. ✅ Save recordings as uncompressed WAV files
3. ✅ Simple start/stop controls
4. ✅ Visual feedback (recording status, duration)
5. ✅ Automatic file naming with timestamps
6. ✅ Permission handling

### Non-Goals (Future Versions)
- ❌ MP3 encoding (V2)
- ❌ Per-application audio capture (V2)
- ❌ Audio effects/processing (V2)
- ❌ Scheduled recording (V2)
- ❌ Cloud upload (V2)

---

## 2. Product Vision & Goals {#product-vision}

### Problem Statement
"I want to capture high-quality audio from my Mac's system output without complex setup, third-party drivers, or quality loss."

### Solution
A simple, native macOS app that:
- Uses Apple's official Core Audio Taps API (no external drivers)
- Records lossless audio (WAV format)
- Works with one click
- Saves files locally with zero hassle

### Success Metrics (MVP)
1. **Technical:** Successfully record 5-minute audio file with zero dropouts
2. **Performance:** < 5% CPU usage during recording
3. **Usability:** User can start recording within 3 clicks
4. **Reliability:** 100% success rate with proper permissions

### User Profile
- **Primary User:** The developer - Tech-savvy developer
- **Use Case:** Recording system audio output for personal use
- **Technical Skill:** High - comfortable with terminal, permissions, etc.
- **Environment:** Mac Studio, macOS Sonoma, local development

---

## 3. MVP Scope {#mvp-scope}

### In Scope (Must Have) ✅

#### Functional Requirements
1. **Audio Capture**
   - Capture all system audio output
   - Support 44.1kHz and 48kHz sample rates
   - Stereo recording
   - Real-time capture with < 100ms latency

2. **File Management**
   - Save as WAV (PCM 16-bit)
   - Auto-generate filenames: `recording_YYYY-MM-DD_HH-MM-SS.wav`
   - Save to user-selected directory (default: Desktop)
   - Show file location after recording

3. **User Interface**
   - Start/Stop recording button
   - Recording duration display (MM:SS)
   - Recording status indicator (red dot when active)
   - Permission status check
   - Error messages (user-friendly)

4. **Permissions**
   - Request Screen Recording permission (required for Core Audio Taps)
   - Clear explanation of why permission is needed
   - Link to System Settings if denied

#### Non-Functional Requirements
1. **Performance**
   - CPU usage: < 5% during recording
   - Memory usage: < 50 MB
   - No audio dropouts or glitches
   - File I/O should not block audio thread

2. **Reliability**
   - Gracefully handle permission denial
   - Recover from disk full errors
   - Clean shutdown (no orphaned files)
   - Log errors for debugging

3. **Usability**
   - Launch time: < 2 seconds
   - Clear visual feedback at all times
   - Minimal configuration required
   - Keyboard shortcut for start/stop (⌘R)

### Out of Scope (Future) ⏭️

- MP3/AAC encoding
- Audio level meters
- Per-app recording selection
- Audio trimming/editing
- Metadata tagging
- Scheduled recording
- Background recording (menu bar app)
- Preferences panel
- Multiple simultaneous recordings

---

## 4. Architecture {#architecture}

### 4.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    macOS System                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │       Audio Sources                              │   │
│  │  (any app producing audio output)                │   │
│  └─────────────────────────────────────────────────┘   │
│                        │                                 │
│                        ▼                                 │
│  ┌─────────────────────────────────────────────────┐   │
│  │       Core Audio HAL                             │   │
│  │  (Hardware Abstraction Layer)                   │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│           System Audio Recorder App                     │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │              Frontend (UI Layer)                  │  │
│  │                                                   │  │
│  │  ┌────────────────────────────────────────────┐ │  │
│  │  │         SwiftUI Views                      │ │  │
│  │  │  - RecorderView (main UI)                  │ │  │
│  │  │  - StatusBar (duration, indicator)         │ │  │
│  │  │  - ErrorAlert (error display)              │ │  │
│  │  └────────────────────────────────────────────┘ │  │
│  │                    │                              │  │
│  │                    ▼                              │  │
│  │  ┌────────────────────────────────────────────┐ │  │
│  │  │       RecorderViewModel                    │ │  │
│  │  │  - UI state management                     │ │  │
│  │  │  - User interaction handling               │ │  │
│  │  │  - File path management                    │ │  │
│  │  └────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────┘  │
│                        │                                 │
│                        ▼                                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │         Business Logic Layer                      │  │
│  │                                                   │  │
│  │  ┌────────────────────────────────────────────┐ │  │
│  │  │      RecordingController                   │ │  │
│  │  │  - Orchestrate recording lifecycle         │ │  │
│  │  │  - Coordinate between components           │ │  │
│  │  └────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────┘  │
│                        │                                 │
│                        ▼                                 │
│  ┌──────────────────────────────────────────────────┐  │
│  │         Core Audio Integration Layer              │  │
│  │                                                   │  │
│  │  ┌────────────────────────────────────────────┐ │  │
│  │  │      PermissionManager                     │ │  │
│  │  │  - Check/request permissions               │ │  │
│  │  └────────────────────────────────────────────┘ │  │
│  │                                                   │  │
│  │  ┌────────────────────────────────────────────┐ │  │
│  │  │      AudioTapManager                       │ │  │
│  │  │  - Create Core Audio Tap                   │ │  │
│  │  │  - Create Aggregate Device                 │ │  │
│  │  │  - Manage tap lifecycle                    │ │  │
│  │  └────────────────────────────────────────────┘ │  │
│  │                                                   │  │
│  │  ┌────────────────────────────────────────────┐ │  │
│  │  │      AudioRecorder                         │ │  │
│  │  │  - Set up IO callback                      │ │  │
│  │  │  - Receive audio buffers (RT thread)       │ │  │
│  │  │  - Buffer management                       │ │  │
│  │  └────────────────────────────────────────────┘ │  │
│  │                                                   │  │
│  │  ┌────────────────────────────────────────────┐ │  │
│  │  │      WAVWriter                             │ │  │
│  │  │  - Create WAV file                         │ │  │
│  │  │  - Write audio buffers to disk             │ │  │
│  │  │  - Finalize WAV header                     │ │  │
│  │  └────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
                ┌──────────────┐
                │  WAV Files   │
                │  (Desktop)   │
                └──────────────┘
```

### 4.2 Frontend Layer (SwiftUI)

#### Components

**RecorderView (Main Window)**
```swift
// Purpose: Main app window
// Responsibilities:
//   - Display recording controls
//   - Show recording status
//   - Display duration
//   - Handle user input
// State: Observes RecorderViewModel
```

**StatusBar**
```swift
// Purpose: Show current recording state
// Elements:
//   - Red dot indicator (pulsing when recording)
//   - Duration label (00:00 format)
//   - Status text ("Ready" / "Recording" / "Error")
```

**ControlButtons**
```swift
// Purpose: Start/Stop controls
// Elements:
//   - Primary button: Start/Stop (toggles)
//   - Secondary button: Reveal in Finder (after recording)
// Behavior:
//   - Disabled when permission denied
//   - Color changes: Blue → Red when recording
```

**ErrorAlert**
```swift
// Purpose: Display errors to user
// Triggered by:
//   - Permission denied
//   - Disk full
//   - Invalid audio format
//   - File creation failure
// Actions:
//   - Show error message
//   - Offer recovery suggestion
//   - Link to System Settings (if permission issue)
```

#### View Hierarchy

```
App
 └── MainWindow
      └── RecorderView
           ├── StatusBar
           │    ├── RecordingIndicator
           │    ├── DurationLabel
           │    └── StatusText
           ├── ControlButtons
           │    ├── StartStopButton
           │    └── RevealButton
           └── ErrorAlert (conditional)
```

### 4.3 Backend Layer (Core Audio Integration)

#### Core Components

**1. PermissionManager**
```swift
// Purpose: Handle macOS permissions
// Responsibilities:
//   - Check Screen Recording permission status
//   - Request permission if needed
//   - Open System Settings if denied
// API:
//   - static func checkPermission() -> PermissionStatus
//   - static func requestPermission() async -> Bool
//   - static func openSystemPreferences()
```

**2. AudioTapManager**
```swift
// Purpose: Manage Core Audio Tap lifecycle
// Responsibilities:
//   - Create system-wide audio tap
//   - Create aggregate device
//   - Extract tap UUID
//   - Clean up resources
// State:
//   - tapDescription: Unmanaged<CATapDescription>?
//   - tapID: AudioObjectID
//   - aggregateDeviceID: AudioDeviceID
// API:
//   - func setupSystemTap() throws
//   - func cleanup()
//   - var isSetup: Bool { get }
```

**3. AudioRecorder**
```swift
// Purpose: Record audio from tap to file
// Responsibilities:
//   - Set up IO callback (real-time thread)
//   - Receive audio buffers
//   - Write buffers to WAV file
//   - Manage recording state
// Dependencies:
//   - AudioTapManager (for device ID)
//   - WAVWriter (for file writing)
// API:
//   - func startRecording(to: URL) throws
//   - func stopRecording()
//   - var isRecording: Bool { get }
```

**4. WAVWriter**
```swift
// Purpose: Write audio data to WAV file
// Responsibilities:
//   - Create WAV file with proper header
//   - Write PCM audio data
//   - Update header on completion
// Format:
//   - PCM 16-bit signed integer
//   - Stereo (2 channels)
//   - 44.1kHz or 48kHz sample rate
// API:
//   - func createFile(at: URL, format: AudioFormat) throws
//   - func writeBuffer(_ buffer: AVAudioPCMBuffer) throws
//   - func finalize() throws
```

**5. RecordingController**
```swift
// Purpose: Orchestrate recording workflow
// Responsibilities:
//   - Coordinate between UI and Core Audio layers
//   - Manage recording lifecycle
//   - Handle errors and recovery
//   - Generate file paths
// API:
//   - func startRecording() async throws -> URL
//   - func stopRecording()
//   - func checkSetup() -> Bool
```

### 4.4 Data Flow

#### Starting a Recording

```
User Clicks "Start"
    │
    ▼
RecorderView.onStartButtonTap()
    │
    ▼
RecorderViewModel.startRecording()
    │
    ├─► Check permission status
    │   └─► If denied: Show error, exit
    │
    ├─► RecordingController.startRecording()
    │   │
    │   ├─► Generate file path
    │   │   └─► ~/Desktop/recording_2025-01-10_15-30-45.wav
    │   │
    │   ├─► AudioTapManager.setupSystemTap()
    │   │   └─► Create tap + aggregate device
    │   │
    │   ├─► WAVWriter.createFile()
    │   │   └─► Create empty WAV file with header
    │   │
    │   └─► AudioRecorder.startRecording()
    │       │
    │       ├─► Set up IO callback
    │       │   └─► AudioDeviceCreateIOProcID()
    │       │
    │       └─► Start audio device
    │           └─► AudioDeviceStart()
    │
    └─► Update UI state
        ├─► isRecording = true
        ├─► Start duration timer
        └─► Show recording indicator
```

#### Audio Flow (Real-Time)

```
System Audio Output
    │
    ▼
Core Audio HAL
    │
    ▼
Audio Tap (our tap intercepts)
    │
    ├─► Original path (to speakers) ─► 🔊
    │
    └─► Copy to Aggregate Device
        │
        ▼
    IO Callback (Real-Time Thread) ⚡
        │
        ├─► Receive AudioBufferList
        │
        ├─► Copy to thread-safe queue
        │
        └─► Return immediately (< 1ms)
            │
            ▼
    Processing Thread
        │
        ├─► Dequeue buffer from queue
        │
        ├─► Convert to AVAudioPCMBuffer
        │
        ├─► WAVWriter.writeBuffer()
        │   │
        │   └─► Write to disk
        │
        └─► Update duration (optional)
```

#### Stopping a Recording

```
User Clicks "Stop"
    │
    ▼
RecorderView.onStopButtonTap()
    │
    ▼
RecorderViewModel.stopRecording()
    │
    └─► RecordingController.stopRecording()
        │
        ├─► AudioRecorder.stopRecording()
        │   │
        │   ├─► AudioDeviceStop()
        │   │   └─► Stop IO callback
        │   │
        │   └─► AudioDeviceDestroyIOProcID()
        │       └─► Clean up callback
        │
        ├─► WAVWriter.finalize()
        │   └─► Update WAV header with final size
        │
        ├─► AudioTapManager.cleanup()
        │   └─► Destroy aggregate device + tap
        │
        └─► Update UI
            ├─► isRecording = false
            ├─► Stop timer
            ├─► Show "Reveal in Finder" button
            └─► Display final file path
```

### 4.5 File Structure

```
SystemAudioRecorder/
├── SystemAudioRecorderApp.swift     # App entry point
├── Info.plist                        # Permissions & metadata
├── Views/
│   ├── RecorderView.swift           # Main UI
│   ├── StatusBar.swift              # Status display
│   └── Components/
│       ├── RecordingIndicator.swift # Red dot animation
│       └── DurationLabel.swift      # Time display
├── ViewModels/
│   └── RecorderViewModel.swift      # UI state management
├── Controllers/
│   └── RecordingController.swift    # Business logic
├── CoreAudio/
│   ├── PermissionManager.swift      # Permission handling
│   ├── AudioTapManager.swift        # Tap management
│   ├── AudioRecorder.swift          # Recording logic
│   └── WAVWriter.swift              # File writing
├── Models/
│   ├── AudioFormat.swift            # Format specifications
│   ├── RecordingSession.swift       # Session data
│   └── AppError.swift               # Error types
├── Utilities/
│   ├── FilePathGenerator.swift      # Filename generation
│   └── Logger.swift                 # Debug logging
└── Resources/
    └── Assets.xcassets              # App icons, images
```

---

## 5. User Stories & Use Cases {#user-stories}

### 5.1 User Stories (MVP)

#### Epic: Basic Recording

**US-001: Start Recording**
```
As a user
I want to start recording system audio with one click
So that I can capture audio playing on my Mac

Acceptance Criteria:
- Click "Start" button to begin recording
- Recording indicator appears (red dot)
- Duration counter starts at 00:00
- Audio is captured in real-time
- File is created on Desktop
- No audio dropouts or glitches
```

**US-002: Stop Recording**
```
As a user
I want to stop recording and save the file
So that I have a permanent copy of the audio

Acceptance Criteria:
- Click "Stop" button to end recording
- Recording indicator stops
- Duration counter freezes
- WAV file is finalized and saved
- File path is displayed
- "Reveal in Finder" button appears
```

**US-003: View Recording**
```
As a user
I want to quickly access my recorded file
So that I can listen to it or move it elsewhere

Acceptance Criteria:
- Click "Reveal in Finder" button
- Finder opens with file selected
- File plays in default audio player
- Filename shows timestamp
```

#### Epic: Permissions

**US-004: Grant Permission**
```
As a user
I want to understand why permission is needed
So that I feel comfortable granting it

Acceptance Criteria:
- App explains permission clearly
- Permission dialog appears on first launch
- If granted, app proceeds normally
- If denied, clear error message shown
```

**US-005: Fix Permission**
```
As a user
I want easy access to fix permission issues
So that I don't have to hunt through System Settings

Acceptance Criteria:
- Error message shows if permission denied
- "Open System Settings" button appears
- Clicking opens correct Settings pane
- After granting, app works on retry
```

#### Epic: Error Handling

**US-006: Handle Disk Full**
```
As a user
I want clear feedback if recording fails
So that I know what went wrong and how to fix it

Acceptance Criteria:
- Recording stops if disk full
- Error message explains the issue
- Partial file is deleted (or kept with warning)
- Suggested action: "Free up disk space"
```

**US-007: Handle Invalid Audio**
```
As a user
I want the app to handle unexpected audio formats
So that recording doesn't crash unexpectedly

Acceptance Criteria:
- App detects unsupported formats
- Clear error: "Audio format not supported"
- Suggested action displayed
- App remains usable (doesn't crash)
```

### 5.2 Use Cases

#### Use Case 1: First-Time User

**Scenario:** Fresh install, first launch

```
1. User downloads and launches app
2. macOS shows permission prompt:
   "System Audio Recorder would like to record your screen and audio"
3. User clicks "OK"
4. App shows main window in "Ready" state
5. User plays any audio source
6. User clicks "Start" button
7. Red indicator appears, duration starts: "00:01"
8. User listens to audio for 2 minutes
9. User clicks "Stop" button
10. Success message: "Recording saved to Desktop"
11. File appears: recording_2025-01-10_15-30-45.wav
12. User clicks "Reveal in Finder"
13. Finder opens with file selected
14. User double-clicks file
15. WAV plays in Music/QuickTime
✅ Success
```

**Edge Cases:**
- Permission denied → Show error + "Open Settings" button
- No audio playing → Records silence (valid)
- Disk full during recording → Error + partial file handling

#### Use Case 2: Regular Recording

**Scenario:** User has used app before, knows the flow

```
1. User launches app (no permission prompt)
2. User starts audio source (any app)
3. User clicks "Start" (⌘R keyboard shortcut)
4. Recording begins
5. User switches to other apps while recording
6. After 5 minutes, user clicks "Stop" (⌘R again)
7. File saved: recording_2025-01-10_16-15-22.wav
8. User clicks "Reveal in Finder"
9. File opens
✅ Success
```

#### Use Case 3: Error Recovery

**Scenario:** User encounters permission issue

```
1. User launches app
2. Permission was revoked in System Settings
3. User clicks "Start"
4. Error alert appears:
   "Screen Recording permission denied"
5. User clicks "Open System Settings"
6. System Settings opens to Privacy & Security > Screen Recording
7. User enables app
8. User returns to app
9. User clicks "Start" again
10. Recording begins successfully
✅ Recovered
```

---

## 6. Technical Requirements {#technical-requirements}

### 6.1 System Requirements

**Minimum:**
- macOS 14.2 (Sonoma) or later
- Apple Silicon (M1/M2/M3) or Intel Mac
- 100 MB free disk space (for app)
- 1 GB free disk space (for recordings)
- Screen Recording permission

**Recommended:**
- macOS 14.4+ (enhanced Core Audio Taps API)
- Apple Silicon (M2 or later)
- 10+ GB free disk space
- SSD storage (for reliable high-quality recording)

### 6.2 Audio Specifications

**Input (System Audio):**
- Sample Rate: 44.1kHz or 48kHz (auto-detected)
- Channels: Stereo (2 channels)
- Bit Depth: 32-bit float (internal processing)

**Output (WAV File):**
- Format: WAV (RIFF)
- Encoding: PCM 16-bit signed integer
- Channels: Stereo (2 channels)
- Sample Rate: Same as input (44.1kHz or 48kHz)
- Endianness: Little-endian

**File Size Estimation:**
```
Sample Rate: 44,100 Hz
Channels: 2 (stereo)
Bit Depth: 16 bits (2 bytes)
Bytes per second: 44,100 × 2 × 2 = 176,400 bytes/sec
≈ 172 KB/sec
≈ 10.3 MB/minute
≈ 618 MB/hour
```

### 6.3 Performance Requirements

| Metric | Target | Maximum |
|--------|--------|---------|
| CPU Usage (recording) | < 3% | < 5% |
| Memory Usage | < 30 MB | < 50 MB |
| Launch Time | < 1 sec | < 2 sec |
| Recording Start Latency | < 200ms | < 500ms |
| Audio Dropout Rate | 0% | 0% |
| File Write Latency | Non-blocking | N/A |
| Max Recording Duration | 1 hour | Limited by disk |

### 6.4 Quality Requirements

**Audio Quality:**
- ✅ No audible artifacts
- ✅ No clipping or distortion
- ✅ Accurate timestamp sync
- ✅ Bit-perfect capture (lossless)

**Reliability:**
- ✅ No crashes during recording
- ✅ Graceful handling of errors
- ✅ No orphaned files
- ✅ Clean shutdown

**Usability:**
- ✅ Intuitive UI (no manual)
- ✅ Clear error messages
- ✅ Fast response to user actions (< 100ms)

### 6.5 Constraints

**Technical:**
- Must use Core Audio Taps API (no external drivers)
- Swift only (no Objective-C mixing unless necessary)
- SwiftUI for UI (no AppKit except where required)
- Minimum external dependencies

**Legal:**
- Must display copyright disclaimer
- Must not market for recording copyrighted content
- User responsible for compliance with ToS

**Environmental:**
- Single user
- Local development only (no distribution)
- Mac Studio environment
- No cloud/network dependencies

---

## 7. Development Phases {#development-phases}

### Phase 1: Project Setup (Day 1)

**Goal:** Get Xcode project configured and running

**Tasks:**
1. ✅ Create new Xcode project
   - Type: macOS App
   - Interface: SwiftUI
   - Language: Swift
   - Organization: Personal

2. ✅ Configure Info.plist
   ```xml
   <key>NSAudioCaptureUsageDescription</key>
   <string>This app records system audio to save it as WAV files on your Mac.</string>
   ```

3. ✅ Set deployment target
   - Minimum: macOS 14.2
   - Target: macOS 14.4

4. ✅ Enable Hardened Runtime
   - Capabilities → Hardened Runtime
   - Enable: Audio Input, Screen Recording

5. ✅ Create file structure
   - Views/, ViewModels/, Controllers/, CoreAudio/, Models/, Utilities/

**Acceptance:**
- ✅ Project builds successfully
- ✅ App launches and shows blank window
- ✅ No warnings or errors

**Time Estimate:** 1-2 hours

---

### Phase 2: Permission Layer (Day 1-2)

**Goal:** Handle macOS permissions properly

**Tasks:**
1. ✅ Implement PermissionManager
   ```swift
   // Methods:
   - checkPermission() -> PermissionStatus
   - requestPermission() async -> Bool
   - openSystemPreferences()
   ```

2. ✅ Create permission UI
   - Initial permission check on launch
   - Error alert if denied
   - "Open Settings" button

3. ✅ Test permission flow
   - Grant permission flow
   - Deny permission flow
   - Revoke and re-grant flow

**Acceptance:**
- ✅ Permission requested on first launch
- ✅ App detects granted/denied status
- ✅ Settings opens to correct pane
- ✅ App handles all permission states

**Time Estimate:** 2-4 hours

---

### Phase 3: Core Audio Tap (Day 2-3)

**Goal:** Create and manage audio tap

**Tasks:**
1. ✅ Implement AudioTapManager
   ```swift
   // Methods:
   - setupSystemTap() throws
   - getTapUUID() throws -> String
   - createAggregateDevice(tapUUID:) throws
   - cleanup()
   ```

2. ✅ Test tap creation
   - Verify tap ID is valid
   - Verify aggregate device created
   - Verify cleanup works

3. ✅ Error handling
   - Tap creation failures
   - Device creation failures
   - Resource cleanup

**Acceptance:**
- ✅ Tap created successfully
- ✅ Aggregate device appears in Audio MIDI Setup
- ✅ No resource leaks after cleanup
- ✅ Errors logged clearly

**Time Estimate:** 4-6 hours

---

### Phase 4: Audio Recorder (Day 3-4)

**Goal:** Capture audio buffers via IO callback

**Tasks:**
1. ✅ Implement AudioRecorder
   ```swift
   // Methods:
   - startRecording(to: URL) throws
   - stopRecording()
   - processAudioBuffer(_ bufferList:)
   ```

2. ✅ Set up IO callback
   - AudioDeviceCreateIOProcID
   - Handle buffer data
   - Thread-safe buffer queue

3. ✅ Test audio flow
   - Verify callbacks fire regularly (~86 Hz at 44.1kHz)
   - Check buffer data is valid
   - Monitor for dropouts

**Acceptance:**
- ✅ IO callback receives audio data
- ✅ No crashes in real-time thread
- ✅ Buffer data is non-zero
- ✅ Callback frequency is consistent

**Time Estimate:** 6-8 hours

---

### Phase 5: WAV File Writing (Day 4-5)

**Goal:** Write audio data to WAV file

**Tasks:**
1. ✅ Implement WAVWriter
   ```swift
   // Methods:
   - createFile(at: URL, format:) throws
   - writeBuffer(_ buffer:) throws
   - finalize() throws
   ```

2. ✅ WAV header generation
   - RIFF header
   - fmt chunk
   - data chunk

3. ✅ Buffer writing
   - Convert Float32 to Int16
   - Write to file
   - Update data size

4. ✅ Finalize file
   - Update header with final sizes
   - Close file handle

**Acceptance:**
- ✅ WAV file created with valid header
- ✅ Audio data written correctly
- ✅ File plays in QuickTime/Music
- ✅ File size matches duration
- ✅ No corruption or glitches

**Time Estimate:** 4-6 hours

---

### Phase 6: UI Implementation (Day 5-6)

**Goal:** Build SwiftUI interface

**Tasks:**
1. ✅ Create RecorderView
   - Status bar
   - Start/Stop button
   - Duration label
   - Error alerts

2. ✅ Implement RecorderViewModel
   - @Published state variables
   - Recording control logic
   - Error handling

3. ✅ Add animations
   - Pulsing red dot
   - Button state transitions
   - Duration counter

**Acceptance:**
- ✅ UI updates in real-time
- ✅ Buttons respond immediately
- ✅ Animations smooth (60 fps)
- ✅ Errors display clearly

**Time Estimate:** 4-6 hours

---

### Phase 7: Integration & Testing (Day 6-7)

**Goal:** Connect all components and test end-to-end

**Tasks:**
1. ✅ Wire up components
   - ViewModel → RecordingController
   - Controller → AudioTapManager + AudioRecorder
   - AudioRecorder → WAVWriter

2. ✅ End-to-end testing
   - Record 30 second file
   - Record 5 minute file
   - Record while switching apps
   - Stop/start multiple times

3. ✅ Edge case testing
   - Disk full
   - Permission revoked mid-recording
   - System audio changes sample rate
   - Very short recordings (< 1 second)

4. ✅ Performance testing
   - CPU usage monitoring
   - Memory leak detection
   - Long recordings (30+ minutes)

**Acceptance:**
- ✅ All user stories pass
- ✅ All edge cases handled
- ✅ No crashes or hangs
- ✅ Performance targets met

**Time Estimate:** 6-10 hours

---

### Phase 8: Polish & Documentation (Day 7)

**Goal:** Final touches and docs

**Tasks:**
1. ✅ Add keyboard shortcuts
   - ⌘R for Start/Stop
   - ⌘O for Reveal in Finder

2. ✅ Improve error messages
   - User-friendly language
   - Actionable suggestions
   - Links to help

3. ✅ Write README
   - Installation
   - Usage
   - Troubleshooting
   - Known limitations

4. ✅ Code cleanup
   - Remove debug prints
   - Add documentation comments
   - Format code

**Acceptance:**
- ✅ Keyboard shortcuts work
- ✅ All errors have good messages
- ✅ README is complete
- ✅ Code is clean

**Time Estimate:** 2-4 hours

---

**Total MVP Time Estimate: 30-50 hours (5-7 days)**

---

## 8. Testing Strategy {#testing-strategy}

### 8.1 Unit Tests

**PermissionManager Tests**
```swift
func testPermissionCheck()
func testPermissionRequest()
func testOpenSystemSettings()
```

**AudioTapManager Tests**
```swift
func testSystemTapCreation()
func testTapUUIDExtraction()
func testAggregateDeviceCreation()
func testCleanup()
func testResourceDeallocation()
```

**WAVWriter Tests**
```swift
func testFileCreation()
func testHeaderGeneration()
func testBufferWriting()
func testFinalization()
func testInvalidPath()
```

**FilePathGenerator Tests**
```swift
func testFilenameGeneration()
func testTimestampFormat()
func testPathCombination()
func testDirectoryCreation()
```

### 8.2 Integration Tests

**Recording Flow Tests**
```swift
func testCompleteRecordingFlow()
  // 1. Setup tap
  // 2. Start recording
  // 3. Wait 2 seconds
  // 4. Stop recording
  // 5. Verify file exists
  // 6. Verify file plays
  
func testMultipleRecordings()
  // Record → Stop → Record → Stop
  // Verify separate files
  
func testRecordingCancellation()
  // Start → Immediate stop
  // Verify cleanup
```

**Error Handling Tests**
```swift
func testDiskFullError()
func testPermissionDeniedError()
func testInvalidFormatError()
func testFilePathError()
```

### 8.3 Manual Testing Checklist

**Basic Functionality**
- [ ] Launch app successfully
- [ ] Grant permission successfully
- [ ] Start recording (plays audio during)
- [ ] Duration updates every second
- [ ] Red dot pulses while recording
- [ ] Stop recording successfully
- [ ] File appears on Desktop
- [ ] File has correct name format
- [ ] File plays in Music app
- [ ] Reveal in Finder works

**Audio Quality**
- [ ] No pops or clicks
- [ ] No dropouts or silence
- [ ] Stereo channels balanced
- [ ] Volume matches original
- [ ] Sample rate correct (44.1 or 48 kHz)

**Error Scenarios**
- [ ] Handle permission denial
- [ ] Handle disk full
- [ ] Handle invalid save location
- [ ] Handle app force quit
- [ ] Handle system sleep during recording

**Performance**
- [ ] CPU < 5% during recording
- [ ] Memory < 50 MB
- [ ] No UI lag
- [ ] Recording starts instantly
- [ ] Recording stops instantly

**Edge Cases**
- [ ] Very short recording (< 1 sec)
- [ ] Very long recording (> 30 min)
- [ ] No audio playing (records silence)
- [ ] Multiple apps playing audio
- [ ] Switch between apps during recording
- [ ] Change system volume during recording

### 8.4 Performance Testing

**Metrics to Monitor**
```swift
// CPU Usage
Activity Monitor → CPU tab → % CPU

// Memory Usage  
Activity Monitor → Memory tab → Real Mem

// Audio Thread Performance
// Log in IO callback (remove in production!)
let start = CFAbsoluteTimeGetCurrent()
// ... process buffer ...
let elapsed = CFAbsoluteTimeGetCurrent() - start
// Should be < 1ms

// File I/O
// Monitor disk writes
fs_usage -f filesys SystemAudioRecorder
```

**Performance Test Cases**
1. **Baseline:** Record 5 min, monitor CPU/memory
2. **Stress:** Record 60 min, check for memory leaks
3. **Concurrent:** Record while CPU-intensive task runs
4. **Disk I/O:** Record to slow external drive

---

## 9. Acceptance Criteria {#acceptance-criteria}

### 9.1 MVP Acceptance Criteria

**Must Pass ALL of the following:**

#### ✅ Functional Requirements

**FR-001: Audio Capture**
- [ ] System audio is captured in real-time
- [ ] Audio quality is lossless (bit-perfect)
- [ ] Stereo channels are preserved
- [ ] Sample rate matches system output
- [ ] No audible artifacts or dropouts

**FR-002: File Creation**
- [ ] WAV file is created on Desktop
- [ ] Filename format: `recording_YYYY-MM-DD_HH-MM-SS.wav`
- [ ] File header is valid WAV format
- [ ] File plays in macOS Music app
- [ ] File size matches recording duration

**FR-003: User Controls**
- [ ] Start button begins recording
- [ ] Stop button ends recording
- [ ] Recording indicator shows active state
- [ ] Duration counter shows elapsed time
- [ ] Reveal in Finder opens file location

**FR-004: Permissions**
- [ ] App requests Screen Recording permission
- [ ] Permission dialog explains purpose
- [ ] App detects permission status
- [ ] Error shown if permission denied
- [ ] Settings link opens correct pane

#### ✅ Non-Functional Requirements

**NFR-001: Performance**
- [ ] CPU usage < 5% during recording
- [ ] Memory usage < 50 MB
- [ ] Launch time < 2 seconds
- [ ] UI responsive (< 100ms to user input)
- [ ] No frame drops in UI

**NFR-002: Reliability**
- [ ] No crashes during 30-minute recording
- [ ] Clean shutdown (no orphaned files)
- [ ] Proper error handling for all scenarios
- [ ] Resources released after recording

**NFR-003: Usability**
- [ ] User can start recording in 3 clicks
- [ ] Clear visual feedback at all times
- [ ] Error messages are user-friendly
- [ ] No configuration required for basic use

### 9.2 Test Scenarios (Must Pass)

**Scenario 1: First Recording**
```
Given: Fresh app install
When: User launches app and grants permission
Then: User can record and save first WAV file
```
- [ ] Pass

**Scenario 2: Multiple Recordings**
```
Given: App has permission
When: User records 3 separate files
Then: All 3 files saved with unique names
```
- [ ] Pass

**Scenario 3: Long Recording**
```
Given: App is recording
When: User records for 30 minutes
Then: File is complete and plays correctly
```
- [ ] Pass

**Scenario 4: Permission Denied**
```
Given: User denies permission
When: User tries to record
Then: Clear error shown with fix instructions
```
- [ ] Pass

**Scenario 5: Disk Full**
```
Given: Disk space < 100 MB
When: User records large file
Then: Error shown, partial file handled
```
- [ ] Pass

### 9.3 Quality Gates

**Before Considering MVP Complete:**

**Code Quality**
- [ ] No compiler warnings
- [ ] All public APIs documented
- [ ] No force unwraps (!) in production code
- [ ] Error handling for all throws
- [ ] Thread safety verified

**Testing**
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Manual test checklist complete
- [ ] Performance benchmarks met
- [ ] No memory leaks detected

**Documentation**
- [ ] README with setup instructions
- [ ] Usage guide with screenshots
- [ ] Troubleshooting section
- [ ] Known limitations listed

**User Experience**
- [ ] UI is intuitive (tested with fresh eyes)
- [ ] All error states handled gracefully
- [ ] Keyboard shortcuts work
- [ ] Visual feedback is clear

### 9.4 Success Metrics

**Technical Success**
- ✅ Record 5-minute file with 0 dropouts
- ✅ CPU usage < 3% average
- ✅ File plays perfectly in QuickTime
- ✅ App runs 24 hours without crash

**User Success**
- ✅ Can record first file in < 2 minutes
- ✅ Understand all UI elements without help
- ✅ Recover from errors without frustration
- ✅ Trust app to work reliably

**MVP Completion Definition**
```
MVP is complete when:
1. All acceptance criteria pass ✅
2. All test scenarios pass ✅
3. All quality gates met ✅
4. Success metrics achieved ✅
5. The developer can confidently use it daily ✅
```

---

## 10. Claude Code Development Guide {#claude-code-guide}

### 10.1 Getting Started with Claude Code

**Initial Prompt Template**
```
I'm building a macOS system audio recorder using Swift and Core Audio Taps.

Project Goal: Record system audio and save as WAV files locally.

Context:
- Platform: macOS 14.2+ (Sonoma)
- Language: Swift 5.9+
- UI: SwiftUI
- Architecture: MVVM pattern
- Target Hardware: Mac Studio (Apple Silicon)

Current Phase: [Phase number from Development Phases section]

Please help me implement [specific component].

Reference: See SystemAudioRecorder project spec, Phase [X].
```

### 10.2 Phase-by-Phase Prompts

**Phase 1: Project Setup**
```
Let's create the Xcode project structure for SystemAudioRecorder.

Requirements:
- macOS App with SwiftUI interface
- Deployment target: macOS 14.2
- Enable Hardened Runtime capabilities
- Add NSAudioCaptureUsageDescription to Info.plist
- Create folder structure: Views/, ViewModels/, CoreAudio/, etc.

Please provide:
1. Step-by-step setup instructions
2. Info.plist configuration
3. Directory structure

Reference: Phase 1 of project spec
```

**Phase 2: Permission Layer**
```
Implement PermissionManager for handling Screen Recording permission.

Requirements:
- Check permission status
- Request permission (async)
- Open System Settings if denied
- Return PermissionStatus enum

API needed:
- checkPermission() -> PermissionStatus
- requestPermission() async -> Bool
- openSystemPreferences()

Reference: Phase 2, section 4.3 component #1
```

**Phase 3: Audio Tap Manager**
```
Implement AudioTapManager to create and manage Core Audio Tap.

Requirements:
- Create system-wide audio tap (pid: 0)
- Extract tap UUID
- Create aggregate device with tap
- Clean up resources

Properties:
- tapDescription: Unmanaged<CATapDescription>?
- tapID: AudioObjectID
- aggregateDeviceID: AudioDeviceID

Reference: Phase 3, implementation guide section on AudioTapManager
```

**Phase 4: Audio Recorder**
```
Implement AudioRecorder with real-time IO callback.

Requirements:
- Set up AudioDeviceIOProc callback
- Receive audio buffers from aggregate device
- Thread-safe buffer handling (no allocations in RT thread)
- Start/stop recording

Important: IO callback runs on real-time thread with strict constraints.

Reference: Phase 4, threading section 6
```

**Phase 5: WAV Writer**
```
Implement WAVWriter to write PCM audio to WAV file.

Requirements:
- Create WAV file with proper RIFF header
- Write audio buffers (convert Float32 to Int16)
- Update header on completion
- Support 44.1kHz and 48kHz

Format: PCM 16-bit stereo WAV

Reference: Phase 5, section 4.3 component #4
```

**Phase 6: UI Implementation**
```
Create SwiftUI interface with RecorderView and RecorderViewModel.

Requirements:
- Start/Stop button
- Recording indicator (pulsing red dot)
- Duration label (MM:SS format)
- Error alerts
- Reveal in Finder button

State management: Use @Published properties in ViewModel

Reference: Phase 6, section 4.2 Frontend Layer
```

**Phase 7: Integration**
```
Connect all components for end-to-end recording flow.

Workflow:
1. User clicks Start
2. ViewModel → RecordingController
3. Controller → AudioTapManager.setupSystemTap()
4. Controller → AudioRecorder.startRecording()
5. AudioRecorder → WAVWriter
6. User clicks Stop
7. Cleanup and finalize file

Reference: Phase 7, section 4.4 Data Flow
```

### 10.3 Testing Prompts

**Unit Testing**
```
Write unit tests for [ComponentName].

Test cases needed:
- Happy path
- Error handling
- Edge cases
- Resource cleanup

Use XCTest framework.

Reference: Section 8.1 Unit Tests
```

**Integration Testing**
```
Create integration test for complete recording flow.

Test scenario:
1. Setup tap
2. Start recording
3. Record for 2 seconds
4. Stop recording
5. Verify file exists and plays

Reference: Section 8.2 Integration Tests
```

### 10.4 Debugging Prompts

**When Stuck**
```
I'm encountering [specific error/issue] in [component name].

Error: [paste error message]

Context:
- What I'm trying to do: [describe]
- What's happening: [describe]
- Expected behavior: [describe]

Code snippet: [paste relevant code]

Please help diagnose and fix.
```

**Performance Issues**
```
I'm seeing [performance issue: high CPU/memory/dropouts].

Metrics:
- CPU: [X]%
- Memory: [X] MB
- Dropouts: [yes/no]

Component: [AudioRecorder/WAVWriter/etc]

Please suggest optimizations.

Reference: Section 6.3 Performance Requirements
```

### 10.5 Code Review Prompts

**Before Committing**
```
Please review this [component] implementation.

Check for:
- Thread safety (especially RT thread)
- Memory leaks
- Error handling completeness
- Swift best practices
- Comments and documentation

Code: [paste]

Reference: Section 9.3 Quality Gates
```

### 10.6 Documentation Prompts

**Generate Comments**
```
Add documentation comments to this class/function.

Follow Swift documentation style:
- /// Summary
- /// - Parameter name: description
- /// - Returns: description
- /// - Throws: error conditions

Code: [paste]
```

### 10.7 Iteration Strategy

**Incremental Development**
1. Start with Phase 1 (setup)
2. Complete each phase fully before moving on
3. Test each component in isolation
4. Integration test after every 2-3 phases
5. Iterate on UI/UX after basic functionality works

**Feedback Loop**
```
After each phase:
1. Test the implementation
2. If it works: Move to next phase
3. If it doesn't: Debug with Claude Code
4. Document any deviations from spec
```

---

## 11. MVP Deliverables Checklist

### Code Deliverables
- [ ] Xcode project (SystemAudioRecorder.xcodeproj)
- [ ] All Swift source files
- [ ] Info.plist configured
- [ ] Assets (app icon, if any)
- [ ] Unit tests
- [ ] Integration tests

### Documentation Deliverables
- [ ] README.md
  - Installation instructions
  - Usage guide
  - Troubleshooting
  - Known limitations
- [ ] Code comments (all public APIs)
- [ ] Architecture diagram (optional)

### Testing Deliverables
- [ ] Test results (all passing)
- [ ] Performance benchmark results
- [ ] Manual test checklist (completed)
- [ ] Recording samples (3-5 WAV files)

### Acceptance Deliverables
- [ ] All acceptance criteria met
- [ ] Success metrics achieved
- [ ] Quality gates passed
- [ ] Developer's approval ✅

---

## 12. Future Roadmap (Post-MVP)

### Version 2.0 Features
- MP3 encoding (AVAssetWriter)
- Per-application audio capture
- Audio level meters (real-time visualization)
- Scheduled recording (start/stop at times)
- Keyboard shortcuts customization

### Version 3.0 Features
- Background recording (menu bar app)
- Audio effects (normalize, fade, trim)
- Metadata tagging (ID3 tags)
- Multiple format support (AAC, FLAC)
- Preferences panel

### Long-term Vision
- Cloud upload integration
- Automatic transcription
- Audio enhancement (noise reduction)
- Batch processing
- Command-line interface

---

## 13. Quick Reference

### File Paths
```
Desktop recordings: ~/Desktop/recording_*.wav
App location: /Applications/SystemAudioRecorder.app
Logs: ~/Library/Logs/SystemAudioRecorder/
```

### Keyboard Shortcuts
```
⌘R - Start/Stop recording
⌘O - Reveal in Finder
⌘, - Preferences (future)
⌘Q - Quit
```

### Common Errors
```
"Permission denied" → Open System Settings > Privacy & Security
"Audio format error" → Check system audio output device
"Disk full" → Free up disk space
"Tap creation failed" → Restart app, check macOS version
```

### Performance Targets
```
CPU: < 5%
Memory: < 50 MB
Latency: < 100ms
Dropouts: 0%
File size: ~10 MB/min
```

---

## 14. Contact & Support

**Developer:** Melissa de Britto
**Project Status:** MVP Development
**Target Completion:** 7 days
**Platform:** macOS 14.2+

**Resources:**
- Apple Core Audio Documentation
- Core Audio Taps Sample Code
- This project specification
- Claude Code AI assistant

---

## Final Notes

This specification provides everything needed to build the MVP with Claude Code:
- ✅ Clear goals and scope
- ✅ Detailed architecture
- ✅ Step-by-step development phases
- ✅ Comprehensive testing strategy
- ✅ Acceptance criteria
- ✅ Claude Code integration guidance

**Start with Phase 1** and work incrementally. Test each phase before moving on. Use the prompts provided for Claude Code assistance.

**MVP Success = Recording and playing your first WAV file! 🎯**

Good luck building! 🚀

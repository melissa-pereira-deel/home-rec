//
//  RecorderViewModel.swift
//  HomeRec
//
//  View model for the recorder UI
//

import Foundation
import SwiftUI
import AppKit
import AVFoundation
import Combine
import os

/// View model managing recording state and user interactions
@MainActor
class RecorderViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Single source of truth for the recording lifecycle. The UI derives from this.
    @Published private(set) var state: RecordingState = .idle
    @Published var duration: TimeInterval = 0
    @Published var errorMessage: String?
    @Published var showError = false
    /// A recovery action to offer alongside the current error, if any.
    @Published var recoverySuggestion: RecoverySuggestion?
    /// Set once a recording passes the long-recording threshold.
    @Published var showLongRecordingWarning = false
    /// Whether the first-run onboarding sheet should be shown.
    @Published var showOnboarding = false
    @Published var lastRecordingURL: URL?
    @Published var permissionStatus: PermissionStatus = .notDetermined
    @Published var waveformSamples: [Float] = Array(repeating: 0, count: 200)
    /// Display name of the current save location (folder name, or "Desktop").
    @Published private(set) var saveLocationName: String = "Desktop"
    /// Whether a non-default save location is configured (controls the Reset affordance).
    @Published private(set) var hasCustomSaveLocation = false

    /// The output format for new recordings (BL-015). Captured at record start —
    /// it can't change mid-recording (the shelf is hidden then). Persisted across
    /// launches; mutate only via `setFormat(_:)`.
    @Published private(set) var selectedFormat: AudioFormat = .wav

    /// Where this bundle is running from (BL-082). Fixed for the process' lifetime —
    /// the bundle cannot move out from under a running app.
    let installLocation: InstallLocation

    /// Whether the install-location explanation is currently on screen.
    @Published private(set) var showsInstallLocationNotice = false

    /// Set once the user dismisses a *soft* note. Has no effect on the hard block.
    @Published private(set) var installNoticeDismissed = false

    /// True while the registering probe runs ahead of System Settings opening, so
    /// the button that started it can disable and not be fired twice (BL-087).
    @Published private(set) var isOpeningSystemSettings = false

    /// Whether a recording is actively capturing. Derived from `state`.
    var isRecording: Bool { state == .recording }

    /// Whether the settings shelf (save location, format, capture source) is shown.
    ///
    /// Gated on the state machine rather than on `isRecording`, which is
    /// `.recording` **only**. The shelf's own comment claims its settings are
    /// "locked once capture starts", and with `isRecording` that was false: the
    /// shelf stayed visible and clickable through `.starting` and `.stopping`,
    /// after `selectedFormat` had already been captured for the take in flight.
    /// `.recovering` is not reachable today, but it returns to `.recording`, so
    /// the same rule keeps the shelf from popping back mid-take if it ever is.
    ///
    /// Extracted from the view so the rule is reachable by a test — living inside
    /// a SwiftUI `if` is why the divergence went unnoticed.
    var showsSettingsShelf: Bool { state.allowsCaptureSourceChange }

    /// Whether the app is actually in a position to record: permission granted and
    /// the bundle in a location where that grant will survive. The record button is
    /// live only in this state; otherwise it carries a corrective action instead.
    var canRecord: Bool { permissionStatus == .granted && !installLocation.blocksRecording }

    /// Recording is refused outright only for a translocated bundle: the grant it
    /// needs cannot survive, so "it worked once and then stopped" is the *best*
    /// case if we let it through. Merely living outside `/Applications` never
    /// blocks — that is a legitimate choice TCC handles fine, and conflating the
    /// two trains users to dismiss the warning that matters.
    var installLocationBlocksRecording: Bool { installLocation.blocksRecording }

    /// The note to show about the install location, or `nil` when there is nothing
    /// worth saying. A soft note disappears once dismissed; the hard block does
    /// not, because dismissing it would leave the app quietly unable to hold a grant.
    var installNotice: String? {
        guard let text = installLocation.explanation else { return nil }
        if installLocation.noticeIsDismissible && installNoticeDismissed { return nil }
        return text
    }

    /// Full path of the current save location, for tooltips / accessibility.
    var saveLocationPath: String { saveLocation.resolvedDirectory.path }

    // MARK: - Private Properties

    private let controller: RecordingControlling
    private let permissions: PermissionProviding
    private let clock: DurationClock
    private let saveLocation: SaveLocationProviding
    /// Capture-source selection, shared with the `RecordingController` that reads it
    /// at `startRecording`. There must be exactly **one** of these in the app: the
    /// menu writes the selection and the controller reads it, so a second instance
    /// would let a picked source be silently ignored by the next recording. Reads
    /// are `UserDefaults`-backed today and so tolerate duplicates by accident — once
    /// the selection is cached in memory (BL-111), duplicates diverge for real.
    let audioSource: AudioSourceProviding
    private var recordingStartTime: Date?
    private var longRecordingWarned = false
    private var activationObserver: NSObjectProtocol?
    /// Whether the user has done something that asks for permission.
    ///
    /// The activation re-probe exists for exactly one scenario — the user granted
    /// in System Settings and came back (BL-040) — so it fires only once they have
    /// been sent there. Counting activations instead ("skip the first, it must be
    /// launch") makes correctness depend on whether SwiftUI built this object
    /// before or after the launch activation, which is not contracted: on a
    /// background launch (`open -g`, a login item) or late scene evaluation the
    /// swallowed activation is a real return, and the grant goes unnoticed.
    ///
    /// Gating on resignation instead was considered and rejected: it re-probes any
    /// ungranted return, so launch → switch to another app → switch back prompts
    /// with no click behind it, which is the whole bug class (BL-085). What intent
    /// gives up is noticing a *spontaneous* grant — a near-empty set, since an app
    /// that has never probed is not listed in System Settings to be granted.
    private var hasSoughtPermission = false
    /// In-flight permission probe, so overlapping callers share one result
    /// rather than racing to write `permissionStatus`. See `checkPermission()`.
    private var permissionProbe: Task<PermissionStatus, Never>?
    /// Watches for a grant made in System Settings while the app runs (BL-088).
    /// Created on first use; started only from a user's own click.
    private var grantWatcher: PermissionGrantWatcher?
    private let installLocationProvider: InstallLocationProviding
    /// The install-location panel, created on first use for the same reason.
    private var installNoticePanel: FloatingPanelHost?
    /// Overrides how the install-location notice is presented.
    ///
    /// Exists for tests: the default presenter materialises a real `NSPanel` and
    /// orders it on screen, which a unit test asserting "translocation blocks
    /// recording" has no business doing. Production never passes this.
    private let installNoticePresenter: (() -> Void)?
    /// Visible main windows, reported by the windows themselves.
    ///
    /// Deliberately *not* inferred from `NSApp.windows`: at init no window exists
    /// yet, and a menu-bar app owns a visible `NSStatusBarWindow` for the whole
    /// process — so "any visible non-panel window" answers `false` exactly when a
    /// window is about to appear, and `true` forever after even with every real
    /// window closed. Both answers are wrong at the moment they matter.
    private(set) var visibleWindowCount = 0
    private var launchNoticeObserver: NSObjectProtocol?
    /// Injected so tests get their own activation notifications. `.default` is
    /// process-global, and the suites are unserialized: one suite's synthetic
    /// `didBecomeActive` would otherwise reach every other suite's live view
    /// model, which is both a false pass and a false failure waiting to happen.
    private let notificationCenter: NotificationCenter
    /// Clock for the registration deadline. Injected so the bounded wait is
    /// deterministic under test — the suite has a no-sleeps rule.
    private let pollClock: PollClock
    private let registrationTimeout: TimeInterval
    private let defaults: UserDefaults
    private let onboardingCompletedKey = "hasCompletedOnboarding"
    private let selectedFormatKey = "selectedFormat"

    // MARK: - Initialization

    init(
        controller: RecordingControlling? = nil,
        permissions: PermissionProviding? = nil,
        clock: DurationClock? = nil,
        saveLocation: SaveLocationProviding? = nil,
        audioSource: AudioSourceProviding? = nil,
        installLocation: InstallLocationProviding? = nil,
        defaults: UserDefaults = .standard,
        installNoticePresenter: (() -> Void)? = nil,
        notificationCenter: NotificationCenter = .default,
        pollClock: PollClock? = nil,
        registrationTimeout: TimeInterval = 2.0
    ) {
        self.notificationCenter = notificationCenter
        self.pollClock = pollClock ?? SystemPollClock()
        self.registrationTimeout = registrationTimeout
        let resolvedInstallLocation = installLocation ?? BundleInstallLocation()
        self.installLocationProvider = resolvedInstallLocation
        self.installLocation = resolvedInstallLocation.location
        self.installNoticePresenter = installNoticePresenter
        let resolvedSaveLocation = saveLocation ?? SaveLocationManager(defaults: defaults)
        self.saveLocation = resolvedSaveLocation
        // Resolved once and handed to the controller, so the menu's writes and the
        // controller's reads are the same object (see `audioSource` above).
        let resolvedAudioSource = audioSource ?? AudioSourceManager(defaults: defaults)
        self.audioSource = resolvedAudioSource
        self.controller = controller ?? RecordingController(
            saveLocation: resolvedSaveLocation,
            audioSource: resolvedAudioSource
        )
        self.permissions = permissions ?? PermissionManager()
        self.clock = clock ?? SystemDurationClock()
        self.defaults = defaults
        self.showOnboarding = !defaults.bool(forKey: onboardingCompletedKey)
        self.selectedFormat = Self.loadFormat(from: defaults, key: selectedFormatKey)
        self.controller.onStreamError = { [weak self] message in
            self?.handleStreamFailure(message)
        }
        refreshSaveLocationDisplay()
        // Re-probe permission whenever the app regains focus, so granting Screen
        // Recording in System Settings takes effect without a relaunch (BL-040).
        //
        // Skipped once permission is granted — which is every activation for every
        // already-set-up user. That probe is an XPC round-trip that can also raise
        // the system prompt, and re-asking a question already answered "yes" buys
        // nothing. A revocation mid-session surfaces when recording next starts.
        activationObserver = notificationCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                // Only re-probe once the user has actually gone looking for the
                // permission. Launch, and any idle activation before then, stays
                // silent — the app wanting to know its own state is never a reason
                // to raise a system dialog (BL-085).
                guard self.hasSoughtPermission else { return }
                guard self.permissionStatus != .granted else { return }
                // A translocated bundle must never be walked into the permission
                // flow (BL-082a): the authoritative probe raises the system prompt,
                // and any grant it wins evaporates on next launch. The block
                // surfaces are the only correct response.
                guard !self.installLocation.blocksRecording else { return }
                await self.checkPermission()
            }
        }
        // Launch uses the *silent* read (BL-085). The authoritative probe can raise
        // the system prompt, and firing it here throws a permission dialog at
        // someone who has not asked for anything yet — the app wanting to know its
        // own state is not a good enough reason to interrupt. Preflight is accurate
        // at launch, which is exactly and only what is needed here.
        permissionStatus = self.permissions.preflight()
        // A translocated bundle is broken from the first launch, so the block state
        // is set now — but nothing is *presented* from here. At this point the view
        // model is still being constructed as a `@StateObject`, so no window exists
        // yet; presenting here would always take the no-window branch and put the
        // panel up moments before the main window appears saying the same thing.
        // The window announces itself via `mainWindowDidAppear()`; a launch that
        // opens no window at all is covered by the fallback below.
        if self.installLocation.blocksRecording {
            self.showsInstallLocationNotice = true
            launchNoticeObserver = notificationCenter.addObserver(
                forName: NSApplication.didFinishLaunchingNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.visibleWindowCount == 0 else { return }
                    self.showInstallLocationNotice()
                }
            }
        }
    }

    deinit {
        if let activationObserver {
            notificationCenter.removeObserver(activationObserver)
        }
        if let launchNoticeObserver {
            notificationCenter.removeObserver(launchNoticeObserver)
        }
    }

    // MARK: - Public Methods

    /// Check permission status.
    ///
    /// Single-flighted: `didBecomeActiveNotification` and the permission guide's
    /// poll loop can both ask at once, and `SCShareableContent` is an XPC round-trip
    /// whose latency varies. Without this, two probes overlap and the *slower* one
    /// writes last — so a stale `.denied` can land after a fresh `.granted` and the
    /// UI insists permission is missing seconds after the user granted it. That is
    /// precisely the failure the guide exists to prevent, so it must not be
    /// reintroduced by the guide's own polling.
    func checkPermission() async {
        if let inFlight = permissionProbe {
            _ = await inFlight.value
            return
        }
        let probe = Task { await permissions.checkPermission() }
        permissionProbe = probe
        let status = await probe.value
        permissionProbe = nil
        permissionStatus = status
    }

    /// Request permission
    func requestPermission() async {
        hasSoughtPermission = true
        let granted = await permissions.requestPermission()
        permissionStatus = granted ? .granted : .denied

        if !granted {
            presentError(
                "Home Rec needs Screen Recording permission to capture audio (it never records your screen). You can turn it on in System Settings.",
                recovery: .openSettings
            )
        }
    }

    /// Start recording
    func startRecording() async {
        // Only legal from idle or a prior error state.
        guard state.canTransition(to: .starting) else { return }

        // Install location is checked *before* permission (BL-082). A translocated
        // bundle can be granted permission and will still lose it on the next
        // launch, so sending the user into the permission flow here would hand them
        // advice that is worse than useless — they'd follow it correctly and the
        // grant would evaporate anyway.
        guard !installLocation.blocksRecording else {
            showInstallLocationNotice()
            return
        }

        // Check permission first; if not granted, remain in the current state.
        if permissionStatus != .granted {
            await requestPermission()
            if permissionStatus != .granted {
                return
            }
        }

        // Recording a microphone needs its own grant, and it is a *different*
        // flow rather than the same one parameterised (BL-130): unlike Screen
        // Recording, macOS will genuinely re-prompt for this, so asking is the
        // recovery path rather than a one-shot that must never be wasted.
        //
        // ⚠️ Requesting this without `NSMicrophoneUsageDescription` in the built
        // bundle is an immediate TCC *termination*, not a denial. `InfoPlistTests`
        // asserts the key is in the product for exactly this reason.
        if case .mic = audioSource.selectedSource {
            guard await requestMicrophoneAccess() else {
                transition(to: .error(.microphoneDenied))
                return
            }
        }

        transition(to: .starting)

        do {
            // Wire waveform callback
            controller.onWaveformData = { [weak self] samples in
                Task { @MainActor in
                    self?.waveformSamples = samples
                }
            }
            // Start recording in the selected format (captured here, at start).
            let fileURL = try await controller.startRecording(format: selectedFormat)
            lastRecordingURL = fileURL
            recordingStartTime = clock.now
            duration = 0
            longRecordingWarned = false

            transition(to: .recording)

            // Start duration timer
            startTimer()

            // If the chosen save folder was unavailable, the recording fell back to
            // the Desktop — tell the user (non-blocking; recording continues).
            if saveLocation.isConfiguredLocationUnavailable {
                presentError(RecorderError.saveLocationUnavailable.message, recovery: .chooseFolder)
            }

        } catch RecordingControllerError.insufficientDiskSpace {
            Log.recorder.error("Refusing to record: insufficient disk space")
            transition(to: .error(.diskFull))
        } catch let sourceError as AudioSourceError {
            // Caught ahead of the generic clause on purpose. `AudioSourceError`
            // already writes accurate copy for its two cases — the app quit, the
            // mic was unplugged — and flattening it into `.startFailed` replaced
            // that with "make sure some audio is playing", which cannot help with
            // either. It also offered "Try again", which fails identically.
            Log.recorder.error("Capture source unavailable: \(sourceError.localizedDescription, privacy: .public)")
            transition(to: .error(.sourceUnavailable(sourceError)))
        } catch {
            Log.recorder.error("Failed to start recording: \(error.localizedDescription, privacy: .public)")
            transition(to: .error(.startFailed(error.localizedDescription)))
        }
    }

    /// Stop recording
    func stopRecording() async {
        guard state.canTransition(to: .stopping) else { return }

        transition(to: .stopping)

        // Tear the timer and waveform down on *both* paths. Before BL-016 the
        // catch branch was unreachable for finalize failures (the error was
        // swallowed inside AudioRecorder), so this only started to matter once
        // the error became live: a leaked timer republishes `duration` at 10Hz
        // for the lifetime of the app and can fire the long-recording warning
        // about a recording that has already ended.
        defer {
            stopTimer()
            waveformSamples = Array(repeating: 0, count: 200)
        }

        do {
            try await controller.stopRecording()
            transition(to: .idle)

        } catch {
            Log.recorder.error("Failed to stop recording: \(error.localizedDescription, privacy: .public)")
            transition(to: .error(.stopFailed(error.localizedDescription)))
        }
    }

    /// Toggle recording state
    func toggleRecording() async {
        switch state {
        case .idle, .error:
            await startRecording()
        case .recording:
            await stopRecording()
        case .starting, .stopping, .recovering:
            // Ignore taps during in-flight transitions.
            break
        }
    }

    /// Reveal recording in Finder
    func revealInFinder() {
        guard let url = lastRecordingURL else { return }

        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Open System Settings *and* leave a guide on screen (BL-081).
    ///
    /// Opening the pane alone is where this flow used to end, and it abandoned the
    /// user at the hardest moment: macOS offers no way to scroll to or highlight an
    /// app's row, the system prompt never fires twice, and Home Rec's own copy
    /// ("only captures audio") points people at the one section it isn't listed in.
    /// The panel outlives the focus change and says where to look; the poll loop
    /// notices the grant without the user having to come back and check.
    /// Runtime ordering (BL-082): the install-location check runs *before* the
    /// permission guide, and replaces it entirely when the bundle is translocated.
    /// Telling a translocated user to flip a toggle is actively harmful — they will
    /// do it correctly, the grant will still evaporate on relaunch, and they will
    /// now believe the app simply doesn't work. So neither the guide nor System
    /// Settings is opened in that case.
    /// Registration ordering (BL-087): an app appears in the Screen & System Audio
    /// Recording list only once it has made a registering `SCShareableContent`
    /// call, and the Settings list does not refresh live. Opening the pane in the
    /// same instant as the first probe therefore lands the user in a list Home Rec
    /// is not in yet — and the guide then points at a row that does not exist. So
    /// the probe runs to completion *first*.
    ///
    /// Order is guide → probe → pane on purpose: the guide is instant, so a slow
    /// or hung probe degrades into "panel is up, carrying its own retry button"
    /// rather than a dead click.
    /// Ask for microphone access, prompting if macOS still will (BL-130).
    ///
    /// Separate from `requestPermission()` on purpose. Screen Recording's prompt
    /// is one-shot and unrepeatable, which is why BL-081 built a whole guidance
    /// surface around it; the microphone prompt is re-presentable, so the honest
    /// flow here is simply to ask.
    /// - Returns: whether access is granted.
    func requestMicrophoneAccess() async -> Bool {
        if permissions.preflight(.microphone) == .granted { return true }
        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    /// Change the capture source (BL-111).
    ///
    /// The only write path. `objectWillChange` is sent explicitly because the
    /// selection lives on `AudioSourceManager`, not in a `@Published` property —
    /// without it the status line would keep naming the previous source until
    /// some unrelated state change happened to redraw the view.
    func setCaptureSource(_ source: AudioSource) {
        guard source != audioSource.selectedSource else { return }
        objectWillChange.send()
        audioSource.setSelectedSource(source)
    }

    /// Human-readable name of the current capture source, for the status line.
    /// `nil` for all-system-audio, which needs no qualifier.
    var captureSourceName: String? {
        switch audioSource.selectedSource {
        case .systemAll:
            return nil
        case .app(let bundleID):
            // Falls back to the bundle ID only if this app has never been seen
            // in the picker — which cannot happen for a source the user chose
            // there, but can for a value restored from a much older build.
            return audioSource.knownAppName(forBundleID: bundleID) ?? bundleID
        case .mic(let deviceUID):
            // Devices are enumerable at any time without a prompt, so unlike an
            // app name this never has to fall back to a raw identifier in
            // practice — only if the device was unplugged.
            return audioSource.availableInputDevices()
                .first { $0.uid == deviceUID }?.name ?? "Microphone"
        }
    }

    func openSystemSettings() {
        guard !installLocation.blocksRecording else {
            showInstallLocationNotice()
            return
        }
        // Set here explicitly, not as a side effect of some other call (BL-088):
        // the activation observer's re-probe is gated on this flag, and losing it
        // silently breaks the grant re-detection on returning from Settings.
        hasSoughtPermission = true
        // The main window is the only in-app surface now (BL-088) — no panel. But
        // the grant must still be *noticed* without the user doing anything: a
        // single probe on return can race the TCC write (observed: stuck at
        // "Almost ready" until relaunch), so a bounded poll watches for it and
        // the window flips the moment it lands.
        startGrantWatcher()
        isOpeningSystemSettings = true
        Task { @MainActor in
            await awaitRegistration()
            isOpeningSystemSettings = false
            // Now that the answer is known: if it was already granted, there is
            // nothing to send the user to Settings for.
            guard permissionStatus != .granted else { return }
            permissions.openSystemPreferences()
        }
    }

    /// Start (or resume) watching for the grant. Idempotent.
    private func startGrantWatcher() {
        if grantWatcher == nil {
            let watcher = PermissionGrantWatcher(permissions: permissions, clock: pollClock)
            watcher.onGranted = { [weak self] in
                // Mirror into the app's own state so every surface updates.
                Task { @MainActor in await self?.checkPermission() }
            }
            grantWatcher = watcher
        }
        grantWatcher?.startPolling()
    }

    /// Wait for one authoritative probe, but not forever.
    ///
    /// The bound lives here rather than inside `checkPermission()` for two
    /// reasons. A timeout there would write a false `.denied` into
    /// `permissionStatus` on a merely slow machine — timeouts must never mutate
    /// permission state. And escaping `checkPermission`'s `await probe.value`
    /// early would leave `permissionProbe` set forever, so every later caller
    /// would join a task that never completes.
    ///
    /// The probe is deliberately *not* cancelled when the deadline passes:
    /// registration is the whole point of running it, and it completes in the
    /// background either way. We simply stop waiting.
    private func awaitRegistration() async {
        let probe = Task { await checkPermission() }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // Whichever finishes first wins; the loser's resume is dropped.
            //
            // Deliberately *not* a task group: a group waits for every child as it
            // exits scope, so the deadline could never actually win — it would fire,
            // and then the group would go on waiting for the probe anyway, which is
            // the opposite of a bounded wait. Everything here is main-actor
            // isolated, so the once-only flag needs no locking.
            let resumer = OnceResumer(continuation)
            Task { @MainActor in
                await probe.value
                resumer.resume()
            }
            Task { @MainActor [pollClock, registrationTimeout] in
                try? await pollClock.sleep(for: registrationTimeout)
                resumer.resume()
            }
        }
    }

    // MARK: - Install location (BL-082)

    /// A main window appeared and will render the block itself.
    func mainWindowDidAppear() {
        visibleWindowCount += 1
        // The window is the canonical surface. Anything the panel was saying, it
        // now says — and saying one fact twice at once reads as two faults.
        installNoticePanel?.dismiss()
    }

    /// A main window went away. If that was the last one and the app is blocked,
    /// nothing on screen carries the block any more — which for a menu-bar app
    /// means a silently dead app. That is the panel's remaining job.
    func mainWindowDidDisappear() {
        visibleWindowCount = max(0, visibleWindowCount - 1)
        if installLocation.blocksRecording && visibleWindowCount == 0 {
            showInstallLocationNotice()
        }
    }

    /// Show the install-location explanation.
    ///
    /// The floating panel is a **fallback, not the primary surface**: the main
    /// window and the menu-bar popover both carry the block inline, so the panel
    /// appears only when no window exists to say it — a translocated launch
    /// running as a pure menu-bar presence, where silence would mean a dead app
    /// with no explanation.
    func showInstallLocationNotice() {
        guard let message = installNotice else { return }
        showsInstallLocationNotice = true

        // The window check comes first, ahead of the test seam, so the seam models
        // *panel presentation* rather than "this method was called" — otherwise a
        // test can't tell the suppressed case from the presented one.
        if visibleWindowCount > 0 {
            // A window is already showing this; `orderOut` deliberately leaves
            // `showsInstallLocationNotice` true — the block state persists, only
            // the duplicate surface goes away. (`orderOut` does not fire
            // `windowWillClose`, so `onWillClose` won't clear it either.)
            installNoticePanel?.dismiss()
            return
        }

        if let installNoticePresenter {
            installNoticePresenter()
            return
        }

        if installNoticePanel == nil {
            let panel = FloatingPanelHost(title: "Home Rec", width: 340) { [weak self] in
                AnyView(
                    InstallLocationNoticeView(
                        message: message,
                        onReveal: { self?.revealAppInFinder() },
                        onDismiss: { self?.dismissInstallLocationNotice() }
                    )
                )
            }
            panel.onWillClose = { [weak self] in self?.showsInstallLocationNotice = false }
            installNoticePanel = panel
        }
        installNoticePanel?.show()
    }

    /// Dismiss the notice. A soft note stays dismissed; the hard block will come
    /// back the next time recording is attempted, because nothing has been fixed.
    func dismissInstallLocationNotice() {
        showsInstallLocationNotice = false
        if installLocation.noticeIsDismissible {
            installNoticeDismissed = true
        }
        installNoticePanel?.dismiss()
    }

    /// Reveal the app bundle itself in Finder. The translocated path is randomised
    /// and unguessable, so this is the only practical way for the user to get hold
    /// of the bundle they've been asked to drag.
    func revealAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([installLocationProvider.bundleURL])
    }

    /// Whether the guide panel is currently on screen.
    /// Whether the grant watcher's poll is currently running (BL-088 test seam).
    var grantWatcherIsPolling: Bool { grantWatcher?.isPolling ?? false }

    /// Present the folder chooser; persist the picked directory.
    func chooseSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = saveLocation.resolvedDirectory
        panel.prompt = "Choose"
        panel.message = "Choose where Home Rec saves recordings"

        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            saveLocation.setSaveDirectory(url)
            refreshSaveLocationDisplay()
        }
    }

    /// Reset the save location back to the Desktop default.
    func resetSaveLocation() {
        saveLocation.reset()
        refreshSaveLocationDisplay()
    }

    /// Select the output format for new recordings and persist the choice (BL-015).
    /// No-ops for a format that isn't currently available (defensive — the picker
    /// only offers `AudioFormat.available`).
    func setFormat(_ format: AudioFormat) {
        guard AudioFormat.available.contains(format) else { return }
        selectedFormat = format
        defaults.set(format.rawValue, forKey: selectedFormatKey)
    }

    /// Mark first-run onboarding complete and dismiss it.
    func completeOnboarding() {
        defaults.set(true, forKey: onboardingCompletedKey)
        showOnboarding = false
    }

    /// Re-open the onboarding sheet (e.g. from the Help menu).
    func showOnboardingAgain() {
        showOnboarding = true
    }

    // MARK: - Private Methods

    /// Handle an unexpected capture-stream failure mid-recording: surface the
    /// error state immediately, then finalize the partial recording so the
    /// audio captured before the failure is preserved.
    private func handleStreamFailure(_ message: String) {
        guard state == .recording else { return }
        stopTimer()
        waveformSamples = Array(repeating: 0, count: 200)
        transition(to: .error(.streamFailed(message)))
        Task { [weak self] in
            await self?.controller.finalizeAfterFailure()
        }
    }

    /// Apply a state transition, rejecting illegal ones. Surfaces the alert when
    /// entering an error state.
    private func transition(to next: RecordingState) {
        guard state.canTransition(to: next) else {
            Log.recorder.error("Rejected illegal recording-state transition")
            return
        }
        state = next
        if case .error(let recorderError) = next {
            presentError(recorderError.message, recovery: recorderError.recovery)
        }
    }

    /// Start duration timer
    private func startTimer() {
        clock.startTicking(every: 0.1) { [weak self] in
            guard let self, let startTime = self.recordingStartTime else { return }
            self.duration = self.clock.now.timeIntervalSince(startTime)
            if !self.longRecordingWarned && self.duration >= DiskSpace.longRecordingThreshold {
                self.longRecordingWarned = true
                self.showLongRecordingWarning = true
            }
        }
    }

    /// Stop duration timer
    private func stopTimer() {
        clock.stopTicking()
    }

    /// Present a user-facing error with optional recovery action.
    private func presentError(_ message: String, recovery: RecoverySuggestion?) {
        errorMessage = message
        recoverySuggestion = recovery
        showError = true
    }

    /// Perform the current error's recovery action (from the alert button).
    func performRecovery() {
        let suggestion = recoverySuggestion
        showError = false
        switch suggestion {
        case .openSettings:
            openSystemSettings()
        case .openMicrophoneSettings:
            // Straight to the Microphone pane. The screen-capture flow's
            // registering probe and grant watcher do not apply here: mic access
            // is re-promptable and its status is live rather than latched.
            permissions.openSystemPreferences(for: .microphone)
        case .tryAgain:
            Task { await startRecording() }
        case .chooseFolder:
            chooseSaveLocation()
        case nil:
            break
        }
    }

    /// Refresh the published save-location display from the provider.
    private func refreshSaveLocationDisplay() {
        saveLocationName = saveLocation.configuredDirectory?.lastPathComponent ?? "Desktop"
        hasCustomSaveLocation = saveLocation.configuredDirectory != nil
    }

    /// Read the persisted format, falling back to `.wav` when the stored value is
    /// absent, unparseable, or no longer available (e.g. a format was removed, or
    /// a future build wrote one this build doesn't support). Pure function of its
    /// inputs so it's safe to call during `init`.
    private static func loadFormat(from defaults: UserDefaults, key: String) -> AudioFormat {
        guard
            let raw = defaults.string(forKey: key),
            let format = AudioFormat(rawValue: raw),
            AudioFormat.available.contains(format)
        else {
            return .wav
        }
        return format
    }

    // MARK: - Computed Properties

    /// Formatted duration string (MM:SS)
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Status text.
    ///
    /// This line names the capture source, and that is deliberate rather than
    /// decorative (BL-111). Picking the wrong format is convertible and the wrong
    /// save location is findable, but recording the wrong *source* means the
    /// audio you wanted does not exist — there is no undo for a take. It is the
    /// one setting that earns permanent space on the primary surface.
    ///
    /// It is also why "Play something, then hit record" could not simply stay:
    /// that sentence is itself a source claim, and it is false the moment a
    /// non-system source is selected.
    var statusText: String {
        switch state {
        case .recording:
            if let name = captureSourceName { return "Recording \(name)" }
            return "Recording"
        case .starting:
            return "Starting…"
        case .stopping:
            return "Stopping…"
        case .recovering:
            return "Recovering…"
        case .error:
            return "Something went wrong"
        case .idle:
            // A translocated bundle can't hold a permission grant, so "Almost
            // ready / grant permission" would be a lie — point at the real fix.
            if installLocation.blocksRecording { return "Move to Applications" }
            guard permissionStatus == .granted else { return "Almost ready" }
            // Naming the source here also pre-announces the failure that
            // `AudioSourceManager.validate()` would otherwise only raise *after*
            // the user commits to a click.
            if let name = captureSourceName { return "Ready to record \(name)" }
            return "Play something, then hit record"
        }
    }
}


/// Resumes a continuation exactly once, whichever racer gets there first.
/// Main-actor isolated, so "exactly once" needs no synchronisation.
@MainActor
private final class OnceResumer {
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

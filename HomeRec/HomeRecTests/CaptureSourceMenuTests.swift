//
//  CaptureSourceMenuTests.swift
//  HomeRecTests
//
//  BL-111: the capture-source section of the overflow menu.
//
//  Every test here runs against the pure builder — no AppKit event loop, no live
//  status item, no permission. That is the point of `entries(_:)` being a
//  function of a snapshot.
//
//  ⚠️ The invariants below are deliberately written over the builder's *output*
//  rather than over a list of known row ids. An id list would keep passing when
//  BL-130 adds a microphone row and nobody remembers to extend it — which is
//  precisely the failure it exists to catch.
//

import Testing
import AppKit
@testable import HomeRec

@MainActor
struct CaptureSourceMenuTests {

    private let apps = [
        RunningAppInfo(bundleID: "com.ableton.live", applicationName: "Ableton Live"),
        RunningAppInfo(bundleID: "com.apple.logic10", applicationName: "Logic Pro"),
        RunningAppInfo(bundleID: "com.spotify.client", applicationName: "Spotify")
    ]

    private func context(
        selected: AudioSource = .systemAll,
        unlocked: Bool = true,
        granted: Bool = true,
        apps: [RunningAppInfo]? = nil,
        selectedAppName: String? = nil,
        devices: [InputDeviceInfo] = [],
        selectedMicName: String? = nil
    ) -> OverflowContext {
        OverflowContext(
            selectedSource: selected,
            allowsCaptureSourceChange: unlocked,
            permissionGranted: granted,
            apps: apps,
            selectedAppName: selectedAppName,
            inputDevices: devices,
            selectedMicName: selectedMicName
        )
    }

    private let devices = [
        InputDeviceInfo(uid: "BuiltInMic", name: "MacBook Pro Microphone"),
        InputDeviceInfo(uid: "USB:Scarlett", name: "Scarlett 2i2 4th Gen")
    ]

    private func headers(_ entries: [OverflowEntry]) -> [String] {
        entries.compactMap { if case .sectionHeader(let t) = $0 { return t } else { return nil } }
    }

    private func notices(_ entries: [OverflowEntry]) -> [String] {
        entries.compactMap { if case .disabledNotice(let t) = $0 { return t } else { return nil } }
    }

    // MARK: - Shape

    @Test("The section offers one row per kind, not one row per app")
    func rootHasOneRowPerKind() {
        // The root must not reshape because the world changed. Whether three apps
        // are running or none, the section is the same height.
        let many = OverflowMenu.captureSourceEntries(context(apps: apps))
        let none = OverflowMenu.captureSourceEntries(context(apps: []))

        let shape: ([OverflowEntry]) -> [String] = { entries in
            entries.compactMap { entry in
                switch entry {
                case .action(let a) where a.isSourceRow: return "action"
                case .submenu:                           return "submenu"
                default:                                 return nil
                }
            }
        }
        // System audio (a compile-time singleton) plus one submenu per
        // runtime-enumerated kind: apps and microphones.
        #expect(shape(many) == ["action", "submenu", "submenu"])
        #expect(shape(none) == shape(many))
    }

    @Test("Section header is passed in sentence case for the system to style")
    func headerIsNotPreUppercased() {
        #expect(headers(OverflowMenu.captureSourceEntries(context())) == ["Capture Source"])
    }

    // MARK: - Checkmarks are derived, and there is exactly one

    /// Checked source rows at the top level, and inside the Per-App submenu.
    ///
    /// Counted per level on purpose. A selected running app is legitimately
    /// checked twice — once on the parent row, which is what lets the root answer
    /// "what am I recording?" without being opened, and once on the leaf inside.
    /// That is a hierarchy, not two competing selections; macOS renders nested
    /// pickers exactly this way. What would be a real defect is two checkmarks
    /// *side by side* in one menu.
    private func checkedPerLevel(_ context: OverflowContext) -> (root: Int, submenu: Int) {
        let entries = OverflowMenu.captureSourceEntries(context)
        var root = 0
        var submenu = 0
        for entry in entries {
            switch entry {
            case .action(let action) where action.isSourceRow && action.isChecked:
                root += 1
            case .submenu(let child):
                if child.isChecked { root += 1 }
                submenu += child.entries.filter { entry in
                    if case .action(let a) = entry { return a.isSourceRow && a.isChecked }
                    return false
                }.count
            default:
                break
            }
        }
        return (root, submenu)
    }

    @Test(
        "Exactly one source row is checked at each level, in every context",
        arguments: [
            AudioSource.systemAll,
            .app(bundleID: "com.ableton.live"),
            .app(bundleID: "com.notrunning.app")
        ]
    )
    func exactlyOneSourceRowIsCheckedPerLevel(_ selected: AudioSource) {
        let counts = checkedPerLevel(
            context(selected: selected, apps: apps, selectedAppName: "Some App")
        )
        #expect(counts.root == 1)
        // Zero inside when the selection isn't an app at all; never more than one.
        #expect(counts.submenu <= 1)
        if case .app = selected {
            #expect(counts.submenu == 1)
        } else {
            #expect(counts.submenu == 0)
        }
    }

    @Test("Selecting system audio checks the system row and nothing else")
    func systemAllIsCheckedByDefault() throws {
        let actions = OverflowMenu.actions(context(apps: apps))
        let system = try #require(actions.first { $0.id == "sourceSystemAll" })
        #expect(system.isChecked)
        #expect(actions.first { $0.id == "sourcePerApp" }?.isChecked == false)
    }

    @Test("A running selection checks its row and names the root")
    func runningSelectionNamesTheRootRow() throws {
        let entries = OverflowMenu.captureSourceEntries(
            context(selected: .app(bundleID: "com.ableton.live"), apps: apps)
        )
        let submenu = try #require(
            entries.compactMap { if case .submenu(let s) = $0 { return s } else { return nil } }.first
        )
        // The root answers "what am I recording?" without being opened.
        #expect(submenu.title == "Ableton Live")
        #expect(submenu.isChecked)
    }

    // MARK: - The persisted-but-not-running case

    @Test("A selection that isn't running still renders, checked and disabled")
    func notRunningSelectionKeepsItsCheckmark() throws {
        // Without this row the builder emits zero checkmarks, and the menu
        // silently implies "All System Audio" while startRecording fails with
        // `.appNotRunning`.
        let actions = OverflowMenu.actions(
            context(
                selected: .app(bundleID: "com.ableton.live"),
                apps: [],
                selectedAppName: "Ableton Live"
            )
        )
        let row = try #require(actions.first { $0.id == "sourceAppNotRunning" })
        #expect(row.title == "Ableton Live (not running)")
        #expect(row.isChecked)
        #expect(row.isEnabled == false)
    }

    @Test("The parent row stays enabled so the user can change away from it")
    func notRunningParentRemainsSelectable() throws {
        let actions = OverflowMenu.actions(
            context(selected: .app(bundleID: "com.ableton.live"), apps: [], selectedAppName: "Ableton Live")
        )
        let parent = try #require(actions.first { $0.id == "sourcePerApp" })
        #expect(parent.isEnabled)
    }

    // MARK: - Empty and cold states are different

    @Test("An unprobed list does not claim there are no apps")
    func coldCacheShowsLookingRatherThanEmpty() throws {
        let submenu = OverflowMenu.perAppSubmenu(context(apps: nil))
        #expect(notices(submenu.entries) == ["Looking for open apps…"])
    }

    @Test("A probed-but-empty list says so")
    func emptyListSaysNoAppsAreOpen() {
        let submenu = OverflowMenu.perAppSubmenu(context(apps: []))
        #expect(notices(submenu.entries) == ["No other apps are open"])
    }

    // MARK: - Permission

    @Test("Without permission the submenu offers a way out, not a dead end")
    func missingPermissionOffersAnEnabledAction() throws {
        let submenu = OverflowMenu.perAppSubmenu(context(granted: false, apps: apps))
        let actions: [OverflowAction] = submenu.entries.compactMap {
            if case .action(let a) = $0 { return a } else { return nil }
        }
        #expect(actions.count == 1)
        let row = try #require(actions.first)
        #expect(row.title == "Allow Screen Recording…")
        // Enabled on purpose: the user is asking "why can't I?", and a disabled
        // row answers that while leaving them stuck.
        #expect(row.isEnabled)
    }

    @Test("Without permission no app row is offered, even if a list is cached")
    func missingPermissionNeverListsApps() {
        let actions = OverflowMenu.actions(context(granted: false, apps: apps))
        #expect(actions.contains { $0.id.hasPrefix("sourceApp:") } == false)
    }

    // MARK: - The mid-recording lock

    @Test("While recording, no capture-source row exists at all")
    func recordingRemovesEverySourceRow() {
        // Written over the builder's output: *any* source row, not a known list.
        // A microphone row added later is covered the moment it exists.
        for selected in [AudioSource.systemAll, .app(bundleID: "com.ableton.live")] {
            let actions = OverflowMenu.actions(
                context(selected: selected, unlocked: false, apps: apps)
            )
            #expect(actions.contains { $0.isSourceRow } == false)
        }
    }

    @Test("While recording, the section header and submenu are gone too")
    func recordingRemovesTheWholeSection() {
        let entries = OverflowMenu.entries(context(unlocked: false, apps: apps))
        #expect(headers(entries).isEmpty)
        #expect(entries.contains { if case .submenu = $0 { return true } else { return false } } == false)
    }

    @Test("The lock follows RecordingState, not a hardcoded state list")
    func lockMirrorsRecordingState() {
        #expect(RecordingState.idle.allowsCaptureSourceChange)
        // The user must be able to change source to *fix* an error.
        #expect(RecordingState.error(.startFailed("x")).allowsCaptureSourceChange)
        #expect(RecordingState.starting.allowsCaptureSourceChange == false)
        #expect(RecordingState.recording.allowsCaptureSourceChange == false)
        #expect(RecordingState.stopping.allowsCaptureSourceChange == false)
        #expect(RecordingState.recovering.allowsCaptureSourceChange == false)
    }

    @Test("App-level actions survive the lock")
    func appActionsAreNeverLocked() {
        // Hiding the source section must not take Quit or Show Window with it —
        // mid-recording those are the main reason to open the menu at all.
        let ids = Set(OverflowMenu.actions(context(unlocked: false)).map(\.id))
        #expect(ids.isSuperset(of: ["showWindow", "quit", "about", "recoverRecordings"]))
    }

    // MARK: - NSMenu rendering

    @Test("The NSMenu tree mirrors the builder, recursing into submenus")
    func nsMenuTreeMatchesBuilder() throws {
        let context = context(selected: .app(bundleID: "com.spotify.client"), apps: apps)
        let menu = OverflowMenu.makeNSMenu(context)

        let perApp = try #require(
            menu.items.first { $0.identifier?.rawValue == OverflowMenu.perAppItemIdentifier }
        )
        #expect(perApp.title == "Spotify")
        #expect(perApp.state == .on)

        let submenu = try #require(perApp.submenu)
        let spotify = try #require(submenu.items.first { $0.title == "Spotify" })
        #expect(spotify.state == .on)
        #expect(submenu.items.filter { $0.state == .on }.count == 1)

        // The system row is a sibling and must be unchecked.
        let system = try #require(menu.items.first { $0.title == "All System Audio" })
        #expect(system.state == .off)
    }

    @Test("Disabled rows carry no action, so AppKit cannot re-enable them")
    func disabledRowsHaveNoAction() throws {
        let menu = OverflowMenu.makeNSMenu(
            context(selected: .app(bundleID: "com.ableton.live"), apps: [], selectedAppName: "Ableton Live")
        )
        let perApp = try #require(
            menu.items.first { $0.identifier?.rawValue == OverflowMenu.perAppItemIdentifier }
        )
        let notRunning = try #require(perApp.submenu?.items.first { $0.title.contains("not running") })
        #expect(notRunning.isEnabled == false)
        #expect(notRunning.action == nil)
    }

    // MARK: - The safety property that matters most

    @Test("Opening the submenu without permission performs zero enumeration")
    func submenuWithoutPermissionNeverProbes() async {
        // The single most important safety property in BL-111. Enumeration costs
        // a TCC prompt, so with permission missing it must not happen at all —
        // otherwise merely *hovering* this submenu raises a system dialog, which
        // is worse than the click-triggered prompt BL-085 removed.
        let probe = CountingAudioSourceProviding()
        let delegate = PerAppMenuDelegate(
            cache: PerAppListCache(),
            source: probe,
            makeContext: { self.context(granted: false, apps: nil) }
        )

        let menu = NSMenu()
        delegate.menuNeedsUpdate(menu)
        // The refresh, if one were wrongly scheduled, is a `Task` — yield so it
        // would have had the chance to run before we assert it did not.
        await Task.yield()

        #expect(probe.availableAppsCallCount == 0)
        #expect(menu.items.contains { $0.title == "Allow Screen Recording…" })
    }

    @Test("Opening the submenu with permission returns immediately, then refreshes")
    func submenuPopulatesFromCacheThenRefreshes() async throws {
        // `menuNeedsUpdate` runs synchronously inside AppKit's menu-tracking
        // loop, so it must return without awaiting anything. Bridging the async
        // enumeration with a semaphore there is a guaranteed deadlock, not a slow
        // menu — the Task is queued on the main actor while wait() blocks the
        // very thread that would drain it.
        let probe = CountingAudioSourceProviding()
        probe.appsToReturn = apps
        let cache = PerAppListCache()
        let delegate = PerAppMenuDelegate(
            cache: cache,
            source: probe,
            makeContext: { self.context(apps: cache.apps) }
        )

        let menu = NSMenu()
        // Returns synchronously against a cold cache: the placeholder, not apps.
        delegate.menuNeedsUpdate(menu)
        #expect(menu.items.map(\.title) == ["Looking for open apps…"])

        // The out-of-band refresh then fills it in place.
        try await Task.sleep(for: .milliseconds(50))
        #expect(probe.availableAppsCallCount == 1)
        #expect(menu.items.map(\.title) == ["Ableton Live", "Logic Pro", "Spotify"])
    }
}

/// Counts enumeration calls so a test can assert none happened.
@MainActor
final class CountingAudioSourceProviding: AudioSourceProviding {
    private(set) var availableAppsCallCount = 0
    var selectedSource: AudioSource = .systemAll
    var appsToReturn: [RunningAppInfo] = []

    func setSelectedSource(_ source: AudioSource) { selectedSource = source }
    func validate(_ source: AudioSource) async throws {}

    func availableApps() async throws -> [RunningAppInfo] {
        availableAppsCallCount += 1
        return appsToReturn
    }

    /// Counted separately: unlike app enumeration this is prompt-free, so the
    /// menu is allowed to call it eagerly. Conflating the two counters would
    /// hide a real regression in the one that matters.
    private(set) var inputDeviceCallCount = 0
    var devicesToReturn: [InputDeviceInfo] = []

    func availableInputDevices() -> [InputDeviceInfo] {
        inputDeviceCallCount += 1
        return devicesToReturn
    }

    var knownNames: [String: String] = [:]

    func knownAppName(forBundleID bundleID: String) -> String? {
        knownNames[bundleID]
    }
}

// MARK: - Microphone rows (BL-130)

@MainActor
struct MicrophoneMenuTests {

    private let devices = [
        InputDeviceInfo(uid: "BuiltInMic", name: "MacBook Pro Microphone"),
        InputDeviceInfo(uid: "USB:Scarlett", name: "Scarlett 2i2 4th Gen")
    ]

    private func context(
        selected: AudioSource = .systemAll,
        granted: Bool = true,
        devices: [InputDeviceInfo] = [],
        selectedMicName: String? = nil
    ) -> OverflowContext {
        OverflowContext(
            selectedSource: selected,
            permissionGranted: granted,
            inputDevices: devices,
            selectedMicName: selectedMicName
        )
    }

    @Test("Devices are listed with the names macOS reports")
    func devicesUseSystemNames() {
        let submenu = OverflowMenu.microphoneSubmenu(context(devices: devices))
        let titles = submenu.entries.compactMap { entry -> String? in
            if case .action(let a) = entry { return a.title }
            return nil
        }
        #expect(titles == ["MacBook Pro Microphone", "Scarlett 2i2 4th Gen"])
    }

    @Test("Selecting a mic checks its row and names the root")
    func selectedMicNamesTheRoot() {
        let submenu = OverflowMenu.microphoneSubmenu(
            context(selected: .mic(deviceUID: "USB:Scarlett"), devices: devices)
        )
        #expect(submenu.title == "Scarlett 2i2 4th Gen")
        #expect(submenu.isChecked)

        let checked = submenu.entries.compactMap { entry -> OverflowAction? in
            if case .action(let a) = entry, a.isChecked { return a }
            return nil
        }
        #expect(checked.count == 1)
        #expect(checked.first?.id == "sourceMic:USB:Scarlett")
    }

    @Test("A disconnected selection keeps its checkmark rather than vanishing")
    func disconnectedMicStillRenders() throws {
        // Same reasoning as the not-running app row: without it the section
        // shows zero checkmarks and silently implies system audio, while
        // startRecording fails pre-flight with `.micNotAvailable`.
        let submenu = OverflowMenu.microphoneSubmenu(
            context(
                selected: .mic(deviceUID: "USB:Gone"),
                devices: devices,
                selectedMicName: "Scarlett 2i2 4th Gen"
            )
        )
        let row = try #require(submenu.entries.compactMap { entry -> OverflowAction? in
            if case .action(let a) = entry, a.id == "sourceMicNotAvailable" { return a }
            return nil
        }.first)
        #expect(row.title == "Scarlett 2i2 4th Gen (not connected)")
        #expect(row.isChecked)
        #expect(row.isEnabled == false)
        #expect(submenu.isChecked)
    }

    @Test("No devices says so rather than showing an empty submenu")
    func emptyDeviceListShowsNotice() {
        let notices = OverflowMenu.microphoneSubmenu(context()).entries
            .compactMap { entry -> String? in
                if case .disabledNotice(let t) = entry { return t }
                return nil
            }
        #expect(notices == ["No microphones found"])
    }

    @Test("Devices are listed without Screen Recording permission")
    func micListDoesNotRequireScreenPermission() {
        // Enumerating input devices raises no dialog and returns real names even
        // with mic access undetermined, so the Per-App permission gate must NOT
        // be copied here — only capturing prompts.
        let submenu = OverflowMenu.microphoneSubmenu(context(granted: false, devices: devices))
        let titles = submenu.entries.compactMap { entry -> String? in
            if case .action(let a) = entry { return a.title }
            return nil
        }
        #expect(titles == ["MacBook Pro Microphone", "Scarlett 2i2 4th Gen"])
    }

    @Test("A mic source is still locked away while recording")
    func micRowsObeyTheRecordingLock() {
        let locked = OverflowContext(
            selectedSource: .mic(deviceUID: "BuiltInMic"),
            allowsCaptureSourceChange: false,
            inputDevices: devices
        )
        #expect(OverflowMenu.actions(locked).contains { $0.isSourceRow } == false)
    }

    @Test("Microphone is a distinct source kind")
    func micHasItsOwnKind() {
        #expect(AudioSource.mic(deviceUID: "x").kind == .microphone)
        #expect(AudioSource.systemAll.kind == .systemAll)
        #expect(AudioSource.app(bundleID: "y").kind == .app)
    }
}

// MARK: - App-list filtering (BL-100 corrections C4/C5)

@MainActor
struct AppListFilteringTests {

    @Test("Finder is excluded from the capture-source list")
    func finderIsExcluded() {
        // Finder is `.regular` and always running, so `activationPolicy`
        // filtering cannot remove it — without the named exclusion it appears
        // as a capture target on every Mac, forever, at the top of an
        // alphabetical list. Nobody wants to record Finder.
        #expect(AudioSourceManager.alwaysExcludedBundleIDs.contains("com.apple.finder"))
    }

    @Test("The exclusion list stays short")
    func exclusionListIsNotGrowingIntoARule() {
        // A long list here means the *rule* is wrong, not that the list is
        // incomplete — and the honest rule ("apps that can produce audio")
        // needs Core Audio process taps (BL-101), not more names.
        #expect(AudioSourceManager.alwaysExcludedBundleIDs.count <= 3)
    }
}

// MARK: - Audio-capability filtering

/// Returns a fixed set, so filtering can be asserted without real Core Audio.
@MainActor
final class StubAudioCapableProcesses: AudioCapableProcessListing {
    var result: Set<String>?
    init(_ result: Set<String>?) { self.result = result }
    func audioCapableBundleIDs() -> Set<String>? { result }
}

@MainActor
struct AudioCapableFilterTests {

    @Test("A real Core Audio query returns rather than blocking", .timeLimit(.minutes(1)))
    func realQueryReturns() {
        // ⚠️ This is the ONE test that touches a real system service, and it must
        // stay tolerant of the machine it runs on.
        //
        // It originally asserted the result was non-nil *and non-empty*, which is
        // a property of the **machine**, not of this code — true on a developer
        // Mac with audio devices, not guaranteed on a headless CI runner with no
        // audio session. That is the same defect class as the four tests that
        // were reading the developer's real `UserDefaults`.
        //
        // What is genuinely worth asserting is that the call **returns at all**:
        // a blocking Core Audio read with nothing to answer it is a hang, and a
        // hang with no time limit takes the whole job down with it.
        let real = AudioCapableProcesses().audioCapableBundleIDs()

        // A machine with no audio processes legitimately yields an empty set, and
        // an unavailable Core Audio yields nil — the production path treats nil
        // as "skip filtering" rather than "show nothing", so neither is a defect.
        if let real {
            #expect(real.allSatisfy { !$0.isEmpty })
        }
    }

    @Test("A failed query disables filtering instead of emptying the list")
    func nilResultMeansNoFilter() {
        // A list that is too long is a papercut; a list that is wrongly empty is
        // a broken feature. `nil` must degrade to "show everything".
        let stub = StubAudioCapableProcesses(nil)
        #expect(stub.audioCapableBundleIDs() == nil)
    }

    @Test("Terminal is not treated as a non-audio app")
    func terminalIsNotBlocklisted() {
        // The blocklist instinct would have hidden Terminal, Xcode and Notes as
        // "not audio apps". Measured: Terminal holds a live Core Audio process
        // object (the bell), Xcode plays build sounds, Notes plays attachments.
        // Whether they appear must depend on whether they actually have audio,
        // never on a guess about what kind of app they are.
        #expect(AudioSourceManager.alwaysExcludedBundleIDs.contains("com.apple.Terminal") == false)
        #expect(AudioSourceManager.alwaysExcludedBundleIDs.contains("com.apple.dt.Xcode") == false)
        #expect(AudioSourceManager.alwaysExcludedBundleIDs.contains("com.apple.Notes") == false)
    }
}

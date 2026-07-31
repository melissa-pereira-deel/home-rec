//
//  AudioSourceManager.swift
//  HomeRec
//
//  Owns capture-source selection for BL-100: persists the user's choice,
//  enumerates currently running apps for the picker, and validates a source
//  is still capturable before a recording starts.
//

import AppKit
import Foundation
import ScreenCaptureKit

/// A running app the capture-source picker can offer, as seen by ScreenCaptureKit.
struct RunningAppInfo: Identifiable, Sendable, Equatable {
    var id: String { bundleID }
    let bundleID: String
    let applicationName: String
}

enum AudioSourceError: Error, LocalizedError, Equatable {
    case appNotRunning(String)
    /// The selected input device is no longer connected (BL-130).
    case micNotAvailable(String)

    var errorDescription: String? {
        switch self {
        case .appNotRunning(let bundleID):
            return "The selected app (\(bundleID)) is not currently running."
        case .micNotAvailable:
            return "The selected microphone isn't connected."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .appNotRunning:
            return "Open the app, or choose a different capture source."
        case .micNotAvailable:
            return "Reconnect it, or choose a different capture source."
        }
    }
}

@MainActor
protocol AudioSourceProviding: AnyObject {
    /// The persisted capture source. Defaults to `.systemAll` on first run.
    var selectedSource: AudioSource { get }
    func setSelectedSource(_ source: AudioSource)
    /// Throws `AudioSourceError` if `source` cannot be captured right now
    /// (e.g. the selected app isn't running). Call before starting capture.
    func validate(_ source: AudioSource) async throws
    /// Currently running apps the picker can offer, excluding Home Rec itself.
    ///
    /// ⚠️ **This calls `SCShareableContent` directly, bypassing `PermissionProviding`.**
    /// That means it can raise the system permission dialog and registers the app
    /// with TCC — so it must never run on a zero-click path (BL-085). It is safe
    /// today only because nothing reaches it without a Record click.
    ///
    /// **Precondition for BL-100's source picker:** SwiftUI evaluates `Menu`
    /// content eagerly in several situations, so a naïvely wired picker would call
    /// this on *popover appearance* — a zero-click prompt. Enumerate only on an
    /// explicit submenu open, and only when `permissionStatus == .granted`.
    func availableApps() async throws -> [RunningAppInfo]
    /// Currently connected input devices (BL-130). Synchronous and prompt-free.
    func availableInputDevices() -> [InputDeviceInfo]
    /// Last-known display name for a bundle ID, or nil if never seen.
    ///
    /// `AudioSource.app` persists only a bundle ID, so without this the UI has
    /// nothing to show but the raw identifier. Reading it must never enumerate —
    /// that would cost a permission prompt on whatever path asked.
    func knownAppName(forBundleID bundleID: String) -> String?
}

@MainActor
final class AudioSourceManager: AudioSourceProviding {
    private let defaults: UserDefaults
    private let deviceEnumerator: InputDeviceEnumerating
    private let audioProcesses: AudioCapableProcessListing
    private let key = "selectedAudioSource"
    private let namesKey = "knownAppNames"

    /// Apps that pass every other filter but that nobody would ever choose to
    /// record.
    ///
    /// Finder is user-facing (`activationPolicy == .regular`) and always running,
    /// so the policy filter cannot remove it — it would otherwise appear as a
    /// capture target on every Mac, forever, at the top of an alphabetical list.
    ///
    /// Kept even though `AudioCapableProcesses` now does the real filtering:
    /// Finder does hold audio objects on some systems (Quick Look preview
    /// playback runs under it), so the audio-capability rule alone would not
    /// reliably remove it — and it is never a thing anyone means to record.
    ///
    /// Keep this list short. It is a patch over specific known-wrong entries,
    /// **not** a substitute for a rule; if it starts growing, the filter above it
    /// is what needs fixing.
    static let alwaysExcludedBundleIDs: Set<String> = [
        "com.apple.finder"
    ]

    /// Read-through cache. The getter used to hit `UserDefaults` *and* run a
    /// `JSONDecoder` on every access; the menu builder reads it once per row, so
    /// that cost is now per-launch instead of per-read.
    ///
    /// This is also why there must be exactly one `AudioSourceManager` in the app
    /// (resolved in `RecorderViewModel.init`): two caches would diverge, and a
    /// source picked in the menu would be silently ignored by the next recording.
    private var cachedSource: AudioSource?

    init(
        defaults: UserDefaults = .standard,
        deviceEnumerator: InputDeviceEnumerating? = nil,
        audioProcesses: AudioCapableProcessListing? = nil
    ) {
        self.defaults = defaults
        self.deviceEnumerator = deviceEnumerator ?? InputDeviceEnumerator()
        self.audioProcesses = audioProcesses ?? AudioCapableProcesses()
    }

    /// Input devices for the picker.
    ///
    /// Unlike `availableApps()` this needs **no permission gate**: discovery
    /// returns real device names with microphone authorization still
    /// `.notDetermined` and raises no dialog. Only actually *capturing* prompts.
    func availableInputDevices() -> [InputDeviceInfo] {
        deviceEnumerator.availableInputDevices()
    }

    /// Bundle ID → display name, remembered from the last enumeration.
    ///
    /// Persisted because the selection is: after a relaunch the app list has not
    /// been enumerated yet (that needs a deliberate submenu open), so without
    /// this the status line would show a raw bundle ID until the user happened
    /// to open the picker again.
    private lazy var knownAppNames: [String: String] =
        defaults.dictionary(forKey: namesKey) as? [String: String] ?? [:]

    func knownAppName(forBundleID bundleID: String) -> String? {
        knownAppNames[bundleID]
    }

    private func rememberNames(_ apps: [RunningAppInfo]) {
        var changed = false
        for app in apps where knownAppNames[app.bundleID] != app.applicationName {
            knownAppNames[app.bundleID] = app.applicationName
            changed = true
        }
        // Only touch UserDefaults when something actually moved — this runs on
        // every submenu open.
        if changed { defaults.set(knownAppNames, forKey: namesKey) }
    }

    var selectedSource: AudioSource {
        if let cachedSource { return cachedSource }
        let decoded = Self.decodeSource(from: defaults, key: key)
        cachedSource = decoded
        return decoded
    }

    /// ⚠️ Decode failures fall back to `.systemAll` rather than throwing, and
    /// that is load-bearing: it is what makes a **downgrade** safe. An older
    /// build reading a newer build's `.mic` selection (BL-130) decodes nothing it
    /// understands and quietly resets to system audio. Turning this into a
    /// throwing decode would convert a silent, correct recovery into an error.
    ///
    /// The corrupt blob is deliberately left in place, not overwritten, so
    /// re-upgrading restores the user's real selection.
    private static func decodeSource(from defaults: UserDefaults, key: String) -> AudioSource {
        guard let data = defaults.data(forKey: key),
              let source = try? JSONDecoder().decode(AudioSource.self, from: data) else {
            return .systemAll
        }
        return source
    }

    func setSelectedSource(_ source: AudioSource) {
        guard let data = try? JSONEncoder().encode(source) else { return }
        // Write through: cache first so a read in the same turn can't observe the
        // stale value, then persist.
        cachedSource = source
        defaults.set(data, forKey: key)
    }

    func validate(_ source: AudioSource) async throws {
        switch source {
        case .systemAll:
            return
        case .app(let bundleID):
            let apps = try await availableApps()
            guard apps.contains(where: { $0.bundleID == bundleID }) else {
                throw AudioSourceError.appNotRunning(bundleID)
            }
        case .mic(let deviceUID):
            // Fail here rather than letting `startCapture` fail obscurely with a
            // device that was unplugged since it was chosen (BL-130).
            guard deviceEnumerator.availableInputDevices().contains(where: { $0.uid == deviceUID }) else {
                throw AudioSourceError.micNotAvailable(deviceUID)
            }
        }
    }

    func availableApps() async throws -> [RunningAppInfo] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        let ownBundleID = Bundle.main.bundleIdentifier
        // `SCShareableContent.applications` includes background agents, helpers
        // and daemons — expect 100+ entries, almost none of them things a person
        // would choose to record. Intersect with the apps macOS itself considers
        // user-facing (BL-100 correction C4).
        let userFacing = Set(
            NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap(\.bundleIdentifier)
        )

        // Narrow to apps that actually have audio. Without this the list is
        // every open window on the Mac — Notes, Xcode, a text editor — none of
        // which anyone scrolls past on purpose.
        //
        // `nil` means Core Audio could not answer, in which case skip the filter
        // rather than showing an empty picker: too long is a papercut, wrongly
        // empty is a broken feature.
        let audioCapable = audioProcesses.audioCapableBundleIDs()

        // The current selection always survives the filter. An app that has not
        // touched audio *yet* holds no Core Audio object, so a DAW sitting idle
        // could otherwise drop out of the list and take the user's own choice
        // with it — leaving the menu implying something they never picked.
        var keep: Set<String>?
        if var audioCapable {
            if case .app(let selectedBundleID) = selectedSource {
                audioCapable.insert(selectedBundleID)
            }
            keep = audioCapable
        }

        var seen = Set<String>()
        let apps = content.applications
            .filter { $0.bundleIdentifier != ownBundleID }
            .filter { userFacing.contains($0.bundleIdentifier) }
            .filter { !Self.alwaysExcludedBundleIDs.contains($0.bundleIdentifier) }
            .filter { keep?.contains($0.bundleIdentifier) ?? true }
            // An app running twice appears twice. There is nowhere to put a PID:
            // `AudioSource.app` carries only a bundle ID, and a PID would not
            // survive the relaunch that persistence requires. So all instances
            // are one entry, and capture resolves to whichever SCK returns first
            // (BL-100 correction C5).
            .filter { seen.insert($0.bundleIdentifier).inserted }
            .map { RunningAppInfo(bundleID: $0.bundleIdentifier, applicationName: $0.applicationName) }
            // Flat and alphabetical. The "audio-producing apps first" ordering in
            // the original spec is unimplementable here — ScreenCaptureKit
            // exposes no is-this-app-making-sound signal (correction C2).
            .sorted { $0.applicationName.localizedStandardCompare($1.applicationName) == .orderedAscending }
        // Enumeration is the only place names are available, and it is gated
        // behind permission and a deliberate submenu open. Capture them here so
        // every other surface can name the selection without enumerating.
        rememberNames(apps)
        return apps
    }
}

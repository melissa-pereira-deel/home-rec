//
//  OverflowContext.swift
//  HomeRec
//
//  The immutable snapshot `OverflowMenu.entries(_:)` builds from (BL-111).
//
//  The menu is rebuilt from scratch every time it opens, so every piece of
//  visible state — which source is checked, whether the section is shown at all —
//  is *derived* from this struct rather than stored anywhere. Desync between the
//  menu and the real selection is therefore unrepresentable, not merely avoided.
//

import Foundation

/// Everything the overflow menu needs to know, captured at the moment it opens.
struct OverflowContext: Sendable, Equatable {

    /// The persisted capture source.
    var selectedSource: AudioSource = .systemAll

    /// Whether the capture-source section should be offered at all.
    ///
    /// Mirrors `RecordingState.allowsCaptureSourceChange`. Held as a plain Bool
    /// rather than the state itself so the builder stays a pure function of data
    /// and tests can construct the locked case without a state machine.
    var allowsCaptureSourceChange: Bool = true

    /// Screen Recording permission. Gates *all* app enumeration: without it, the
    /// submenu must show an explanatory row and perform zero `SCShareableContent`
    /// calls, or merely hovering would raise a system dialog.
    var permissionGranted: Bool = true

    /// Running apps for the Per-App submenu.
    ///
    /// `nil` means "not loaded yet" — the cache is cold and no probe has run.
    /// That is different from `[]`, which means a probe ran and found nothing.
    /// Collapsing the two would show "no apps are open" before we ever looked.
    var apps: [RunningAppInfo]?

    /// Display name for the selected app when it is *not* in `apps` — i.e. it was
    /// picked in an earlier session and isn't running now.
    ///
    /// `AudioSource.app` persists only a bundle ID, so without a remembered name
    /// there is nothing to render but the raw identifier.
    var selectedAppName: String?

    /// Connected input devices (BL-130).
    ///
    /// Not optional, unlike `apps`: enumeration is synchronous and prompt-free,
    /// so there is no "not probed yet" state to distinguish — an empty list
    /// genuinely means no microphones.
    var inputDevices: [InputDeviceInfo] = []

    /// Remembered name for a selected device that is no longer connected.
    var selectedMicName: String?

    init(
        selectedSource: AudioSource = .systemAll,
        allowsCaptureSourceChange: Bool = true,
        permissionGranted: Bool = true,
        apps: [RunningAppInfo]? = nil,
        selectedAppName: String? = nil,
        inputDevices: [InputDeviceInfo] = [],
        selectedMicName: String? = nil
    ) {
        self.selectedSource = selectedSource
        self.allowsCaptureSourceChange = allowsCaptureSourceChange
        self.permissionGranted = permissionGranted
        self.apps = apps
        self.selectedAppName = selectedAppName
        self.inputDevices = inputDevices
        self.selectedMicName = selectedMicName
    }
}

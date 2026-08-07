//
//  PermissionKind.swift
//  HomeRec
//
//  Which system permission is being requested, and everything the user needs to
//  find it in System Settings (BL-081).
//
//  The navigation copy lives here rather than in a view because it changes as a
//  *unit* — the pane heading, the confusable neighbour, and the deep-link anchor
//  are three facets of one fact, and they move together. When Apple renames a
//  pane, or when BL-101 moves system-audio capture to the audio-only permission,
//  this file is the whole diff.
//

import Foundation

enum PermissionKind: Sendable {
    /// Screen Recording — what ScreenCaptureKit requires, including for audio-only use.
    case screenCapture
    /// Microphone input (BL-130). Unlike screen capture this one is genuinely
    /// re-promptable via `AVCaptureDevice.requestAccess`, and its status is not
    /// latched — so the two kinds share *data*, not a flow. Do not generalise
    /// the request path across them.
    case microphone
    // BL-101 moves system capture to an audio-only kind.

    /// Anchor for `x-apple.systempreferences:` deep links.
    var settingsAnchor: String {
        switch self {
        case .screenCapture: return "Privacy_ScreenCapture"
        case .microphone:    return "Privacy_Microphone"
        }
    }

    /// The System Settings pane heading the user must find Home Rec under.
    ///
    /// ⚠️ This is an OS-vendor UI label with no API to read it, so it cannot be
    /// verified at runtime and **will silently rot** across macOS releases and
    /// locales. Verified against macOS 26.5.2 (2026-07-26). If a user reports the
    /// guidance naming a section that doesn't exist, this is the line to check.
    var settingsSectionName: String {
        switch self {
        case .screenCapture: return "Screen & System Audio Recording"
        case .microphone:    return "Microphone"
        }
    }

    /// The section users look in *first* and don't find the app in.
    ///
    /// Home Rec's own copy truthfully says it only captures audio, which sends
    /// people straight to "System Audio Recording Only" — where Home Rec is not,
    /// because ScreenCaptureKit registers under the screen permission. Naming the
    /// wrong section explicitly is the single highest-leverage sentence in this
    /// flow; without it the guidance fights the reassurance.
    var confusableSectionName: String? {
        switch self {
        case .screenCapture: return "System Audio Recording Only"
        // No confusable neighbour: "Microphone" is its own pane and users find
        // it. The disambiguation sentence exists for screen capture only.
        case .microphone:    return nil
        }
    }

    /// The one place the two section names are combined into prose. Phrased as an
    /// observation about macOS rather than a numbered step, so a future rename is
    /// a string edit and not a rewrite of the surrounding instructions.
    var navigationHint: String {
        guard let confusable = confusableSectionName else {
            return "macOS lists Home Rec under \(settingsSectionName)."
        }
        return "macOS lists Home Rec under \(settingsSectionName), "
             + "not the \u{201C}\(confusable)\u{201D} list below it."
    }
}

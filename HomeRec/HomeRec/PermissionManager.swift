//
//  PermissionManager.swift
//  HomeRec
//
//  Screen Recording permission: probing current state and opening the pane where
//  the user grants it.
//

import Foundation
import AVFoundation
import ScreenCaptureKit
import AppKit
import CoreGraphics

/// Permission status states
enum PermissionStatus {
    case notDetermined
    case granted
    case denied
}

/// Manages the system permissions Home Rec depends on.
class PermissionManager: PermissionProviding {

    /// Silent, launch-only read. See `PermissionProviding.preflight` for the
    /// latching behaviour that makes this unusable for observing changes.
    ///
    /// `CGPreflightScreenCaptureAccess` is **not** deprecated — plain
    /// `API_AVAILABLE(macos(10.15))` in `CGWindow.h` on the current SDK. The
    /// project previously believed otherwise; the real reason it can't replace
    /// `checkPermission` is that its answer is frozen at process start (BL-085).
    ///
    /// Returns `.denied` rather than `.notDetermined` when access is absent: the
    /// API is a `Bool` and cannot distinguish "never asked" from "refused", and
    /// the UI treats both identically (offer the guide).
    func preflight(_ kind: PermissionKind = .screenCapture) -> PermissionStatus {
        switch kind {
        case .screenCapture:
            return CGPreflightScreenCaptureAccess() ? .granted : .denied
        case .microphone:
            // ⚠️ The "latched at process start" caveat above is a *screen
            // capture* property, not a general one. `AVCaptureDevice`'s status
            // is live and updates within the session, so for this kind preflight
            // is trustworthy at any time — not only at launch.
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:                 return .granted
            case .notDetermined:              return .notDetermined
            case .denied, .restricted:        return .denied
            @unknown default:                 return .denied
            }
        }
    }

    /// Probe current permission state, authoritatively and live.
    ///
    /// For `.screenCapture` this doubles as registration: a `SCShareableContent`
    /// call is what puts Home Rec into the System Settings list in the first
    /// place, and on a fresh install it triggers the one-time system prompt.
    /// Because of that side effect it must stay behind a deliberate user action
    /// or the on-screen guide — never on launch or idle activation (BL-085).
    func checkPermission(_ kind: PermissionKind = .screenCapture) async -> PermissionStatus {
        switch kind {
        case .screenCapture:
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                return .granted
            } catch {
                return .denied
            }
        case .microphone:
            // No probing side effect to worry about here: reading the status is
            // free and silent. Unlike `SCShareableContent`, it neither prompts
            // nor registers the app anywhere.
            return preflight(.microphone)
        }
    }

    /// Probe, prompting if macOS still can.
    ///
    /// The system prompt only ever appears once; after a deny or a dismiss there is
    /// no second chance at it, which is why the in-app guide (BL-081) is the real
    /// recovery path rather than a nicety.
    ///
    /// This deliberately does **not** open System Settings any more (BL-087). It
    /// used to, as a side effect, which meant the record-while-denied path opened
    /// the pane once with no guide attached and then again via the error's
    /// recovery action. The view model owns every decision to open Settings, so
    /// that every one of them is registered, guided, and granted-gated.
    func requestPermission(_ kind: PermissionKind = .screenCapture) async -> Bool {
        await checkPermission(kind) == .granted
    }

    /// Open System Settings at the pane for `kind`.
    ///
    /// Deep-linking to the pane is the most macOS allows — there is no API to
    /// scroll to or highlight our row, which is why the guide has to describe
    /// where to look instead.
    func openSystemPreferences(for kind: PermissionKind = .screenCapture) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(kind.settingsAnchor)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

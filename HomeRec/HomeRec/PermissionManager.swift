//
//  PermissionManager.swift
//  HomeRec
//
//  Handles Screen Recording permission required for Core Audio Taps API
//

import Foundation
import ScreenCaptureKit
import AppKit

/// Permission status states
enum PermissionStatus {
    case notDetermined
    case granted
    case denied
}

/// Manages Screen Recording permission (required for Core Audio Taps)
class PermissionManager {

    /// Check current Screen Recording permission status using SCShareableContent.
    /// This also registers the app in System Settings > Screen Recording.
    /// - Returns: Current permission status
    static func checkPermission() async -> PermissionStatus {
        do {
            // Probing SCShareableContent registers the app in the Screen Recording list
            // and succeeds only if permission is already granted.
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return .granted
        } catch {
            return .denied
        }
    }

    /// Request Screen Recording permission.
    /// Probes SCShareableContent to register the app, then opens System Settings
    /// so the user can flip the toggle (the app will now appear in the list).
    /// - Returns: True if permission is already granted, false otherwise
    @MainActor
    static func requestPermission() async -> Bool {
        let status = await checkPermission()
        if status == .granted {
            return true
        }
        // The probe above registered the app; now open Settings so the user can enable it
        openSystemPreferences()
        return false
    }

    /// Open System Settings to Screen Recording privacy pane
    static func openSystemPreferences() {
        // Open System Settings to Privacy & Security > Screen Recording
        if #available(macOS 13.0, *) {
            // macOS Ventura and later
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        } else {
            // Fallback for older versions
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

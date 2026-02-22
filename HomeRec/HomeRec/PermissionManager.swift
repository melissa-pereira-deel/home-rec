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

    /// Check current Screen Recording permission status
    /// - Returns: Current permission status
    static func checkPermission() -> PermissionStatus {
        // Check if we can get screen content
        // This is a proxy for Screen Recording permission
        if #available(macOS 14.0, *) {
            // For macOS 14+, use ScreenCaptureKit
            // If we can query content, we have permission
            let canCapture = CGPreflightScreenCaptureAccess()
            return canCapture ? .granted : .denied
        } else {
            return .denied
        }
    }

    /// Request Screen Recording permission
    /// - Returns: True if permission is granted, false otherwise
    @MainActor
    static func requestPermission() async -> Bool {
        if #available(macOS 14.0, *) {
            // Request permission - this will show system dialog if needed
            _ = CGRequestScreenCaptureAccess()

            // Wait a moment for the system dialog
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Check final status
            return CGPreflightScreenCaptureAccess()
        } else {
            return false
        }
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

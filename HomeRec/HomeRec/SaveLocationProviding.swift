//
//  SaveLocationProviding.swift
//  HomeRec
//
//  Where recordings are saved. Persists a user-chosen directory (plain path —
//  the app isn't sandboxed, so no security-scoped bookmark is needed) and always
//  resolves to a valid, writable directory, falling back to the Desktop so a
//  recording is never lost. (BL-010)
//

import Foundation

@MainActor
protocol SaveLocationProviding: AnyObject {
    /// The user's configured directory, or `nil` when using the default (Desktop).
    /// May point at a folder that no longer exists — for display only.
    var configuredDirectory: URL? { get }
    /// A resolved, writable directory to record into. Falls back to the Desktop
    /// if the configured directory is missing, not a directory, or unwritable.
    var resolvedDirectory: URL { get }
    /// True when a custom directory is configured but currently unusable (so
    /// `resolvedDirectory` has fallen back to the Desktop).
    var isConfiguredLocationUnavailable: Bool { get }
    func setSaveDirectory(_ url: URL)
    func reset()
}

@MainActor
final class SaveLocationManager: SaveLocationProviding {
    private let defaults: UserDefaults
    private let key = "saveLocationPath"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The Desktop, or the home directory if Desktop can't be resolved. Never force-unwrapped.
    private var desktop: URL {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    var configuredDirectory: URL? {
        guard let path = defaults.string(forKey: key) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    var resolvedDirectory: URL {
        if let configured = configuredDirectory, Self.isWritableDirectory(configured) {
            return configured
        }
        return desktop
    }

    var isConfiguredLocationUnavailable: Bool {
        guard let configured = configuredDirectory else { return false }
        return !Self.isWritableDirectory(configured)
    }

    func setSaveDirectory(_ url: URL) {
        defaults.set(url.path, forKey: key)
    }

    /// Clears the custom location; resolution falls back to the Desktop.
    func reset() {
        defaults.removeObject(forKey: key)
    }

    private static func isWritableDirectory(_ url: URL) -> Bool {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }
        return fm.isWritableFile(atPath: url.path)
    }
}

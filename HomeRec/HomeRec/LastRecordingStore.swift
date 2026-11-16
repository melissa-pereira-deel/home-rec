//
//  LastRecordingStore.swift
//  HomeRec
//
//  Remembers the last recording across launches, so the popover's
//  last-recording row is still there the next time the app opens (BL-143).
//  A plain path, as for the save folder: the app isn't sandboxed, so no
//  security-scoped bookmark is needed.
//

import Foundation
import os

@MainActor
final class LastRecordingStore {
    private let defaults: UserDefaults
    private let key = "lastRecordingPath"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The remembered recording, if it is still where it was saved.
    ///
    /// A file that has been moved or deleted is forgotten here, not just
    /// skipped: the row would offer a Reveal that can only fail, and a file
    /// that later reappears at the same path is not one the user asked to see.
    func load() -> URL? {
        guard let path = defaults.string(forKey: key) else { return nil }
        guard FileManager.default.fileExists(atPath: path) else {
            Log.recorder.info("The last recording is no longer where it was saved; forgetting it")
            save(nil)
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    func save(_ url: URL?) {
        if let url {
            defaults.set(url.path, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

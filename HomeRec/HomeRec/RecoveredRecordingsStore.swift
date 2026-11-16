//
//  RecoveredRecordingsStore.swift
//  HomeRec
//
//  Remembers which interrupted recordings the user has already recovered, so
//  Recover Recordings does not offer them again after a relaunch (BL-140a).
//  M4A repair is a no-op, so a recovered M4A still looks interrupted to the
//  detector; without this, it came back every launch.
//

import Foundation
import os

/// Tells one file at a path apart from a later file at the same path.
///
/// A path alone cannot: a recording deleted after it was recovered, and a new
/// take interrupted under the same name, share it. The file number is the
/// inode, which APFS hands out in increasing order rather than reusing; the
/// creation date backs it up on filesystems whose file numbers are less
/// dependable. Neither changes when the file is written to in place.
nonisolated struct FileIdentity: Codable, Equatable, Sendable {
    let fileNumber: UInt64?
    let creationDate: Date?

    /// `nil` when there is no identifiable regular file at `path`.
    ///
    /// Read through `FileManager` rather than `URLResourceValues`: a URL caches
    /// its resource values, so a URL kept from before a delete and recreate
    /// could report the old file.
    init?(atPath path: String) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              attributes[.type] as? FileAttributeType == .typeRegular else { return nil }
        let fileNumber = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
        let creationDate = attributes[.creationDate] as? Date
        guard fileNumber != nil || creationDate != nil else { return nil }
        self.fileNumber = fileNumber
        self.creationDate = creationDate
    }
}

@MainActor
final class RecoveredRecordingsStore {
    static let defaultsKey = "recoveredRecordings"
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The recovered files, keyed by path, that are still the file the user
    /// recovered.
    ///
    /// Everything else is forgotten here, and the shorter list written back, so
    /// the list only ever holds files that exist. A file that has gone cannot
    /// come back as the same file, and one replaced by a new file at the same
    /// path never matches again.
    func load() -> [String: FileIdentity] {
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return [:] }
        let stored: [String: FileIdentity]
        do {
            stored = try PropertyListDecoder().decode([String: FileIdentity].self, from: data)
        } catch {
            // Only costs re-offering recordings already recovered, which
            // Recover then hides again.
            Log.file.error("Could not read the recovered recordings list; starting a new one: \(error.localizedDescription, privacy: .public)")
            defaults.removeObject(forKey: Self.defaultsKey)
            return [:]
        }

        let current = stored.filter { path, identity in FileIdentity(atPath: path) == identity }
        if current.count != stored.count {
            Log.file.info("Forgetting \(stored.count - current.count) recovered recordings that are no longer there")
            save(current)
        }
        return current
    }

    func save(_ recovered: [String: FileIdentity]) {
        guard !recovered.isEmpty else {
            defaults.removeObject(forKey: Self.defaultsKey)
            return
        }
        do {
            defaults.set(try PropertyListEncoder().encode(recovered), forKey: Self.defaultsKey)
        } catch {
            Log.file.error("Could not save the recovered recordings list: \(error.localizedDescription, privacy: .public)")
        }
    }
}

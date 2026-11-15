//
//  DiskSpace.swift
//  HomeRec
//
//  Guardrails so a forgotten or doomed recording can't silently fill the disk
//  or surprise the user. (BL-043)
//

import Foundation

/// `nonisolated` on the type, not on each member. Two of the functions below
/// were already annotated individually while the constants they read were left
/// to infer `@MainActor` from the target default — so a `nonisolated` function
/// referenced main-actor state, which is an error in the Swift 6 language mode.
/// Nothing here is mutable or actor-bound: two constants and two pure
/// functions over a `URL`.
nonisolated enum DiskSpace {
    /// Minimum free space required to begin a recording (~8 min of WAV headroom
    /// at ~11.5 MB/min). Below this, starting is refused with a clear message.
    static let minimumBytesToRecord: Int64 = 100 * 1024 * 1024  // 100 MB

    /// A single recording passing this length triggers a one-time warning.
    static let longRecordingThreshold: TimeInterval = 30 * 60   // 30 minutes

    /// Whether there's enough free space to start a recording.
    static func hasEnoughSpace(availableBytes: Int64) -> Bool {
        availableBytes >= minimumBytesToRecord
    }

    /// Available capacity (for important usage) on the volume holding `url`,
    /// or `nil` if it can't be determined.
    static func availableBytes(at url: URL) -> Int64? {
        let directory = url.deletingLastPathComponent()
        let values = try? directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}

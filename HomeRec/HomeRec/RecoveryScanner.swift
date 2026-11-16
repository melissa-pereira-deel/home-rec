//
//  RecoveryScanner.swift
//  HomeRec
//
//  BL-140: finds recordings that were never finalized — the ones a crash or
//  force-quit left behind. Detection itself belongs to each format (see
//  `AudioFileRecovery.swift`); this type only decides *which files to ask about*.
//

import Foundation

/// One recording the user could recover.
struct RecoverableRecording: Identifiable, Equatable {
    var id: URL { url }
    let url: URL
    let format: AudioFormat
    let byteCount: Int
    let modifiedAt: Date
    /// False when the file was interrupted so early that no audio reached disk —
    /// listed for honesty, but `recover` cannot help it.
    let isRepairable: Bool
    let identity: FileIdentity

    var displayName: String { url.lastPathComponent }
}

@MainActor
protocol RecoveryScanning {
    /// - Parameter excluding: the file currently being written, if any. A live
    ///   recording is unfinalized *by definition* and must never be offered.
    func scan(excluding inProgress: URL?) -> [RecoverableRecording]
    func candidate(at url: URL, excluding inProgress: URL?) -> RecoverableRecording?
}

@MainActor
final class RecoveryScanner: RecoveryScanning {

    private let saveLocation: SaveLocationProviding
    private let fileManager: FileManager

    init(saveLocation: SaveLocationProviding, fileManager: FileManager = .default) {
        self.saveLocation = saveLocation
        self.fileManager = fileManager
    }

    func scan(excluding inProgress: URL? = nil) -> [RecoverableRecording] {
        let directory = saveLocation.resolvedDirectory
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )) ?? []

        return contents.compactMap { Self.inspect(at: $0, excluding: inProgress) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func candidate(at url: URL, excluding inProgress: URL?) -> RecoverableRecording? {
        guard url.standardizedFileURL.deletingLastPathComponent().path
                == saveLocation.resolvedDirectory.standardizedFileURL.path else { return nil }
        return Self.inspect(at: url, excluding: inProgress)
    }

    private static func inspect(at url: URL, excluding inProgress: URL?) -> RecoverableRecording? {
        let path = url.standardizedFileURL
        guard path != inProgress?.standardizedFileURL,
              url.lastPathComponent.hasPrefix("recording_"),
              let format = AudioFormat(rawValue: url.pathExtension.lowercased()),
              let recovery = format.recovery,
              let identity = FileIdentity(atPath: path.path),
              (try? recovery.isUnfinalized(at: url)) == true else { return nil }

        let isRepairable = (try? recovery.isRepairable(at: url)) ?? false
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        // If the file changed during inspection, wait for the next scan.
        guard FileIdentity(atPath: path.path) == identity else { return nil }
        return RecoverableRecording(
            url: url,
            format: format,
            byteCount: values?.fileSize ?? 0,
            modifiedAt: values?.contentModificationDate ?? .distantPast,
            isRepairable: isRepairable,
            identity: identity
        )
    }
}

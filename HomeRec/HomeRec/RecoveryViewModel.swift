//
//  RecoveryViewModel.swift
//  HomeRec
//
//  BL-140: state for the Recover Recordings window. Deliberately thin — the
//  detection and repair logic lives behind `AudioFileRecovering`, so this type
//  only orchestrates and reports.
//

import Foundation
import Combine
import AppKit

@MainActor
final class RecoveryViewModel: ObservableObject {

    @Published private(set) var recordings: [RecoverableRecording] = []
    @Published private(set) var hasScanned = false
    /// Set when an action fails, so the window can say so rather than silently
    /// doing nothing — the same honesty BL-016 added to the stop path.
    @Published var errorMessage: String?

    private let scanner: RecoveryScanning
    /// The file being written right now, if any. A live recording is unfinalized
    /// by definition and must never be offered for recovery.
    private let inProgressURL: @MainActor () -> URL?

    /// Files the user has already recovered, by path, with the identity of the
    /// file they recovered there.
    ///
    /// Detection alone can't carry this. Repairing a WAV or FLAC changes the
    /// bytes the detector reads, so those rows disappear on the next scan — but
    /// **M4A repair is intentionally a no-op** (BL-016's fragments already play),
    /// so its row would survive its own recovery and the button would look dead.
    /// Requirement 7 is about the user's action, not the file's state.
    ///
    /// The identity is what lets a new take interrupted under a recovered
    /// file's name be offered: the path matches, the file does not.
    private var handled: [String: FileIdentity]
    /// `nil` remembers recoveries for this window's lifetime only. The app
    /// passes one. Tests that are not about this leave it out, so they never
    /// read or write the real app's settings: the test host is the app, and
    /// `.standard` is its domain.
    private let recoveredStore: RecoveredRecordingsStore?

    init(
        scanner: RecoveryScanning,
        inProgressURL: @escaping @MainActor () -> URL? = { nil },
        recoveredStore: RecoveredRecordingsStore? = nil
    ) {
        self.scanner = scanner
        self.inProgressURL = inProgressURL
        self.recoveredStore = recoveredStore
        self.handled = recoveredStore?.load() ?? [:]
    }

    var isEmpty: Bool { hasScanned && recordings.isEmpty }

    func refresh() {
        recordings = scanner.scan(excluding: inProgressURL())
            .filter { !isHandled($0.url) }
        hasScanned = true
    }

    func recover(_ recording: RecoverableRecording) {
        guard canModify(recording) else { return }
        do {
            try RecoveryScanner.recover(recording)
            markHandled(recording.url)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revealInFinder(_ recording: RecoverableRecording) {
        NSWorkspace.shared.activateFileViewerSelecting([recording.url])
    }

    func moveToTrash(_ recording: RecoverableRecording) {
        guard canModify(recording) else { return }
        do {
            try FileManager.default.trashItem(at: recording.url, resultingItemURL: nil)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isHandled(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        guard let recovered = handled[path] else { return false }
        return FileIdentity(atPath: path) == recovered
    }

    /// Read after the repair, not before: WAV and FLAC repair write a new file
    /// and swap it in, so the file left at the path is the one to remember.
    private func markHandled(_ url: URL) {
        let path = url.standardizedFileURL.path
        guard let identity = FileIdentity(atPath: path) else { return }
        handled[path] = identity
        recoveredStore?.save(handled)
    }

    /// Recheck stale rows immediately before touching disk. This check and the
    /// synchronous file operation share MainActor with session acquisition, so
    /// a new recording cannot claim the file between them.
    private func canModify(_ recording: RecoverableRecording) -> Bool {
        guard recording.url.standardizedFileURL != inProgressURL()?.standardizedFileURL else {
            errorMessage = "This recording is still in use. Wait until it finishes before recovering it or moving it to Trash."
            refresh()
            return false
        }
        return true
    }

    // MARK: - Display helpers

    func sizeText(_ recording: RecoverableRecording) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(recording.byteCount), countStyle: .file)
    }

    func dateText(_ recording: RecoverableRecording) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: recording.modifiedAt)
    }
}

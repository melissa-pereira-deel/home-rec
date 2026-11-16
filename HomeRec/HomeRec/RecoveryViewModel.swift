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
            .filter { !isHandled($0) }
        hasScanned = true
    }

    func recover(_ recording: RecoverableRecording) {
        guard canModify(recording) else { return }
        do {
            guard recording.isRepairable, let recovery = recording.format.recovery else {
                throw AudioFileRecoveryError.notRepairable
            }
            if let repairedIdentity = try recovery.repair(at: recording.url, expectedIdentity: recording.identity) {
                handled[recording.url.standardizedFileURL.path] = repairedIdentity
                recoveredStore?.save(handled)
            }
            refresh()
        } catch AudioFileRecoveryError.recordingChanged {
            reportRecordingChanged()
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
            guard FileIdentity(atPath: recording.url.standardizedFileURL.path) == recording.identity else {
                throw AudioFileRecoveryError.recordingChanged
            }
            try FileManager.default.trashItem(at: recording.url, resultingItemURL: nil)
            refresh()
        } catch AudioFileRecoveryError.recordingChanged {
            reportRecordingChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isHandled(_ recording: RecoverableRecording) -> Bool {
        handled[recording.url.standardizedFileURL.path] == recording.identity
    }

    /// Session acquisition shares MainActor with this synchronous check and
    /// file operation, so a new recording cannot claim this path between them.
    private func canModify(_ recording: RecoverableRecording) -> Bool {
        let activeURL = inProgressURL()
        let path = recording.url.standardizedFileURL
        guard path != activeURL?.standardizedFileURL else {
            errorMessage = "This recording is still in use. Wait until it finishes before recovering it or moving it to Trash."
            refresh()
            return false
        }
        guard !isHandled(recording),
              FileIdentity(atPath: path.path) == recording.identity,
              let current = scanner.candidate(at: recording.url, excluding: activeURL),
              current.identity == recording.identity,
              current.isRepairable == recording.isRepairable else {
            reportRecordingChanged()
            return false
        }
        return true
    }

    private func reportRecordingChanged() {
        errorMessage = AudioFileRecoveryError.recordingChanged.localizedDescription
        refresh()
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

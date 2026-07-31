//
//  AudioFormat.swift
//  HomeRec
//
//  The output formats Home Rec can record to (BL-011). Single source of truth
//  for each format's file extension, display name, availability, and encoder
//  construction. Metadata lives here (not on `AudioFileEncoder`) because the
//  recording path/extension must be known before any encoder instance exists.
//
//  BL-011 ships only `.wav`; the other cases are declared so the format picker
//  (BL-015) and downstream items (M4A/FLAC/MP3 — BL-012/013/014) have a stable
//  enum to grow into, but `makeEncoder()` throws for them until implemented.
//

import Foundation

nonisolated enum AudioFormat: String, CaseIterable, Sendable {
    case wav
    case m4a
    case flac
    case mp3

    /// File extension, no leading dot. Used to build the recording path before
    /// any encoder instance exists (`RecordingController.generateFilePath()`).
    var fileExtension: String {
        switch self {
        case .wav:  return "wav"
        case .m4a:  return "m4a"
        case .flac: return "flac"
        case .mp3:  return "mp3"
        }
    }

    /// Full, descriptive name for the format picker's dropdown rows (BL-015),
    /// where the lossless/lossy distinction is decision-relevant.
    var displayName: String {
        switch self {
        case .wav:  return "WAV (Lossless)"
        case .m4a:  return "M4A (AAC)"
        case .flac: return "FLAC (Lossless)"
        case .mp3:  return "MP3"
        }
    }

    /// Short token for the resting shelf label (BL-015), e.g. "Recording as WAV".
    var shortName: String {
        switch self {
        case .wav:  return "WAV"
        case .m4a:  return "M4A"
        case .flac: return "FLAC"
        case .mp3:  return "MP3"
        }
    }

    /// Formats with a working encoder today. The picker (BL-015) filters to this
    /// so an unimplemented format can never be selected.
    static let available: [AudioFormat] = [.wav, .m4a, .flac]

    /// How a crash-interrupted file of this format is detected and repaired
    /// (BL-140). This exhaustive switch is the ONLY place a format maps to its
    /// recovery behaviour — `RecoveryScanner` must never switch on file extension
    /// itself, or a future format ships undetectable exactly the way BL-012
    /// shipped without durability (see BL-018).
    var recovery: (any AudioFileRecovering.Type)? {
        switch self {
        case .wav:  return WAVWriter.self
        case .m4a:  return M4AEncoder.self
        case .flac: return FLACEncoder.self
        case .mp3:  return nil   // no encoder, so nothing of ours to recover
        }
    }

    /// Construct a streaming encoder for this format.
    /// - Throws: `AudioFormatError.notImplemented` for formats not yet supported
    ///   (BL-014). Throwing here means no file is ever created for a stubbed
    ///   format — the failure surfaces before recording begins.
    func makeEncoder() throws -> any AudioFileEncoder {
        switch self {
        case .wav:
            return WAVWriter()
        case .m4a:
            return M4AEncoder()
        case .flac:
            return FLACEncoder()
        case .mp3:
            throw AudioFormatError.notImplemented(self)
        }
    }
}

enum AudioFormatError: Error, LocalizedError, Equatable {
    case notImplemented(AudioFormat)

    var errorDescription: String? {
        switch self {
        case .notImplemented(let format):
            return "\(format.displayName) recording isn't available yet."
        }
    }
}

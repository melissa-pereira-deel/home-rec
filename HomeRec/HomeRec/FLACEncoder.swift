//
//  FLACEncoder.swift
//  HomeRec
//
//  FLAC conformer of AudioFileEncoder (BL-013). Lossless, ~0.23–0.7× the size
//  of the equivalent WAV depending on content.
//
//  Like every encoder it runs entirely on AudioRecorder's serial processingQueue,
//  so it is not thread-safe by design — the owner guarantees serial access.
//
//  ⚠️ Route note (BL-013 spike, 2026-07-29): `AVAssetWriter` CANNOT write FLAC.
//  It raises an *uncatchable* Objective-C NSException for any FLAC UTI — not a
//  Swift error, so it cannot be caught or recovered from — and there is no
//  `AVFileType.flac` in the SDK at all. `AVAudioFile` + `kAudioFormatFLAC` is the
//  only working route. Do not "fix" this back to AVAssetWriter.
//

import Foundation
import AVFoundation
import AudioToolbox

enum FLACEncoderError: Error, LocalizedError, Equatable {
    case setupFailed
    case notOpen
    case formatMismatch
    case noAudioWritten
    case finalizeFailed

    var errorDescription: String? {
        switch self {
        case .setupFailed:     return "Failed to set up the FLAC encoder"
        case .notOpen:         return "FLAC file is not open for writing"
        case .formatMismatch:  return "The audio format doesn't match the FLAC file"
        case .noAudioWritten:  return "No audio was captured for this recording"
        case .finalizeFailed:  return "Failed to finalize the FLAC file"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .setupFailed:     return "Check that the destination folder exists and is writable"
        case .notOpen:         return "Start a recording before writing audio"
        case .formatMismatch:  return "Stop and start the recording to resynchronise the audio format"
        case .noAudioWritten:  return "Check that audio was playing, then record again"
        // Deliberately does NOT say "try again": the encoder has already released
        // the file by the time this throws, so a retry can only report .notOpen.
        case .finalizeFailed:  return "Check that there is enough free disk space, then record again"
        }
    }
}

nonisolated final class FLACEncoder: AudioFileEncoder {

    /// FLAC encodes in fixed packets; nothing at all is written to disk until the
    /// first full packet exists. A shorter take produces a 42-byte header stub
    /// with **no** `fLaC` magic that no player — not even `AVAudioFile` — can
    /// open. Measured in BL-013: 4607 frames → unreadable, 4608 → valid. We pad
    /// to this boundary in `finalize()` rather than throwing, so a very short
    /// take yields a real (if briefly silence-padded) file instead of an error.
    static let minimumEncodableFrames: AVAudioFrameCount = 4_608

    private var file: AVAudioFile?
    private var url: URL?
    private var framesWritten: AVAudioFrameCount = 0

    func createFile(at url: URL, sampleRate: Double, channels: Int) throws {
        framesWritten = 0
        self.url = url

        // Match every other encoder: don't inherit a stale file.
        try? FileManager.default.removeItem(at: url)

        // No bit-depth key: `AVLinearPCMBitDepthKey` is silently ignored for FLAC
        // (16/24/32/omitted all produce byte-identical 24-bit output), so passing
        // one would only imply control we don't have.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatFLAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels
        ]
        guard let file = try? AVAudioFile(
            forWriting: url,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        ) else {
            throw FLACEncoderError.setupFailed
        }
        self.file = file
    }

    func writeBuffer(_ buffer: AVAudioPCMBuffer) throws {
        guard let file else { throw FLACEncoderError.notOpen }

        // CRASH GUARD, not defensive style. `AVAudioFile.write` is unsafe on a
        // mismatched buffer in two distinct ways, both measured in BL-013:
        //   • an Int16 non-interleaved buffer triggers an *uncatchable* C++
        //     abort inside ExtAudioFile (a buffer-size overrun — no Swift error,
        //     no NSException, the process simply dies);
        //   • a sample-rate mismatch is accepted SILENTLY with no resampling,
        //     writing pitch-shifted audio with no error at all.
        // Full `AVAudioFormat` equality closes both. Do not weaken this to a
        // channel-count check.
        guard buffer.format == file.processingFormat else {
            throw FLACEncoderError.formatMismatch
        }

        try file.write(from: buffer)
        framesWritten += buffer.frameLength
    }

    func finalize() throws {
        guard let file, let url else { throw FLACEncoderError.notOpen }

        // Never pad a recording that captured *nothing*. Padding exists for a
        // genuinely short take; if not a single buffer was accepted — e.g. the
        // format guard rejected every one because the capture format drifted —
        // then padding would turn total failure into a 96ms silent file that
        // reports success, with `AudioRecorder`'s `try? writeBuffer` having
        // swallowed each rejection on the hot path. That is the silent-data-loss
        // shape BL-016 exists to prevent, so fail loudly instead.
        guard framesWritten > 0 else {
            file.close()
            self.file = nil
            self.url = nil
            throw FLACEncoderError.noAudioWritten
        }

        // Pad a sub-packet take up to the encodable boundary so it lands as a
        // real file rather than an unopenable stub (see `minimumEncodableFrames`).
        if framesWritten < Self.minimumEncodableFrames {
            let padding = Self.minimumEncodableFrames - framesWritten
            guard let silence = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: padding
            ) else {
                throw FLACEncoderError.finalizeFailed
            }
            silence.frameLength = padding
            // Zero explicitly. A fresh AVAudioPCMBuffer *is* zeroed in practice
            // (measured 0/200 trials non-zero against a deliberately dirtied
            // heap), but Apple documents no such guarantee, and the failure mode
            // if it ever changed is a burst of full-scale noise appended to every
            // short recording. One memset per recording is a cheap price for not
            // resting audio correctness on undocumented behaviour.
            if let channels = silence.floatChannelData {
                let bytes = Int(padding) * MemoryLayout<Float>.size
                for channel in 0..<Int(silence.format.channelCount) {
                    memset(channels[channel], 0, bytes)
                }
            }
            // Advance the counter only on a successful write, so `expected`
            // below always describes what is actually on disk.
            try file.write(from: silence)
            framesWritten += padding
        }

        let expected = framesWritten
        file.close()
        self.file = nil
        self.url = nil
        framesWritten = 0

        // `close()` returns Void and reports nothing, so re-opening read-only is
        // the only way finalize() can honestly claim the file is good — and it is
        // the only cheap detector of the short-take stub. `length` is read from
        // STREAMINFO rather than by scanning, so this costs ~0.2ms even on a
        // 5-minute recording.
        guard let verified = try? AVAudioFile(forReading: url),
              verified.length == AVAudioFramePosition(expected) else {
            throw FLACEncoderError.finalizeFailed
        }
    }

    deinit {
        // Backstop if finalize() never ran, mirroring WAVWriter's deinit.
        file?.close()
    }
}

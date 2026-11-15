//
//  AudioFileEncoder.swift
//  HomeRec
//
//  The codec seam (BL-011): turns a stream of captured PCM buffers into an
//  on-disk audio file in one format. Distinct from `AudioFileWriting`, which is
//  the higher-level workflow seam owned by `RecordingController`. An encoder is
//  owned privately by `AudioRecorder` and driven entirely on its serial
//  `processingQueue` — so it is intentionally NOT @MainActor and NOT Sendable;
//  the owner guarantees single-threaded, serial access.
//
//  Lifecycle is strict: createFile → writeBuffer* → finalize.
//

import Foundation
import AVFoundation

/// Carries a non-Sendable reference across exactly one queue hop whose safety
/// the caller guarantees structurally.
///
/// `DispatchQueue.async` takes a `@Sendable` closure, and the audio path moves
/// AVFoundation objects — PCM buffers, asset writers — that AVFoundation does
/// not declare `Sendable`. Where the hand-off genuinely is a *transfer* (one
/// reference, created by the sender, never touched again) this states that
/// claim in one greppable place instead of marking a whole class
/// `@unchecked Sendable` and losing the checking on everything else it holds.
/// Precedent: `InputSource` in `AudioFormatNormalizer.swift`.
///
/// Every use must say at the use site why the transfer is sole-ownership. If
/// that sentence cannot be written, this is the wrong tool.
nonisolated struct UncheckedTransfer<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

nonisolated protocol AudioFileEncoder: AnyObject {
    /// Open the output file. `sampleRate`/`channels` describe the *input* buffers
    /// the encoder will receive (the capture format, currently 48kHz stereo). Each
    /// encoder owns its own *output* format internally and resamples if it differs.
    func createFile(at url: URL, sampleRate: Double, channels: Int) throws

    /// Encode one buffer of captured audio. Input is non-interleaved Float32 PCM.
    func writeBuffer(_ buffer: AVAudioPCMBuffer) throws

    /// Flush and close the file, writing any authoritative trailer/header.
    func finalize() throws
}

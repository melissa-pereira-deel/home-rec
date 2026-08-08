//
//  AudioFormatNormalizer.swift
//  HomeRec
//
//  Forces every captured buffer to one canonical format before it reaches an
//  encoder (BL-112).
//
//  Why this exists: `AudioRecorder` tells each encoder the file is 48 kHz stereo
//  (`AudioRecorder.startRecording`), and that has been true only because
//  `ScreenCaptureAudioManager` pins `config.sampleRate`/`channelCount` on the
//  `.audio` output. Those settings do **not** govern the `.microphone` output —
//  the SDK states a mic buffer's format follows the *device's* native format
//  (`SCStream.h`). A 44.1 kHz or mono mic would therefore reach an encoder that
//  has already written a 48 kHz stereo header, with no error anywhere:
//
//    · WAV  — the header stamps the declared rate/channels while the interleave
//             loop uses the buffer's, so a mono take plays at half speed an
//             octave down, and a 44.1 kHz take plays ~8.8% fast.
//    · M4A  — a mono buffer is appended to a 2-channel input; the append fails,
//             and `finalize()` then throws `.writeFailed`. The whole take is lost
//             at stop, not merely mistimed.
//    · FLAC — already refuses, via its own `processingFormat` guard (BL-013).
//
//  ⚠️ Threading: `AVAudioConverter` is declared Sendable but carries mutable
//  resampler state, so the compiler will not warn about cross-queue use. One
//  normalizer belongs to exactly one sample-handler queue, for its lifetime.
//  `.audio` and `.microphone` must therefore either share a queue or hold
//  separate normalizers — never one normalizer across two queues.
//
//  Not here: BL-130's Force Mono. Averaging L+R back into *both* channels is not
//  `AVAudioConverter.downmix` (which converts N→1 and would change the channel
//  count); it needs a separate transform on the already-canonical buffer. It
//  belongs downstream of this type, not inside it.
//

import AVFoundation

/// Converts captured buffers to Home Rec's canonical encoder input format.
///
/// Explicitly `nonisolated`: the app target builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so an unannotated class would be
/// inferred `@MainActor` and then be illegal to touch from the capture queue.
nonisolated final class AudioFormatNormalizer {

    /// 48 kHz, stereo, Float32, non-interleaved — what every encoder is told to
    /// expect and what `AudioRecorder` hardcodes.
    static let canonical: AVAudioFormat = {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2) else {
            // `standardFormatWithSampleRate` only fails on nonsense arguments;
            // these are compile-time constants, so this is unreachable.
            preconditionFailure("Canonical 48kHz/stereo format is not constructible")
        }
        return format
    }()

    private let outputFormat: AVAudioFormat
    private var converter: AVAudioConverter?
    /// The input format `converter` was built for. A mid-stream format change
    /// (device switch) invalidates it.
    private var converterInputFormat: AVAudioFormat?

    init(outputFormat: AVAudioFormat = AudioFormatNormalizer.canonical) {
        self.outputFormat = outputFormat
    }

    /// Convert `buffer` to the canonical format, or return it untouched if it is
    /// already canonical.
    ///
    /// - Returns: nil if conversion failed or produced no frames. Callers drop
    ///   the buffer, matching the capture path's existing hot-path tolerance.
    func normalize(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        // Fast path, and the one that matters for regression safety: system-audio
        // capture is already canonical, so it must reach the encoder untouched
        // rather than round-tripping through a converter (BL-051 golden file).
        if buffer.format == outputFormat {
            return buffer
        }

        guard let converter = converter(for: buffer.format) else { return nil }

        // Output length varies per call even for a constant input length, so the
        // buffer needs headroom and `frameLength` must be read back afterwards —
        // never computed.
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }

        // The simple `convert(to:from:)` form throws -50 for any sample-rate
        // conversion; the input-block form is the only supported route.
        let source = InputSource(buffer)
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            guard let next = source.next() else {
                inputStatus.pointee = .noDataNow
                return nil
            }
            inputStatus.pointee = .haveData
            return next
        }

        // ⚠️ `.inputRanDry` is the NORMAL result of feeding one buffer per call —
        // it is returned on every single call and `.haveData` never is. Gating on
        // `.haveData` here would silently discard 100% of the audio.
        guard status != .error, conversionError == nil, output.frameLength > 0 else {
            return nil
        }
        return output
    }

    /// Build a converter and give it an explicit channel map when reducing
    /// channel count.
    ///
    /// ⚠️ Without this, a source with **more than two channels produces silence**
    /// — full-length, correctly-timed, and reported as success (BL-150).
    /// `AVAudioFormat` cannot be constructed above stereo without a channel
    /// layout, and the only layout available for an interface's raw inputs is
    /// `DiscreteInOrder`, which by definition asserts nothing about which
    /// channel is left or right. `AVAudioConverter` therefore refuses to guess
    /// and defaults `channelMap` to `[-1, -1]` — "no source channel for this
    /// output" — emitting zeros while returning `error == nil` and a full
    /// `frameLength`. Setting `downmix = true` does **not** rescue it.
    ///
    /// Measured on a Focusrite Scarlett 2i2 4th Gen: 4 channels in, peak 0.5;
    /// out, peak 0.0. Every guard on the path passes, the encoder writes the
    /// zeros, and the take has perfect duration — which is why a duration-based
    /// hardware check reported success on a silent file.
    ///
    /// `[0, 1]` takes the first two channels, matching the device's own
    /// `preferredChannelsForStereo`. That is deliberate rather than convenient:
    /// on this interface channels 3–4 are **Loopback**, carrying whatever the
    /// Mac is playing, so summing all four would fold system audio into a
    /// microphone take — the one outcome `ScreenCaptureAudioManager` explicitly
    /// rules out. A single mic on input 1 therefore lands hard left; centring it
    /// is Force Mono's job, downstream, not a lossy default here.
    ///
    /// Only set when reducing: an upmix (mono → stereo) has a working default
    /// that an explicit map would break.
    private func configuredConverter(from inputFormat: AVAudioFormat) -> AVAudioConverter? {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            return nil
        }
        if inputFormat.channelCount > outputFormat.channelCount {
            converter.channelMap = (0..<Int(outputFormat.channelCount)).map { NSNumber(value: $0) }
        }
        return converter
    }

    /// The converter for `inputFormat`, built on first use and reused after that.
    ///
    /// Held across buffers deliberately: a converter rebuilt (or `reset()`) per
    /// buffer loses its resampler state, which measurably produces a full-scale
    /// discontinuity at every buffer seam — an audible click ~47×/second — plus
    /// steady frame drift. Rebuilding is therefore reserved for a genuine input
    /// format change, where one click is unavoidable anyway.
    private func converter(for inputFormat: AVAudioFormat) -> AVAudioConverter? {
        if let converter, converterInputFormat == inputFormat {
            return converter
        }
        guard let fresh = configuredConverter(from: inputFormat) else {
            return nil
        }
        converter = fresh
        converterInputFormat = inputFormat
        return fresh
    }
}

/// Feeds one buffer to `AVAudioConverter`'s input block, then reports dry.
///
/// ⚠️ `nonisolated` is load-bearing, not decoration. The app target sets
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so without it this type is
/// implicitly `@MainActor` while being constructed and called from the capture
/// queue — the exact defect constraint #12 exists to prevent, in the file
/// written to fix it. The `@unchecked Sendable` below is what silences Swift 5,
/// which is why a warning-free build did not catch it; `SWIFT_VERSION=6`
/// reports it as an error at the call site.
///
/// `@unchecked Sendable` on purpose: the block's signature is `@Sendable`, but
/// `AVAudioConverter` invokes it **synchronously, on this thread, before
/// `convert` returns**, so the non-Sendable `AVAudioPCMBuffer` never crosses a
/// concurrency domain. The type system cannot express "escaping in signature
/// only", and the alternative — capturing the buffer directly — is the same
/// unsafety with a warning instead of a written-down reason.
private nonisolated final class InputSource: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    /// The buffer on the first call, nil on every call after it.
    func next() -> AVAudioPCMBuffer? {
        defer { buffer = nil }
        return buffer
    }
}

//
//  AudioRecorder.swift
//  HomeRec
//
//  Processes audio from ScreenCaptureKit and writes to WAV file
//

import Foundation
import AVFoundation
import os

/// Errors that can occur during audio recording
enum AudioRecorderError: Error, LocalizedError {
    case invalidSampleBuffer
    case formatNotSupported
    case bufferConversionFailed
    case notRecording

    var errorDescription: String? {
        switch self {
        case .invalidSampleBuffer:
            return "Invalid audio sample buffer"
        case .formatNotSupported:
            return "Audio format not supported"
        case .bufferConversionFailed:
            return "Failed to convert audio buffer"
        case .notRecording:
            return "Not currently recording"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidSampleBuffer:
            return "Check if system audio is playing"
        case .formatNotSupported:
            return "System audio format must be PCM"
        case .bufferConversionFailed:
            return "Try restarting the recording"
        case .notRecording:
            return "Start recording first"
        }
    }
}

/// Records audio from ScreenCaptureKit to WAV file
///
/// `nonisolated` for the same reason its encoders are: everything here runs on
/// `processingQueue` or on the capture queue that feeds it. See
/// `AudioFileWriting` for why it used to claim otherwise.
///
/// `@unchecked Sendable` because the capture queue hands buffers to the
/// processing queue through a `@Sendable` closure that captures `self`. The
/// claim behind the `unchecked` is the one this class was already built on and
/// documents throughout: every mutable property is read and written **only**
/// inside `processingQueue`, which is serial. The two public sinks are the
/// exception that proves it — they are assigned before `startRecording` and
/// immediately snapshotted into queue-confined copies, so the queue never reads
/// a property another thread may be writing.
///
/// It is `unchecked` rather than checked because Swift cannot see a dispatch
/// queue as an isolation domain. If that confinement is ever broken, this
/// annotation is what will have stopped the compiler from saying so — so do not
/// add mutable state here without putting it behind the queue.
nonisolated final class AudioRecorder: AudioFileWriting, @unchecked Sendable {

    // MARK: - Properties

    private var encoder: (any AudioFileEncoder)?

    /// Set once, on the processing queue, when a write fails (BL-173). Latched
    /// rather than re-reported: buffers arrive ~47×/sec, so an unlatched failure
    /// would raise an alert for every one of them.
    private var writeFailed = false

    /// Snapshot of `onWriteError` taken at start and confined to the processing
    /// queue, so the queue never reads a property the main actor is writing.
    /// This is the confinement TD-009 exists about, applied to a new callback
    /// rather than repeated as a new instance of the same bug.
    private var activeWriteErrorHandler: (@MainActor (WriteFailure) -> Void)?

    /// Snapshot of `onWaveformData`, confined to the processing queue for the
    /// same reason as the handler above. `processPCMBuffer` used to read the
    /// stored property directly, ~47 times a second, while the main actor was
    /// free to assign it — the identical cross-thread read that was fixed for
    /// the write-error sink and left in place for this one.
    private var activeWaveformHandler: (@MainActor ([Float]) -> Void)?

    /// How an encoder is built for a format. Injectable so tests can drive the
    /// stop path with an encoder that fails to finalize (BL-016) — the real app
    /// always uses `AudioFormat.makeEncoder()`.
    private let encoderFactory: (AudioFormat) throws -> any AudioFileEncoder

    init(encoderFactory: @escaping (AudioFormat) throws -> any AudioFileEncoder = { try $0.makeEncoder() }) {
        self.encoderFactory = encoderFactory
    }

    private let sampleRate: Double = 48000  // Match ScreenCaptureKit config
    private let channels: Int = 2           // Stereo

    /// Callback for waveform visualization data (downsampled amplitude values)
    var onWaveformData: (@MainActor ([Float]) -> Void)?

    /// Called once when the encoder refuses a buffer (BL-173).
    var onWriteError: (@MainActor (WriteFailure) -> Void)?

    // Processing queue for writing to disk
    private let processingQueue = DispatchQueue(
        label: "com.mdebritto.homerec.audiorecorder.processing",
        qos: .userInitiated
    )

    // MARK: - Public Methods

    /// Start recording to file
    /// - Parameters:
    ///   - fileURL: destination file; its extension should match `format`.
    ///   - format: output format whose encoder is created (BL-015). `sampleRate`/
    ///     `channels` are the capture (input) format; the encoder owns its output.
    /// - Throws: the format's `makeEncoder()` error, or a file-creation error.
    func startRecording(to fileURL: URL, format: AudioFormat) throws {
        let encoder = try encoderFactory(format)
        try encoder.createFile(at: fileURL, sampleRate: sampleRate, channels: channels)

        // Confine the encoder to the processing queue: capture and stop threads
        // must never touch `encoder` directly, so there's no cross-thread race.
        // The write-failure latch and its handler are confined the same way and
        // reset here, so a previous take's failure cannot silence this one.
        let handler = onWriteError
        let waveformHandler = onWaveformData
        processingQueue.sync {
            self.encoder = encoder
            self.writeFailed = false
            self.activeWriteErrorHandler = handler
            self.activeWaveformHandler = waveformHandler
        }

        Log.recorder.debug("AudioRecorder started: \(fileURL.path, privacy: .private)")
    }

    /// Process a captured audio buffer (already converted to the canonical
    /// 48kHz/stereo/Float32/non-interleaved format by the `AudioCapturing` source).
    /// - Parameter pcmBuffer: Audio buffer from the capture source
    func processAudioSample(_ pcmBuffer: AVAudioPCMBuffer) {
        // Hand off to the serial queue immediately. `encoder` is only ever read
        // there, so a concurrent stop cannot free it mid-read.
        //
        // The buffer crosses in an `UncheckedTransfer` because `async` takes a
        // `@Sendable` closure and `AVAudioPCMBuffer` is not Sendable. Why this
        // is a transfer and not a shared reference: the capture source builds a
        // fresh buffer for every callback — `AudioSampleConverter.makePCMBuffer`
        // from the `CMSampleBuffer`, then `AudioFormatNormalizer` — and does not
        // keep it. There is one reference, and it is being handed over.
        let transfer = UncheckedTransfer(pcmBuffer)
        processingQueue.async { [weak self] in
            guard let self, self.encoder != nil else { return }
            self.processPCMBuffer(transfer.value)
        }
    }

    /// Stop recording
    /// - Throws: AudioRecorderError if stop fails
    func stopRecording() throws {
        // Runs on the processing queue *after* all in-flight buffers (FIFO), so no
        // trailing audio is dropped and the writer is finalized exactly once.
        try processingQueue.sync {
            guard encoder != nil else {
                throw AudioRecorderError.notRecording
            }
            // Release the encoder even if finalize fails, otherwise a failed
            // finalize would leave the recorder permanently "recording" and
            // refuse every subsequent start.
            defer {
                encoder = nil
                activeWriteErrorHandler = nil
                activeWaveformHandler = nil
            }
            // BL-016: this was `try?`, which discarded every conformer's finalize
            // error — a failed M4A finish was invisible to the user. The error
            // now propagates and surfaces as `.stopFailed`.
            try encoder?.finalize()
        }
    }

    /// Whether the recorder is currently writing to a file.
    var recording: Bool {
        processingQueue.sync { encoder != nil }
    }

    // MARK: - Private Methods

    /// Process a PCM buffer on background thread (orchestrator).
    /// - Parameter pcmBuffer: canonical AVAudioPCMBuffer from the capture source
    private func processPCMBuffer(_ pcmBuffer: AVAudioPCMBuffer) {
        // Runs ~47×/sec on the processing queue, so nothing here may log or report
        // per buffer. A write failure is the one exception, and it is latched so
        // it costs one log and one callback per take rather than per buffer
        // (BL-173). CMSampleBuffer→AVAudioPCMBuffer conversion now
        // happens at the capture source's delegate boundary (BL-099); downsampling
        // is still extracted into a `nonisolated` unit (BL-007), and the write goes
        // through the format-agnostic `AudioFileEncoder` seam (BL-011).
        guard let encoder = encoder else { return }

        // This take is already over. Keep taking buffers off the queue, but stop
        // writing and — the point of BL-173 — stop publishing evidence that the
        // recording is still healthy.
        guard !writeFailed else { return }

        // Write FIRST. This used to run after the waveform was already on screen,
        // with the error discarded by `try?`, so a file that had stopped growing
        // still drove a moving waveform and a running timer. The only evidence of
        // success the user got was produced by code that never touched the file.
        //
        // BL-112 made the encoders throw here; it never made this caller listen.
        do {
            try encoder.writeBuffer(pcmBuffer)
        } catch {
            writeFailed = true
            // Classified here rather than downstream, because this is the only
            // place that still has the typed error. A size ceiling is not a
            // failure — the file is complete — and it must not inherit the
            // "couldn't save the audio" copy (BL-170).
            let reason: WriteFailure = (error as? WAVWriterError) == .sizeLimitReached
                ? .sizeLimitReached
                : .other(error.localizedDescription)
            // The one log this hot path is allowed: it happens once per take, on
            // the way out, not once per buffer.
            Log.recorder.error(
                "Write stopped mid-recording: \(error.localizedDescription, privacy: .public)"
            )
            if let handler = activeWriteErrorHandler {
                Task { @MainActor in handler(reason) }
            }
            return
        }

        // Waveform only once the audio is actually on disk, so the UI cannot
        // outlive the file it is describing.
        if let onWaveformData = activeWaveformHandler {
            let waveformSamples = WaveformDownsampler.downsample(pcmBuffer)
            // `DispatchQueue.main.async`, not `Task { @MainActor in }`: this runs
            // ~47×/sec and tasks carry no ordering guarantee relative to one
            // another, so waveform frames could arrive out of order and draw a
            // jittering trace. The main queue is FIFO. `assumeIsolated` states
            // what is already true inside it — this is the main actor.
            //
            // The handler crosses in an `UncheckedTransfer` because Swift 6.1 —
            // the CI toolchain — does not infer a global-actor-isolated closure
            // to be `Sendable`, so capturing it in a `@Sendable` closure warns
            // there even though it does not on 6.3. Sole ownership: this is a
            // local copy of a queue-confined snapshot, read nowhere else.
            let handler = UncheckedTransfer(onWaveformData)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { handler.value(waveformSamples) }
            }
        }
    }
}

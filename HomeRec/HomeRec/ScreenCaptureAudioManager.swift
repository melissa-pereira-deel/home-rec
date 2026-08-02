//
//  ScreenCaptureAudioManager.swift
//  HomeRec
//
//  Manages system audio capture using ScreenCaptureKit
//

import Foundation
import ScreenCaptureKit
import AVFoundation
import os

/// Errors for ScreenCaptureKit audio capture
enum ScreenCaptureAudioError: Error, LocalizedError {
    case notAuthorized
    case noDisplaysAvailable
    case streamCreationFailed
    case startCaptureFailed(Error)
    /// The `.app` source's bundle ID has no matching running `SCRunningApplication` (BL-100).
    case appNotRunning(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Screen Recording permission not granted"
        case .noDisplaysAvailable:
            return "No displays available for capture"
        case .streamCreationFailed:
            return "Failed to create capture stream"
        case .startCaptureFailed(let error):
            return "Failed to start audio capture: \(error.localizedDescription)"
        case .appNotRunning(let bundleID):
            return "The selected app (\(bundleID)) is not currently running."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthorized:
            return "Grant Screen Recording permission in System Settings > Privacy & Security"
        case .noDisplaysAvailable:
            return "Ensure your Mac has at least one display connected"
        case .streamCreationFailed:
            return "Try restarting the application"
        case .startCaptureFailed:
            return "Check if another app is already capturing system audio"
        case .appNotRunning:
            return "Open the app, or choose a different capture source."
        }
    }
}

/// Manages system audio capture using ScreenCaptureKit
class ScreenCaptureAudioManager: NSObject, AudioCapturing {

    // MARK: - Properties

    private var stream: SCStream?
    private var audioCallback: ((AVAudioPCMBuffer) -> Void)?
    private var isCapturing = false

    /// Forces every captured buffer to the canonical 48 kHz stereo format the
    /// encoders are told to expect (BL-112).
    ///
    /// ⚠️ One normalizer per sample-handler queue — it holds a stateful
    /// `AVAudioConverter`, which is declared Sendable but is not safe to drive
    /// from two queues. This one belongs to the `.audio` handler queue. When
    /// BL-130 adds a `.microphone` output it must either share that queue or get
    /// its own normalizer; it must not share this one across queues.
    private var audioNormalizer = AudioFormatNormalizer()

    /// One-shot latches so a rejected buffer is reported once per session rather
    /// than per buffer — this is the capture hot path (BL-150).
    ///
    /// ⚠️ Written and read on the sample-handler queue only, unlike the
    /// properties above it, so these two add no new cross-queue access. The rest
    /// of this file's race is TD-009 and is not made worse here.
    private var hasLoggedConversionFailure = false
    private var hasLoggedNormalizeFailure = false

    /// Called when the stream stops unexpectedly. See `AudioCapturing`.
    var onStreamError: (@MainActor (String) -> Void)?

    // MARK: - Public Methods

    /// Set up capture for `source` (BL-100: all system audio or a specific running app).
    /// - Parameters:
    ///   - source: what to capture. `.app` resolves to the matching `SCRunningApplication`.
    ///   - audioCallback: Closure called for each audio buffer
    /// - Throws: ScreenCaptureAudioError if setup fails, or `.appNotRunning` if `source`
    ///   is `.app` and no running app matches its bundle ID.
    func setupCapture(source: AudioSource, audioCallback: @escaping (AVAudioPCMBuffer) -> Void) async throws {
        self.audioCallback = audioCallback
        // Fresh converter state per session: this manager outlives a single
        // recording, and a converter carrying the previous take's resampler state
        // would start the next one mid-phase.
        self.audioNormalizer = AudioFormatNormalizer()

        // Get available displays (and, for .app, running applications)
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )

        guard let display = content.displays.first else {
            Log.capture.error("No displays available for audio capture")
            throw ScreenCaptureAudioError.noDisplaysAvailable
        }

        // Configure stream for audio capture
        // Note: ScreenCaptureKit requires video to be captured alongside audio
        let config = SCStreamConfiguration()

        // Audio configuration. For a mic source we want *only* the mic: mixing
        // mic and system audio into one file is a stated non-goal for v1.
        //
        // ⚠️ `sampleRate`/`channelCount` govern the `.audio` output ONLY. A
        // `.microphone` buffer arrives in the device's native format regardless
        // (SCStream.h), which is exactly why `AudioFormatNormalizer` exists.
        let isMicSource: Bool
        if case .mic = source { isMicSource = true } else { isMicSource = false }

        config.capturesAudio = !isMicSource
        config.excludesCurrentProcessAudio = true  // Don't record our own app
        config.sampleRate = 48000  // 48kHz
        config.channelCount = 2    // Stereo

        if case .mic(let deviceUID) = source {
            config.captureMicrophone = true
            // "This deviceID is the uniqueID from AVCaptureDevice" (SCStream.h),
            // which is precisely what `InputDeviceEnumerator` returns.
            config.microphoneCaptureDeviceID = deviceUID
        }

        // Minimal video configuration (required but we won't use it)
        config.width = 100
        config.height = 100
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.scalesToFit = false

        // Content filter: all display audio, or a single app's audio (BL-100).
        let filter: SCContentFilter
        switch source {
        case .systemAll:
            filter = SCContentFilter(display: display, excludingWindows: [])
        case .app(let bundleID):
            guard let app = content.applications.first(where: { $0.bundleIdentifier == bundleID }) else {
                Log.capture.error("Selected app not running for per-app capture")
                throw ScreenCaptureAudioError.appNotRunning(bundleID)
            }
            filter = SCContentFilter(display: display, including: [app], exceptingWindows: [])
        case .mic:
            // The filter still has to describe *something* capturable — the
            // stream needs a display for its (unused) video output — but with
            // `capturesAudio = false` no system audio is recorded from it.
            filter = SCContentFilter(display: display, excludingWindows: [])
        }

        // Create stream
        stream = SCStream(filter: filter, configuration: config, delegate: self)

        // Add output handlers
        guard let stream = stream else {
            throw ScreenCaptureAudioError.streamCreationFailed
        }

        // Add screen output (required even though we only want audio)
        try stream.addStreamOutput(
            self,
            type: .screen,
            sampleHandlerQueue: DispatchQueue(label: "com.mdebritto.homerec.screen.capture", qos: .userInitiated)
        )

        // Add audio output.
        //
        // ⚠️ `.audio` and `.microphone` deliberately SHARE one sample-handler
        // queue. They feed the same `AudioFormatNormalizer`, which holds a
        // stateful `AVAudioConverter` — declared Sendable but not safe to drive
        // from two queues, and the compiler will not warn about it. Giving the
        // mic its own queue would be a silent data race.
        let audioQueue = DispatchQueue(
            label: "com.mdebritto.homerec.audio.capture",
            qos: .userInitiated
        )
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)

        if isMicSource {
            try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: audioQueue)
        }

        Log.capture.debug("Capture stream configured (screen + audio handlers added)")
    }

    /// Start audio capture
    /// - Throws: ScreenCaptureAudioError if start fails
    func startCapture() async throws {
        guard let stream = stream else {
            throw ScreenCaptureAudioError.streamCreationFailed
        }

        do {
            try await stream.startCapture()
            isCapturing = true
            Log.capture.info("Capture started")
        } catch {
            Log.capture.error("Capture failed to start: \(error.localizedDescription, privacy: .public)")
            throw ScreenCaptureAudioError.startCaptureFailed(error)
        }
    }

    /// Stop audio capture
    func stopCapture() async throws {
        guard let stream = stream else { return }

        try await stream.stopCapture()
        isCapturing = false
    }

    /// Clean up resources
    func cleanup() async {
        try? await stopCapture()
        stream = nil
        audioCallback = nil
    }

    var capturing: Bool {
        return isCapturing
    }
}

// MARK: - SCStreamDelegate

extension ScreenCaptureAudioManager: SCStreamDelegate {

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        let message = error.localizedDescription
        Log.capture.error("Capture stream stopped with error: \(message, privacy: .public)")
        isCapturing = false
        onStreamError?(message)
    }
}

// MARK: - SCStreamOutput

extension ScreenCaptureAudioManager: SCStreamOutput {

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        // Ignore video samples (we only need audio). No logging here: this
        // fires per audio buffer on the capture queue — the hot path.
        //
        // `.microphone` is a distinct output type from `.audio` (BL-130), and
        // only one of them is ever configured at a time — a mic source sets
        // `capturesAudio = false`, so no `.audio` buffers arrive to interleave
        // with it. Both are normalised by the same converter on the same queue.
        guard type == .audio || type == .microphone else { return }

        // Convert at the delegate boundary so every AudioCapturing implementation
        // hands AudioRecorder the same canonical AVAudioPCMBuffer type (BL-099),
        // then normalise so it is the same *format* too (BL-112). For system
        // audio the normaliser is a pass-through — the SCK config already pins
        // 48 kHz stereo — so the existing path stays byte-identical.
        // ⚠️ Never drop a buffer here in silence (BL-150). These two guards used
        // to be one `else { return }`, so when a Scarlett 2i2's integer-format
        // microphone buffers were rejected, every one vanished without a trace
        // and the only symptom was "No audio was captured for this recording"
        // at the end. The format is logged once per session — this is the hot
        // path, so it must not log per buffer.
        guard let pcmBuffer = AudioSampleConverter.makePCMBuffer(from: sampleBuffer) else {
            if !hasLoggedConversionFailure {
                hasLoggedConversionFailure = true
                let desc = CMSampleBufferGetFormatDescription(sampleBuffer)
                    .flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
                    .map { "\($0.mChannelsPerFrame)ch \($0.mSampleRate)Hz \($0.mBitsPerChannel)-bit flags=\($0.mFormatFlags)" }
                    ?? "unknown format"
                Log.capture.error("Dropping buffers: unsupported capture format — \(desc, privacy: .public)")
            }
            return
        }
        guard let normalized = audioNormalizer.normalize(pcmBuffer) else {
            if !hasLoggedNormalizeFailure {
                hasLoggedNormalizeFailure = true
                let f = pcmBuffer.format
                Log.capture.error("Dropping buffers: normalizer rejected \(f.channelCount, privacy: .public)ch \(f.sampleRate, privacy: .public)Hz")
            }
            return
        }
        audioCallback?(normalized)
    }
}

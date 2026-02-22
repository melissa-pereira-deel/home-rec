//
//  ScreenCaptureAudioManager.swift
//  HomeRec
//
//  Manages system audio capture using ScreenCaptureKit
//

import Foundation
import ScreenCaptureKit
import AVFoundation

/// Errors for ScreenCaptureKit audio capture
enum ScreenCaptureAudioError: Error, LocalizedError {
    case notAuthorized
    case noDisplaysAvailable
    case streamCreationFailed
    case startCaptureFailed(Error)

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
        }
    }
}

/// Manages system audio capture using ScreenCaptureKit
class ScreenCaptureAudioManager: NSObject {

    // MARK: - Properties

    private var stream: SCStream?
    private var audioCallback: ((CMSampleBuffer) -> Void)?
    private var isCapturing = false

    // MARK: - Public Methods

    /// Set up system audio capture
    /// - Parameter callback: Closure called for each audio buffer
    /// - Throws: ScreenCaptureAudioError if setup fails
    func setupCapture(audioCallback: @escaping (CMSampleBuffer) -> Void) async throws {
        DebugLogger.log("📺 ScreenCaptureAudioManager.setupCapture() called")
        self.audioCallback = audioCallback

        // Get available displays
        DebugLogger.log("   Getting shareable content...")
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: false
        )

        guard let display = content.displays.first else {
            DebugLogger.log("   ❌ No displays available")
            throw ScreenCaptureAudioError.noDisplaysAvailable
        }
        DebugLogger.log("   ✅ Found display: \(display.displayID)")

        // Configure stream for audio capture
        // Note: ScreenCaptureKit requires video to be captured alongside audio
        let config = SCStreamConfiguration()

        // Audio configuration
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true  // Don't record our own app
        config.sampleRate = 48000  // 48kHz
        config.channelCount = 2    // Stereo

        // Minimal video configuration (required but we won't use it)
        config.width = 100
        config.height = 100
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.scalesToFit = false

        // Create content filter (captures all audio from display)
        let filter = SCContentFilter(display: display, excludingWindows: [])

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

        // Add audio output
        try stream.addStreamOutput(
            self,
            type: .audio,
            sampleHandlerQueue: DispatchQueue(label: "com.mdebritto.homerec.audio.capture", qos: .userInitiated)
        )

        DebugLogger.log("✅ ScreenCaptureAudioManager: Added screen and audio output handlers")
        print("✅ Added screen and audio output handlers")
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
            print("✅ ScreenCaptureKit stream started successfully")
        } catch {
            print("❌ ScreenCaptureKit stream start failed: \(error)")
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
        print("❌ ScreenCaptureKit stream stopped with error: \(error.localizedDescription)")
        isCapturing = false
    }
}

// MARK: - SCStreamOutput

extension ScreenCaptureAudioManager: SCStreamOutput {

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        // Debug: Log all sample types received
        if type == .screen {
            // Ignore video samples (we don't need them)
            return
        }

        if type == .audio {
            let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
            DebugLogger.log("🎵 SCStream: Received audio sample with \(frameCount) frames")
            NSLog("🎵 SCStream: Received audio sample with \(frameCount) frames")
            // Forward to callback
            if let callback = audioCallback {
                callback(sampleBuffer)
                DebugLogger.log("✅ SCStream: Forwarded to callback")
                NSLog("✅ SCStream: Forwarded to callback")
            } else {
                DebugLogger.log("❌ SCStream: No callback set!")
                NSLog("❌ SCStream: No callback set!")
            }
        } else if type != .screen {
            DebugLogger.log("⚠️ SCStream: Unexpected sample type: \(type.rawValue)")
            NSLog("⚠️ SCStream: Unexpected sample type: \(type.rawValue)")
        }
    }
}

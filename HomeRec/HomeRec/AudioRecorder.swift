//
//  AudioRecorder.swift
//  HomeRec
//
//  Processes audio from ScreenCaptureKit and writes to WAV file
//

import Foundation
import CoreMedia
import AVFoundation

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
class AudioRecorder {

    // MARK: - Properties

    private var wavWriter: WAVWriter?
    private var isRecording = false

    private let sampleRate: Double = 48000  // Match ScreenCaptureKit config
    private let channels: Int = 2           // Stereo

    /// Callback for waveform visualization data (downsampled amplitude values)
    var onWaveformData: (([Float]) -> Void)?

    // Processing queue for writing to disk
    private let processingQueue = DispatchQueue(
        label: "com.mdebritto.homerec.audiorecorder.processing",
        qos: .userInitiated
    )

    // MARK: - Public Methods

    /// Start recording to file
    /// - Parameter fileURL: URL where WAV file will be saved
    /// - Throws: AudioRecorderError if recording cannot start
    func startRecording(to fileURL: URL) throws {
        DebugLogger.log("🎙️ AudioRecorder.startRecording() called")
        DebugLogger.log("   File URL: \(fileURL.path)")

        // Create WAV writer
        let writer = WAVWriter()
        DebugLogger.log("   Creating WAV file...")
        try writer.createFile(at: fileURL, sampleRate: sampleRate, channels: channels)
        DebugLogger.log("   ✅ WAV file created")
        self.wavWriter = writer

        isRecording = true
        DebugLogger.log("✅ AudioRecorder is now recording")
    }

    /// Process audio sample from ScreenCaptureKit
    /// - Parameter sampleBuffer: Audio sample from SCStream
    func processAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording else {
            DebugLogger.log("⚠️ AudioRecorder: Received sample but not recording")
            NSLog("⚠️ AudioRecorder: Received sample but not recording")
            return
        }

        DebugLogger.log("📥 AudioRecorder: Processing audio sample")
        NSLog("📥 AudioRecorder: Processing audio sample")
        // Process on background queue to avoid blocking capture
        processingQueue.async { [weak self] in
            self?.processSampleBuffer(sampleBuffer)
        }
    }

    /// Stop recording
    /// - Throws: AudioRecorderError if stop fails
    func stopRecording() throws {
        guard isRecording else {
            throw AudioRecorderError.notRecording
        }

        // Wait for processing queue to finish
        processingQueue.sync {
            // Finalize WAV file
            try? wavWriter?.finalize()
            wavWriter = nil
        }

        isRecording = false
    }

    var recording: Bool {
        return isRecording
    }

    // MARK: - Private Methods

    /// Process sample buffer on background thread
    /// - Parameter sampleBuffer: CMSampleBuffer from ScreenCaptureKit
    private func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        DebugLogger.log("    🔄 processSampleBuffer() started")

        guard let wavWriter = wavWriter else {
            DebugLogger.log("    ❌ No WAV writer available")
            print("⚠️ No WAV writer available")
            return
        }
        DebugLogger.log("    ✅ WAV writer exists")

        // Get format description
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            DebugLogger.log("    ❌ Failed to get format description")
            return
        }
        DebugLogger.log("    ✅ Got format description")

        // Get audio stream description
        guard let streamDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else {
            DebugLogger.log("    ❌ Failed to get stream description")
            return
        }
        DebugLogger.log("    ✅ Got stream description - SR: \(streamDesc.pointee.mSampleRate), Channels: \(streamDesc.pointee.mChannelsPerFrame)")

        // Create AVAudioFormat from stream description
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: streamDesc.pointee.mSampleRate,
            channels: AVAudioChannelCount(streamDesc.pointee.mChannelsPerFrame),
            interleaved: false
        ) else {
            DebugLogger.log("    ❌ Failed to create AVAudioFormat")
            return
        }
        DebugLogger.log("    ✅ Created AVAudioFormat")

        // Get number of frames
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        DebugLogger.log("    Frame count: \(frameCount)")
        guard frameCount > 0 else {
            DebugLogger.log("    ❌ Frame count is 0")
            return
        }

        // Create PCM buffer
        DebugLogger.log("    Creating PCM buffer...")
        guard let pcmBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            DebugLogger.log("    ❌ Failed to create PCM buffer")
            return
        }
        DebugLogger.log("    ✅ PCM buffer created")

        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        // Get audio buffer list from sample buffer
        DebugLogger.log("    Getting audio buffer list...")

        // First, query the required size
        var requiredSize: Int = 0
        var status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &requiredSize,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: nil
        )

        guard status == noErr else {
            DebugLogger.log("    ❌ Failed to query buffer list size, status: \(status)")
            return
        }
        DebugLogger.log("    Required buffer list size: \(requiredSize)")

        // Allocate the audio buffer list with the correct size
        let audioBufferListPtr = UnsafeMutableRawPointer.allocate(
            byteCount: requiredSize,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { audioBufferListPtr.deallocate() }

        var blockBuffer: CMBlockBuffer?
        status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferListPtr.assumingMemoryBound(to: AudioBufferList.self),
            bufferListSize: requiredSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else {
            DebugLogger.log("    ❌ Failed to get audio buffer list, status: \(status)")
            return
        }
        defer { blockBuffer = nil }

        let audioBufferListPointer = UnsafeMutableAudioBufferListPointer(audioBufferListPtr.assumingMemoryBound(to: AudioBufferList.self))
        DebugLogger.log("    ✅ Got audio buffer list with \(audioBufferListPointer.count) buffers")

        // Copy audio data to PCM buffer
        guard let floatChannelData = pcmBuffer.floatChannelData else {
            DebugLogger.log("    ❌ PCM buffer has no float channel data")
            return
        }
        DebugLogger.log("    ✅ Got float channel data")

        let channelCount = Int(streamDesc.pointee.mChannelsPerFrame)
        let isInterleaved = (streamDesc.pointee.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0
        DebugLogger.log("    Channels: \(channelCount), Interleaved: \(isInterleaved)")

        if isInterleaved {
            DebugLogger.log("    Deinterleaving audio data...")
            // Deinterleave audio data
            if let buffer = audioBufferListPointer.first,
               let srcData = buffer.mData?.assumingMemoryBound(to: Float.self) {

                for frame in 0..<frameCount {
                    for channel in 0..<channelCount {
                        let srcIndex = frame * channelCount + channel
                        floatChannelData[channel][frame] = srcData[srcIndex]
                    }
                }
                DebugLogger.log("    ✅ Deinterleaved \(frameCount) frames")
            } else {
                DebugLogger.log("    ❌ Failed to get source data for deinterleaving")
                return
            }
        } else {
            DebugLogger.log("    Copying non-interleaved audio data...")
            // Non-interleaved (already separated by channel)
            for channel in 0..<min(channelCount, audioBufferListPointer.count) {
                if let srcData = audioBufferListPointer[channel].mData?.assumingMemoryBound(to: Float.self) {
                    floatChannelData[channel].update(from: srcData, count: frameCount)
                }
            }
            DebugLogger.log("    ✅ Copied \(frameCount) frames for \(channelCount) channels")
        }

        // Extract waveform data for visualization
        if let onWaveformData = onWaveformData {
            let targetSamples = 200
            let step = max(1, frameCount / targetSamples)
            var waveformSamples: [Float] = []
            waveformSamples.reserveCapacity(targetSamples)

            for i in stride(from: 0, to: frameCount, by: step) {
                var sample: Float = 0
                for ch in 0..<channelCount {
                    sample += floatChannelData[ch][i]
                }
                sample /= Float(channelCount)
                waveformSamples.append(sample)
            }

            DispatchQueue.main.async {
                onWaveformData(waveformSamples)
            }
        }

        // Write to WAV file
        do {
            try wavWriter.writeBuffer(pcmBuffer)
            DebugLogger.log("✅ AudioRecorder: Wrote \(pcmBuffer.frameLength) frames to WAV")
            NSLog("✅ AudioRecorder: Wrote \(pcmBuffer.frameLength) frames to WAV")
        } catch {
            DebugLogger.log("❌ AudioRecorder: Failed to write buffer: \(error)")
            NSLog("❌ AudioRecorder: Failed to write buffer: \(error)")
        }
    }

    // MARK: - Cleanup

    deinit {
        if isRecording {
            try? stopRecording()
        }
    }
}

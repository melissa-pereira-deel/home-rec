//
//  M4AEncoder.swift
//  HomeRec
//
//  AAC-in-M4A conformer of AudioFileEncoder (BL-012). Encodes the captured
//  Float32 PCM stream to AAC via AVAssetWriter (44.1kHz, 256 kbps, stereo).
//
//  Like every encoder it runs entirely on AudioRecorder's serial processingQueue,
//  so it is not thread-safe by design — the owner guarantees serial access.
//
//  Impedance mismatch handled here: our contract is a *synchronous push*
//  (writeBuffer per buffer), while AVAssetWriterInput is push-but-async
//  (append only when `isReadyForMoreMediaData`, and `finishWriting` is async).
//  A small pending queue absorbs the rare not-ready window; finalize() drains it
//  and bridges the async finish to the synchronous contract via a semaphore.
//

import Foundation
import AVFoundation
import CoreMedia
import os

enum M4AEncoderError: Error, LocalizedError, Equatable {
    case setupFailed
    case notOpen
    case writeFailed
    /// A buffer arrived whose rate/channels differ from what the writer input was
    /// configured for. Appending it would fail and cost the whole take at stop.
    case formatMismatch

    var errorDescription: String? {
        switch self {
        case .setupFailed:     return "Failed to set up the M4A encoder"
        case .notOpen:         return "M4A file is not open for writing"
        case .writeFailed:     return "Failed to finalize the M4A file"
        case .formatMismatch:  return "Audio format changed mid-recording"
        }
    }
}

nonisolated final class M4AEncoder: AudioFileEncoder {

    // AAC output config (BL-012).
    private let outputSampleRate: Double = 44_100
    private let bitRate: Int = 256_000

    /// Flush a movie fragment this often so the file on disk stays playable even
    /// if `finalize()` never runs (crash / force-quit). This is the M4A analogue
    /// of `WAVWriter.headerUpdateInterval` (BL-022): without it AVFoundation
    /// writes the `moov` atom *only* at `finishWriting`, and a mid-recording copy
    /// is completely unreadable — measured in BL-016, where fragmenting recovered
    /// everything up to the last flushed fragment. Recovery granularity equals
    /// this interval; the cost is ~6% larger output.
    static let fragmentIntervalSeconds: Double = 1.0

    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?

    /// Input (capture) sample rate, used to stamp presentation times. The AAC
    /// output rate differs; AVAssetWriter resamples and remaps timestamps.
    private var inputSampleRate: Double = 48_000
    /// Input channel count the writer input was configured for. A buffer with a
    /// different count cannot be appended to it (see the guard in `writeBuffer`).
    private var inputChannels: Int = 2
    private var totalInputFrames: Int64 = 0

    /// Buffers awaiting append while the input reports not-ready (FIFO).
    private var pending: [CMSampleBuffer] = []

    func createFile(at url: URL, sampleRate: Double, channels: Int) throws {
        inputSampleRate = sampleRate
        inputChannels = channels
        totalInputFrames = 0
        pending.removeAll()

        // AVAssetWriter refuses to overwrite an existing file.
        try? FileManager.default.removeItem(at: url)

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .m4a) else {
            throw M4AEncoderError.setupFailed
        }
        // Must be set before `startWriting()` — see `fragmentIntervalSeconds`.
        writer.movieFragmentInterval = CMTime(
            seconds: Self.fragmentIntervalSeconds,
            preferredTimescale: 600
        )
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: outputSampleRate,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: bitRate
        ]
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(input) else { throw M4AEncoderError.setupFailed }
        writer.add(input)
        guard writer.startWriting() else { throw M4AEncoderError.setupFailed }
        writer.startSession(atSourceTime: .zero)

        self.writer = writer
        self.input = input
    }

    func writeBuffer(_ buffer: AVAudioPCMBuffer) throws {
        guard let input = input, writer != nil else { throw M4AEncoderError.notOpen }

        // Presentation times are stamped from the *declared* input rate while the
        // sample buffer's format description comes from the buffer's own — so a
        // rate mismatch drifts the timeline and reports a wrong duration. A
        // channel mismatch is worse: the writer input was configured for
        // `inputChannels`, so appending a differently-shaped buffer fails and
        // `finalize()` then throws `.writeFailed` — losing the entire take rather
        // than mistiming it. `AudioFormatNormalizer` should make this unreachable
        // (BL-112); reaching it must fail loudly, not silently.
        guard buffer.format.sampleRate == inputSampleRate,
              Int(buffer.format.channelCount) == inputChannels else {
            throw M4AEncoderError.formatMismatch
        }

        let pts = CMTime(value: totalInputFrames, timescale: CMTimeScale(inputSampleRate))
        guard let sample = Self.makeInterleavedSampleBuffer(from: buffer, presentationTime: pts) else {
            // Bad/empty buffer: drop it (matches the WAV path's hot-path tolerance).
            return
        }
        totalInputFrames += Int64(buffer.frameLength)

        pending.append(sample)
        guard drainPending(into: input) else { throw M4AEncoderError.writeFailed }
    }

    /// Append as many pending buffers as the input will currently accept.
    ///
    /// - Returns: false once an append is refused. That return used to be
    ///   discarded, which made a rejected buffer invisible until `finalize()`
    ///   found `writer.status != .completed` and threw — by which point the whole
    ///   take was gone with no indication of when or why it broke.
    @discardableResult
    private func drainPending(into input: AVAssetWriterInput) -> Bool {
        while let head = pending.first, input.isReadyForMoreMediaData {
            guard input.append(head) else {
                // The writer has failed; every later append fails too. Stop and
                // let the caller surface it while there is still context.
                Log.recorder.error(
                    "M4A append rejected: \(self.writer?.error?.localizedDescription ?? "unknown", privacy: .public)"
                )
                return false
            }
            pending.removeFirst()
        }
        return true
    }

    func finalize() throws {
        guard let writer = writer, let input = input else { throw M4AEncoderError.notOpen }

        // Drain anything still queued. The input encodes on its own queue, so
        // readiness recovers continuously; bound the wait so a stuck writer can't
        // hang stop indefinitely.
        var waited = 0
        while !pending.isEmpty {
            drainPending(into: input)
            if pending.isEmpty { break }
            if waited >= 5_000 { break }   // ~5s ceiling
            usleep(1_000)
            waited += 1
        }

        input.markAsFinished()

        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()   // completion fires on AVF's internal queue — no deadlock

        let status = writer.status
        self.writer = nil
        self.input = nil
        pending.removeAll()

        if status != .completed {
            throw M4AEncoderError.writeFailed
        }
    }

    // MARK: - PCM → CMSampleBuffer

    /// Convert a non-interleaved Float32 PCM buffer into an interleaved Float32
    /// `CMSampleBuffer` (the AAC encoder's preferred LPCM layout) stamped with
    /// `presentationTime`. The interleaved backing buffer is pinned to the sample
    /// buffer's lifetime via an attachment, since the sample buffer may sit in the
    /// pending queue and be appended after this call returns.
    private static func makeInterleavedSampleBuffer(
        from pcm: AVAudioPCMBuffer,
        presentationTime: CMTime
    ) -> CMSampleBuffer? {
        guard let src = pcm.floatChannelData else { return nil }
        let frames = Int(pcm.frameLength)
        let channels = Int(pcm.format.channelCount)
        guard frames > 0, channels > 0 else { return nil }

        guard let interleavedFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: pcm.format.sampleRate,
                channels: AVAudioChannelCount(channels),
                interleaved: true),
              let out = AVAudioPCMBuffer(pcmFormat: interleavedFormat, frameCapacity: AVAudioFrameCount(frames))
        else { return nil }
        out.frameLength = AVAudioFrameCount(frames)

        let dst = UnsafeMutableAudioBufferListPointer(out.mutableAudioBufferList)[0]
            .mData!.assumingMemoryBound(to: Float.self)
        for frame in 0..<frames {
            for channel in 0..<channels {
                dst[frame * channels + channel] = src[channel][frame]
            }
        }

        var asbd = interleavedFormat.streamDescription.pointee
        var formatDescription: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(
                allocator: kCFAllocatorDefault, asbd: &asbd,
                layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil,
                extensions: nil, formatDescriptionOut: &formatDescription) == noErr,
              let format = formatDescription
        else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(pcm.format.sampleRate)),
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        guard CMSampleBufferCreate(
                allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
                makeDataReadyCallback: nil, refcon: nil, formatDescription: format,
                sampleCount: CMItemCount(frames), sampleTimingEntryCount: 1,
                sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil,
                sampleBufferOut: &sampleBuffer) == noErr,
              let sample = sampleBuffer
        else { return nil }

        guard CMSampleBufferSetDataBufferFromAudioBufferList(
                sample,
                blockBufferAllocator: kCFAllocatorDefault,
                blockBufferMemoryAllocator: kCFAllocatorDefault,
                flags: 0,
                bufferList: out.audioBufferList) == noErr
        else { return nil }

        // The block buffer references `out`'s memory; pin its lifetime to the
        // sample buffer so it survives until appended (see SampleBufferFixtures).
        CMSetAttachment(
            sample,
            key: "HomeRecBackingPCMBuffer" as CFString,
            value: out,
            attachmentMode: kCMAttachmentMode_ShouldNotPropagate
        )
        return sample
    }
}

//
//  WAVWriterTests.swift
//  HomeRecTests
//
//  Data-integrity tests for WAVWriter (BL-004): header layout, finalize,
//  byte accumulation, Int16 conversion/clipping, and error paths.
//

import Testing
import Foundation
import AVFoundation
@testable import HomeRec

@MainActor
struct WAVWriterTests {

    // MARK: - Helpers

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("wavwriter-test-\(UUID().uuidString).wav")
    }

    /// Build a non-interleaved Float32 PCM buffer, filling each sample via `fill`.
    private func makeFloatBuffer(
        channels: AVAudioChannelCount,
        frames: AVAudioFrameCount,
        fill: (_ channel: Int, _ frame: Int) -> Float
    ) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: channels,
            interleaved: false
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let data = buffer.floatChannelData!
        for c in 0..<Int(channels) {
            for f in 0..<Int(frames) {
                data[c][f] = fill(c, f)
            }
        }
        return buffer
    }

    private func readUInt32LE(_ b: [UInt8], _ o: Int) -> UInt32 {
        UInt32(b[o]) | (UInt32(b[o + 1]) << 8) | (UInt32(b[o + 2]) << 16) | (UInt32(b[o + 3]) << 24)
    }

    private func readUInt16LE(_ b: [UInt8], _ o: Int) -> UInt16 {
        UInt16(b[o]) | (UInt16(b[o + 1]) << 8)
    }

    private func readInt16LE(_ b: [UInt8], _ o: Int) -> Int16 {
        Int16(bitPattern: readUInt16LE(b, o))
    }

    private func ascii(_ b: [UInt8], _ range: Range<Int>) -> String {
        String(bytes: b[range], encoding: .ascii) ?? ""
    }

    // MARK: - Header layout

    @Test("Header layout is exact for stereo 48kHz")
    func headerStereo48k() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = WAVWriter()
        try writer.createFile(at: url, sampleRate: 48000, channels: 2)
        try writer.finalize()

        let bytes = [UInt8](try Data(contentsOf: url))
        #expect(bytes.count == 44)                       // header only, no audio data
        #expect(ascii(bytes, 0..<4) == "RIFF")
        #expect(readUInt32LE(bytes, 4) == 36)            // 36 + dataSize(0)
        #expect(ascii(bytes, 8..<12) == "WAVE")
        #expect(ascii(bytes, 12..<16) == "fmt ")
        #expect(readUInt32LE(bytes, 16) == 16)           // fmt chunk size
        #expect(readUInt16LE(bytes, 20) == 1)            // PCM
        #expect(readUInt16LE(bytes, 22) == 2)            // channels
        #expect(readUInt32LE(bytes, 24) == 48000)        // sample rate
        #expect(readUInt32LE(bytes, 28) == 48000 * 2 * 2) // byte rate
        #expect(readUInt16LE(bytes, 32) == 4)            // block align (channels * 2)
        #expect(readUInt16LE(bytes, 34) == 16)           // bits per sample
        #expect(ascii(bytes, 36..<40) == "data")
        #expect(readUInt32LE(bytes, 40) == 0)            // data size
    }

    @Test("Header layout is exact for mono 44.1kHz")
    func headerMono44k() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = WAVWriter()
        try writer.createFile(at: url, sampleRate: 44100, channels: 1)
        try writer.finalize()

        let bytes = [UInt8](try Data(contentsOf: url))
        #expect(readUInt16LE(bytes, 22) == 1)            // channels
        #expect(readUInt32LE(bytes, 24) == 44100)        // sample rate
        #expect(readUInt32LE(bytes, 28) == 44100 * 1 * 2) // byte rate
        #expect(readUInt16LE(bytes, 32) == 2)            // block align (channels * 2)
        #expect(readUInt16LE(bytes, 34) == 16)           // bits per sample
    }

    // MARK: - Finalize / byte accounting

    @Test("finalize rewrites RIFF and data sizes to match bytes written")
    func finalizeUpdatesSizes() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = WAVWriter()
        try writer.createFile(at: url, sampleRate: 48000, channels: 2)
        try writer.writeBuffer(makeFloatBuffer(channels: 2, frames: 100) { _, _ in 0 })
        try writer.finalize()

        let expectedDataSize: UInt32 = 100 * 2 * 2 // frames * channels * 2 bytes
        let bytes = [UInt8](try Data(contentsOf: url))
        #expect(readUInt32LE(bytes, 40) == expectedDataSize)          // data chunk size
        #expect(readUInt32LE(bytes, 4) == 36 + expectedDataSize)      // RIFF size
        #expect(bytes.count == 44 + Int(expectedDataSize))            // header + data
    }

    @Test("bytesWritten accumulates across multiple writeBuffer calls")
    func multipleWritesAccumulate() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = WAVWriter()
        try writer.createFile(at: url, sampleRate: 48000, channels: 2)
        for _ in 0..<3 {
            try writer.writeBuffer(makeFloatBuffer(channels: 2, frames: 50) { _, _ in 0 })
        }
        try writer.finalize()

        let expected: UInt32 = 3 * 50 * 2 * 2
        let bytes = [UInt8](try Data(contentsOf: url))
        #expect(readUInt32LE(bytes, 40) == expected)
    }

    @Test("Header is periodically rewritten so the file is playable without finalize (crash safety)")
    func periodicHeaderMakesFilePlayableWithoutFinalize() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = WAVWriter()
        try writer.createFile(at: url, sampleRate: 48000, channels: 2)

        // Write exactly enough buffers to trigger one periodic header rewrite.
        let frames = 64
        let count = WAVWriter.headerUpdateInterval
        for _ in 0..<count {
            try writer.writeBuffer(makeFloatBuffer(channels: 2, frames: AVAudioFrameCount(frames)) { _, _ in 0 })
        }

        // Deliberately DO NOT finalize — simulate a crash / force-quit.
        let bytes = [UInt8](try Data(contentsOf: url))
        let dataSize = readUInt32LE(bytes, 40)
        let expected = UInt32(count * frames * 2 * 2)
        #expect(dataSize == expected)   // header reflects written audio
        #expect(dataSize > 0)           // not the initial zero-size (unreadable) header
        #expect(readUInt32LE(bytes, 4) == 36 + expected)
    }

    // MARK: - Int16 conversion / clipping

    @Test("Float→Int16 conversion clamps to the representable range")
    func int16ConversionAndClipping() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let inputs: [Float] = [1.0, -1.0, 2.0, -2.0, 0.0]
        let writer = WAVWriter()
        try writer.createFile(at: url, sampleRate: 48000, channels: 1)
        try writer.writeBuffer(makeFloatBuffer(channels: 1, frames: AVAudioFrameCount(inputs.count)) { _, frame in
            inputs[frame]
        })
        try writer.finalize()

        let bytes = [UInt8](try Data(contentsOf: url))
        let samples = (0..<inputs.count).map { readInt16LE(bytes, 44 + $0 * 2) }
        // +1→32767, -1→-32767, +2 clamped→32767, -2 clamped→-32767, 0→0
        #expect(samples == [32767, -32767, 32767, -32767, 0])
    }

    @Test("Known asymmetry: full-scale negative encodes as -32767, never -32768")
    func fullScaleNegativeAsymmetry() throws {
        // Documents a known bug: WAVWriter uses `value * 32767.0`, so -1.0 maps to
        // -32767 and the minimum Int16 (-32768) is unreachable. Asserting current
        // behavior; a proper symmetric mapping is a separate fix.
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = WAVWriter()
        try writer.createFile(at: url, sampleRate: 48000, channels: 1)
        try writer.writeBuffer(makeFloatBuffer(channels: 1, frames: 1) { _, _ in -1.0 })
        try writer.finalize()

        let bytes = [UInt8](try Data(contentsOf: url))
        #expect(readInt16LE(bytes, 44) == -32767)
        #expect(readInt16LE(bytes, 44) != Int16.min)
    }

    @Test("Golden: a known ramp encodes to the expected Int16 little-endian bytes")
    func goldenRamp() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let ramp: [Float] = [-1.0, -0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75]
        let writer = WAVWriter()
        try writer.createFile(at: url, sampleRate: 48000, channels: 1)
        try writer.writeBuffer(makeFloatBuffer(channels: 1, frames: AVAudioFrameCount(ramp.count)) { _, frame in
            ramp[frame]
        })
        try writer.finalize()

        let expected = ramp.map { Int16(max(-1.0, min(1.0, $0)) * 32767.0) }
        let bytes = [UInt8](try Data(contentsOf: url))
        let samples = (0..<ramp.count).map { readInt16LE(bytes, 44 + $0 * 2) }
        #expect(samples == expected)
    }

    // MARK: - Size ceiling (BL-170)

    // WAV cannot exceed 4 GiB, and that is the *format's* limit, not ours: the
    // RIFF chunk size and data chunk size are both UInt32 fields. Before BL-170
    // the writer counted bytes in a UInt32 and incremented it unguarded, so
    // reaching the ceiling was not a truncated file — `+=` traps in Swift, so it
    // was a **crash in the middle of a take**, at 6h12m49s of 48kHz stereo.
    //
    // These drive the boundary through an injected cap rather than by writing
    // 4 GiB. Note a red run here does not look like a normal failure: an
    // overflow trap takes the test host down with it.

    @Test("Writing up to the cap succeeds and the header reports the true size")
    func writesUpToTheCap() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        // 512 stereo frames = 2048 bytes; two of them exactly fill a 4096 cap.
        let writer = WAVWriter(maxDataBytes: 4096)
        try writer.createFile(at: url, sampleRate: 48000, channels: 2)
        let buffer = makeFloatBuffer(channels: 2, frames: 512) { _, _ in 0 }

        try writer.writeBuffer(buffer)
        try writer.writeBuffer(buffer)
        try writer.finalize()

        let bytes = [UInt8](try Data(contentsOf: url))
        #expect(readUInt32LE(bytes, 40) == 4096, "data chunk size")
        #expect(readUInt32LE(bytes, 4) == 36 + 4096, "RIFF chunk size")
        #expect(bytes.count == 44 + 4096)
    }

    @Test("The buffer that would exceed the cap is refused, and nothing is written")
    func bufferPastTheCapIsRefused() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = WAVWriter(maxDataBytes: 4096)
        try writer.createFile(at: url, sampleRate: 48000, channels: 2)
        let buffer = makeFloatBuffer(channels: 2, frames: 512) { _, _ in 0 }

        try writer.writeBuffer(buffer)
        try writer.writeBuffer(buffer)

        #expect(throws: WAVWriterError.sizeLimitReached) {
            try writer.writeBuffer(buffer)
        }

        // Refused, not truncated: a partial frame would be silent corruption, so
        // the take keeps exactly what fit.
        try writer.finalize()
        let bytes = [UInt8](try Data(contentsOf: url))
        #expect(readUInt32LE(bytes, 40) == 4096)
        #expect(bytes.count == 44 + 4096)
    }

    @Test("A buffer that only partly fits is refused whole")
    func partiallyFittingBufferIsRefusedWhole() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        // Cap deliberately not a multiple of the 2048-byte buffer.
        let writer = WAVWriter(maxDataBytes: 3000)
        try writer.createFile(at: url, sampleRate: 48000, channels: 2)
        let buffer = makeFloatBuffer(channels: 2, frames: 512) { _, _ in 0 }

        try writer.writeBuffer(buffer)   // 2048 ≤ 3000, fits
        #expect(throws: WAVWriterError.sizeLimitReached) {
            try writer.writeBuffer(buffer)   // 4096 > 3000, refused whole
        }

        try writer.finalize()
        let bytes = [UInt8](try Data(contentsOf: url))
        #expect(readUInt32LE(bytes, 40) == 2048, "no partial frame was written")
    }

    @Test("The real ceiling is the RIFF field's, block-aligned")
    func realCeilingIsDerivedNotGuessed() {
        // 36 + dataSize must fit UInt32, so dataSize ≤ 2³² − 37; and dataSize must
        // be a whole number of frames, so round down to a multiple of the block
        // align (4 bytes for 16-bit stereo).
        #expect(WAVWriter.maximumDataBytes == 4_294_967_256)
        #expect(WAVWriter.maximumDataBytes % 4 == 0, "must be a whole number of stereo frames")

        // The header arithmetic that used to trap 36 bytes before the counter did.
        let riff = UInt64(36) + UInt64(WAVWriter.maximumDataBytes)
        #expect(riff <= UInt64(UInt32.max), "36 + dataSize must not overflow")

        // And the duration that implies, which is what the user actually meets.
        let seconds = Double(WAVWriter.maximumDataBytes) / 192_000.0
        #expect(seconds > 22_369.0 && seconds < 22_370.0, "≈ 6h12m49s at 48kHz stereo")
    }

    @Test("An unsafe cap is clamped, so the header arithmetic cannot be made to trap")
    func unsafeCapIsClamped() {
        // The 36-byte window `36 + dataSize` used to overflow in is the top of
        // UInt32, and the counter's 4096-byte stride steps over it — which is why
        // the crash lands on the counter and not the header ~99% of the time.
        // Rather than try to write 4 GiB to reach it, close the window by
        // construction: no caller can set a cap that would let `dataSize` enter
        // it, including a caller that passes UInt32.max outright.
        #expect(WAVWriter(maxDataBytes: .max).effectiveMaxDataBytes == WAVWriter.maximumDataBytes)
        #expect(WAVWriter(maxDataBytes: UInt32.max - 20).effectiveMaxDataBytes == WAVWriter.maximumDataBytes)

        // A safe cap is honoured as given.
        #expect(WAVWriter(maxDataBytes: 4096).effectiveMaxDataBytes == 4096)

        // The invariant the clamp buys: for every reachable dataSize, the RIFF
        // field fits without narrowing.
        for candidate: UInt32 in [0, 4096, WAVWriter.maximumDataBytes] {
            #expect(UInt64(36) + UInt64(candidate) <= UInt64(UInt32.max))
        }
    }

    @Test("Repairing an oversized orphan clamps instead of trapping")
    func repairClampsOversizedFile() {
        let header = WAVWriter.headerByteCount

        // Ordinary files: payload is just total minus the header.
        #expect(WAVWriter.repairableDataSize(totalBytes: header) == 0)
        #expect(WAVWriter.repairableDataSize(totalBytes: header + 4096) == 4096)

        // A file at exactly the ceiling stays exact.
        let atCeiling = header + Int(WAVWriter.maximumDataBytes)
        #expect(WAVWriter.repairableDataSize(totalBytes: atCeiling) == WAVWriter.maximumDataBytes)

        // And past it — the case that used to take the whole app down, because
        // `UInt32(total - headerByteCount)` traps rather than saturating. These
        // are the sizes an old build could leave behind after a crash.
        #expect(WAVWriter.repairableDataSize(totalBytes: atCeiling + 1) == WAVWriter.maximumDataBytes)
        #expect(WAVWriter.repairableDataSize(totalBytes: 8_000_000_000) == WAVWriter.maximumDataBytes)

        // Degenerate input must not underflow into a huge size either.
        #expect(WAVWriter.repairableDataSize(totalBytes: 0) == 0)
        #expect(WAVWriter.repairableDataSize(totalBytes: 10) == 0)
    }

    // MARK: - Error paths

    @Test("writeBuffer before createFile throws .fileNotOpen")
    func writeBeforeCreateThrows() {
        let writer = WAVWriter()
        let buffer = makeFloatBuffer(channels: 2, frames: 10) { _, _ in 0 }
        #expect(throws: WAVWriterError.fileNotOpen) {
            try writer.writeBuffer(buffer)
        }
    }

    @Test("finalize before createFile throws .fileNotOpen")
    func finalizeBeforeCreateThrows() {
        let writer = WAVWriter()
        #expect(throws: WAVWriterError.fileNotOpen) {
            try writer.finalize()
        }
    }

    @Test("writeBuffer with a non-float buffer throws .invalidFormat")
    func nonFloatBufferThrows() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = WAVWriter()
        try writer.createFile(at: url, sampleRate: 48000, channels: 2)

        let intFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 48000,
            channels: 2,
            interleaved: true
        )!
        let intBuffer = AVAudioPCMBuffer(pcmFormat: intFormat, frameCapacity: 10)!
        intBuffer.frameLength = 10

        #expect(throws: WAVWriterError.invalidFormat) {
            try writer.writeBuffer(intBuffer)
        }
    }
}

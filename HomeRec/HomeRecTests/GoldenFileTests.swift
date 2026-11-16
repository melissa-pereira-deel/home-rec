//
//  GoldenFileTests.swift
//  HomeRecTests
//
//  BL-051 / BL-007 behavior guard: feed a deterministic, non-zero buffer
//  sequence through the full AudioRecorder and assert the produced WAV's PCM
//  bytes exactly match an independently-computed reference. Uses the recorder's
//  production format (48kHz stereo, the header it always writes). Buffers are
//  fed as canonical non-interleaved AVAudioPCMBuffer (BL-099) — the same shape
//  every AudioCapturing source delivers; interleaved-source conversion is
//  covered separately by AudioSampleConverterTests.
//

import Testing
import Foundation
import AVFoundation
@testable import HomeRec

@MainActor
struct GoldenFileTests {

    private let bufferCount = 5
    private let framesPerBuffer = 64
    private let channels = 2

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("golden-\(UUID().uuidString).wav")
    }

    /// Deterministic, channel-distinct sample in [-1, 1).
    private func sample(buffer b: Int, channel ch: Int, frame f: Int) -> Float {
        let n = b * framesPerBuffer + f
        let base = Float(n % 200) / 100.0 - 1.0   // -1.0 … 0.99
        return ch == 0 ? base : -base
    }

    /// The WAV `data` bytes we expect: interleaved Int16 LE (frame-major), using
    /// the exact clamp+scale WAVWriter applies.
    private func expectedPCMBytes() -> [UInt8] {
        var bytes = [UInt8]()
        bytes.reserveCapacity(bufferCount * framesPerBuffer * channels * 2)
        for b in 0..<bufferCount {
            for f in 0..<framesPerBuffer {
                for ch in 0..<channels {
                    let clamped = max(-1.0, min(1.0, sample(buffer: b, channel: ch, frame: f)))
                    let u = UInt16(bitPattern: Int16(clamped * 32767.0))
                    bytes.append(UInt8(u & 0xff))
                    bytes.append(UInt8(u >> 8))
                }
            }
        }
        return bytes
    }

    /// The full recorded file (header + data).
    private func recordedBytes() async throws -> [UInt8] {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let recorder = AudioRecorder()
        try recorder.startRecording(to: url, format: .wav)
        for b in 0..<bufferCount {
            let pcmBuffer = SampleBufferFixtures.makePCMBuffer(
                channels: channels, frames: framesPerBuffer, interleaved: false
            ) { ch, f in sample(buffer: b, channel: ch, frame: f) }
            recorder.processAudioSample(pcmBuffer)
        }
        try await recorder.stopRecording()   // drains the queue, then finalizes

        return [UInt8](try Data(contentsOf: url))
    }

    private func recordedPCMBytes() async throws -> [UInt8] {
        Array(try await recordedBytes()[44...])   // strip the 44-byte header
    }

    @Test("Canonical PCM buffer input → expected WAV PCM bytes (golden)")
    func golden() async throws {
        #expect(try await recordedPCMBytes() == expectedPCMBytes())
    }

    @Test("WAV header is the expected 48kHz stereo PCM header (unchanged by the encoder seam)")
    func goldenHeader() async throws {
        let bytes = try await recordedBytes()
        #expect(bytes.count >= 44)

        func u32(_ o: Int) -> UInt32 {
            UInt32(bytes[o]) | (UInt32(bytes[o + 1]) << 8) | (UInt32(bytes[o + 2]) << 16) | (UInt32(bytes[o + 3]) << 24)
        }
        func u16(_ o: Int) -> UInt16 { UInt16(bytes[o]) | (UInt16(bytes[o + 1]) << 8) }
        func ascii(_ r: Range<Int>) -> String { String(bytes: bytes[r], encoding: .ascii) ?? "" }

        let dataSize = UInt32(bufferCount * framesPerBuffer * channels * 2)
        #expect(ascii(0..<4) == "RIFF")
        #expect(u32(4) == 36 + dataSize)
        #expect(ascii(8..<12) == "WAVE")
        #expect(ascii(12..<16) == "fmt ")
        #expect(u32(16) == 16)              // fmt chunk size
        #expect(u16(20) == 1)               // PCM
        #expect(u16(22) == 2)               // channels
        #expect(u32(24) == 48000)           // sample rate
        #expect(u32(28) == 48000 * 2 * 2)   // byte rate
        #expect(u16(32) == 4)               // block align
        #expect(u16(34) == 16)              // bits per sample
        #expect(ascii(36..<40) == "data")
        #expect(u32(40) == dataSize)
    }
}

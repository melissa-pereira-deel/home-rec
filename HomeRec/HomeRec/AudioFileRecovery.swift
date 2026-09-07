//
//  AudioFileRecovery.swift
//  HomeRec
//
//  BL-140: telling a crash-interrupted recording from a normally-finished one,
//  and making the interrupted one playable.
//
//  Every detector here is MEASURED against real finalized/crash-snapshot pairs
//  (see private/reports/2026-07-30-bl100-daw-spike-results.md's sibling, the
//  BL-140 detector spike). None of it is inferred from documentation:
//
//    WAV   header dataSize != fileSize - 44   → finalize() writes the exact size,
//                                               the periodic rewrite lags (BL-022)
//    M4A   a top-level `moof` box exists      → finishWriting() consolidates
//                                               fragments, so a finished file is
//                                               flat `ftyp mdat moov` (BL-016)
//    FLAC  bytes 4...41 are all zero          → STREAMINFO is written only at
//                                               close(); everything else, including
//                                               VORBIS_COMMENT, is already in place
//
//  The format→handler mapping lives on `AudioFormat` (one exhaustive switch the
//  compiler checks), NOT in the scanner. A `switch` on file extension in the
//  scanner is the shape that let BL-012 ship without durability — see BL-018.
//

import Foundation
import AVFoundation

enum AudioFileRecoveryError: Error, LocalizedError, Equatable {
    case unreadable
    case notRepairable
    case repairFailed

    var errorDescription: String? {
        switch self {
        case .unreadable:     return "The recording couldn't be read"
        case .notRepairable:  return "This recording is too short to recover"
        case .repairFailed:   return "The recording couldn't be repaired"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unreadable:     return "Check that the file still exists and is readable"
        case .notRepairable:  return "Recordings shorter than about a tenth of a second contain no audio to recover"
        case .repairFailed:   return "Check that there is enough free disk space, then try again"
        }
    }
}

/// Type-level, because detection happens with no encoder instance — the file is
/// found on disk long after the process that wrote it died.
protocol AudioFileRecovering {
    /// True when the file was never finalized (crash / force-quit).
    static func isUnfinalized(at url: URL) throws -> Bool

    /// Whether a repair would actually yield playable audio. A file can be
    /// unfinalized *and* beyond saving — a FLAC with no encoded packet, say.
    static func isRepairable(at url: URL) throws -> Bool

    /// Make the file playable, in place. Must be atomic: a crash mid-repair
    /// leaves either the original or a valid repaired file, never a hybrid.
    static func repair(at url: URL) throws
}

// MARK: - Shared helpers

private enum RecoveryIO {
    static func size(of url: URL) throws -> Int {
        guard let n = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int else {
            throw AudioFileRecoveryError.unreadable
        }
        return n
    }

    /// Read the first `count` bytes without paging in the whole recording — these
    /// files can be hours long and we only ever need the header.
    static func head(of url: URL, _ count: Int) throws -> Data {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw AudioFileRecoveryError.unreadable
        }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: count)) ?? Data()
    }

    /// Copy → mutate → atomic replace. `replaceItemAt` is atomic on the same
    /// volume, so an interrupted repair can never leave a half-patched take.
    static func atomicallyPatch(_ url: URL, _ mutate: (inout Data) throws -> Void) throws {
        guard var bytes = try? Data(contentsOf: url) else {
            throw AudioFileRecoveryError.unreadable
        }
        try mutate(&bytes)

        let temp = url.deletingLastPathComponent()
            .appendingPathComponent(".homerec-repair-\(UUID().uuidString)")
        do {
            try bytes.write(to: temp, options: .atomic)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw AudioFileRecoveryError.repairFailed
        }
    }

    static func uint32LE(_ d: Data, _ offset: Int) -> UInt32 {
        guard d.count >= offset + 4 else { return 0 }
        return UInt32(d[offset]) | (UInt32(d[offset + 1]) << 8)
            | (UInt32(d[offset + 2]) << 16) | (UInt32(d[offset + 3]) << 24)
    }
}

// MARK: - WAV

extension WAVWriter: AudioFileRecovering {

    /// The 44-byte canonical header this writer emits.
    static let headerByteCount = 44

    static func isUnfinalized(at url: URL) throws -> Bool {
        let total = try RecoveryIO.size(of: url)
        guard total > headerByteCount else { return true }   // header-only: never finalized

        let head = try RecoveryIO.head(of: url, headerByteCount)
        guard head.count == headerByteCount,
              head.prefix(4) == Data("RIFF".utf8) else { throw AudioFileRecoveryError.unreadable }

        // `finalize()` stamps the exact byte count; the periodic rewrite lags by up
        // to `headerUpdateInterval` buffers. A mismatch therefore means the file
        // was still being written. (A crash landing exactly on a rewrite boundary
        // is indistinguishable — and harmless, since that file is already correct.)
        return Int(RecoveryIO.uint32LE(head, 40)) != total - headerByteCount
    }

    static func isRepairable(at url: URL) throws -> Bool {
        try RecoveryIO.size(of: url) > headerByteCount
    }

    /// The `data` chunk size to stamp when repairing a file of `totalBytes`.
    ///
    /// Clamps rather than narrows (BL-170). `UInt32(total - headerByteCount)`
    /// **traps** on a file larger than 4 GiB — so the tool that exists to rescue
    /// an interrupted take would crash on exactly the oversized file the old
    /// writer could produce. Nothing creates such a file any more, but ones
    /// already on disk outlive the fix.
    ///
    /// Clamping repairs to a valid 4 GiB WAV rather than refusing: audio past the
    /// RIFF ceiling is unaddressable by the format regardless, and a playable
    /// file holding the first ~6 hours beats an unreadable one holding
    /// everything.
    ///
    /// Split out from `repair` so the boundary is testable without a 4 GiB
    /// fixture — `RecoveryIO.atomicallyPatch` reads the whole file into memory,
    /// so one could not be used here anyway.
    static func repairableDataSize(totalBytes: Int) -> UInt32 {
        let payload = UInt64(max(0, totalBytes - headerByteCount))
        return UInt32(min(payload, UInt64(WAVWriter.maximumDataBytes)))
    }


    static func repair(at url: URL) throws {
        let total = try RecoveryIO.size(of: url)
        guard total > headerByteCount else { throw AudioFileRecoveryError.notRepairable }
        let dataSize = Self.repairableDataSize(totalBytes: total)

        try RecoveryIO.atomicallyPatch(url) { bytes in
            func put(_ value: UInt32, at offset: Int) {
                bytes[offset]     = UInt8(value & 0xFF)
                bytes[offset + 1] = UInt8((value >> 8) & 0xFF)
                bytes[offset + 2] = UInt8((value >> 16) & 0xFF)
                bytes[offset + 3] = UInt8((value >> 24) & 0xFF)
            }
            // Safe: `dataSize` is clamped to maximumDataBytes, which is derived
            // so that `36 + dataSize` fits UInt32.
            put(dataSize + 36, at: 4)    // RIFF chunk size
            put(dataSize, at: 40)        // data chunk size
        }
    }
}

// MARK: - M4A

extension M4AEncoder: AudioFileRecovering {

    /// Walk the top-level box list. `moof` (movie fragment) appears only in a file
    /// whose `finishWriting()` never ran — see the header note.
    private static func topLevelBoxTypes(at url: URL) throws -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw AudioFileRecoveryError.unreadable
        }
        defer { try? handle.close() }

        let total = try RecoveryIO.size(of: url)
        var offset = 0
        var types: [String] = []

        while offset + 8 <= total {
            try handle.seek(toOffset: UInt64(offset))
            guard let header = try handle.read(upToCount: 8), header.count == 8 else { break }

            // Box sizes are big-endian.
            var size = (Int(header[0]) << 24) | (Int(header[1]) << 16)
                     | (Int(header[2]) << 8)  | Int(header[3])
            let type = String(decoding: header[4..<8], as: UTF8.self)
            types.append(type)

            if size == 0 { break }                     // extends to EOF
            if size == 1 {                             // 64-bit extended size
                guard let ext = try handle.read(upToCount: 8), ext.count == 8 else { break }
                var big = 0
                for byte in ext { big = (big << 8) | Int(byte) }
                size = big
            }
            guard size >= 8 else { break }
            offset += size
        }
        return types
    }

    static func isUnfinalized(at url: URL) throws -> Bool {
        try topLevelBoxTypes(at: url).contains("moof")
    }

    /// A fragmented M4A already plays; recovery is purely "stop offering it".
    static func isRepairable(at url: URL) throws -> Bool {
        try isUnfinalized(at: url)
    }

    static func repair(at url: URL) throws {
        // Nothing to do — `movieFragmentInterval` (BL-016) means the fragments on
        // disk are already a playable file. Remuxing to a flat layout is an
        // explicit non-goal; it would rewrite the whole take for no user benefit.
    }
}

// MARK: - FLAC

extension FLACEncoder: AudioFileRecovering {

    /// `fLaC` magic (4) + metadata block header (4) + STREAMINFO body (34).
    private static let streamInfoRange = 4..<42
    private static let streamInfoBodyLength = 34

    static func isUnfinalized(at url: URL) throws -> Bool {
        let head = try RecoveryIO.head(of: url, 42)
        guard head.count == 42 else { throw AudioFileRecoveryError.unreadable }
        guard head.prefix(4) == Data("fLaC".utf8) else {
            throw AudioFileRecoveryError.unreadable
        }
        // AVAudioFile reserves the STREAMINFO region up front and fills it only in
        // close(). Everything after it — including VORBIS_COMMENT — is already
        // correct, which is why patching these 38 bytes is a complete repair.
        return head[streamInfoRange].allSatisfy { $0 == 0 }
    }

    /// Audio begins after the metadata blocks. Below that there is no encoded
    /// packet at all (FLAC emits nothing under one 4608-frame block), so there is
    /// literally nothing to recover — see `minimumEncodableFrames`.
    private static func audioStartOffset(at url: URL) throws -> Int {
        let head = try RecoveryIO.head(of: url, 64)
        guard head.count >= 46 else { throw AudioFileRecoveryError.unreadable }
        // Block after STREAMINFO starts at 42: 1 flag/type byte + 3 length bytes.
        let length = (Int(head[43]) << 16) | (Int(head[44]) << 8) | Int(head[45])
        return 46 + length
    }

    static func isRepairable(at url: URL) throws -> Bool {
        let total = try RecoveryIO.size(of: url)
        guard total > 42 else { return false }
        return total > (try audioStartOffset(at: url))
    }

    /// The encoder's fixed output settings. A recording made by this app is always
    /// 48 kHz / stereo / 24-bit (`AudioRecorder` pins the first two, the FLAC
    /// encoder the third), so these can be restored rather than recovered.
    private static let repairSampleRate: UInt64 = 48_000
    private static let repairChannels: UInt64 = 2
    private static let repairBitsPerSample: UInt64 = 24

    private static func patchStreamInfo(_ bytes: inout Data, totalSamples: UInt64) {
        // Metadata block header: STREAMINFO (type 0), not last — VORBIS_COMMENT
        // follows it and carries the last-block flag.
        bytes[4] = 0x00
        bytes[5] = 0x00
        bytes[6] = 0x00
        bytes[7] = UInt8(streamInfoBodyLength)

        // min/max block size — fixed by this encoder.
        let blockSize = UInt16(FLACEncoder.minimumEncodableFrames)
        bytes[8]  = UInt8(blockSize >> 8);  bytes[9]  = UInt8(blockSize & 0xFF)
        bytes[10] = UInt8(blockSize >> 8);  bytes[11] = UInt8(blockSize & 0xFF)

        // min/max frame size: 0 means "unknown", which the format permits.
        for i in 12..<18 { bytes[i] = 0 }

        // 20b sample rate | 3b (channels-1) | 5b (bitsPerSample-1) | 36b total.
        let packed = (repairSampleRate << 44)
            | ((repairChannels - 1) << 41)
            | ((repairBitsPerSample - 1) << 36)
            | (totalSamples & 0xF_FFFF_FFFF)
        for i in 0..<8 { bytes[18 + i] = UInt8((packed >> (56 - 8 * UInt64(i))) & 0xFF) }

        // MD5 all-zero = "not computed". Legal, and recomputing it would mean
        // hashing the decoded audio for no user-visible benefit.
        for i in 26..<42 { bytes[i] = 0 }
    }

    /// Decode the repaired file to learn its true length. Measured at ~0.7 ms per
    /// second of audio — about 2.4 s for a one-hour recording — which is why this
    /// is worth doing: leaving `totalSamples` at the "unknown" sentinel produces a
    /// file that decodes perfectly but reports **0:00** everywhere, and a recovery
    /// feature that hands back a take showing zero duration undermines the exact
    /// trust it exists to create.
    private static func countFrames(at url: URL) -> UInt64? {
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: FLACEncoder.minimumEncodableFrames)
        else { return nil }
        var total: UInt64 = 0
        while true {
            do { try file.read(into: buffer) } catch { break }
            if buffer.frameLength == 0 { break }
            total += UInt64(buffer.frameLength)
        }
        return total > 0 ? total : nil
    }

    static func repair(at url: URL) throws {
        guard try isRepairable(at: url) else { throw AudioFileRecoveryError.notRepairable }
        guard var bytes = try? Data(contentsOf: url) else {
            throw AudioFileRecoveryError.unreadable
        }

        let temp = url.deletingLastPathComponent()
            .appendingPathComponent(".homerec-repair-\(UUID().uuidString)")
        do {
            // Pass 1: a valid header with an unknown length — enough to decode.
            patchStreamInfo(&bytes, totalSamples: 0)
            try bytes.write(to: temp, options: .atomic)

            // Pass 2: stamp the real length. If counting fails the pass-1 file is
            // still valid and playable, so this can degrade without losing audio.
            if let frames = countFrames(at: temp) {
                patchStreamInfo(&bytes, totalSamples: frames)
                try bytes.write(to: temp, options: .atomic)
            }

            _ = try FileManager.default.replaceItemAt(url, withItemAt: temp)
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw AudioFileRecoveryError.repairFailed
        }
    }
}

//
//  WAVWriter.swift
//  HomeRec
//
//  Writes PCM audio data to WAV file format
//

import Foundation
import AVFoundation

/// Errors that can occur during WAV file writing
enum WAVWriterError: Error, LocalizedError, Equatable {
    case fileCreationFailed
    case fileWriteFailed
    case invalidFormat
    case fileNotOpen
    /// A buffer arrived whose rate/channels differ from what the header declares.
    case formatMismatch
    /// The take reached the largest size a WAV file can hold (BL-170).
    case sizeLimitReached

    var errorDescription: String? {
        switch self {
        case .fileCreationFailed:
            return "Failed to create WAV file"
        case .fileWriteFailed:
            return "Failed to write audio data to file"
        case .invalidFormat:
            return "Invalid audio format"
        case .fileNotOpen:
            return "WAV file is not open for writing"
        case .formatMismatch:
            return "Audio format changed mid-recording"
        case .sizeLimitReached:
            return "This recording reached the largest size a WAV file can hold"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .fileCreationFailed:
            return "Check if you have write permissions to the destination folder"
        case .fileWriteFailed:
            return "Check if there is enough disk space available"
        case .invalidFormat:
            return "Use 44.1kHz or 48kHz stereo format"
        case .fileNotOpen:
            return "Call createFile() before writing data"
        case .formatMismatch:
            return "Capture buffers must be normalised to the file's declared format before writing"
        case .sizeLimitReached:
            // Deliberately NOT `.fileWriteFailed`'s "check disk space" — the disk
            // is fine, the file is complete, and the other two formats have no
            // comparable limit.
            return "Record the next stretch as a new take, or choose M4A or FLAC for longer recordings"
        }
    }
}

/// Writes audio data to WAV file. The `.wav` conformer of `AudioFileEncoder` (BL-011).
nonisolated class WAVWriter: AudioFileEncoder {

    // MARK: - Properties

    private var fileHandle: FileHandle?
    private var fileURL: URL?
    private var sampleRate: Double = 44100.0
    private var channels: Int = 2
    /// Bytes of PCM written so far.
    ///
    /// `UInt64`, not `UInt32`, and that is the whole of BL-170. The counter used
    /// to be `UInt32` and was incremented unguarded — and `+=` **traps** in Swift
    /// rather than wrapping, so reaching WAV's 4 GiB ceiling was not a truncated
    /// file, it was a crash in the middle of a take. Widening the counter means
    /// the arithmetic can no longer be the thing that fails; the ceiling is
    /// enforced deliberately, below, with a check *before* the addition.
    ///
    /// A trap cannot be caught, so this could never have been handled as an
    /// error. It had to stop being reachable.
    private var bytesWritten: UInt64 = 0

    /// The largest `data` chunk a WAV file can legally hold, for this writer's
    /// block alignment.
    ///
    /// This is the **format's** limit, not a policy: RIFF stores both the chunk
    /// size (offset 4) and the data size (offset 40) in `UInt32` fields. The
    /// binding one is the RIFF field, which holds `36 + dataSize`:
    ///
    ///     36 + dataSize ≤ UInt32.max      →  dataSize ≤ 4_294_967_259
    ///
    /// and `dataSize` must be a whole number of frames, so it rounds down to a
    /// multiple of the block align (4 bytes for 16-bit stereo):
    ///
    ///     4_294_967_256 bytes  =  6 h 12 m 49.6 s at 48 kHz stereo
    ///
    /// Derived rather than written as a literal so the reasoning survives a
    /// change of format.
    static let maximumDataBytes: UInt32 = {
        let blockAlign: UInt32 = 4          // 2 channels × 16-bit
        return ((UInt32.max - 36) / blockAlign) * blockAlign
    }()

    /// The cap this instance enforces. Injectable so the boundary is testable
    /// without writing 4 GiB — the same reason `AudioRecorder` takes an
    /// `encoderFactory` (BL-016). Always clamped to `maximumDataBytes`, so no
    /// caller can widen the window the format itself imposes.
    let effectiveMaxDataBytes: UInt32

    init(maxDataBytes: UInt32 = WAVWriter.maximumDataBytes) {
        self.effectiveMaxDataBytes = min(maxDataBytes, WAVWriter.maximumDataBytes)
    }

    /// Rewrite the header in place after this many buffers (~0.7s at 48kHz) so the
    /// on-disk file stays playable even if `finalize()` never runs (crash/force-quit).
    static let headerUpdateInterval = 32
    private var buffersSinceHeaderUpdate = 0

    // MARK: - Public Methods

    /// Create WAV file and write header
    /// - Parameters:
    ///   - url: File URL where WAV file will be created
    ///   - sampleRate: Sample rate (44100 or 48000)
    ///   - channels: Number of channels (1 for mono, 2 for stereo)
    /// - Throws: WAVWriterError if file creation fails
    func createFile(at url: URL, sampleRate: Double, channels: Int) throws {
        self.fileURL = url
        self.sampleRate = sampleRate
        self.channels = channels
        self.bytesWritten = 0
        self.buffersSinceHeaderUpdate = 0

        // Create the file
        let fileManager = FileManager.default
        guard fileManager.createFile(atPath: url.path, contents: nil, attributes: nil) else {
            throw WAVWriterError.fileCreationFailed
        }

        // Open file handle
        do {
            fileHandle = try FileHandle(forWritingTo: url)
        } catch {
            throw WAVWriterError.fileCreationFailed
        }

        // Write initial WAV header (will be updated in finalize())
        try writeWAVHeader(dataSize: 0)
    }

    /// Write audio buffer to file
    /// - Parameter buffer: AVAudioPCMBuffer containing audio data
    /// - Throws: WAVWriterError if write fails
    func writeBuffer(_ buffer: AVAudioPCMBuffer) throws {
        guard let fileHandle = fileHandle else {
            throw WAVWriterError.fileNotOpen
        }

        // The header was stamped with the rate and channel count `createFile`
        // was given, but the payload loop below interleaves using the *buffer's*
        // channel count. A mismatch is therefore silent corruption, not a bad
        // frame: a mono buffer written into a stereo-declared file reads back as
        // L/R pairs — half speed, an octave down — and a 44.1 kHz buffer plays
        // ~8.8% fast. `AudioFormatNormalizer` should make this unreachable; if it
        // is ever reached, refusing beats writing a pitch-shifted file (BL-112).
        //
        // Deliberately narrower than FLAC's full `AVAudioFormat` equality: these
        // two fields are what the header commits to, and interleaving is already
        // covered by the `floatChannelData` guard below.
        guard buffer.format.sampleRate == sampleRate,
              Int(buffer.format.channelCount) == channels else {
            throw WAVWriterError.formatMismatch
        }

        guard let floatChannelData = buffer.floatChannelData else {
            throw WAVWriterError.invalidFormat
        }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Convert Float32 to Int16 PCM
        var int16Data = [Int16]()
        int16Data.reserveCapacity(frameLength * channelCount)

        for frame in 0..<frameLength {
            for channel in 0..<channelCount {
                let floatValue = floatChannelData[channel][frame]
                // Clamp and convert to Int16
                let clampedValue = max(-1.0, min(1.0, floatValue))
                let int16Value = Int16(clampedValue * 32767.0)
                int16Data.append(int16Value)
            }
        }

        // Write to file.
        //
        // ⚠️ `write(contentsOf:)`, not `write(_:)`. The nonthrowing `write(_:)`
        // signals a failed write — a full disk, an ejected volume — by raising an
        // ObjC `NSException`, which Swift cannot catch. So WAV could not detect an
        // IO failure at all: the take carried on, the file stopped growing, and
        // nothing anywhere found out. `write(contentsOf:)` throws instead, and
        // `AudioRecorder` now listens (BL-173).
        let data = Data(bytes: int16Data, count: int16Data.count * MemoryLayout<Int16>.size)

        // Refuse the whole buffer rather than writing the part that fits (BL-170).
        // A partial frame is silent corruption — the tail would read back as
        // interleaved garbage — so the take keeps exactly the frames that fit and
        // stops. Checked *before* the write and before the addition, because an
        // overflow traps and cannot be caught after the fact.
        guard bytesWritten + UInt64(data.count) <= UInt64(effectiveMaxDataBytes) else {
            throw WAVWriterError.sizeLimitReached
        }

        do {
            try fileHandle.write(contentsOf: data)
        } catch {
            throw WAVWriterError.fileWriteFailed
        }
        bytesWritten += UInt64(data.count)

        // Periodically rewrite the header so the file is playable even if the
        // app is killed before finalize() runs.
        buffersSinceHeaderUpdate += 1
        if buffersSinceHeaderUpdate >= Self.headerUpdateInterval {
            buffersSinceHeaderUpdate = 0
            updateHeaderInPlace()
        }
    }

    /// Overwrite the 44-byte header with the current data size, then seek back to
    /// the end so appending continues. Best-effort: `finalize()` writes the
    /// authoritative header.
    private func updateHeaderInPlace() {
        guard let fileHandle = fileHandle else { return }
        do {
            try fileHandle.seek(toOffset: 0)
            fileHandle.write(createWAVHeader(dataSize: currentDataSize))
            try fileHandle.seekToEnd()
        } catch {
            // Ignore; the next periodic update or finalize() will correct the header.
        }
    }

    /// Finalize WAV file and update header with correct sizes
    /// - Throws: WAVWriterError if finalization fails
    func finalize() throws {
        guard let fileHandle = fileHandle, let fileURL = fileURL else {
            throw WAVWriterError.fileNotOpen
        }

        // Close the file
        try? fileHandle.close()
        self.fileHandle = nil

        // Re-open for reading and writing to update header
        do {
            let handle = try FileHandle(forUpdating: fileURL)
            defer { try? handle.close() }

            // Seek to beginning and update header with actual data size
            try handle.seek(toOffset: 0)

            let headerData = createWAVHeader(dataSize: currentDataSize)
            handle.write(headerData)
        } catch {
            throw WAVWriterError.fileWriteFailed
        }
    }

    // MARK: - Private Methods

    /// Write initial WAV header to file
    /// - Parameter dataSize: Size of audio data (0 initially)
    /// - Throws: WAVWriterError if write fails
    private func writeWAVHeader(dataSize: UInt32) throws {
        guard let fileHandle = fileHandle else {
            throw WAVWriterError.fileNotOpen
        }

        let headerData = createWAVHeader(dataSize: dataSize)
        fileHandle.write(headerData)
    }

    /// `bytesWritten` narrowed for the header fields.
    ///
    /// Safe by construction rather than by hope: the guard in `writeBuffer` means
    /// `bytesWritten` can never exceed `effectiveMaxDataBytes`, which is itself
    /// clamped to `maximumDataBytes` — so both this narrowing and the
    /// `36 + dataSize` below are in range. That second expression is the one that
    /// used to overflow 36 bytes *before* the counter did, in the ~1% of cases
    /// where a buffer size let the counter land inside that window instead of
    /// stepping over it.
    private var currentDataSize: UInt32 {
        UInt32(bytesWritten)
    }

    /// Create WAV header data
    /// - Parameter dataSize: Size of audio data in bytes
    /// - Returns: WAV header as Data
    private func createWAVHeader(dataSize: UInt32) -> Data {
        var data = Data()

        // RIFF chunk
        data.append(string: "RIFF")
        data.append(uint32: 36 + dataSize) // File size - 8
        data.append(string: "WAVE")

        // fmt chunk
        data.append(string: "fmt ")
        data.append(uint32: 16) // fmt chunk size
        data.append(uint16: 1) // Audio format (1 = PCM)
        data.append(uint16: UInt16(channels)) // Number of channels
        data.append(uint32: UInt32(sampleRate)) // Sample rate
        let byteRate = UInt32(sampleRate) * UInt32(channels) * 2 // bytes per second
        data.append(uint32: byteRate)
        data.append(uint16: UInt16(channels * 2)) // Block align
        data.append(uint16: 16) // Bits per sample

        // data chunk
        data.append(string: "data")
        data.append(uint32: dataSize) // Data size

        return data
    }

    // MARK: - Cleanup

    deinit {
        try? fileHandle?.close()
    }
}

// MARK: - Data Extension Helpers

// `nonisolated` for the same reason the writer is: these run on
// `AudioRecorder.processingQueue`, and the app target would otherwise infer
// `@MainActor` on an unannotated extension.
nonisolated extension Data {
    mutating func append(string: String) {
        if let stringData = string.data(using: .ascii) {
            self.append(stringData)
        }
    }

    mutating func append(uint16: UInt16) {
        var value = uint16
        Swift.withUnsafeBytes(of: &value) { bytes in
            self.append(contentsOf: bytes)
        }
    }

    mutating func append(uint32: UInt32) {
        var value = uint32
        Swift.withUnsafeBytes(of: &value) { bytes in
            self.append(contentsOf: bytes)
        }
    }
}

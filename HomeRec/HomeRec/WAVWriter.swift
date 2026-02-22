//
//  WAVWriter.swift
//  HomeRec
//
//  Writes PCM audio data to WAV file format
//

import Foundation
import AVFoundation

/// Errors that can occur during WAV file writing
enum WAVWriterError: Error, LocalizedError {
    case fileCreationFailed
    case fileWriteFailed
    case invalidFormat
    case fileNotOpen

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
        }
    }
}

/// Writes audio data to WAV file
class WAVWriter {

    // MARK: - Properties

    private var fileHandle: FileHandle?
    private var fileURL: URL?
    private var sampleRate: Double = 44100.0
    private var channels: Int = 2
    private var bytesWritten: UInt32 = 0

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

        // Write to file
        let data = Data(bytes: int16Data, count: int16Data.count * MemoryLayout<Int16>.size)
        fileHandle.write(data)
        bytesWritten += UInt32(data.count)
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

            let headerData = createWAVHeader(dataSize: bytesWritten)
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

extension Data {
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

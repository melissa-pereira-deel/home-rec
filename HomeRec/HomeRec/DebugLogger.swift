//
//  DebugLogger.swift
//  HomeRec
//
//  Debug logging to file for troubleshooting
//

import Foundation

/// Simple file-based logger for debugging
class DebugLogger {
    private static let logURL: URL = {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        return desktop.appendingPathComponent("AudioRecorderDebug.log")
    }()

    private static let queue = DispatchQueue(label: "com.debuglogger", qos: .utility)

    /// Log a message to the debug file
    static func log(_ message: String, file: String = #file, line: Int = #line) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let filename = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [\(filename):\(line)] \(message)\n"

        queue.async {
            // Create file if it doesn't exist
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil, attributes: nil)
            }

            // Append to file
            if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                fileHandle.seekToEndOfFile()
                if let data = logMessage.data(using: .utf8) {
                    fileHandle.write(data)
                }
                try? fileHandle.close()
            }
        }

        // Also print to console
        print(logMessage, terminator: "")
    }

    /// Clear the log file
    static func clearLog() {
        queue.async {
            try? "".write(to: logURL, atomically: true, encoding: .utf8)
        }
    }
}

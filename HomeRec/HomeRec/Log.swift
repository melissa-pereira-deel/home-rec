//
//  Log.swift
//  HomeRec
//
//  Unified logging via os.Logger. Routes to the system log, retrievable
//  with Console.app or OSLogStore — never a file on the user's Desktop.
//

import os

/// App-wide loggers, grouped by subsystem area.
///
/// Use `.debug`/`.info` for development tracing (not persisted in Release)
/// and `.error` for failures worth diagnosing from a shipped build.
/// Never log on the audio hot path (per-buffer processing).
nonisolated enum Log {
    private static let subsystem = "com.mdebritto.homerec"

    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let recorder = Logger(subsystem: subsystem, category: "recorder")
    static let file = Logger(subsystem: subsystem, category: "file")
    static let permission = Logger(subsystem: subsystem, category: "permission")
}

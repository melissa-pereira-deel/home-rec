import Foundation

/// Owns the output file from before the encoder opens it until teardown finishes.
struct RecordingSession: Sendable {
    /// The file reserved for this take, including while capture starts or stops.
    let fileURL: URL
}

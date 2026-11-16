import Foundation

/// Owns the output file from before the encoder opens it until teardown finishes.
struct RecordingSession: Sendable {
    /// Tells this take's reports apart from an earlier take's. The layers below
    /// are shared across takes and deliver asynchronously, so a report can
    /// arrive after its take has been released and another has begun.
    let id = UUID()
    /// The file reserved for this take, including while capture starts or stops.
    let fileURL: URL
}

//
//  AudioFileWriting.swift
//  HomeRec
//
//  Abstraction over the object that turns captured buffers into an audio
//  file on disk, so the workflow can be tested without real capture.
//

import Foundation
import AVFoundation

/// Writes captured audio buffers to a file. Implemented by `AudioRecorder`.
///
/// `nonisolated`, and that is the whole of TD-009 on this seam. Every buffer
/// this protocol receives arrives on a capture queue and is written on
/// `AudioRecorder.processingQueue`; none of it belongs on the main actor.
/// Declaring it `@MainActor` — which an unannotated declaration in this target
/// infers, see the `Data` extension at the foot of `WAVWriter.swift` — did not
/// move the work there. It only stated something untrue, and the compiler then
/// had to be told at each call site that a buffer crossing into the recorder
/// was safe after all. The encoders one level down (`AudioFileEncoder`) were
/// always declared this way; this seam above them was simply missed.
///
/// Not `Sendable`, for `AudioFileEncoder`'s reason: the owner guarantees
/// serial access through a single queue, and a `Sendable` conformance here
/// could only be `@unchecked` — a claim with no checking behind it.
nonisolated protocol AudioFileWriting: AnyObject {
    /// `@MainActor`, like the two sinks below it. This one was the odd one out:
    /// an unannotated closure read on the processing queue and invoked on the
    /// main queue, which made every delivery a value sent across a boundary the
    /// compiler could not check.
    var onWaveformData: (@MainActor ([Float]) -> Void)? { get set }
    /// Called once when a buffer cannot be written, so a take whose file has
    /// stopped growing cannot keep looking healthy (BL-173).
    var onWriteError: (@MainActor (WriteFailure) -> Void)? { get set }
    var recording: Bool { get }
    /// Begin writing to `fileURL`, encoding in `format` (BL-015). The format is
    /// fixed for the lifetime of this recording.
    func startRecording(to fileURL: URL, format: AudioFormat) throws
    func processAudioSample(_ pcmBuffer: AVAudioPCMBuffer)
    func stopRecording() throws
}

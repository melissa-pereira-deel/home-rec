import SwiftUI

/// One store, four skins. Every concept reads this instance, so switching
/// concepts mid-recording keeps the timer and levels flowing — the point of
/// comparison. Data tier ticks at 30 Hz; continuous motion (reels, needles,
/// blinks) belongs in views via `TimelineView(.animation)`.
@MainActor
final class PrototypeStateStore: ObservableObject {
    /// Single instance shared by the stage and the snapshot driver.
    static let shared = PrototypeStateStore()

    // Stage chrome
    @Published var concept: ConceptID = .pocketOperator
    @Published var screen: ScreenID = .recorder {
        // Leaving a screen never leaves a phantom playhead running behind it.
        didSet { if oldValue != screen { pausePlayback() } }
    }

    // Transport
    @Published private(set) var transport: TransportState = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    /// Same contract as the real app's `waveformSamples`: fixed-length ring,
    /// zero-filled at rest, newest sample last.
    @Published private(set) var liveSamples: [Float]
    @Published private(set) var currentLevel: Float = 0
    /// Fader/dial position. Purely visual — scales the synth output.
    @Published var gain: Double = 0.7
    /// Mirrors the shipping app's format picker; visual only.
    @Published var selectedFormat: FakeFormat = .wav
    /// Dictaphone reels: accumulated rotation (degrees) banked across takes,
    /// so the reels hold their position when the machine stops — a tell that
    /// this is a machine, not a GIF. Live rotation adds on top while recording.
    @Published var reelBankedRotation: Double = 0

    /// Supply-reel angular velocity while recording (deg/s). Take-up runs 1.15×.
    static let reelSpeed: Double = 72

    // Library
    @Published var library: [FakeRecording]
    @Published var selectedRecordingID: UUID?
    @Published var playbackProgress: Double = 0
    @Published var isPlaying = false

    static let liveSampleCount = 200

    private var recordTask: Task<Void, Never>?
    private var transitionTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    /// Full capture history for the current take — downsampled into the saved
    /// recording's identity waveform.
    private var captureHistory: [Float] = []

    init() {
        liveSamples = Array(repeating: 0, count: Self.liveSampleCount)
        library = FakeLibrary.canned()
    }

    var selectedRecording: FakeRecording? {
        guard let id = selectedRecordingID else { return nil }
        return library.first { $0.id == id }
    }

    // MARK: - Transport intents

    func toggleRecording() {
        switch transport {
        case .idle, .saved: record()
        case .recording: stop()
        default: break
        }
    }

    func record() {
        // `.saved` is immediately re-armable — a recorder must never present a
        // dead record control while the previous take's beat plays out.
        guard transport == .idle || transport.isSaved else { return }
        cancelTransitions()
        transition(to: .starting)
        transitionTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }
            self.beginRecording()
        }
    }

    func stop() {
        guard transport.isRecording else { return }
        cancelTransitions()
        recordTask?.cancel()
        transition(to: .stopping)
        transitionTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let self else { return }
            let recording = self.finishTake()
            self.library.insert(recording, at: 0)
            self.transition(to: .saved(recording))
            try? await Task.sleep(for: .milliseconds(1400))
            guard !Task.isCancelled else { return }
            self.transition(to: .idle)
        }
    }

    /// Stage-scrubber override: jump straight to a state, cleaning up timers.
    func forceState(_ state: TransportState) {
        cancelTransitions()
        recordTask?.cancel()
        pausePlayback()
        if transport.isRecording {
            bankReels()
        }
        switch state {
        case .recording(let startedAt):
            // Honor the payload: "recording that started 20 minutes ago" is a
            // real state the scrubber must be able to reach.
            beginRecording(startedAt: startedAt)
        case .saved:
            // Replay the saved beat with the most recent library entry.
            resetLiveData()
            if let latest = library.first {
                transition(to: .saved(latest))
                transitionTask = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(1400))
                    guard !Task.isCancelled else { return }
                    self?.transition(to: .idle)
                }
            } else {
                transition(to: .idle)
            }
        default:
            resetLiveData()
            transition(to: state)
        }
    }

    func cycleFormat() {
        let all = FakeFormat.allCases
        guard let index = all.firstIndex(of: selectedFormat) else { return }
        selectedFormat = all[(index + 1) % all.count]
    }

    /// Ordinal shortcut (PO number keys): jump to the library with take N open.
    func openLibrary(at index: Int) {
        screen = .library
        guard index < library.count else { return }
        select(library[index])
    }

    // MARK: - Playback sim

    func togglePlayback(for recording: FakeRecording) {
        if selectedRecordingID != recording.id {
            select(recording)
        }
        isPlaying ? pausePlayback() : startPlayback(duration: recording.duration)
    }

    func select(_ recording: FakeRecording) {
        pausePlayback()
        selectedRecordingID = recording.id
        playbackProgress = 0
    }

    func deselect() {
        pausePlayback()
        selectedRecordingID = nil
        playbackProgress = 0
    }

    func scrub(to progress: Double) {
        playbackProgress = min(1, max(0, progress))
    }

    // MARK: - Scrub suspend/resume (drag must not fight the playback task)

    private var wasPlayingBeforeScrub = false

    func beginScrub() {
        wasPlayingBeforeScrub = isPlaying
        pausePlayback()
    }

    func endScrub() {
        defer { wasPlayingBeforeScrub = false }
        guard wasPlayingBeforeScrub, playbackProgress < 1,
              let recording = selectedRecording else { return }
        startPlayback(duration: recording.duration)
    }

    private func startPlayback(duration: TimeInterval) {
        isPlaying = true
        playbackTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                guard let self, self.isPlaying else { return }
                // Fake playhead: real durations, min 4s sweep so shorts feel alive.
                let sweep = max(4, duration)
                self.playbackProgress += 0.033 / sweep
                if self.playbackProgress >= 1 {
                    self.playbackProgress = 1
                    self.pausePlayback()
                    return
                }
            }
        }
    }

    func pausePlayback() {
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
    }

    // MARK: - Recording engine

    private func beginRecording(startedAt: Date = .now) {
        resetLiveData()
        transition(to: .recording(startedAt: startedAt))
        // Seed elapsed immediately so a forced "35 minutes in" state renders
        // the right timecode on its first frame, not after the first tick.
        elapsed = max(0, Date.now.timeIntervalSince(startedAt))
        recordTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                guard let self, self.transport.isRecording else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        // Wall-clock derived, matching the shipping app (`clock.now - startTime`).
        // Accumulating the nominal tick interval drifts: Task.sleep guarantees a
        // minimum, so +=0.033 undercounts real time by minutes on long takes.
        guard case .recording(let startedAt) = transport else { return }
        elapsed = Date.now.timeIntervalSince(startedAt)
        let level = LevelSynth.level(at: elapsed) * Float(0.35 + 0.65 * gain)
        currentLevel = level
        captureHistory.append(level)
        liveSamples.removeFirst()
        liveSamples.append(level)
    }

    private func bankReels() {
        reelBankedRotation += elapsed * Self.reelSpeed
    }

    private func finishTake() -> FakeRecording {
        let duration = elapsed
        bankReels()
        // The rewind clunk: reels snap a few degrees backward as the
        // mechanism disengages. Views animate this with a loose spring.
        reelBankedRotation -= 8
        let samples = WaveformFactory.downsample(captureHistory)
        let megabytes = duration * 0.1875 // 48kHz 16-bit stereo ≈ 11.25MB/min
        let recording = FakeRecording(
            id: UUID(),
            name: Formatters.recordingName(),
            date: .now,
            duration: duration,
            format: selectedFormat,
            sampleRate: "48kHz",
            bitDepth: selectedFormat == .flac ? "24-bit" : "16-bit",
            fileSize: megabytes < 1
                ? String(format: "%.0fKB", megabytes * 1024)
                : String(format: "%.1fMB", megabytes),
            samples: samples,
            versionCount: 1
        )
        resetLiveData()
        return recording
    }

    private func resetLiveData() {
        elapsed = 0
        currentLevel = 0
        captureHistory = []
        liveSamples = Array(repeating: 0, count: Self.liveSampleCount)
    }

    private func transition(to state: TransportState) {
        withAnimation(.easeOut(duration: 0.15)) {
            transport = state
        }
    }

    private func cancelTransitions() {
        transitionTask?.cancel()
        transitionTask = nil
    }
}

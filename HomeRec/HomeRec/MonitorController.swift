//
//  MonitorController.swift
//  HomeRec
//
//  Live headphone monitoring of the selected input device (BL-131).
//
//  Fully independent of the recording pipeline: its own `AVAudioEngine`, its own
//  lifecycle, its own failure handling. Monitoring is a convenience; a recording
//  is not. **A monitor failure must never move `RecordingState` to `.error`** —
//  that is the load-bearing invariant of this file, and the one thing here that
//  is unit-testable without hardware.
//
//  ⚠️ Not shipped until the concurrency spike passes. Six of BL-131's nine
//  acceptance criteria need a human with headphones: whether an SCK `.microphone`
//  capture and an `AVAudioEngine` reading the *same* device glitch against each
//  other, and the clap-test latency measurement. What is settled statically is
//  that nothing *forbids* it — measured `kAudioDevicePropertyHogMode == -1` (free)
//  on both devices, so neither client takes exclusive access. The spike is about
//  quality, not feasibility.
//

import AVFoundation
import CoreAudio

/// When live monitoring should be running.
///
/// One three-valued setting, not two booleans. The spec described two toggles —
/// "Monitor Input" and "Monitor While Recording" — which produce four states for
/// three meanings: with the first ON, the second changes nothing, so that
/// combination is indistinguishable from the first alone. A UI with an
/// unreachable state generates support questions.
enum MonitoringMode: String, Codable, Sendable, CaseIterable {
    case off
    case whileRecording
    case always

    var displayName: String {
        switch self {
        case .off:            return "Off"
        case .whileRecording: return "While Recording"
        case .always:         return "Always"
        }
    }
}

/// Why monitoring stopped or failed to start. Never fatal to a recording.
enum MonitorError: Error, LocalizedError, Equatable {
    case engineUnavailable(String)
    case deviceUnavailable

    var errorDescription: String? {
        switch self {
        case .engineUnavailable:
            return "Home Rec couldn't start monitoring."
        case .deviceUnavailable:
            return "The input device for monitoring isn't available."
        }
    }

    var recoverySuggestion: String? {
        "Your recording is unaffected. Check the device, then turn monitoring on again."
    }
}

@MainActor
protocol MonitorControlling: AnyObject {
    var mode: MonitoringMode { get }
    func setMode(_ mode: MonitoringMode)
    /// Whether the monitor graph is running right now.
    var isMonitoring: Bool { get }
    /// React to a recording starting or stopping. Drives `.whileRecording`.
    func recordingStateChanged(isRecording: Bool)
    /// Called when monitoring fails. Deliberately a *warning* channel, separate
    /// from anything that can reach `RecordingState`.
    var onWarning: (@MainActor (MonitorError) -> Void)? { get set }
}

@MainActor
final class MonitorController: MonitorControlling {

    private let defaults: UserDefaults
    private let key = "monitoringMode"
    private var engine: AVAudioEngine?
    private var isRecordingNow = false

    var onWarning: (@MainActor (MonitorError) -> Void)?

    /// Resolves the device UID to monitor. Injected so the mode/lifecycle logic
    /// is testable without touching audio hardware.
    private let currentDeviceUID: @MainActor () -> String?

    private(set) var mode: MonitoringMode {
        didSet { defaults.set(mode.rawValue, forKey: key) }
    }

    init(
        defaults: UserDefaults = .standard,
        currentDeviceUID: @escaping @MainActor () -> String? = { nil }
    ) {
        self.defaults = defaults
        self.currentDeviceUID = currentDeviceUID
        // Defaults to off: monitoring through built-in speakers feeds back, and
        // silently starting an engine that lights the mic indicator would be a
        // poor first impression for an app positioned on permission honesty.
        let raw = defaults.string(forKey: key) ?? MonitoringMode.off.rawValue
        self.mode = MonitoringMode(rawValue: raw) ?? .off
    }

    var isMonitoring: Bool { engine?.isRunning ?? false }

    func setMode(_ mode: MonitoringMode) {
        self.mode = mode
        reconcile()
    }

    func recordingStateChanged(isRecording: Bool) {
        isRecordingNow = isRecording
        reconcile()
    }

    /// Whether the graph should be running, given mode and recording state.
    ///
    /// Pure and `static` so the state machine can be asserted directly, with no
    /// engine, no device and no audio session.
    static func shouldRun(mode: MonitoringMode, isRecording: Bool) -> Bool {
        switch mode {
        case .off:            return false
        case .always:         return true
        case .whileRecording: return isRecording
        }
    }

    private func reconcile() {
        let wanted = Self.shouldRun(mode: mode, isRecording: isRecordingNow)
        if wanted {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard engine == nil else { return }
        guard let deviceUID = currentDeviceUID() else {
            // Not fatal, and not silent either: the user asked for monitoring
            // and should learn it isn't happening.
            onWarning?(.deviceUnavailable)
            return
        }

        let engine = AVAudioEngine()
        do {
            try Self.selectInputDevice(uid: deviceUID, on: engine)
            // Straight pass-through: input → mixer → output. No effects; gain and
            // EQ are explicitly out of scope.
            let input = engine.inputNode
            engine.connect(input, to: engine.mainMixerNode, format: input.outputFormat(forBus: 0))
            try engine.start()
            self.engine = engine
        } catch {
            // ⚠️ Warning only. This must not reach `RecordingState`: a monitor
            // that cannot start is an inconvenience, and turning it into a
            // recording error would abort a take for a headphone problem.
            onWarning?(.engineUnavailable(error.localizedDescription))
            self.engine = nil
        }
    }

    private func stop() {
        guard let engine else { return }
        engine.stop()
        // Released rather than kept paused: once an engine has had its input
        // enabled, macOS keeps the orange microphone indicator lit for as long
        // as it is running. Apple's own guidance for apps that switch between
        // output-only and input-output is to use separate engine instances.
        self.engine = nil
    }

    /// Point `engine`'s input at a specific device.
    ///
    /// 🔴 `AVAudioEngine` exposes **no** API for this — `inputNode` is bound to
    /// the system default. BL-131 requirement 1 ("route the selected input
    /// device") reads as though it were free; without this, monitoring silently
    /// listens to the wrong microphone whenever the user's pick is not the
    /// system default, which is the common case for anyone with an interface.
    private static func selectInputDevice(uid: String, on engine: AVAudioEngine) throws {
        guard let deviceID = audioDeviceID(forUID: uid) else {
            throw MonitorError.deviceUnavailable
        }
        var id = deviceID
        let status = AudioUnitSetProperty(
            engine.inputNode.audioUnit!,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw MonitorError.engineUnavailable("AudioUnitSetProperty failed: \(status)")
        }
    }

    /// Core Audio's device ID for an `AVCaptureDevice.uniqueID`.
    ///
    /// The two identifier spaces coincide: `kAudioDevicePropertyDeviceUID`
    /// returns the same strings `AVCaptureDevice.uniqueID` does, which is what
    /// lets one UID serve both ScreenCaptureKit and this lookup.
    private static func audioDeviceID(forUID uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
        ) == noErr else { return nil }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices
        ) == noErr else { return nil }

        for device in devices {
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            // `Unmanaged`, not a bare `CFString`: taking a raw pointer to a
            // variable holding an object reference is not a valid way to receive
            // one, and Core Audio hands back a +1 reference here.
            var deviceUID: Unmanaged<CFString>?
            var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(
                device, &uidAddress, 0, nil, &uidSize, &deviceUID
            ) == noErr, let cfUID = deviceUID?.takeRetainedValue() else { continue }
            if (cfUID as String) == uid { return device }
        }
        return nil
    }
}

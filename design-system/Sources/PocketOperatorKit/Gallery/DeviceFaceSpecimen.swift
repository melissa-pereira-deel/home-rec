import SwiftUI

/// A complete device built only from the kit — the worked example.
///
/// Deliberately not an audio recorder. It is a step sequencer, so the language
/// has to carry a product it was not designed around: pattern banks instead of
/// takes, tempo instead of timecode, step latching instead of a single armed
/// key. Everything here is stock; nothing reaches past the public API.
@available(macOS 15, *)
public struct DeviceFaceSpecimen: View {
    @State private var phase: TransportPhase = .idle
    @State private var steps: Set<Int> = [0, 3, 6, 8, 11, 14]
    @State private var gain = 0.7
    @State private var tempo = 128
    @State private var isDisplayInverted = false
    @State private var commitCount = 0
    @State private var patternIndex = 2

    private let startedAt = Date()

    public init() {}

    public var body: some View {
        DeviceFace(
            brand: "POCKET OPERATOR KIT",
            model: "PK-01",
            subtitle: "SIXTEEN STEP SEQUENCER"
        ) {
            VStack(spacing: 14) {
                display
                HStack(alignment: .top, spacing: 14) {
                    stepBed
                    controlColumn
                }
                transportRow
            }
        } footer: {
            SpecGrid([
                SpecCell(label: "MODE", value: "SEQ", accessibilityLabel: "Mode"),
                SpecCell(label: "BPM", value: "\(tempo)", accessibilityLabel: "Tempo"),
                SpecCell(label: "STEP", value: "16", accessibilityLabel: "Step count"),
                SpecCell(
                    label: "ON",
                    value: String(format: "%02d", steps.count),
                    accessibilityLabel: "Active steps"
                ),
                SpecCell(label: "BANK", value: "A\(patternIndex)", accessibilityLabel: "Bank"),
            ])
        }
        .frame(width: 500)
        .poCommitFlash(on: commitCount, isInverted: $isDisplayInverted)
    }

    private var display: some View {
        LCDPanel(isInverted: isDisplayInverted, accessibilityLabel: "Sequencer display") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    SegmentLCD(
                        "\(tempo).0",
                        size: 30,
                        capacity: 6,
                        alignment: .trailing,
                        accessibilityLabel: "Tempo",
                        accessibilityValue: "\(tempo) beats per minute"
                    )
                    Spacer()
                    SegmentLCD(
                        signal.word,
                        size: 16,
                        accessibilityLabel: "Transport",
                        accessibilityValue: signal.spoken
                    )
                    .poBlink(isActive: phase == .recording || phase == .arming)
                }
                HStack(spacing: 12) {
                    LCDLevelBar(level: currentLevel, peak: min(1, currentLevel + 0.12))
                    SegmentLCD(
                        "PATTERN A\(patternIndex)",
                        face: .dotMatrix,
                        size: 11,
                        accessibilityLabel: "Pattern",
                        accessibilityValue: "A\(patternIndex)"
                    )
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var stepBed: some View {
        KeyGrid(
            (0..<16).map { index in
                KeyGridItem(
                    id: "step-\(index)",
                    legend: String(format: "%02d", index + 1),
                    accessibilityLabel: "Step \(index + 1)",
                    accessibilityHint: steps.contains(index) ? "Active" : "Inactive",
                    isOn: steps.contains(index),
                    action: { toggle(step: index) }
                )
            },
            columns: 4,
            keySize: .custom(CGSize(width: 58, height: 34)),
            caption: "STEPS",
            accessibilityLabel: "Step keys"
        )
    }

    private var controlColumn: some View {
        VStack(spacing: 14) {
            VUMeter(
                level: { currentLevel },
                legend: "OUT",
                accessibilityLabel: "Output level"
            )
            .frame(width: 118, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .poBezel(corner: 3)

            HStack(alignment: .top, spacing: 14) {
                LabelledControl("GAIN", accessibilityLabel: "Output gain") {
                    Fader(
                        value: $gain,
                        length: 96,
                        label: "",
                        accessibilityValue: { "\(Int(($0 * 100).rounded())) percent" }
                    )
                }
                VStack(spacing: 10) {
                    HardwareKey(
                        "BANK",
                        size: .compact,
                        accessibilityLabel: "Next bank",
                        action: nextBank
                    )
                    HardwareKey(
                        "TAP",
                        size: .compact,
                        accessibilityLabel: "Tap tempo",
                        action: tapTempo
                    )
                    HardwareKey(
                        "CLR",
                        variant: .dark,
                        size: .compact,
                        accessibilityLabel: "Clear pattern",
                        action: clear
                    )
                }
            }
        }
    }

    private var transportRow: some View {
        HStack {
            TransportKeys(
                phase: phase,
                keySize: .compact,
                onRecord: { commit(.recording) },
                onStop: { commit(.idle) },
                onPlay: { commit(phase == .playing ? .paused : .playing) }
            )
            Spacer()
            LampAnnunciator(
                "SYNC",
                mode: phase.isRunning ? .on : .off,
                role: .armed,
                accessibilityLabel: "External sync"
            )
        }
    }

    private var signal: POStateSignal {
        POStateSignal.standard(for: phase)
    }

    /// Meter feed. Silent when stopped, because a device with a moving needle
    /// and a stopped transport is lying about what it is doing.
    private var currentLevel: Double {
        guard phase.isRunning else { return 0 }
        return POSampleData.level(at: Date.now.timeIntervalSince(startedAt))
    }

    private func toggle(step: Int) {
        if steps.contains(step) { steps.remove(step) } else { steps.insert(step) }
    }

    private func commit(_ next: TransportPhase) {
        phase = next
        commitCount += 1
    }

    private func nextBank() {
        patternIndex = patternIndex % 8 + 1
        commitCount += 1
    }

    private func tapTempo() {
        tempo = tempo >= 180 ? 60 : tempo + 4
    }

    private func clear() {
        steps.removeAll()
        commitCount += 1
    }
}

@available(macOS 15, *)
#Preview("Device face — standard") {
    DeviceFaceSpecimen()
        .padding(30)
        .background(Color.black)
}

@available(macOS 15, *)
#Preview("Device face — amber re-skin") {
    DeviceFaceSpecimen()
        .pocketOperatorTheme(.amberService)
        .padding(30)
        .background(Color.black)
}

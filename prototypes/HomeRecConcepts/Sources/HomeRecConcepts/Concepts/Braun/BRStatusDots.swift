import SwiftUI

/// Two small lamps with engraved labels. The active dot simply *is on* —
/// no pulsing. On save, the green dot double-blinks its acknowledgement.
struct BRStatusDots: View {
    @EnvironmentObject private var store: PrototypeStateStore

    @State private var greenBlinkOn = true

    var body: some View {
        HStack(spacing: 22) {
            dot(
                color: BRTheme.recordRed,
                on: store.transport.isRecording,
                label: "record"
            )
            dot(
                color: BRTheme.readyGreen,
                on: readyOn,
                label: "ready"
            )
        }
        .task(id: store.transport) { await runSavedBlink() }
    }

    private var readyOn: Bool {
        switch store.transport {
        case .idle: true
        case .saved: greenBlinkOn
        default: false
        }
    }

    private func dot(color: Color, on: Bool, label: String) -> some View {
        VStack(spacing: 6) {
            Circle()
                // Off is paint, not a dead lamp: flat at quarter strength.
                .fill(on ? color : color.opacity(0.25))
                .frame(width: 8, height: 8)
                .shadow(color: on ? color.opacity(0.4) : .clear, radius: 6)
            BRTheme.engraved(label, size: 8)
        }
    }

    private func runSavedBlink() async {
        guard case .saved = store.transport else {
            greenBlinkOn = true
            return
        }
        for _ in 0..<2 {
            greenBlinkOn = true
            try? await Task.sleep(for: .milliseconds(150))
            greenBlinkOn = false
            try? await Task.sleep(for: .milliseconds(150))
        }
        greenBlinkOn = true
    }
}

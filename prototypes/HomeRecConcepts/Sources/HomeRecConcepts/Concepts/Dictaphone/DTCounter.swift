import SwiftUI

/// Amber tape counter in a recessed window. Runs while recording; freezes and
/// blinks twice on save — the mechanism acknowledging the take.
struct DTCounter: View {
    @EnvironmentObject private var store: PrototypeStateStore

    @State private var savedBlinkVisible = true

    var body: some View {
        counterWindow
            .task(id: store.transport) { await runSavedBlink() }
    }

    private var counterWindow: some View {
        Group {
            switch store.transport {
            case .saved(let recording):
                SegmentLCD(
                    text: Formatters.timecode(recording.duration, tenths: recording.duration < 60),
                    color: DTTheme.amber, size: 22, ghostOpacity: 0.09
                )
                .opacity(savedBlinkVisible ? 1 : 0.12)
            case .recording, .stopping:
                SegmentLCD(
                    text: Formatters.timecode(store.elapsed, tenths: store.elapsed < 3600),
                    color: DTTheme.amber, size: 22, ghostOpacity: 0.09
                )
            default:
                SegmentLCD(
                    text: "0:00.0",
                    color: DTTheme.amber, size: 22, ghostOpacity: 0.09
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DTTheme.counterBed)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            // Recessed bezel: dark top lip, light bottom lip.
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    LinearGradient(
                        colors: [.black.opacity(0.8), .white.opacity(0.12)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        )
    }

    /// Two hard blinks, then hold — the counter acknowledging the save.
    private func runSavedBlink() async {
        guard case .saved = store.transport else {
            savedBlinkVisible = true
            return
        }
        for _ in 0..<2 {
            savedBlinkVisible = false
            try? await Task.sleep(for: .milliseconds(140))
            savedBlinkVisible = true
            try? await Task.sleep(for: .milliseconds(140))
        }
    }
}

import SwiftUI

/// The design stage: a neutral dark canvas that presents each concept's panel
/// at real size, with chrome for switching concepts, screens, and states.
/// Chrome stays deliberately quiet (SF Mono, dark grey) so it never competes
/// with the concepts under review.
struct StageView: View {
    @ObservedObject private var store = PrototypeStateStore.shared
    @FocusState private var stageFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            stageChrome
            Spacer(minLength: 0)
            conceptPanel
            Spacer(minLength: 0)
            stateScrubber
        }
        .frame(width: 620, height: 780)
        .background(Color(red: 0.02, green: 0.02, blue: 0.02))
        .environmentObject(store)
        .focusable()
        .focused($stageFocused)
        .focusEffectDisabled()
        .onAppear { stageFocused = true }
        .onKeyPress { press in handleKey(press) }
    }

    // MARK: - Panel host

    @ViewBuilder
    private var conceptPanel: some View {
        // Placeholder host — concept faces land here (task #4).
        VStack(spacing: 14) {
            Text("Home Rec")
                .font(.custom("Archivo", size: 34, relativeTo: .largeTitle))
                .foregroundStyle(.white)
            debugReadout
        }
    }

    /// Temporary gate for the shared core: proves the timer runs and levels
    /// jitter before any concept face exists. Removed once faces land.
    private var debugReadout: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("state    \(String(describing: store.transport).prefix(28))")
            Text("elapsed  \(Formatters.timecode(store.elapsed, tenths: true))")
            Text("level    \(String(format: "%.2f", store.currentLevel))  " + bar(store.currentLevel))
            Text("gain     \(String(format: "%.2f", store.gain))")
            Text("library  \(store.library.count) recordings")
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Color(red: 0.61, green: 0.91, blue: 0.44))
        .padding(20)
        .frame(width: 450, alignment: .leading)
        .background(Color(white: 0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private func bar(_ level: Float) -> String {
        let filled = Int(level * 20)
        return String(repeating: "▮", count: filled)
            + String(repeating: "▯", count: max(0, 20 - filled))
    }

    // MARK: - Chrome

    private var stageChrome: some View {
        HStack(spacing: 14) {
            ForEach(ConceptID.allCases) { concept in
                Button {
                    store.concept = concept
                } label: {
                    Text(concept.label)
                        .font(.system(size: 10, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(store.concept == concept ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button {
                store.screen = store.screen == .recorder ? .library : .recorder
            } label: {
                Text(store.screen == .recorder ? "⇥ LIBRARY" : "⇥ RECORDER")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(white: 0.08))
    }

    private var stateScrubber: some View {
        HStack(spacing: 10) {
            scrubButton("DISARM") { store.forceState(.disarmed) }
            scrubButton("IDLE") { store.forceState(.idle) }
            scrubButton("REC") { store.forceState(.recording(startedAt: .now)) }
            scrubButton("SAVE") { store.forceState(.saved(store.library[0])) }
            Spacer()
            Text("1–4 concept · tab screen · space rec/stop")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(white: 0.08))
    }

    private func scrubButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case "1", "2", "3", "4":
            if let n = Int(press.key.character.description),
               let concept = ConceptID(rawValue: n) {
                store.concept = concept
                return .handled
            }
            return .ignored
        case .tab:
            store.screen = store.screen == .recorder ? .library : .recorder
            return .handled
        case .space:
            store.toggleRecording()
            return .handled
        case "s":
            store.forceState(.saved(store.library[0]))
            return .handled
        default:
            return .ignored
        }
    }
}

#Preview {
    StageView()
}

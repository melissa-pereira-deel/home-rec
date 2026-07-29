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
        switch (store.concept, store.screen) {
        case (.pocketOperator, .recorder):
            POFace()
        case (.dictaphone, .recorder):
            DTFace()
        case (.braun, .recorder):
            BRFace()
        case (.glassShelf, .recorder):
            // V2: flat record pill. Original GSFace preserved — swap back here.
            GSFaceV2()
        case (.pocketOperator, .library):
            POLibrary()
        case (.dictaphone, .library):
            DTLibrary()
        case (.braun, .library):
            BRLibrary()
        case (.glassShelf, .library):
            GSLibrary()
        }
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

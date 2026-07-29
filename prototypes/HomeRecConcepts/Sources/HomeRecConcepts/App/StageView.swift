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
        VStack(spacing: 6) {
            // Row 1: transport + permission/translocation entry points.
            HStack(spacing: 8) {
                scrubButton("ND") { scrubDisarmed(.notDetermined) }
                scrubButton("DENIED") { scrubDisarmed(.denied) }
                scrubButton("TRANSLOC", active: store.translocationBlocked) {
                    clearAxes()
                    store.permissionStatus = .granted
                    store.translocationBlocked = true
                    store.forceState(.idle)
                }
                scrubButton("IDLE") { scrubTransport(.idle) }
                scrubButton("REC") { scrubTransport(.recording(startedAt: .now)) }
                scrubButton("REC 1:12") {
                    // Wall-clock payload honored: instantly a 1:12:03 take,
                    // which also trips the long-recording warning latch.
                    scrubTransport(.recording(startedAt: .now.addingTimeInterval(-4323)))
                }
                scrubButton("SAVE") {
                    guard let latest = store.library.first else { return }
                    scrubTransport(.saved(latest))
                }
                Spacer()
            }
            // Row 2: error/guardrail/surface/data axes.
            HStack(spacing: 8) {
                scrubButton(errorCycleLabel, active: store.activeError != nil) {
                    cycleError()
                }
                scrubButton("DISKFULL", active: store.simulateDiskFullOnRecord) {
                    store.simulateDiskFullOnRecord.toggle()
                }
                scrubButton("ONBOARD", active: store.showOnboarding) {
                    store.showOnboarding.toggle()
                }
                scrubButton("SEED \(store.library.count)") { cycleSeed() }
                scrubButton("NAMES", active: store.useRealisticNames) {
                    store.useRealisticNames.toggle()
                }
                Spacer()
                Text("1–4 · tab · space · ⌘r")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(white: 0.08))
    }

    private func scrubButton(
        _ label: String, active: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(active ? Color.black : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    active ? Color(white: 0.75) : Color(white: 0.14),
                    in: RoundedRectangle(cornerRadius: 4)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scrub actions

    /// Transport scrubs reset conflicting axes so states compose predictably.
    private func clearAxes() {
        store.dismissError()
        store.translocationBlocked = false
        store.showOnboarding = false
    }

    private func scrubTransport(_ state: TransportState) {
        clearAxes()
        store.permissionStatus = .granted
        store.forceState(state)
    }

    private func scrubDisarmed(_ status: FakePermissionStatus) {
        clearAxes()
        store.permissionStatus = status
        store.forceState(.disarmed)
    }

    private var errorCycleLabel: String {
        switch store.activeError {
        case nil: "ERR ▸"
        case .startFailed: "ERR START"
        case .stopFailed: "ERR STOP"
        case .streamFailed: "ERR STREAM"
        case .diskFull: "ERR DISK"
        case .saveLocationUnavailable: "ERR FOLDER"
        }
    }

    private func cycleError() {
        let cycle: [FakeRecorderError?] = [nil] + FakeRecorderError.allCases
        let index = cycle.firstIndex(of: store.activeError) ?? 0
        store.activeError = cycle[(index + 1) % cycle.count]
    }

    private func cycleSeed() {
        let seeds = LibrarySeed.allCases
        let current = seeds.firstIndex { $0.rawValue == store.library.count }
        let next = seeds[((current ?? 1) + 1) % seeds.count]
        store.applySeed(next)
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
        case "r" where press.modifiers.contains(.command):
            // ⌘R mirrors the shipping shortcut — record/stop from any screen.
            store.toggleRecording()
            return .handled
        case "s":
            guard let latest = store.library.first else { return .ignored }
            store.forceState(.saved(latest))
            return .handled
        default:
            return .ignored
        }
    }
}

#Preview {
    StageView()
}

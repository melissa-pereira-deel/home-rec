import AppKit
import SwiftUI

/// Headless-ish visual verification: launch with `HRC_SNAPSHOT=<dir>` and the
/// app drives the shared store through every concept × screen × state, writes
/// a PNG per scenario via AppKit's own rendering, then quits. Doubles as a
/// design-review artifact generator (no Screen Recording permission needed).
@MainActor
enum SnapshotDriver {
    static func runIfRequested() {
        guard let dir = ProcessInfo.processInfo.environment["HRC_SNAPSHOT"] else { return }
        Task { await run(outputDir: dir) }
    }

    private struct Scenario {
        let name: String
        let settleMilliseconds: Int
        let apply: @MainActor (PrototypeStateStore) -> Void
    }

    private static func run(outputDir: String) async {
        try? FileManager.default.createDirectory(
            atPath: outputDir, withIntermediateDirectories: true
        )
        let store = PrototypeStateStore.shared
        // Let the window settle before the first capture.
        try? await Task.sleep(for: .milliseconds(700))

        for scenario in scenarios() {
            scenario.apply(store)
            try? await Task.sleep(for: .milliseconds(scenario.settleMilliseconds))
            capture(to: "\(outputDir)/\(scenario.name).png")
        }
        NSApp.terminate(nil)
    }

    private static func scenarios() -> [Scenario] {
        var all: [Scenario] = []
        for concept in ConceptID.allCases {
            let slug = slug(for: concept)
            func set(_ screen: ScreenID, _ state: TransportState) -> @MainActor (PrototypeStateStore) -> Void {
                { store in
                    store.concept = concept
                    store.screen = screen
                    store.forceState(state)
                }
            }
            all.append(Scenario(name: "\(slug)-rec-idle", settleMilliseconds: 400,
                                apply: set(.recorder, .idle)))
            // Long settle: let the live waveform accumulate history.
            all.append(Scenario(name: "\(slug)-rec-recording", settleMilliseconds: 2600,
                                apply: set(.recorder, .recording(startedAt: .now))))
            // Saved auto-returns to idle after 1.4s; capture mid-beat.
            all.append(Scenario(name: "\(slug)-rec-saved", settleMilliseconds: 600,
                                apply: { store in
                                    store.concept = concept
                                    store.screen = .recorder
                                    store.forceState(.saved(store.library[0]))
                                }))
            all.append(Scenario(name: "\(slug)-rec-disarmed", settleMilliseconds: 400,
                                apply: set(.recorder, .disarmed)))
            all.append(Scenario(name: "\(slug)-library", settleMilliseconds: 400,
                                apply: { store in
                                    store.concept = concept
                                    store.screen = .library
                                    store.forceState(.idle)
                                    store.deselect()
                                }))
            all.append(Scenario(name: "\(slug)-library-open", settleMilliseconds: 500,
                                apply: { store in
                                    store.concept = concept
                                    store.screen = .library
                                    store.forceState(.idle)
                                    store.select(store.library[1])
                                    store.scrub(to: 0.42)
                                }))
        }
        // Policy C / RecordingBar: recording continues into the library, and
        // playback during a capture shows the monitoring guarantee.
        all.append(Scenario(name: "spec-03-recbar-library", settleMilliseconds: 1200,
                            apply: { store in
                                store.concept = .glassShelf
                                store.forceState(.recording(startedAt: .now.addingTimeInterval(-72)))
                                store.screen = .library
                            }))
        all.append(Scenario(name: "spec-04-monitoring", settleMilliseconds: 1200,
                            apply: { store in
                                store.concept = .glassShelf
                                store.forceState(.recording(startedAt: .now.addingTimeInterval(-72)))
                                store.screen = .library
                                if store.library.indices.contains(1) {
                                    store.togglePlayback(for: store.library[1])
                                    store.scrub(to: 0.42)
                                }
                            }))
        // Continuity proof: start one recording, then hop concepts WITHOUT
        // touching transport. Timers in these captures must keep counting.
        all.append(Scenario(name: "continuity-0-start", settleMilliseconds: 1200,
                            apply: { store in
                                store.screen = .recorder
                                store.concept = .pocketOperator
                                store.forceState(.recording(startedAt: .now))
                            }))
        for concept in [ConceptID.dictaphone, .braun, .glassShelf] {
            all.append(Scenario(name: "continuity-\(concept.rawValue)", settleMilliseconds: 900,
                                apply: { store in store.concept = concept }))
        }
        return all
    }

    private static func slug(for concept: ConceptID) -> String {
        switch concept {
        case .pocketOperator: "1-po"
        case .dictaphone: "2-dt"
        case .braun: "3-br"
        case .glassShelf: "4-gs"
        }
    }

    private static func capture(to path: String) {
        guard
            let window = NSApp.windows.first(where: { $0.isVisible }),
            let view = window.contentView,
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else {
            NSLog("SnapshotDriver: no capturable window for \(path)")
            return
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}

import AppKit
import SwiftUI

/// Headless-ish visual verification: launch with `HRC_SNAPSHOT=<dir>` and the
/// app drives the shared store through every concept × screen × state, writes
/// a PNG per scenario via AppKit's own rendering, then quits. Doubles as a
/// design-review artifact generator (no Screen Recording permission needed).
@MainActor
enum SnapshotDriver {
    /// True for the whole capture run. The stage promotes itself with
    /// `NSApp.activate(ignoringOtherApps:)` and its key handler maps digits to
    /// concepts, so a keystroke the user aimed at whatever they were actually
    /// doing lands on the stage and rewrites the state mid-run — silently
    /// producing a screen of the wrong concept. Capture must be deaf.
    private(set) static var isRunning = false

    static func runIfRequested() {
        guard let dir = ProcessInfo.processInfo.environment["HRC_SNAPSHOT"] else { return }
        isRunning = true
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

        // HRC_SNAPSHOT_FILTER=<substring> runs a subset for fast iteration.
        let filter = ProcessInfo.processInfo.environment["HRC_SNAPSHOT_FILTER"]
        for scenario in scenarios() {
            if let filter, !scenario.name.contains(filter) { continue }
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
        // Glass v2 shares Glass's notice slot and onboarding sheet, but its
        // LCD is taller than the waveform card — capture both so the fixed
        // 450pt face is proven not to overflow.
        all.append(Scenario(name: "5-gl-rec-notice", settleMilliseconds: 400,
                            apply: { store in
                                store.concept = .glassLCD
                                store.screen = .recorder
                                store.forceState(.idle)
                                store.activeError = .startFailed
                            }))
        all.append(Scenario(name: "5-gl-rec-onboarding", settleMilliseconds: 500,
                            apply: { store in
                                store.concept = .glassLCD
                                store.screen = .recorder
                                store.dismissError()
                                store.forceState(.idle)
                                store.showOnboarding = true
                            }))
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
        // Spec matrix: permission, errors, guardrails — all on Glass.
        func specReset(_ store: PrototypeStateStore) {
            store.concept = .glassShelf
            store.screen = .recorder
            store.permissionStatus = .granted
            store.translocationBlocked = false
            store.simulateDiskFullOnRecord = false
            store.saveLocation = SaveLocationSim()
            store.dismissError()
            store.showOnboarding = false
            store.useRealisticNames = false
            store.renamingID = nil
            store.pendingDeleteID = nil
            store.scrollTargetID = nil
            store.applySeed(.eight)
            store.forceState(.idle)
        }
        all.append(Scenario(name: "spec-01-idle-honest", settleMilliseconds: 400,
                            apply: { store in
                                specReset(store)
                                store.useRealisticNames = true
                            }))
        all.append(Scenario(name: "spec-02a-starting", settleMilliseconds: 150,
                            apply: { store in
                                specReset(store)
                                store.forceState(.starting)
                            }))
        all.append(Scenario(name: "spec-02b-recording", settleMilliseconds: 800,
                            apply: { store in
                                specReset(store)
                                store.forceState(.recording(startedAt: .now.addingTimeInterval(-8)))
                            }))
        all.append(Scenario(name: "spec-02d-saved", settleMilliseconds: 600,
                            apply: { store in
                                specReset(store)
                                if let latest = store.library.first {
                                    store.forceState(.saved(latest))
                                }
                            }))
        all.append(Scenario(name: "spec-08-library-50-scrolled", settleMilliseconds: 700,
                            apply: { store in
                                specReset(store)
                                store.applySeed(.fifty)
                                store.screen = .library
                                if store.library.indices.contains(24) {
                                    store.scrollTargetID = store.library[24].id
                                }
                            }))
        all.append(Scenario(name: "spec-09a-empty", settleMilliseconds: 400,
                            apply: { store in
                                specReset(store)
                                store.applySeed(.empty)
                                store.screen = .library
                            }))
        all.append(Scenario(name: "spec-09b-filter-empty", settleMilliseconds: 400,
                            apply: { store in
                                specReset(store)
                                store.applySeed(.three)
                                store.screen = .library
                                // Delete the only m4a take, then filter to m4a.
                                if store.library.indices.contains(2) {
                                    store.delete(id: store.library[2].id)
                                }
                                store.libraryFilter = .format(.m4a)
                            }))
        all.append(Scenario(name: "spec-10a-player-8s", settleMilliseconds: 500,
                            apply: { store in
                                specReset(store)
                                store.screen = .library
                                if store.library.indices.contains(4) {
                                    store.select(store.library[4])   // "untitled", 8s
                                    store.scrub(to: 0.42)
                                }
                            }))
        all.append(Scenario(name: "spec-10b-player-hour-clamp-left", settleMilliseconds: 500,
                            apply: { store in
                                specReset(store)
                                store.screen = .library
                                if store.library.indices.contains(5) {
                                    store.select(store.library[5])   // "band practice", 1:12:03
                                    store.scrub(to: 0.03)
                                }
                            }))
        all.append(Scenario(name: "spec-10c-player-hour-clamp-right", settleMilliseconds: 500,
                            apply: { store in
                                specReset(store)
                                store.screen = .library
                                if store.library.indices.contains(5) {
                                    store.select(store.library[5])
                                    store.scrub(to: 0.97)
                                }
                            }))
        all.append(Scenario(name: "spec-11a-rename", settleMilliseconds: 500,
                            apply: { store in
                                specReset(store)
                                store.screen = .library
                                if store.library.indices.contains(1) {
                                    store.renamingID = store.library[1].id
                                }
                            }))
        all.append(Scenario(name: "spec-11b-delete-confirm", settleMilliseconds: 500,
                            apply: { store in
                                specReset(store)
                                store.screen = .library
                                if store.library.indices.contains(2) {
                                    store.pendingDeleteID = store.library[2].id
                                }
                            }))
        all.append(Scenario(name: "spec-05a-perm-nd", settleMilliseconds: 400,
                            apply: { store in
                                specReset(store)
                                store.permissionStatus = .notDetermined
                                store.forceState(.disarmed)
                            }))
        all.append(Scenario(name: "spec-05b-perm-denied", settleMilliseconds: 400,
                            apply: { store in
                                specReset(store)
                                store.permissionStatus = .denied
                                store.forceState(.disarmed)
                            }))
        all.append(Scenario(name: "spec-05c-perm-opening", settleMilliseconds: 700,
                            apply: { store in
                                specReset(store)
                                store.permissionStatus = .denied
                                store.forceState(.disarmed)
                                store.simulateOpenSystemSettings()
                            }))
        all.append(Scenario(name: "spec-05d-transloc", settleMilliseconds: 400,
                            apply: { store in
                                specReset(store)
                                store.translocationBlocked = true
                            }))
        all.append(Scenario(name: "spec-06a-err-startfailed", settleMilliseconds: 400,
                            apply: { store in
                                specReset(store)
                                store.activeError = .startFailed
                            }))
        all.append(Scenario(name: "spec-06b-err-diskfull", settleMilliseconds: 400,
                            apply: { store in
                                specReset(store)
                                store.simulateDiskFullOnRecord = true
                                store.record()   // refusal on press
                            }))
        all.append(Scenario(name: "spec-06c-err-savefallback", settleMilliseconds: 1600,
                            apply: { store in
                                specReset(store)
                                store.saveLocation.isUnavailable = true
                                store.record()   // notice appears, recording continues
                            }))
        all.append(Scenario(name: "spec-06d-err-streamfailed", settleMilliseconds: 400,
                            apply: { store in
                                specReset(store)
                                store.activeError = .streamFailed
                            }))
        all.append(Scenario(name: "spec-07-longrec", settleMilliseconds: 900,
                            apply: { store in
                                specReset(store)
                                store.forceState(.recording(startedAt: .now.addingTimeInterval(-4323)))
                            }))
        all.append(Scenario(name: "spec-02c-stopping", settleMilliseconds: 550,
                            apply: { store in
                                specReset(store)
                                store.forceState(.recording(startedAt: .now.addingTimeInterval(-8)))
                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(300))
                                    store.stop()
                                }
                            }))
        all.append(Scenario(name: "spec-12a-onboarding-nd", settleMilliseconds: 500,
                            apply: { store in
                                specReset(store)
                                store.permissionStatus = .notDetermined
                                store.forceState(.disarmed)
                                store.showOnboarding = true
                            }))
        all.append(Scenario(name: "spec-12b-onboarding-granted", settleMilliseconds: 500,
                            apply: { store in
                                specReset(store)
                                store.showOnboarding = true
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
        case .glassLCD: "5-gl"
        }
    }

    private static func capture(to path: String) {
        // Target the stage window by title — "first visible" would grab a
        // popover or child window if one happened to be open.
        let stage = NSApp.windows.first {
            $0.title == "Home Rec — Concepts" && $0.isVisible
        }
        guard
            let window = stage ?? NSApp.windows.first(where: { $0.isVisible }),
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

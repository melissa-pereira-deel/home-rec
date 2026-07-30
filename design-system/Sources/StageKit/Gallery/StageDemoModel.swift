import SwiftUI

// A deliberately generic toy domain — a room thermostat — so the gallery
// demonstrates the kit rather than any particular product. Nothing in StageKit
// proper depends on any of this.

@available(macOS 15.0, *)
public enum StageDemoMode: String, CaseIterable, Hashable {
    case off, heat, cool

    var label: String { rawValue.uppercased() }
}

@available(macOS 15.0, *)
public enum StageDemoFault: String, CaseIterable, Hashable {
    case sensor, filter, power

    var label: String { rawValue.uppercased() }
    var message: String {
        switch self {
        case .sensor: "Room sensor not reporting."
        case .filter: "Filter is due for a change."
        case .power: "Running on backup power."
        }
    }
}

@available(macOS 15.0, *)
public enum StageDemoDensity: String, CaseIterable, Hashable {
    case tight, cozy, airy

    var label: String { rawValue.uppercased() }
    var padding: CGFloat {
        switch self {
        case .tight: 10
        case .cozy: 18
        case .airy: 28
        }
    }
}

@available(macOS 15.0, *)
public enum StageDemoScreen: String, CaseIterable, Hashable {
    case control, schedule

    var label: String { rawValue.uppercased() }
}

/// The consumer-owned state a stage drives. A plain value type: the axes are
/// key paths into it, and a scenario is a mutation of it.
@available(macOS 15.0, *)
public struct StageDemoState {
    public var setpoint: Double = 21
    public var mode: StageDemoMode = .heat
    public var isOffline: Bool = false
    public var fault: StageDemoFault?
    public var density: StageDemoDensity = .cozy
    public var screen: StageDemoScreen = .control

    public init() {}

    /// Derived, not stored — a concept should never be able to render a
    /// "heating" badge while the mode says off.
    var isCalling: Bool { mode != .off && !isOffline }

    var schedule: [(String, Int)] {
        [("06:30", 20), ("08:00", 18), ("17:30", 21), ("22:00", 17)]
    }
}

/// The whole stage declaration, in one place, as a consumer would write it.
@available(macOS 15.0, *)
public enum StageDemo {
    public static var concepts: [StageConcept<StageDemoState>] {
        [
            StageConcept(id: "dial", title: "Dial", subtitle: "Radial, one gesture") {
                StageDemoDialConcept(state: $0)
            },
            StageConcept(id: "slab", title: "Slab", subtitle: "Flat, list-led") {
                StageDemoSlabConcept(state: $0)
            },
        ]
    }

    public static var axisGroups: [StageAxisGroup<StageDemoState>] {
        [
            StageAxisGroup(id: "primary", axes: [
                .options("TEMP", path: \.setpoint, values: [4, 21, 30], label: { "\(Int($0))°" }),
                .options("MODE", path: \.mode, label: \.label),
                .toggle("OFFLINE", path: \.isOffline, shortcut: "o"),
            ]),
            StageAxisGroup(id: "edge", axes: [
                .optionalCycle("FAULT", path: \.fault, label: \.label, shortcut: "f"),
                .options("DENSITY", path: \.density, label: \.label, presentation: .segmented),
                // Dependent axis: schedule presets are meaningless on a
                // thermostat that is switched off, so the chips grey out
                // instead of silently doing nothing.
                .shots("PRESET", values: [
                    StageAxisValue("NIGHT") { $0.mode = .cool; $0.setpoint = 18 },
                    StageAxisValue("AWAY") { $0.mode = .off; $0.setpoint = 12 },
                    StageAxisValue("PARTY") { $0.mode = .cool; $0.setpoint = 26 },
                ], isEnabled: { !$0.isOffline }),
            ]),
            StageAxisGroup(id: "screen", axes: [
                .options("SCREEN", path: \.screen, label: \.label, placement: .tabBarTrailing),
            ]),
        ]
    }

    @MainActor
    public static func makeDriver() -> StageDriver<StageDemoState> {
        StageDriver(state: StageDemoState(), concepts: concepts, axes: axisGroups)
    }

    /// The set a snapshot run would iterate. Every concept at rest, then every
    /// concept in every single-axis state.
    public static func scenarios() -> [StageScenario<StageDemoState>] {
        StageScenario.baseline(concepts: concepts)
            + StageScenario.sweep(
                concepts: concepts,
                axes: axisGroups.flatMap(\.axes),
                reset: { $0 = StageDemoState() }
            )
    }
}

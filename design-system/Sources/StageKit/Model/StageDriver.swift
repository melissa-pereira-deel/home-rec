import SwiftUI

/// The prototype operating system: one model, N concepts, M axes.
///
/// Every concept reads and writes this single instance, which is what makes a
/// stage worth building — switching directions mid-state keeps timers running,
/// scroll positions held, and errors on screen, so the comparison is between
/// the designs rather than between two fresh launches.
///
/// Generic over the consumer's model, which is expected to be a value type. Its
/// mutations funnel through ``mutate(_:)`` so a reference-type model still
/// notifies observers correctly.
@available(macOS 15.0, *)
@MainActor
public final class StageDriver<Model>: ObservableObject {
    /// The prototype's state. Concepts bind to it; axes read and write it.
    @Published public var state: Model
    /// Currently staged concept.
    @Published public private(set) var conceptID: String

    public let concepts: [StageConcept<Model>]
    public let groups: [StageAxisGroup<Model>]

    public init(
        state: Model,
        concepts: [StageConcept<Model>],
        axes groups: [StageAxisGroup<Model>],
        initialConceptID: String? = nil
    ) {
        self.state = state
        self.concepts = concepts
        self.groups = groups
        self.conceptID = initialConceptID ?? concepts.first?.id ?? ""
    }

    /// Flat-axis convenience: every axis lands in a single scrubber row.
    public convenience init(
        state: Model,
        concepts: [StageConcept<Model>],
        axes: [StageAxis<Model>],
        initialConceptID: String? = nil
    ) {
        self.init(
            state: state,
            concepts: concepts,
            axes: [StageAxisGroup(id: "default", axes: axes)],
            initialConceptID: initialConceptID
        )
    }

    // MARK: Axes

    public var allAxes: [StageAxis<Model>] { groups.flatMap(\.axes) }

    /// Axes rendered in the bottom scrubber, grouped into rows.
    public var scrubberGroups: [StageAxisGroup<Model>] {
        groups.compactMap { group in
            let axes = group.axes.filter { $0.placement == .scrubber }
            guard !axes.isEmpty else { return nil }
            return StageAxisGroup(id: group.id, title: group.title, axes: axes)
        }
    }

    /// Axes rendered at the trailing end of the tab bar.
    public var tabBarTrailingAxes: [StageAxis<Model>] {
        allAxes.filter { $0.placement == .tabBarTrailing }
    }

    public func axis(id: String) -> StageAxis<Model>? {
        allAxes.first { $0.id == id }
    }

    // MARK: Concepts

    public var concept: StageConcept<Model>? {
        concepts.first { $0.id == conceptID } ?? concepts.first
    }

    public var conceptIndex: Int {
        concepts.firstIndex { $0.id == conceptID } ?? 0
    }

    public func select(conceptID id: String) {
        guard concepts.contains(where: { $0.id == id }), id != conceptID else { return }
        conceptID = id
    }

    /// Selects by the 1-based number shown in the tab bar.
    @discardableResult
    public func selectConcept(number: Int) -> Bool {
        let index = number - 1
        guard concepts.indices.contains(index) else { return false }
        conceptID = concepts[index].id
        return true
    }

    public func cycleConcept(by delta: Int = 1) {
        guard !concepts.isEmpty else { return }
        let count = concepts.count
        let next = ((conceptIndex + delta) % count + count) % count
        conceptID = concepts[next].id
    }

    // MARK: Mutation

    /// The single write path into the model.
    ///
    /// `objectWillChange` is sent explicitly so that a class-typed model — a
    /// pre-existing `ObservableObject` prototype store someone is adopting
    /// StageKit around — still refreshes the stage, even though `@Published`
    /// would not fire for an in-place mutation of a reference.
    public func mutate(_ body: (inout Model) -> Void) {
        objectWillChange.send()
        body(&state)
    }

    public func apply(_ value: StageAxisValue<Model>) {
        mutate(value.apply)
    }

    /// Steps an axis and returns where it landed, so callers can announce it.
    @discardableResult
    public func step(_ axis: StageAxis<Model>, by delta: Int = 1) -> StageAxisValue<Model>? {
        guard axis.isEnabled(state), let next = axis.value(steppedBy: delta, from: state) else { return nil }
        mutate(next.apply)
        return next
    }

    @discardableResult
    public func step(axisID: String, by delta: Int = 1) -> StageAxisValue<Model>? {
        guard let axis = axis(id: axisID) else { return nil }
        return step(axis, by: delta)
    }

    /// Returns every axis to its base position without touching the model's
    /// other properties. The "start the demo over" gesture.
    public func resetAxes() {
        mutate { model in
            for axis in allAxes {
                guard let base = axis.baseValueID, let value = axis.value(id: base) else { continue }
                value.apply(&model)
            }
        }
    }

    // MARK: Scenarios

    public func apply(_ scenario: StageScenario<Model>) {
        if let id = scenario.conceptID { select(conceptID: id) }
        mutate(scenario.apply)
    }

    /// A sweep over this driver's own concepts and axes — the set most stages
    /// want to snapshot, with no extra declaration.
    public func defaultScenarios(
        reset: @escaping (inout Model) -> Void = { _ in },
        settle: Duration = .milliseconds(400)
    ) -> [StageScenario<Model>] {
        StageScenario.baseline(concepts: concepts, reset: reset, settle: settle)
            + StageScenario.sweep(concepts: concepts, axes: allAxes, reset: reset, settle: settle)
    }

    // MARK: Keyboard

    /// Keyboard hints derived from what this stage actually declares, so the
    /// hint row cannot go stale when an axis is added or a shortcut changes.
    public var derivedKeyHints: [StageKeyHintItem] {
        var hints: [StageKeyHintItem] = []
        if concepts.count > 1 {
            let last = min(concepts.count, 9)
            hints.append(StageKeyHintItem(last == 1 ? "1" : "1–\(last)", "concept"))
        }
        if !tabBarTrailingAxes.isEmpty {
            hints.append(StageKeyHintItem("\\", tabBarTrailingAxes[0].title.lowercased()))
        }
        for axis in allAxes where axis.shortcut != nil {
            hints.append(StageKeyHintItem(String(axis.shortcut!), axis.title.lowercased()))
        }
        return hints
    }

    /// Handles the shortcuts StageKit owns. `StageWindow` calls this; a custom
    /// chrome can too.
    public func handleStageKey(_ press: KeyPress) -> KeyPress.Result {
        let characters = press.characters
        // ⌘1…⌘9 duplicates 1…9 so concept switching still works while a text
        // field inside a concept is swallowing bare digits.
        if press.modifiers.isEmpty || press.modifiers == .command,
           let number = Int(characters), (1...9).contains(number) {
            return selectConcept(number: number) ? .handled : .ignored
        }
        guard press.modifiers.isEmpty else { return .ignored }
        switch characters {
        case "[":
            cycleConcept(by: -1)
            return .handled
        case "]":
            cycleConcept(by: 1)
            return .handled
        case "\\":
            guard let axis = tabBarTrailingAxes.first else { return .ignored }
            return step(axis) != nil ? .handled : .ignored
        default:
            break
        }
        if let character = characters.first, characters.count == 1,
           let axis = allAxes.first(where: { $0.shortcut == character }) {
            return step(axis) != nil ? .handled : .ignored
        }
        return .ignored
    }
}

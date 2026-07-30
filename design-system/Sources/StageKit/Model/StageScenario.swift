import Foundation

/// A named, applied combination of axis positions.
///
/// A scenario is what you point at in a review ("look at *empty, offline, on
/// the compact concept*") and it is exactly the unit a snapshot run iterates.
/// Because both uses share the type, the picture in the spec document and the
/// state you can reach live from the scrubber cannot drift apart.
@available(macOS 15.0, *)
public struct StageScenario<Model>: Identifiable {
    /// Filename-safe. Becomes `<id>.png` in a snapshot run, so keep it stable:
    /// renaming a scenario orphans every reference to its image.
    public let id: String
    /// Human-readable name for review documents and logs.
    public let title: String
    /// Concept to switch to first. `nil` leaves the current one, which is how
    /// you write a continuity sequence — one scenario sets up a live state, the
    /// following ones only change concept.
    public let conceptID: String?
    /// How long to wait after applying before capturing.
    ///
    /// Not a fudge factor. Animated prototypes have a settling time and a
    /// meaningful mid-transition; this is the knob that says which moment of
    /// the state you meant.
    public let settle: Duration
    public let apply: (inout Model) -> Void
    /// Free-form labels for filtering a run (`"regression"`, `"spec"`).
    public let tags: [String]

    public init(
        id: String,
        title: String? = nil,
        conceptID: String? = nil,
        settle: Duration = .milliseconds(400),
        tags: [String] = [],
        apply: @escaping (inout Model) -> Void = { _ in }
    ) {
        self.id = id
        self.title = title ?? id
        self.conceptID = conceptID
        self.settle = settle
        self.tags = tags
        self.apply = apply
    }
}

// MARK: - Generators

@available(macOS 15.0, *)
extension StageScenario {
    /// One scenario per axis position, per concept, with every other axis left
    /// at its base.
    ///
    /// The default way to generate a review set. For *n* concepts and axes with
    /// *v₁…vₖ* positions it produces `n · Σvᵢ` scenarios — linear, so it stays
    /// runnable as a stage grows. Full combinatorial coverage is almost never
    /// what a design review needs; you are looking for "does this direction
    /// hold up in this state", one state at a time.
    public static func sweep(
        concepts: [StageConcept<Model>],
        axes: [StageAxis<Model>],
        reset: @escaping (inout Model) -> Void = { _ in },
        settle: Duration = .milliseconds(400),
        tags: [String] = []
    ) -> [StageScenario<Model>] {
        var scenarios: [StageScenario<Model>] = []
        for concept in concepts {
            for axis in axes {
                for value in axis.values {
                    scenarios.append(
                        StageScenario(
                            id: "\(concept.id)__\(axis.id)-\(value.id)",
                            title: "\(concept.title) · \(axis.title) \(value.label.isEmpty ? "base" : value.label)",
                            conceptID: concept.id,
                            settle: settle,
                            tags: tags
                        ) { model in
                            reset(&model)
                            value.apply(&model)
                        }
                    )
                }
            }
        }
        return scenarios
    }

    /// The full cartesian product of the given axes, per concept.
    ///
    /// Grows multiplicatively — three 3-position axes across four concepts is
    /// 108 captures. Reach for it when you genuinely need interaction coverage
    /// (does the empty state survive every locale *and* every density), and
    /// filter the run rather than shortening the list.
    public static func matrix(
        concepts: [StageConcept<Model>],
        axes: [StageAxis<Model>],
        reset: @escaping (inout Model) -> Void = { _ in },
        settle: Duration = .milliseconds(400),
        tags: [String] = []
    ) -> [StageScenario<Model>] {
        let combinations = product(of: axes)
        var scenarios: [StageScenario<Model>] = []
        for concept in concepts {
            for combination in combinations {
                let slug = combination
                    .map { "\($0.axis.id)-\($0.value.id)" }
                    .joined(separator: "__")
                let readable = combination
                    .map { "\($0.axis.title) \($0.value.label.isEmpty ? "base" : $0.value.label)" }
                    .joined(separator: " · ")
                scenarios.append(
                    StageScenario(
                        id: "\(concept.id)__\(slug)",
                        title: "\(concept.title) · \(readable)",
                        conceptID: concept.id,
                        settle: settle,
                        tags: tags
                    ) { model in
                        reset(&model)
                        for step in combination { step.value.apply(&model) }
                    }
                )
            }
        }
        return scenarios
    }

    private struct Step {
        let axis: StageAxis<Model>
        let value: StageAxisValue<Model>
    }

    private static func product(of axes: [StageAxis<Model>]) -> [[Step]] {
        axes.reduce([[]]) { partial, axis in
            guard !axis.values.isEmpty else { return partial }
            return partial.flatMap { prefix in
                axis.values.map { prefix + [Step(axis: axis, value: $0)] }
            }
        }
    }

    /// One scenario per concept in its base state — the "line up the directions
    /// side by side" set every review opens with.
    public static func baseline(
        concepts: [StageConcept<Model>],
        reset: @escaping (inout Model) -> Void = { _ in },
        settle: Duration = .milliseconds(400),
        tags: [String] = []
    ) -> [StageScenario<Model>] {
        concepts.map { concept in
            StageScenario(
                id: "\(concept.id)__baseline",
                title: "\(concept.title) · baseline",
                conceptID: concept.id,
                settle: settle,
                tags: tags,
                apply: reset
            )
        }
    }
}

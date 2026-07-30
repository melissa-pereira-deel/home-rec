import SwiftUI

// MARK: - Slug

/// Derives a stable, filename-safe identifier from a display title.
///
/// Snapshot files are named from axis and value ids, so ids must survive being
/// written to disk, sorted, and diffed in a review — hence lowercase ASCII with
/// single dashes.
func stageSlug(_ text: String) -> String {
    var out = ""
    var pendingDash = false
    for scalar in text.lowercased().unicodeScalars {
        if CharacterSet.alphanumerics.contains(scalar) {
            if pendingDash { out.append("-"); pendingDash = false }
            out.unicodeScalars.append(scalar)
        } else if !out.isEmpty {
            pendingDash = true
        }
    }
    return out.isEmpty ? "axis" : out
}

// MARK: - Value

/// One discrete position on an axis.
///
/// `apply` is a mutation rather than a value so a single position can set
/// several correlated properties at once. A "denied permission" position that
/// only set `permission = .denied` and left `transport = .recording` would put
/// the prototype in a state the real app can never reach, and reviewers would
/// spend the meeting discussing an artefact of the harness.
@available(macOS 15.0, *)
public struct StageAxisValue<Model>: Identifiable {
    public let id: String
    /// Shown on the chip. Uppercased at render time.
    public let label: String
    public let apply: (inout Model) -> Void

    public init(id: String, label: String, apply: @escaping (inout Model) -> Void) {
        self.id = id
        self.label = label
        self.apply = apply
    }

    /// Convenience for value ids derived from the label.
    public init(_ label: String, apply: @escaping (inout Model) -> Void) {
        self.init(id: stageSlug(label), label: label, apply: apply)
    }
}

// MARK: - Presentation

/// How the scrubber renders an axis.
///
/// The choice is about how many positions there are and how often you switch,
/// not about the underlying type — a three-value axis can legitimately be a
/// cycle (compact, one chip) or chips (one press per state).
@available(macOS 15.0, *)
public enum StageAxisPresentation: Hashable {
    /// One chip, on/off. The chip is active when the axis is off its base.
    case toggle
    /// One chip that steps to the next value on each press, showing the current
    /// one. Right for long tails you only occasionally need — five error kinds,
    /// eight locales — where N chips would crowd out everything else.
    case cycle
    /// One chip per value; the current value's chip is active. Right for the
    /// two-to-five values you switch between constantly.
    case chips
    /// A joined track. Right when the values form a scale.
    case segmented
}

/// Where in the chrome an axis is rendered.
@available(macOS 15.0, *)
public enum StageAxisPlacement: Hashable {
    /// The bottom scrubber. The default.
    case scrubber
    /// The trailing end of the top tab bar.
    ///
    /// Reserve this for the axis that selects *what you are looking at* rather
    /// than what state it is in — screen, route, viewport. Putting it beside
    /// the concept tabs groups the two "which view" controls together and keeps
    /// the scrubber purely about state.
    case tabBarTrailing
}

// MARK: - Axis

/// A named state dimension with discrete positions.
///
/// This is the unit of declaration in StageKit: describe your prototype's state
/// as a list of axes and the scrubber, keyboard shortcuts, accessibility, and
/// snapshot matrix all fall out of it. Nothing here knows what your state
/// *means* — it only knows how to read the current position and how to move to
/// another one.
@available(macOS 15.0, *)
public struct StageAxis<Model>: Identifiable {
    public let id: String
    /// Display name, e.g. `"THEME"`. Also the accessibility label.
    public let title: String
    public let presentation: StageAxisPresentation
    public let placement: StageAxisPlacement
    public let values: [StageAxisValue<Model>]
    /// The neutral position. An axis is "active" — and its chip inverts — when
    /// it is anywhere else. `nil` means the axis has no resting state, which is
    /// correct for action-style axes.
    public let baseValueID: String?
    /// Unmodified key that steps this axis from anywhere on the stage. StageKit
    /// renders it into the hint bar automatically.
    public let shortcut: Character?

    /// Reads the current position out of the model. `nil` means the model is in
    /// a combination this axis cannot name — no chip is shown active, which is
    /// honest, and better than guessing.
    public let currentValueID: (Model) -> String?
    /// Label for the single-chip presentations.
    public let summaryLabel: (Model) -> String
    /// Whether the axis applies right now. Use it for dependent axes — a
    /// "sort order" axis is meaningless while an "empty list" axis is on.
    public let isEnabled: (Model) -> Bool

    public init(
        id: String,
        title: String,
        presentation: StageAxisPresentation,
        placement: StageAxisPlacement = .scrubber,
        values: [StageAxisValue<Model>],
        baseValueID: String? = nil,
        shortcut: Character? = nil,
        currentValueID: @escaping (Model) -> String?,
        summaryLabel: ((Model) -> String)? = nil,
        isEnabled: @escaping (Model) -> Bool = { _ in true }
    ) {
        self.id = id
        self.title = title
        self.presentation = presentation
        self.placement = placement
        self.values = values
        let base = baseValueID ?? values.first?.id
        self.baseValueID = base
        self.shortcut = shortcut
        self.currentValueID = currentValueID
        self.isEnabled = isEnabled
        self.summaryLabel = summaryLabel ?? { model in
            // A cycle chip must report where it currently sits, or the reviewer
            // has to press it to find out. At base it shows the bare title so
            // the resting scrubber stays scannable.
            guard presentation == .cycle,
                  let current = currentValueID(model),
                  current != base,
                  let value = values.first(where: { $0.id == current }),
                  !value.label.isEmpty
            else { return title }
            return "\(title) \(value.label)"
        }
    }

    // MARK: Queries

    public func value(id: String) -> StageAxisValue<Model>? {
        values.first { $0.id == id }
    }

    public func currentValue(in model: Model) -> StageAxisValue<Model>? {
        currentValueID(model).flatMap { value(id: $0) }
    }

    /// True when the axis has been moved off its base — the condition the chip
    /// inverts on.
    public func isActive(in model: Model) -> Bool {
        guard let base = baseValueID, let current = currentValueID(model) else { return false }
        return current != base
    }

    /// The position `delta` steps along, wrapping. An unrecognised current
    /// position steps to the first value, so a cycle chip always does something.
    public func value(steppedBy delta: Int, from model: Model) -> StageAxisValue<Model>? {
        guard !values.isEmpty else { return nil }
        let index = currentValueID(model).flatMap { id in values.firstIndex { $0.id == id } } ?? -1
        let count = values.count
        let next = ((index + delta) % count + count) % count
        return values[next]
    }

    public func controlState(in model: Model) -> StageControlState {
        guard isEnabled(model) else { return .disabled }
        return isActive(in: model) ? .active : .idle
    }

    /// Human-readable current position, for `accessibilityValue`.
    public func accessibilityValue(in model: Model) -> String {
        guard let value = currentValue(in: model) else { return "Mixed" }
        return value.label.isEmpty ? "Off" : value.label
    }
}

// MARK: - Declarative constructors

@available(macOS 15.0, *)
extension StageAxis {
    /// A boolean flag: `EMPTY`, `OFFLINE`, `REDUCED MOTION`.
    public static func toggle(
        _ title: String,
        id: String? = nil,
        path: WritableKeyPath<Model, Bool>,
        placement: StageAxisPlacement = .scrubber,
        shortcut: Character? = nil,
        isEnabled: @escaping (Model) -> Bool = { _ in true }
    ) -> StageAxis<Model> {
        StageAxis(
            id: id ?? stageSlug(title),
            title: title,
            presentation: .toggle,
            placement: placement,
            values: [
                StageAxisValue(id: "off", label: "OFF") { $0[keyPath: path] = false },
                StageAxisValue(id: "on", label: "ON") { $0[keyPath: path] = true },
            ],
            baseValueID: "off",
            shortcut: shortcut,
            currentValueID: { $0[keyPath: path] ? "on" : "off" },
            summaryLabel: { _ in title },
            isEnabled: isEnabled
        )
    }

    /// An explicit list of positions, stepped by one chip.
    public static func cycle<V: Equatable>(
        _ title: String,
        id: String? = nil,
        path: WritableKeyPath<Model, V>,
        values source: [V],
        label: @escaping (V) -> String,
        placement: StageAxisPlacement = .scrubber,
        shortcut: Character? = nil,
        isEnabled: @escaping (Model) -> Bool = { _ in true }
    ) -> StageAxis<Model> {
        StageAxis(
            id: id ?? stageSlug(title),
            title: title,
            presentation: .cycle,
            placement: placement,
            values: Self.values(from: source, path: path, label: label),
            baseValueID: source.isEmpty ? nil : "v0",
            shortcut: shortcut,
            currentValueID: Self.reader(source, path: path),
            isEnabled: isEnabled
        )
    }

    /// Every case of an enum, stepped by one chip.
    public static func cycle<V: CaseIterable & Equatable>(
        _ title: String,
        id: String? = nil,
        path: WritableKeyPath<Model, V>,
        label: @escaping (V) -> String,
        placement: StageAxisPlacement = .scrubber,
        shortcut: Character? = nil,
        isEnabled: @escaping (Model) -> Bool = { _ in true }
    ) -> StageAxis<Model> {
        cycle(title, id: id, path: path, values: Array(V.allCases), label: label,
              placement: placement, shortcut: shortcut, isEnabled: isEnabled)
    }

    /// `nil` plus every case of an enum — the "no error / error N" shape.
    ///
    /// `nil` is the base, so the chip stays quiet until you step into a failure
    /// and inverts for as long as you are in one. That single rule is why a
    /// reviewer can glance at a scrubber and see that the screenshot they are
    /// looking at is not the happy path.
    public static func optionalCycle<V: CaseIterable & Equatable>(
        _ title: String,
        id: String? = nil,
        path: WritableKeyPath<Model, V?>,
        label: @escaping (V) -> String,
        placement: StageAxisPlacement = .scrubber,
        shortcut: Character? = nil,
        isEnabled: @escaping (Model) -> Bool = { _ in true }
    ) -> StageAxis<Model> {
        let source: [V?] = [nil] + Array(V.allCases)
        return cycle(
            title, id: id, path: path, values: source,
            label: { $0.map(label) ?? "" },
            placement: placement, shortcut: shortcut, isEnabled: isEnabled
        )
    }

    /// One chip (or one segment) per position.
    public static func options<V: Equatable>(
        _ title: String,
        id: String? = nil,
        path: WritableKeyPath<Model, V>,
        values source: [V],
        label: @escaping (V) -> String,
        presentation: StageAxisPresentation = .chips,
        placement: StageAxisPlacement = .scrubber,
        shortcut: Character? = nil,
        isEnabled: @escaping (Model) -> Bool = { _ in true }
    ) -> StageAxis<Model> {
        StageAxis(
            id: id ?? stageSlug(title),
            title: title,
            presentation: presentation,
            placement: placement,
            values: Self.values(from: source, path: path, label: label),
            baseValueID: source.isEmpty ? nil : "v0",
            shortcut: shortcut,
            currentValueID: Self.reader(source, path: path),
            isEnabled: isEnabled
        )
    }

    /// Every case of an enum, one chip each.
    public static func options<V: CaseIterable & Equatable>(
        _ title: String,
        id: String? = nil,
        path: WritableKeyPath<Model, V>,
        label: @escaping (V) -> String,
        presentation: StageAxisPresentation = .chips,
        placement: StageAxisPlacement = .scrubber,
        shortcut: Character? = nil,
        isEnabled: @escaping (Model) -> Bool = { _ in true }
    ) -> StageAxis<Model> {
        options(title, id: id, path: path, values: Array(V.allCases), label: label,
                presentation: presentation, placement: placement,
                shortcut: shortcut, isEnabled: isEnabled)
    }

    /// Positions that set several properties at once and cannot be read back
    /// from a single key path — the compound "put it in *this* situation" chips.
    ///
    /// Supply `current` when the combination *is* recognisable; without it no
    /// chip ever shows as active, which is the honest default for a shortcut
    /// that fires and forgets.
    public static func shots(
        _ title: String,
        id: String? = nil,
        values: [StageAxisValue<Model>],
        current: @escaping (Model) -> String? = { _ in nil },
        placement: StageAxisPlacement = .scrubber,
        isEnabled: @escaping (Model) -> Bool = { _ in true }
    ) -> StageAxis<Model> {
        StageAxis(
            id: id ?? stageSlug(title),
            title: title,
            presentation: .chips,
            placement: placement,
            values: values,
            // No base: a shot list has no resting position to be "off" from.
            baseValueID: nil,
            currentValueID: current,
            isEnabled: isEnabled
        )
    }

    // MARK: Shared plumbing

    private static func values<V>(
        from source: [V],
        path: WritableKeyPath<Model, V>,
        label: @escaping (V) -> String
    ) -> [StageAxisValue<Model>] {
        source.enumerated().map { index, value in
            // Positional ids rather than slugged labels: labels get reworded
            // constantly during a design review, and renaming a chip should not
            // silently rename every snapshot file it appears in.
            StageAxisValue(id: "v\(index)", label: label(value)) { $0[keyPath: path] = value }
        }
    }

    private static func reader<V: Equatable>(
        _ source: [V],
        path: WritableKeyPath<Model, V>
    ) -> (Model) -> String? {
        { model in
            let current = model[keyPath: path]
            guard let index = source.firstIndex(where: { $0 == current }) else { return nil }
            return "v\(index)"
        }
    }
}

// MARK: - Group

/// A row of axes in the scrubber.
///
/// Grouping is the only editorial decision the scrubber asks of you, and it is
/// worth making deliberately: reviewers learn a stage by row. Keep the axes you
/// drive a demo with on the first row and the ones you reach for when
/// interrogating an edge case on the second.
@available(macOS 15.0, *)
public struct StageAxisGroup<Model>: Identifiable {
    public let id: String
    /// Optional caption printed before the row. Most stages want none — the
    /// chips label themselves and a caption steals horizontal room.
    public let title: String?
    public let axes: [StageAxis<Model>]

    public init(id: String? = nil, title: String? = nil, axes: [StageAxis<Model>]) {
        self.id = id ?? title.map(stageSlug) ?? axes.map(\.id).joined(separator: "+")
        self.title = title
        self.axes = axes
    }
}

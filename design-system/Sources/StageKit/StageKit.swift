import SwiftUI

/// # StageKit
///
/// A design system for *prototype-showcase chrome* — the harness that surrounds
/// and drives design concepts under review.
///
/// A stage hosts several competing designs, switches between them by number,
/// and exposes every state they can be in as a row of chips along the bottom.
/// It is a prototype operating system: declare your state axes once and you get
/// a scrubber, keyboard shortcuts, and a deterministic snapshot run for free.
///
/// ## The three layers
///
/// - **Tokens** (`StageTheme`) — a deliberately recessive near-black visual
///   language. The chrome must never read as part of the design being reviewed.
/// - **Chrome** (`StageFrame`, `StageTabBar`, `StageScrubber`) — the furniture.
///   Usable on its own with hand-written content.
/// - **Driving model** (`StageDriver`, `StageAxis`, `StageScenario`) — the part
///   that makes it a system rather than a skin. Generic over *your* state type.
///
/// ## Minimum adoption
///
/// ```swift
/// struct AppState { var isEmpty = false; var theme: Theme = .light }
///
/// let driver = StageDriver(
///     state: AppState(),
///     concepts: [
///         StageConcept(id: "a", title: "Card") { CardConcept(state: $0) },
///         StageConcept(id: "b", title: "List") { ListConcept(state: $0) },
///     ],
///     axes: [
///         .toggle("EMPTY", path: \.isEmpty),
///         .cycle("THEME", path: \.theme, label: \.name),
///     ]
/// )
///
/// StageWindow(driver: driver, stageSize: CGSize(width: 420, height: 700))
/// ```
///
/// See `docs/stage.md` for the full spec.
public enum StageKit {
    /// Semantic version of the kit's public API. Consumers pin against this
    /// when they vendor the sources rather than depend on the package.
    public static let version = "1.0.0"
}

import SwiftUI

/// PocketOperatorKit — a SwiftUI design system for interfaces that read as
/// hardware instruments rather than applications.
///
/// The language descends from Teenage Engineering's Pocket Operator / OP-1
/// line: an exposed dark chassis, screen-printed micro-labels, hard-edged
/// keys with real travel, a phosphor segment display, analogue meters, and a
/// single saturated accent reserved for the armed control.
///
/// Layering, lowest to highest:
///
/// - `Tokens/` — semantic colour, type, metric, texture and motion roles.
///   Literal values live only here; component bodies never name a hex.
/// - `Primitives/` — the physical vocabulary: `ChassisSurface`,
///   `ScreenPrintLabel`, `HardwareKey`, `IndicatorLamp`, `Well`,
///   `HairlineEtch`.
/// - `Components/` — assembled controls and readouts built from primitives.
/// - `Patterns/` — the composition rules (`DeviceFace`, panel hierarchy,
///   label placement, motion language) that make the parts read as one object.
///
/// Re-skinning is done by injecting a different `POTheme` at the root:
///
/// ```swift
/// DeviceFace(brand: "ACME", model: "AK-2") { … }
///     .pocketOperatorTheme(.amberService)
/// ```
///
/// The package floor is macOS 15, so every symbol here is unconditionally
/// available to clients; `@available` annotations mark the public surface for
/// readers rather than gating it.
public enum PocketOperatorKit {
    /// Semantic version of the design language, not of the Swift package.
    /// Bumped when a token role is renamed or a component's visual contract
    /// changes, so a consuming product can pin a look.
    public static let languageVersion = "1.0.0"
}

import SwiftUI

/// The complete token set for a stage: colour, type, metrics.
///
/// Passed through the environment so that a primitive dropped anywhere inside a
/// stage is themed correctly without threading parameters. No StageKit view
/// contains a literal colour or point size; they all resolve through here.
@available(macOS 15.0, *)
public struct StageTheme: Equatable {
    public var colors: StageColorRoles
    public var typography: StageTypography
    public var metrics: StageMetrics

    public init(
        colors: StageColorRoles = .dark,
        typography: StageTypography = .default,
        metrics: StageMetrics = .default
    ) {
        self.colors = colors
        self.typography = typography
        self.metrics = metrics
    }

    /// The default stage: near-black chrome that recedes behind the concept.
    public static let dark = StageTheme()

    /// Inverted chrome, for framing concepts that are themselves dark.
    public static let light = StageTheme(colors: .light)

    /// Louder chrome and larger type, for projection or design reviews held
    /// across a room.
    public static let presentation = StageTheme(
        colors: .highContrast,
        typography: .large,
        metrics: .comfortable
    )
}

@available(macOS 15.0, *)
private struct StageThemeKey: EnvironmentKey {
    static let defaultValue = StageTheme.dark
}

@available(macOS 15.0, *)
extension EnvironmentValues {
    /// Tokens for every StageKit view below this point in the hierarchy.
    public var stageTheme: StageTheme {
        get { self[StageThemeKey.self] }
        set { self[StageThemeKey.self] = newValue }
    }
}

@available(macOS 15.0, *)
extension View {
    /// Themes this subtree's stage chrome.
    ///
    /// Apply to the whole stage, not to individual controls — a scrubber whose
    /// chips disagree about their theme reads as a bug in the concept.
    public func stageTheme(_ theme: StageTheme) -> some View {
        environment(\.stageTheme, theme)
    }
}

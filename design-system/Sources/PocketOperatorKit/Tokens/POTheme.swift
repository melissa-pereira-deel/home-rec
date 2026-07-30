import SwiftUI

/// The complete token set for one device.
///
/// A product adopts the language by injecting a theme at its root and never
/// touching tokens again. Because every component resolves colour, type,
/// metrics, texture and motion through the environment, re-skinning is a
/// one-line change and cannot drift out of sync with a component that
/// hard-coded a value — there are none.
public struct POTheme: Sendable, Equatable {
    public var colors: POColors
    public var typography: POTypography
    public var metrics: POMetrics
    public var texture: POTextureTokens
    public var motion: POMotion

    public init(
        colors: POColors = .standard,
        typography: POTypography = .standard,
        metrics: POMetrics = .standard,
        texture: POTextureTokens = .standard,
        motion: POMotion = .standard
    ) {
        self.colors = colors
        self.typography = typography
        self.metrics = metrics
        self.texture = texture
        self.motion = motion
    }

    /// Black chassis, aluminium caps, orange accent, green phosphor.
    public static let standard = POTheme()

    /// Warm graphite body, amber phosphor, signal-red accent.
    public static let amberService = POTheme(colors: .amberService)

    /// Flat fills with no procedural texture — for snapshot tests, and for
    /// hosts where a large always-on `Canvas` is not wanted.
    public static let flat = POTheme(texture: .disabled)
}

private struct POThemeKey: EnvironmentKey {
    static let defaultValue = POTheme.standard
}

/// Ink colour for content drawn inside a display cavity.
///
/// Lives in the environment rather than being passed down so that a display's
/// contents do not have to thread a palette through every nesting level — and
/// so an inverted display flips everything inside it at once.
private struct PODisplayInkKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

private struct PODisplayBedKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

public extension EnvironmentValues {
    var poTheme: POTheme {
        get { self[POThemeKey.self] }
        set { self[POThemeKey.self] = newValue }
    }

    /// Resolved lit-segment colour for the enclosing display, if any.
    var poDisplayInk: Color? {
        get { self[PODisplayInkKey.self] }
        set { self[PODisplayInkKey.self] = newValue }
    }

    /// Resolved substrate colour for the enclosing display, if any.
    var poDisplayBed: Color? {
        get { self[PODisplayBedKey.self] }
        set { self[PODisplayBedKey.self] = newValue }
    }
}

public extension View {
    /// Adopt a Pocket Operator theme for this subtree.
    func pocketOperatorTheme(_ theme: POTheme) -> some View {
        environment(\.poTheme, theme)
    }

    /// Override individual token groups without restating a whole theme.
    func pocketOperatorTheme(
        transform: @escaping (inout POTheme) -> Void
    ) -> some View {
        modifier(POThemeTransform(transform: transform))
    }
}

private struct POThemeTransform: ViewModifier {
    @Environment(\.poTheme) private var theme
    let transform: (inout POTheme) -> Void

    func body(content: Content) -> some View {
        var updated = theme
        transform(&updated)
        return content.environment(\.poTheme, updated)
    }
}

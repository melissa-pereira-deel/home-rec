import SwiftUI

/// Every token layer, in one injectable value.
///
/// Components never reference `GlassColors.standard` directly — they read
/// `@Environment(\.glassTheme)`. That indirection is the difference between a
/// design system and a namespace of constants: a host app can hand the kit a
/// different accent, a different type family, or a tighter spacing scale, and
/// every component follows without an edit.
public struct GlassTheme {
    public var colors: GlassColors
    public var typography: GlassTypography
    public var metrics: GlassMetrics
    public var materials: GlassMaterials

    public init(
        colors: GlassColors = .standard,
        typography: GlassTypography = .standard,
        metrics: GlassMetrics = .standard,
        materials: GlassMaterials = .standard
    ) {
        self.colors = colors
        self.typography = typography
        self.metrics = metrics
        self.materials = materials
    }

    /// The shipped Glass theme.
    public static let standard = GlassTheme()

    /// The increased-contrast variant. Applied automatically by
    /// `glassThemeAdaptingToContrast()`; also available directly for hosts
    /// that want to force it.
    public static let highContrast = GlassTheme(colors: .highContrast)
}

// MARK: - Environment

private struct GlassThemeKey: EnvironmentKey {
    static let defaultValue = GlassTheme.standard
}

public extension EnvironmentValues {
    /// The active Glass theme. Defaults to `.standard`, so a component works
    /// with no setup at all — injection is for re-skinning, not for booting.
    var glassTheme: GlassTheme {
        get { self[GlassThemeKey.self] }
        set { self[GlassThemeKey.self] = newValue }
    }
}

public extension View {
    /// Injects a theme into this subtree.
    func glassTheme(_ theme: GlassTheme) -> some View {
        environment(\.glassTheme, theme)
    }

    /// Injects the standard theme, swapping to the increased-contrast palette
    /// when the system asks for it. Apply once at the root of a Glass surface.
    func glassThemeAdaptingToContrast() -> some View {
        modifier(GlassContrastAdaptingTheme())
    }
}

private struct GlassContrastAdaptingTheme: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.environment(\.glassTheme, contrast == .increased ? .highContrast : .standard)
    }
}

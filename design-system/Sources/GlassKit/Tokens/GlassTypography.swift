import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Roles

/// The closed type scale.
///
/// Fourteen roles, no free-form sizes. If a screen needs type that isn't
/// here, the answer is almost always an existing role — and if it genuinely
/// isn't, the role gets added here with a written reason, not inlined at the
/// call site.
///
/// Three registers run through the scale, and mixing them is the single most
/// load-bearing typographic decision in the system:
///
/// - **UI (Inter)** — anything a person reads as language: names, copy,
///   control labels. Lowercase in the control register.
/// - **Mono (SF Mono)** — anything a machine produced: timecodes, sample
///   rates, file sizes, dates, version numbers. Monospace is the signal for
///   "this is data", and it also keeps columns from dancing as values change.
/// - **Display (Archivo)** — the wordmark, and only the wordmark.
public enum GlassTextRole: String, CaseIterable, Hashable, Sendable {
    /// Archivo 26 medium, −0.02em. The brand wordmark on the onboarding card.
    case wordmark
    /// Archivo 13 medium, −0.02em. The panel's own header lockup ("Home Rec").
    case appTitle
    /// SF Mono 30 light. The hero timecode.
    case timer
    /// SF Mono 14 medium. The recording bar's wall-clock timer.
    case timerCompact
    /// Inter 14 medium. Expanded take title.
    case title
    /// Inter 13 regular. Take names, onboarding supporting copy.
    case body
    /// Inter 13 medium. Emphasised body — the permission ask.
    case bodyEmphasized
    /// Inter 14 semibold. Primary pill label.
    case control
    /// Inter 12 semibold. Compact pill labels.
    case controlCompact
    /// Inter 12 regular. Chips, secondary labels.
    case caption
    /// Inter 11 regular. Notice messages, hints, captions under actions.
    case captionSmall
    /// SF Mono 10 regular. Metadata lines, eyebrows, nav links, timestamps.
    case meta
    /// SF Mono 9 regular. Version rows, badges, the densest metadata.
    case metaSmall
    /// SF Mono 10 medium, **fixed size**. The floating timecode chip.
    case timecodeChip
}

// MARK: - Family

/// A font family slot. `name` is a real installed family; when it is missing
/// the system font in `design` takes over at the same size, so a host app
/// that hasn't registered Inter still gets a correctly *proportioned* kit —
/// just in SF.
public struct GlassFontFamily: Hashable, Sendable {
    public var name: String?
    public var design: Font.Design

    public init(name: String?, design: Font.Design = .default) {
        self.name = name
        self.design = design
    }

    public static let ui = GlassFontFamily(name: "Inter", design: .default)
    public static let display = GlassFontFamily(name: "Archivo", design: .default)
    /// No name: SF Mono is reached through `Font.Design.monospaced` rather
    /// than by PostScript name, which is the only supported way to get it.
    public static let mono = GlassFontFamily(name: nil, design: .monospaced)
}

// MARK: - Style

/// The resolved specification for one text role.
public struct GlassTextStyle: Hashable, Sendable {
    public var family: GlassFontFamily
    /// Size at the default Dynamic Type setting, in points.
    public var size: CGFloat
    public var weight: Font.Weight
    /// Letter spacing in points. Negative tightens.
    public var tracking: CGFloat
    /// Extra leading in points, on top of the font's natural line height.
    public var lineSpacing: CGFloat
    /// Upper bound on Dynamic Type growth. `1.0` means the role never scales.
    ///
    /// Two roles are capped below the default: the hero timer (the panel is a
    /// fixed-size floating window and a 2× timer would push the transport
    /// control off it) and the timecode chip (its horizontal clamp is
    /// computed from a known glyph advance — see `GlassTimecodeChip`).
    public var maxScale: CGFloat

    public init(
        family: GlassFontFamily,
        size: CGFloat,
        weight: Font.Weight = .regular,
        tracking: CGFloat = 0,
        lineSpacing: CGFloat = 0,
        maxScale: CGFloat = 2.0
    ) {
        self.family = family
        self.size = size
        self.weight = weight
        self.tracking = tracking
        self.lineSpacing = lineSpacing
        self.maxScale = maxScale
    }
}

// MARK: - Typography

/// The type system. Holds the family slots (so a host can substitute its own
/// faces) and the closed role table.
public struct GlassTypography {
    public var uiFamily: GlassFontFamily
    public var displayFamily: GlassFontFamily
    public var monoFamily: GlassFontFamily

    public init(
        uiFamily: GlassFontFamily = .ui,
        displayFamily: GlassFontFamily = .display,
        monoFamily: GlassFontFamily = .mono
    ) {
        self.uiFamily = uiFamily
        self.displayFamily = displayFamily
        self.monoFamily = monoFamily
    }

    public static let standard = GlassTypography()

    /// The role table.
    public func style(_ role: GlassTextRole) -> GlassTextStyle {
        switch role {
        // Both wordmark roles are the homerec.app lockup, to the letter:
        // Archivo at weight 500 with −0.02em tracking. The site is the brand's
        // published form, so the app matches the site rather than the other
        // way round — and the two stop drifting the moment either is edited.
        // −0.02em is a *ratio*, so it resolves per size: −0.52 at 26, −0.26
        // at 13.
        case .wordmark:
            GlassTextStyle(family: displayFamily, size: 26, weight: .medium, tracking: -0.52)
        case .appTitle:
            GlassTextStyle(family: displayFamily, size: 13, weight: .medium, tracking: -0.26)
        case .timer:
            // Light weight at 30pt: the number is already enormous: weight on
            // top of size would make the panel shout its own chrome.
            GlassTextStyle(family: monoFamily, size: 30, weight: .light, maxScale: 1.4)
        case .timerCompact:
            GlassTextStyle(family: monoFamily, size: 14, weight: .medium)
        case .title:
            GlassTextStyle(family: uiFamily, size: 14, weight: .medium)
        case .body:
            GlassTextStyle(family: uiFamily, size: 13, weight: .regular)
        case .bodyEmphasized:
            GlassTextStyle(family: uiFamily, size: 13, weight: .medium)
        case .control:
            // +0.1 tracking: lowercase semibold Inter in a solid capsule
            // closes up at 14pt; a hair of air keeps "record" from blotting.
            GlassTextStyle(family: uiFamily, size: 14, weight: .semibold, tracking: 0.1)
        case .controlCompact:
            GlassTextStyle(family: uiFamily, size: 12, weight: .semibold, tracking: 0.1)
        case .caption:
            GlassTextStyle(family: uiFamily, size: 12, weight: .regular)
        case .captionSmall:
            // +2 leading: notice copy is the one place in the kit that wraps
            // to three lines, and 11pt at default leading sets too tight.
            GlassTextStyle(family: uiFamily, size: 11, weight: .regular, lineSpacing: 2)
        case .meta:
            GlassTextStyle(family: monoFamily, size: 10, weight: .regular)
        case .metaSmall:
            GlassTextStyle(family: monoFamily, size: 9, weight: .regular)
        case .timecodeChip:
            GlassTextStyle(family: monoFamily, size: 10, weight: .medium, maxScale: 1.0)
        }
    }

    /// Point size for a role at a given Dynamic Type setting.
    ///
    /// macOS has no per-app text-size slider, but `dynamicTypeSize` is a real
    /// environment value that hosts (and previews, and the gallery) can set,
    /// and honouring it costs nothing. Scaling is applied to *all* families
    /// including monospace, because a fixed 9pt metadata line is the kind of
    /// thing that quietly excludes people.
    public func size(_ role: GlassTextRole, for dynamicTypeSize: DynamicTypeSize = .large) -> CGFloat {
        let style = style(role)
        let scale = min(dynamicTypeSize.glassScale, style.maxScale)
        return (style.size * scale).rounded()
    }

    /// Whether the UI family resolved to its real face rather than the system
    /// fallback. Optical adjustments that compensate for a specific face's
    /// metrics (see the pill's 1pt label offset) must key off this — applying
    /// an Inter correction to SF pushes the label *off* centre.
    public var usesCustomUIFamily: Bool {
        guard let name = uiFamily.name else { return false }
        return GlassFontRegistry.isAvailable(name)
    }

    /// The resolved `Font` for an arbitrary style. Used by the brand lockup,
    /// which sets the wordmark at the site's 15pt — a brand measurement rather
    /// than a UI role, so it does not belong in the closed role table.
    public func font(_ style: GlassTextStyle) -> Font {
        if let name = style.family.name, GlassFontRegistry.isAvailable(name) {
            return .custom(name, fixedSize: style.size).weight(style.weight)
        }
        return .system(size: style.size, weight: style.weight, design: style.family.design)
    }

    /// The resolved `Font` for a role.
    public func font(_ role: GlassTextRole, for dynamicTypeSize: DynamicTypeSize = .large) -> Font {
        let style = style(role)
        let size = size(role, for: dynamicTypeSize)
        if let name = style.family.name, GlassFontRegistry.isAvailable(name) {
            return .custom(name, fixedSize: size).weight(style.weight)
        }
        return .system(size: size, weight: style.weight, design: style.family.design)
    }
}

// MARK: - Dynamic Type scale

public extension DynamicTypeSize {
    /// Multiplier applied to the token size. Mirrors the shape of Apple's own
    /// body-text ramp, flattened at the top: the accessibility sizes grow the
    /// kit enough to be usable without turning a 450pt panel into a scroll.
    var glassScale: CGFloat {
        switch self {
        case .xSmall: 0.88
        case .small: 0.92
        case .medium: 0.96
        case .large: 1.00
        case .xLarge: 1.08
        case .xxLarge: 1.16
        case .xxxLarge: 1.24
        case .accessibility1: 1.40
        case .accessibility2: 1.55
        case .accessibility3: 1.70
        case .accessibility4: 1.85
        case .accessibility5: 2.00
        @unknown default: 1.00
        }
    }
}

// MARK: - Font availability

/// Caches which optional families are actually installed, so the fallback
/// decision costs one dictionary read rather than a font lookup per `Text`.
enum GlassFontRegistry {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: Bool] = [:]

    static func isAvailable(_ name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let known = cache[name] { return known }
        #if canImport(AppKit)
        let available = NSFont(name: name, size: 12) != nil
        #else
        let available = false
        #endif
        cache[name] = available
        return available
    }
}

// MARK: - Applying a role

/// Applies a text role — font, tracking, leading — and optionally a colour
/// role. Reads the theme and Dynamic Type setting from the environment so a
/// re-skin or a text-size change propagates without touching call sites.
public struct GlassTextRoleModifier: ViewModifier {
    @Environment(\.glassTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let role: GlassTextRole
    let colorRole: GlassColorRole?

    public func body(content: Content) -> some View {
        let style = theme.typography.style(role)
        let typed = content
            .font(theme.typography.font(role, for: dynamicTypeSize))
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
        // Leaving `foregroundStyle` untouched when no colour role is given is
        // load-bearing: an inner style silently wins over an outer one, so a
        // parent tint (a notice, a selected row) must be able to reach the
        // text through this modifier.
        if let colorRole {
            return AnyView(typed.foregroundStyle(theme.colors[colorRole]))
        }
        return AnyView(typed)
    }
}

public extension View {
    /// Applies a type role, and a colour role when one is given.
    ///
    /// Passing `color: nil` leaves the foreground style alone, which is what
    /// you want when the colour is already set by a parent (a notice tint, a
    /// selected row) or when the text is inside an accent fill.
    func glassText(_ role: GlassTextRole, color: GlassColorRole? = nil) -> some View {
        modifier(GlassTextRoleModifier(role: role, colorRole: color))
    }
}

#Preview("Type scale") {
    GlassPreviewStage {
        VStack(alignment: .leading, spacing: GlassSpacing.md) {
            ForEach(GlassTextRole.allCases, id: \.self) { role in
                HStack(alignment: .firstTextBaseline, spacing: GlassSpacing.md) {
                    Text(role.rawValue)
                        .glassText(.metaSmall, color: .textTertiary)
                        .frame(width: 110, alignment: .leading)
                    Text("home rec · 0:08.7")
                        .glassText(role, color: .textPrimary)
                }
            }
        }
    }
}

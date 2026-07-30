import SwiftUI

// MARK: - Roles

/// The closed set of colour roles in the system.
///
/// Roles are named for the *job* the colour does, never for the colour it is.
/// `accent` may be re-skinned to teal without a single rename; `red` could
/// not. Anything that needs a colour asks for a role — components never see
/// a hex value.
public enum GlassColorRole: String, CaseIterable, Hashable, Sendable {
    // Ground — what the glass has something to blur.
    case ground
    case groundRaised

    // Surfaces — the things that sit on the ground.
    case surfacePanel
    case surfaceCard
    case surfaceInset
    case surfaceScrim

    // Lines — hairlines, borders, the edge-light on glass.
    case line
    case lineStrong

    // Text.
    case textPrimary
    case textSecondary
    case textTertiary
    case textOnAccent
    case textAccent

    // Accent — brand red, spent only on the record state.
    case accent
    case accentStrong
    case accentMuted

    // Status.
    case statusDanger
    case statusWarning
    case statusSuccess
    case statusNeutral

    // Control fills — emphasis carried by luminance, not by an outline.
    case controlPrimaryNeutral
    case controlSecondary
    case textOnNeutralControl
}

// MARK: - Palette

/// The resolved colour values for one theme.
///
/// GlassKit is a dark-only system by intent: it is a recording panel that
/// floats over whatever the user is actually looking at, and a light variant
/// would put a bright rectangle in front of that. `standard` is therefore the
/// only shipped palette; `highContrast` is a *variant of it*, not a second
/// theme, and is applied automatically when the user asks for increased
/// contrast (see `GlassPillButtonStyle`).
public struct GlassColors {

    // Ground
    public var ground: Color
    public var groundRaised: Color

    // Surfaces
    /// Tint painted *under* the panel material so the glass has a body and
    /// the content behind it can't ghost through as bright bands.
    public var surfacePanel: Color
    public var surfaceCard: Color
    public var surfaceInset: Color
    public var surfaceScrim: Color

    // Lines
    public var line: Color
    public var lineStrong: Color

    // Text
    public var textPrimary: Color
    public var textSecondary: Color
    public var textTertiary: Color
    public var textOnAccent: Color
    /// Accent-coloured *text*. Deliberately lighter than `accent`: the brand
    /// red only reaches 4.4:1 on the card surface, which fails AA for body
    /// copy. This tint reaches 6.1:1 and is what accent-coloured words must
    /// use. `accent` itself is a fill, an indicator, a stroke — not a word.
    public var textAccent: Color

    // Accent
    public var accent: Color
    /// Deeper accent used for pressed fills and for the increased-contrast
    /// variant, where white-on-accent needs to clear 4.5:1 (it reaches 5.7:1).
    public var accentStrong: Color
    /// Accent at rest inside a disabled control.
    public var accentMuted: Color

    // Status
    public var statusDanger: Color
    public var statusWarning: Color
    public var statusSuccess: Color
    public var statusNeutral: Color

    // Control fills
    //
    // Emphasis in this kit is *luminance*, never an outline. A resting control
    // is a filled shape; the only stroke a button ever draws is its focus
    // ring, which is a different thing with a different job (WCAG 2.4.11).
    // Three fills, in descending weight:

    /// Near-white. The default action of a group where the accent is spent or
    /// reserved — a notice's recovery action, for instance. Not pure white:
    /// #FFF against this ground haloes at mini sizes.
    public var controlPrimaryNeutral: Color
    /// Light grey, one clear luminance step below the primary. The companion
    /// action. Its job is to be obviously pressable and obviously *not* the
    /// one being recommended, and it does that by being dimmer — which
    /// survives greyscale, low vision and a bad monitor, where a 1px outline
    /// does not.
    public var controlSecondary: Color
    /// Ink for both light fills above.
    public var textOnNeutralControl: Color

    public init(
        ground: Color,
        groundRaised: Color,
        surfacePanel: Color,
        surfaceCard: Color,
        surfaceInset: Color,
        surfaceScrim: Color,
        line: Color,
        lineStrong: Color,
        textPrimary: Color,
        textSecondary: Color,
        textTertiary: Color,
        textOnAccent: Color,
        textAccent: Color,
        accent: Color,
        accentStrong: Color,
        accentMuted: Color,
        statusDanger: Color,
        statusWarning: Color,
        statusSuccess: Color,
        statusNeutral: Color,
        controlPrimaryNeutral: Color = Color(glassHex: 0xF2F2F5),
        controlSecondary: Color = Color(glassHex: 0xC2C2CA),
        textOnNeutralControl: Color = Color(glassHex: 0x0D0D0F)
    ) {
        self.ground = ground
        self.groundRaised = groundRaised
        self.surfacePanel = surfacePanel
        self.surfaceCard = surfaceCard
        self.surfaceInset = surfaceInset
        self.surfaceScrim = surfaceScrim
        self.line = line
        self.lineStrong = lineStrong
        self.textPrimary = textPrimary
        self.textSecondary = textSecondary
        self.textTertiary = textTertiary
        self.textOnAccent = textOnAccent
        self.textAccent = textAccent
        self.accent = accent
        self.accentStrong = accentStrong
        self.accentMuted = accentMuted
        self.statusDanger = statusDanger
        self.statusWarning = statusWarning
        self.statusSuccess = statusSuccess
        self.statusNeutral = statusNeutral
        self.controlPrimaryNeutral = controlPrimaryNeutral
        self.controlSecondary = controlSecondary
        self.textOnNeutralControl = textOnNeutralControl
    }

    /// Role lookup. Lets generic code (the gallery, a token inspector) walk
    /// the palette without a switch at every call site.
    public subscript(role: GlassColorRole) -> Color {
        switch role {
        case .ground: ground
        case .groundRaised: groundRaised
        case .surfacePanel: surfacePanel
        case .surfaceCard: surfaceCard
        case .surfaceInset: surfaceInset
        case .surfaceScrim: surfaceScrim
        case .line: line
        case .lineStrong: lineStrong
        case .textPrimary: textPrimary
        case .textSecondary: textSecondary
        case .textTertiary: textTertiary
        case .textOnAccent: textOnAccent
        case .textAccent: textAccent
        case .accent: accent
        case .accentStrong: accentStrong
        case .accentMuted: accentMuted
        case .statusDanger: statusDanger
        case .statusWarning: statusWarning
        case .statusSuccess: statusSuccess
        case .statusNeutral: statusNeutral
        case .controlPrimaryNeutral: controlPrimaryNeutral
        case .controlSecondary: controlSecondary
        case .textOnNeutralControl: textOnNeutralControl
        }
    }
}

// MARK: - Standard palette

public extension GlassColors {

    /// The shipped Glass palette.
    ///
    /// Values carried over from the concept prototype, with two additions the
    /// prototype didn't need but a real system does: `textAccent` (accessible
    /// accent type) and `accentStrong` (pressed + increased-contrast fills).
    static let standard = GlassColors(
        // #0D1119 — the darkest node of the backdrop mesh, used as the flat
        // fallback wherever the mesh itself isn't drawn.
        ground: Color(glassHex: 0x0D1119),
        groundRaised: Color(glassHex: 0x21243F),

        // #1A1C22 at 55%: a body for the glass. Under `.ultraThinMaterial`
        // this reads ≈ #26282E, which is the surface every contrast ratio in
        // the docs is measured against.
        surfacePanel: Color(glassHex: 0x1A1C22).opacity(0.55),
        // #1C1C1E — warm charcoal. The prototype paints it at 85% so a hint
        // of the mesh survives underneath; that opacity is applied by the
        // surface style, not baked into the token, so the same card colour
        // works on an opaque host.
        surfaceCard: Color(glassHex: 0x1C1C1E),
        // The one inset container (onboarding's permission row): white at 6%
        // rather than a darker card, because it must read as *carved into*
        // the panel rather than stacked on top of it.
        surfaceInset: Color.white.opacity(0.06),
        surfaceScrim: Color.black.opacity(0.45),

        // Hairlines. `line` is the interior seam between cards; `lineStrong`
        // is the panel's edge-light, which needs to survive the material.
        line: Color.white.opacity(0.08),
        lineStrong: Color.white.opacity(0.18),

        textPrimary: Color.white.opacity(0.92),
        textSecondary: Color.white.opacity(0.65),
        // #8E8E93 — systemGray. The one text colour that is a hue rather than
        // an opacity, so monospace metadata stays legible over both the card
        // and the lighter panel (5.2:1 / 4.5:1).
        textTertiary: Color(glassHex: 0x8E8E93),
        textOnAccent: Color.white,
        textAccent: Color(glassHex: 0xFF6B6B),

        // #F23A3A — brand red pulled ~5% darker than the wordmark's #FF3E3E.
        // Large solid fills read hotter than thin strokes, so the flat pill
        // wants the deeper tone to sit at the same perceived intensity.
        accent: Color(glassHex: 0xF23A3A),
        accentStrong: Color(glassHex: 0xC72121),
        accentMuted: Color(glassHex: 0xF23A3A).opacity(0.45),

        statusDanger: Color(glassHex: 0xF23A3A),
        // #EBA82E — amber. Distinct from the error red at a glance *and* in
        // greyscale, which matters because "still recording" is a warning a
        // user must be able to tell apart from a failure without reading.
        statusWarning: Color(glassHex: 0xEBA82E),
        statusSuccess: Color(glassHex: 0x30D158),
        statusNeutral: Color.white.opacity(0.25)
    )

    /// Increased-contrast variant, applied when the system reports
    /// `colorSchemeContrast == .increased`. Only the values that fail WCAG AA
    /// in the standard palette move; the character of the system doesn't.
    static let highContrast: GlassColors = {
        var colors = GlassColors.standard
        colors.accent = colors.accentStrong          // white-on-fill 3.9:1 → 5.7:1
        colors.textSecondary = Color.white.opacity(0.78)
        colors.textTertiary = Color(glassHex: 0xAEAEB2)
        colors.line = Color.white.opacity(0.16)
        colors.lineStrong = Color.white.opacity(0.30)
        return colors
    }()
}

// MARK: - Hex

public extension Color {
    /// Hex initialiser for token definitions. Deliberately takes an integer
    /// literal rather than a string: a typo in `0xF23A3` is a compile-time
    /// length you can see, not a silent runtime black.
    init(glassHex hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Documentation table

/// Design-time metadata for one colour role: what it is, where it came from,
/// and how it performs. Consumed by the gallery so the specimen sheet and
/// `docs/glass.md` can never drift apart.
public struct GlassColorSpec: Identifiable, Sendable {
    public let role: GlassColorRole
    /// Literal value as authored, e.g. `#F23A3A` or `white 65%`.
    public let value: String
    /// One line: what this role is for.
    public let usage: String
    /// Measured contrast against the card surface (#1C1C1E), or `nil` for
    /// roles that are never used to carry text.
    public let contrastOnCard: Double?

    public var id: GlassColorRole { role }
}

public extension GlassColorSpec {
    /// The full reference table, in the order the docs present it.
    static let all: [GlassColorSpec] = [
        .init(role: .ground, value: "#0D1119", usage: "Window ground; darkest node of the backdrop mesh.", contrastOnCard: nil),
        .init(role: .groundRaised, value: "#21243F", usage: "Brightest mesh node; the blue the glass picks up.", contrastOnCard: nil),
        .init(role: .surfacePanel, value: "#1A1C22 · 55%", usage: "Tint under the panel material. Reads ≈#26282E through glass.", contrastOnCard: nil),
        .init(role: .surfaceCard, value: "#1C1C1E", usage: "Cards, rows, notices, neutral pills. The contrast baseline.", contrastOnCard: nil),
        .init(role: .surfaceInset, value: "white 6%", usage: "Carved-in containers (onboarding permission row).", contrastOnCard: nil),
        .init(role: .surfaceScrim, value: "black 45%", usage: "Scrim behind modal cards.", contrastOnCard: nil),
        .init(role: .line, value: "white 8%", usage: "Interior hairlines between cards and rows.", contrastOnCard: nil),
        .init(role: .lineStrong, value: "white 18%", usage: "Panel edge-light; must survive the material.", contrastOnCard: nil),
        .init(role: .textPrimary, value: "white 92%", usage: "Titles, take names, control labels.", contrastOnCard: 14.5),
        .init(role: .textSecondary, value: "white 65%", usage: "Supporting copy, notice messages.", contrastOnCard: 7.8),
        .init(role: .textTertiary, value: "#8E8E93", usage: "Monospace metadata, eyebrows, timestamps.", contrastOnCard: 5.2),
        .init(role: .textOnAccent, value: "#FFFFFF", usage: "Labels on accent fills.", contrastOnCard: nil),
        .init(role: .textAccent, value: "#FF6B6B", usage: "Accent-coloured words. Use instead of `accent` for type.", contrastOnCard: 6.1),
        .init(role: .accent, value: "#F23A3A", usage: "Record/stop fill, playhead, live waveform. Fills only.", contrastOnCard: 4.4),
        .init(role: .accentStrong, value: "#C72121", usage: "Pressed accent; accent fill under increased contrast.", contrastOnCard: nil),
        .init(role: .accentMuted, value: "#F23A3A · 45%", usage: "Accent fill inside a disabled control.", contrastOnCard: nil),
        .init(role: .statusDanger, value: "#F23A3A", usage: "Error notices. Same red as accent, by design.", contrastOnCard: 4.4),
        .init(role: .statusWarning, value: "#EBA82E", usage: "Long-recording warning. Separable in greyscale.", contrastOnCard: 8.3),
        .init(role: .statusSuccess, value: "#30D158", usage: "Permission granted / ready.", contrastOnCard: 8.4),
        .init(role: .statusNeutral, value: "white 25%", usage: "Secondary notice actions, terminal blocks.", contrastOnCard: nil),
    ]
}

#Preview("Colour roles") {
    GlassPreviewStage {
        VStack(alignment: .leading, spacing: GlassSpacing.s) {
            ForEach(GlassColorSpec.all) { spec in
                HStack(spacing: GlassSpacing.md) {
                    RoundedRectangle(cornerRadius: GlassRadius.control, style: .continuous)
                        .fill(GlassColors.standard[spec.role])
                        .frame(width: 44, height: 24)
                    Text(spec.role.rawValue).glassText(.caption, color: .textPrimary)
                    Spacer()
                    GlassMetaLabel(spec.value)
                    GlassMetaLabel(
                        spec.contrastOnCard.map { String(format: "%.1f:1", $0) } ?? "—",
                        role: .metaSmall
                    )
                    .frame(width: 48, alignment: .trailing)
                }
            }
        }
    }
}

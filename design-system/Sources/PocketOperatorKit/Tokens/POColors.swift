import SwiftUI

/// The colour system, expressed as roles rather than pigments.
///
/// The palette is deliberately tiny — a chassis black, one structural metal,
/// one saturated accent, one phosphor, one print grey. Hardware gets its
/// legibility from *material contrast* (dark body, bright cap, glowing
/// screen), not from hue variety, so every additional colour dilutes the
/// illusion. Adding a sixth family is almost always the wrong fix; reach for
/// a different elevation or a lamp instead.
public struct POColors: Sendable, Equatable {

    // MARK: - Chassis

    /// The device body. Near-black rather than black so the darker well and
    /// key plinth still have somewhere to go.
    public var chassis: Color
    /// Machined outer edge of the body — a single hairline that separates the
    /// device from whatever it sits on.
    public var chassisEdge: Color
    /// A raised region of the body carrying controls or data.
    public var panel: Color
    public var panelEdge: Color
    /// Milled-out recess a control sits in (key bed, display cavity).
    public var well: Color
    /// Light catch on the upper lip of a recess; the cue that reads "cut into".
    public var wellRim: Color
    public var wellShadow: Color

    // MARK: - Keys

    /// Top of the anodised-aluminium cap ramp. The ramp runs light-to-dark
    /// top-to-bottom because the implied light source is always directly
    /// above; every bevel and shadow in the kit assumes the same lamp.
    public var keyCapTop: Color
    public var keyCapBottom: Color
    /// Bevel highlight on the cap's machined top edge.
    public var keyBevel: Color
    /// Screen-printed legend on a light cap — ink, so it is dark, never white.
    public var keyLabel: Color
    /// The plinth the cap sinks toward; darker than the well so travel reads.
    public var keyPlinth: Color

    /// The armed key. Exactly one colour in the system is allowed to be
    /// saturated, and it belongs to the control with consequences.
    public var accentKeyTop: Color
    public var accentKeyBottom: Color
    public var accentKeyLabel: Color

    /// The accent key when its function is unavailable — a different *part*,
    /// not a faded one. Hardware signals "not fitted" with a duller material.
    public var mutedKeyTop: Color
    public var mutedKeyBottom: Color
    public var mutedKeyLabel: Color

    /// Unavailable neutral cap.
    public var disabledKeyTop: Color
    public var disabledKeyBottom: Color
    public var disabledKeyLabel: Color

    /// Blacked-out cap for secondary/modifier keys that should recede.
    public var darkKeyTop: Color
    public var darkKeyBottom: Color
    public var darkKeyLabel: Color

    // MARK: - Display

    /// Unlit LCD substrate. Tinted toward the phosphor hue so the screen reads
    /// as one material even with every segment off.
    public var displayBed: Color
    /// Lit segment / phosphor.
    public var displayOn: Color
    /// Bezel lip around the display cavity.
    public var displayRim: Color
    /// Sheen laid over the cover glass.
    public var displayGlass: Color
    /// Opacity of an *unlit* segment, drawn in the phosphor colour. Real LCDs
    /// show their dead segments faintly; without this ghost the display looks
    /// like text on a dark rectangle instead of a screen.
    public var displayOffOpacity: Double

    // MARK: - Print

    /// Screen-printed micro-label on the chassis.
    public var screenPrint: Color
    /// Screen print for a brand mark or primary legend.
    public var screenPrintEmphasis: Color
    /// A printed *value* (as opposed to its label) — brighter, so a spec block
    /// scans as label/value pairs at a glance.
    public var readout: Color
    /// Etched hairline: rules, dividers, spec-grid frames, fader detents.
    public var etch: Color

    // MARK: - Indicators

    public var lampOff: Color
    /// Something is happening now.
    public var lampActive: Color
    /// Ready, armed, nominal.
    public var lampArmed: Color
    /// Attention, clipping, fault.
    public var lampWarn: Color

    // MARK: - Meters

    /// Painted meter face — the one warm, light surface in the system, which
    /// is exactly why an analogue meter draws the eye.
    public var meterFace: Color
    /// Printed scale and needle ink.
    public var meterInk: Color
    public var meterRedZone: Color

    // MARK: - Focus

    /// Keyboard focus ring. Deliberately the accent hue: focus is a physical
    /// state in this language, so it borrows the armed colour.
    public var focusRing: Color

    public init(
        chassis: Color,
        chassisEdge: Color,
        panel: Color,
        panelEdge: Color,
        well: Color,
        wellRim: Color,
        wellShadow: Color,
        keyCapTop: Color,
        keyCapBottom: Color,
        keyBevel: Color,
        keyLabel: Color,
        keyPlinth: Color,
        accentKeyTop: Color,
        accentKeyBottom: Color,
        accentKeyLabel: Color,
        mutedKeyTop: Color,
        mutedKeyBottom: Color,
        mutedKeyLabel: Color,
        disabledKeyTop: Color,
        disabledKeyBottom: Color,
        disabledKeyLabel: Color,
        darkKeyTop: Color,
        darkKeyBottom: Color,
        darkKeyLabel: Color,
        displayBed: Color,
        displayOn: Color,
        displayRim: Color,
        displayGlass: Color,
        displayOffOpacity: Double,
        screenPrint: Color,
        screenPrintEmphasis: Color,
        readout: Color,
        etch: Color,
        lampOff: Color,
        lampActive: Color,
        lampArmed: Color,
        lampWarn: Color,
        meterFace: Color,
        meterInk: Color,
        meterRedZone: Color,
        focusRing: Color
    ) {
        self.chassis = chassis
        self.chassisEdge = chassisEdge
        self.panel = panel
        self.panelEdge = panelEdge
        self.well = well
        self.wellRim = wellRim
        self.wellShadow = wellShadow
        self.keyCapTop = keyCapTop
        self.keyCapBottom = keyCapBottom
        self.keyBevel = keyBevel
        self.keyLabel = keyLabel
        self.keyPlinth = keyPlinth
        self.accentKeyTop = accentKeyTop
        self.accentKeyBottom = accentKeyBottom
        self.accentKeyLabel = accentKeyLabel
        self.mutedKeyTop = mutedKeyTop
        self.mutedKeyBottom = mutedKeyBottom
        self.mutedKeyLabel = mutedKeyLabel
        self.disabledKeyTop = disabledKeyTop
        self.disabledKeyBottom = disabledKeyBottom
        self.disabledKeyLabel = disabledKeyLabel
        self.darkKeyTop = darkKeyTop
        self.darkKeyBottom = darkKeyBottom
        self.darkKeyLabel = darkKeyLabel
        self.displayBed = displayBed
        self.displayOn = displayOn
        self.displayRim = displayRim
        self.displayGlass = displayGlass
        self.displayOffOpacity = displayOffOpacity
        self.screenPrint = screenPrint
        self.screenPrintEmphasis = screenPrintEmphasis
        self.readout = readout
        self.etch = etch
        self.lampOff = lampOff
        self.lampActive = lampActive
        self.lampArmed = lampArmed
        self.lampWarn = lampWarn
        self.meterFace = meterFace
        self.meterInk = meterInk
        self.meterRedZone = meterRedZone
        self.focusRing = focusRing
    }
}

public extension POColors {

    /// Black chassis, aluminium caps, industrial orange accent, green phosphor.
    static let standard = POColors(
        chassis: .poHex(0x0A0A0A),
        chassisEdge: .poHex(0x242424),
        panel: .poHex(0x111214),
        panelEdge: .poHex(0x1C1D20),
        well: .poHex(0x161616),
        wellRim: .poHex(0x2A2A2A),
        wellShadow: .black.opacity(0.6),
        keyCapTop: .poHex(0xC8CCD0),
        keyCapBottom: .poHex(0x9BA0A6),
        keyBevel: .white.opacity(0.35),
        keyLabel: .black.opacity(0.65),
        keyPlinth: .poHex(0x0D0D0D),
        accentKeyTop: .poHex(0xFF6600),
        accentKeyBottom: .poHex(0xC24E00),
        accentKeyLabel: .black.opacity(0.8),
        mutedKeyTop: .poHex(0x5A4A3E),
        mutedKeyBottom: .poHex(0x483A30),
        mutedKeyLabel: .black.opacity(0.55),
        disabledKeyTop: .poHex(0x5A5D60),
        disabledKeyBottom: .poHex(0x4A4D50),
        disabledKeyLabel: .black.opacity(0.4),
        darkKeyTop: .poHex(0x2E3033),
        darkKeyBottom: .poHex(0x1F2124),
        darkKeyLabel: .poHex(0xB6BABE),
        displayBed: .poHex(0x141B12),
        displayOn: .poHex(0x9BE870),
        displayRim: .poHex(0x2A2A2A),
        displayGlass: .white.opacity(0.03),
        displayOffOpacity: 0.07,
        // Lifted from the darker grey the concept used, which measured 4.48:1
        // on the key bed — just under AA for 7-9pt print. This clears 4.5:1 on
        // every surface a legend can land on while staying visually recessive.
        screenPrint: .poHex(0x84898F),
        screenPrintEmphasis: .poHex(0xC7CACD),
        readout: .poHex(0xC7C7C7),
        etch: .poHex(0x3A3A3A),
        lampOff: .poHex(0x2A2A2A),
        lampActive: .poHex(0xFF6600),
        lampArmed: .poHex(0x9BE870),
        lampWarn: .poHex(0xD93B2B),
        meterFace: .poHex(0xEDE6D6),
        meterInk: .poHex(0x2B2B2B),
        meterRedZone: .poHex(0xD93B2B),
        focusRing: .poHex(0xFF6600)
    )

    /// Service-instrument re-skin: warm graphite body, amber phosphor, signal
    /// red accent. Exists to prove the roles carry the language, not the
    /// pigments — no component changes to adopt it.
    static let amberService = POColors(
        chassis: .poHex(0x111010),
        chassisEdge: .poHex(0x2B2827),
        panel: .poHex(0x181615),
        panelEdge: .poHex(0x232120),
        well: .poHex(0x1D1A18),
        wellRim: .poHex(0x332F2C),
        wellShadow: .black.opacity(0.65),
        keyCapTop: .poHex(0xD3CDC2),
        keyCapBottom: .poHex(0xA49E93),
        keyBevel: .white.opacity(0.32),
        keyLabel: .black.opacity(0.68),
        keyPlinth: .poHex(0x0F0D0C),
        accentKeyTop: .poHex(0xE23B2A),
        accentKeyBottom: .poHex(0xA82A1D),
        accentKeyLabel: .black.opacity(0.78),
        mutedKeyTop: .poHex(0x5A3A34),
        mutedKeyBottom: .poHex(0x472D28),
        mutedKeyLabel: .black.opacity(0.55),
        disabledKeyTop: .poHex(0x5E5A55),
        disabledKeyBottom: .poHex(0x4C4844),
        disabledKeyLabel: .black.opacity(0.4),
        darkKeyTop: .poHex(0x33302D),
        darkKeyBottom: .poHex(0x24211F),
        darkKeyLabel: .poHex(0xBDB8B1),
        displayBed: .poHex(0x1A1408),
        displayOn: .poHex(0xFFB020),
        displayRim: .poHex(0x332F2C),
        displayGlass: .white.opacity(0.035),
        displayOffOpacity: 0.08,
        screenPrint: .poHex(0x8F8981),
        screenPrintEmphasis: .poHex(0xD0CAC2),
        readout: .poHex(0xCFC9C1),
        etch: .poHex(0x413C38),
        lampOff: .poHex(0x332F2C),
        lampActive: .poHex(0xE23B2A),
        lampArmed: .poHex(0xFFB020),
        lampWarn: .poHex(0xFFD84D),
        meterFace: .poHex(0xF0E9DA),
        meterInk: .poHex(0x2B2724),
        meterRedZone: .poHex(0xC22B1C),
        focusRing: .poHex(0xFFB020)
    )
}

extension Color {
    /// Token-local hex constructor.
    ///
    /// Kept internal on purpose: literal colour values are allowed to exist in
    /// the token layer and nowhere else, so components physically cannot name
    /// a pigment.
    static func poHex(_ hex: UInt32, opacity: Double = 1) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

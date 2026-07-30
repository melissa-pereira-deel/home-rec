import SwiftUI

/// The specimen sheet: every token, primitive, component and state in one
/// scroll, followed by the language composed into a working device.
///
/// This is the kit's own test instrument. A change that looks right in
/// isolation and wrong here is wrong — the whole point of the language is that
/// the parts have to look like they came out of the same factory.
@available(macOS 15, *)
public struct PocketOperatorKitGallery: View {
    @Environment(\.poTheme) private var theme

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                header
                ColourSpecimen()
                TypeSpecimen()
                MetricSpecimen()
                TextureSpecimen()
                SurfaceSpecimen()
                PrintSpecimen()
                LampSpecimen()
                KeySpecimen()
                SegmentSpecimen()
                DisplaySpecimen()
                MeterSpecimen()
                ContinuousSpecimen()
                GridSpecimen()
                TransportSpecimen()
                SignalSpecimen()
                AssemblySpecimen()
            }
            .padding(30)
        }
        .background(Color.poHex(0x050505))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScreenPrintLabel("POCKETOPERATORKIT", scale: .brand, emphasis: .strong)
            ScreenPrintLabel(
                "SPECIMEN SHEET · LANGUAGE \(PocketOperatorKit.languageVersion)",
                scale: .micro,
                emphasis: .dim
            )
        }
    }
}

// MARK: - Sheet furniture

@available(macOS 15, *)
private struct SpecimenSection<Content: View>: View {
    let title: String
    let note: String?
    @ViewBuilder let content: Content

    init(_ title: String, note: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                ScreenPrintLabel(title, scale: .large, emphasis: .strong)
                if let note {
                    ScreenPrintLabel(note, scale: .micro, emphasis: .dim)
                }
            }
            HairlineEtch()
            content
        }
    }
}

@available(macOS 15, *)
private struct SpecimenRow<Content: View>: View {
    let caption: String
    @ViewBuilder let content: Content

    init(_ caption: String, @ViewBuilder content: () -> Content) {
        self.caption = caption
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ScreenPrintLabel(caption, scale: .micro, emphasis: .dim)
                .frame(width: 130, alignment: .leading)
            content
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Tokens

@available(macOS 15, *)
private struct ColourSpecimen: View {
    @Environment(\.poTheme) private var theme

    var body: some View {
        SpecimenSection(
            "COLOUR ROLES",
            note: "SEMANTIC ROLES ONLY — NO COMPONENT NAMES A PIGMENT"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                group("CHASSIS", swatches: [
                    ("chassis", theme.colors.chassis),
                    ("chassisEdge", theme.colors.chassisEdge),
                    ("panel", theme.colors.panel),
                    ("panelEdge", theme.colors.panelEdge),
                    ("well", theme.colors.well),
                    ("wellRim", theme.colors.wellRim),
                ])
                group("KEYS", swatches: [
                    ("keyCapTop", theme.colors.keyCapTop),
                    ("keyCapBottom", theme.colors.keyCapBottom),
                    ("keyLabel", theme.colors.keyLabel),
                    ("keyPlinth", theme.colors.keyPlinth),
                    ("accentKeyTop", theme.colors.accentKeyTop),
                    ("accentKeyBottom", theme.colors.accentKeyBottom),
                    ("mutedKeyTop", theme.colors.mutedKeyTop),
                    ("disabledKeyTop", theme.colors.disabledKeyTop),
                    ("darkKeyTop", theme.colors.darkKeyTop),
                ])
                group("DISPLAY", swatches: [
                    ("displayBed", theme.colors.displayBed),
                    ("displayOn", theme.colors.displayOn),
                    ("displayOff", theme.colors.displayOn.opacity(theme.colors.displayOffOpacity)),
                    ("displayRim", theme.colors.displayRim),
                ])
                group("PRINT", swatches: [
                    ("screenPrint", theme.colors.screenPrint),
                    ("screenPrintEmphasis", theme.colors.screenPrintEmphasis),
                    ("readout", theme.colors.readout),
                    ("etch", theme.colors.etch),
                ])
                group("INDICATORS AND METERS", swatches: [
                    ("lampOff", theme.colors.lampOff),
                    ("lampActive", theme.colors.lampActive),
                    ("lampArmed", theme.colors.lampArmed),
                    ("lampWarn", theme.colors.lampWarn),
                    ("meterFace", theme.colors.meterFace),
                    ("meterInk", theme.colors.meterInk),
                    ("meterRedZone", theme.colors.meterRedZone),
                    ("focusRing", theme.colors.focusRing),
                ])
            }
        }
    }

    private func group(_ title: String, swatches: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ScreenPrintLabel(title, scale: .micro)
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(96), spacing: 10), count: 6),
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(swatches, id: \.0) { name, color in
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(color)
                            .frame(height: 30)
                            .poEtchedFrame(corner: 2)
                        ScreenPrintLabel(name, scale: .micro, emphasis: .dim)
                    }
                }
            }
        }
    }
}

@available(macOS 15, *)
private struct TypeSpecimen: View {
    @Environment(\.poTheme) private var theme

    var body: some View {
        SpecimenSection(
            "TYPE SCALE",
            note: "MONOSPACED, SMALL, TRACKED OUT — SCREEN PRINT, NOT UI TEXT"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                SpecimenRow("BRAND 9/1.2") {
                    ScreenPrintLabel("POCKET OPERATOR", scale: .brand, emphasis: .strong)
                }
                SpecimenRow("LABEL LARGE 9/1.2") {
                    ScreenPrintLabel("SECTION LEGEND", scale: .large)
                }
                SpecimenRow("LABEL 8/1.2") {
                    ScreenPrintLabel("STANDARD LEGEND")
                }
                SpecimenRow("MICRO 7/1.2") {
                    ScreenPrintLabel("MICRO ANNOTATION", scale: .micro)
                }
                SpecimenRow("KEYCAP 10/0.5") {
                    Text("SRC")
                        .font(theme.typography.keyCap.font())
                        .tracking(theme.typography.keyCap.tracking)
                        .foregroundStyle(theme.colors.screenPrintEmphasis)
                }
                SpecimenRow("KEYCAP EMPH 11/0.6") {
                    Text("REC")
                        .font(theme.typography.keyCapEmphasis.font())
                        .tracking(theme.typography.keyCapEmphasis.tracking)
                        .foregroundStyle(theme.colors.screenPrintEmphasis)
                }
                SpecimenRow("READOUT 10/0.5") {
                    ScreenPrintValue("48K · 24 BIT")
                }
                SpecimenRow("READOUT LG 13/0.5") {
                    ScreenPrintValue("0:41", isLarge: true)
                }
                SpecimenRow("DATA TITLE 14") {
                    Text("human language content")
                        .font(theme.typography.dataTitle.font())
                        .foregroundStyle(theme.colors.screenPrintEmphasis)
                }
                SpecimenRow("DATA META 11") {
                    Text("secondary human language")
                        .font(theme.typography.dataMeta.font())
                        .foregroundStyle(theme.colors.screenPrint)
                }
                SpecimenRow("DYNAMIC TYPE CAP") {
                    ScreenPrintLabel(
                        "PRINT SCALES TO \(String(format: "%.1f", theme.typography.maxDynamicTypeScale))X THEN STOPS",
                        scale: .micro,
                        emphasis: .dim
                    )
                }
            }
        }
    }
}

@available(macOS 15, *)
private struct MetricSpecimen: View {
    @Environment(\.poTheme) private var theme

    var body: some View {
        SpecimenSection(
            "METRICS",
            note: "RADIUS DECREASES WITH DEPTH — SHELL, PANEL, RECESS, CUT GLASS"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                SpecimenRow("SPACING LADDER") {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(spacingSteps, id: \.0) { name, value in
                            VStack(spacing: 4) {
                                Rectangle()
                                    .fill(theme.colors.screenPrint.opacity(0.5))
                                    .frame(width: value, height: 18)
                                ScreenPrintLabel(name, scale: .micro, emphasis: .dim)
                            }
                        }
                    }
                }
                SpecimenRow("CORNER LADDER") {
                    HStack(spacing: 10) {
                        ForEach(cornerSteps, id: \.0) { name, radius in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                                    .strokeBorder(theme.colors.etch, lineWidth: 1)
                                    .frame(width: 46, height: 34)
                                ScreenPrintLabel(name, scale: .micro, emphasis: .dim)
                            }
                        }
                    }
                }
                SpecimenRow("KEY FOOTPRINTS") {
                    HStack(alignment: .bottom, spacing: 12) {
                        HardwareKey("CPT", size: .compact) {}
                        HardwareKey("REG") {}
                        HardwareKey("LRG", size: .large) {}
                    }
                }
                SpecimenRow("HIT TARGET") {
                    HStack(spacing: 18) {
                        HardwareKey("A", size: .custom(CGSize(width: 20, height: 18)), shape: .round) {}
                        ScreenPrintLabel(
                            "CAP 20×18 · HIT REGION PADDED TO \(Int(theme.metrics.minimumHitTarget))PT",
                            scale: .micro,
                            emphasis: .dim
                        )
                    }
                }
            }
        }
    }

    private var spacingSteps: [(String, CGFloat)] {
        let s = theme.metrics.spacing
        return [
            ("2", s.hair), ("4", s.tight), ("6", s.snug), ("8", s.base),
            ("10", s.cozy), ("12", s.key), ("14", s.panel),
            ("18", s.section), ("22", s.chassis),
        ]
    }

    private var cornerSteps: [(String, CGFloat)] {
        let m = theme.metrics
        return [
            ("SHELL", m.chassisCorner),
            ("PANEL", m.panelCorner),
            ("WELL", m.wellCorner),
            ("KEY", m.keyCorner),
            ("GLASS", m.displayCorner),
        ]
    }
}

@available(macOS 15, *)
private struct TextureSpecimen: View {
    @Environment(\.poTheme) private var theme

    var body: some View {
        SpecimenSection(
            "TEXTURE",
            note: "RASTERISED ONCE — NO OBSERVED STATE, SO IDLE COST IS ZERO"
        ) {
            HStack(spacing: 14) {
                sample("SPECKLE · BED") {
                    POTexture.speckle(
                        density: theme.texture.speckleDensity,
                        seed: theme.texture.speckleSeed,
                        light: theme.texture.speckleLight,
                        dark: theme.texture.speckleDark
                    )
                    .background(theme.colors.well)
                }
                sample("SPECKLE · SHELL") {
                    POTexture.speckle(
                        density: theme.texture.chassisSpeckleDensity,
                        seed: theme.texture.speckleSeed,
                        light: theme.texture.speckleLight,
                        dark: theme.texture.speckleDark
                    )
                    .background(theme.colors.chassis)
                }
                sample("DOT GRILLE") {
                    POTexture.dotGrille(
                        pitch: theme.texture.grillePitch,
                        dotSize: theme.texture.grilleDotSize,
                        dotColor: theme.colors.wellRim
                    )
                    .background(theme.colors.chassis)
                }
                sample("BRUSHED METAL") {
                    POTexture.brushedMetal(
                        base: theme.colors.keyCapBottom,
                        seed: theme.texture.brushedMetalSeed
                    )
                }
            }
        }
    }

    private func sample(_ caption: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            content()
                .frame(width: 130, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .poEtchedFrame(corner: 3)
            ScreenPrintLabel(caption, scale: .micro, emphasis: .dim)
        }
    }
}

// MARK: - Primitives

@available(macOS 15, *)
private struct SurfaceSpecimen: View {
    var body: some View {
        SpecimenSection(
            "SURFACES",
            note: "CHASSIS → PANEL → WELL → CONTROL"
        ) {
            HStack(alignment: .top, spacing: 16) {
                labelled("CHASSIS") {
                    ScreenPrintLabel("SHELL", scale: .micro, emphasis: .dim)
                        .frame(width: 118, height: 44)
                        .poChassis(padding: 10)
                }
                labelled("PANEL") {
                    ScreenPrintLabel("SUB-ASSEMBLY", scale: .micro, emphasis: .dim)
                        .frame(width: 118, height: 44)
                        .poPanel(padding: 10)
                }
                labelled("WELL · TEXTURED") {
                    ScreenPrintLabel("CONTROL BED", scale: .micro, emphasis: .dim)
                        .frame(width: 118, height: 44)
                        .poWell(padding: 10)
                }
                labelled("WELL · SMOOTH") {
                    ScreenPrintLabel("CAVITY", scale: .micro, emphasis: .dim)
                        .frame(width: 118, height: 44)
                        .poWell(padding: 10, hasTexture: false)
                }
                labelled("BEZEL ONLY") {
                    Color.poHex(0x141B12)
                        .frame(width: 138, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .poBezel(corner: 4)
                }
            }
        }
    }

    private func labelled(_ caption: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
            ScreenPrintLabel(caption, scale: .micro, emphasis: .dim)
        }
    }
}

@available(macOS 15, *)
private struct PrintSpecimen: View {
    var body: some View {
        SpecimenSection(
            "SCREEN PRINT AND ETCH",
            note: "ONE LINE, UPPERCASE, NEVER TRUNCATED WITH AN ELLIPSIS"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                SpecimenRow("EMPHASIS") {
                    HStack(spacing: 18) {
                        ScreenPrintLabel("STRONG", emphasis: .strong)
                        ScreenPrintLabel("NORMAL", emphasis: .normal)
                        ScreenPrintLabel("DIM", emphasis: .dim)
                        ScreenPrintValue("VALUE")
                    }
                }
                SpecimenRow("RULES") {
                    HStack(spacing: 14) {
                        HairlineEtch(.horizontal, length: 90)
                        HairlineEtch(.vertical, length: 20)
                        ScreenPrintLabel("FRAMED", scale: .micro)
                            .padding(8)
                            .poEtchedFrame(corner: 2)
                    }
                }
                SpecimenRow("PRINTED PAIRS") {
                    HStack(spacing: 20) {
                        PrintedPair("RATE", value: "48K", accessibilityLabel: "Sample rate")
                        PrintedPair("BIT", value: "24", accessibilityLabel: "Bit depth")
                        PrintedPair("SRC", value: "LINE", accessibilityLabel: "Source")
                    }
                }
            }
        }
    }
}

@available(macOS 15, *)
private struct LampSpecimen: View {
    var body: some View {
        SpecimenSection(
            "INDICATOR LAMPS",
            note: "THREE STATES, NO IN-BETWEEN · BLINK RENDERS STEADY UNDER REDUCE MOTION"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                SpecimenRow("MODES") {
                    HStack(spacing: 24) {
                        LampAnnunciator("OFF", mode: .off, accessibilityLabel: "Off lamp")
                        LampAnnunciator("ON", mode: .on, accessibilityLabel: "On lamp")
                        LampAnnunciator("BLINK", mode: .blinking, accessibilityLabel: "Blinking lamp")
                    }
                }
                SpecimenRow("ROLES") {
                    HStack(spacing: 24) {
                        LampAnnunciator("ACTIVE", mode: .on, role: .active, accessibilityLabel: "Active")
                        LampAnnunciator("ARMED", mode: .on, role: .armed, accessibilityLabel: "Armed")
                        LampAnnunciator("WARN", mode: .on, role: .warning, accessibilityLabel: "Warning")
                        LampAnnunciator(
                            "CUSTOM",
                            mode: .on,
                            role: .custom(.poHex(0x4DA6FF)),
                            accessibilityLabel: "Custom"
                        )
                    }
                }
                SpecimenRow("SIZES") {
                    HStack(alignment: .center, spacing: 18) {
                        IndicatorLamp(.on, diameter: 5, accessibilityLabel: "Small")
                        IndicatorLamp(.on, diameter: 8, accessibilityLabel: "Standard")
                        IndicatorLamp(.on, diameter: 14, accessibilityLabel: "Large")
                    }
                }
            }
        }
    }
}

@available(macOS 15, *)
private struct KeySpecimen: View {
    var body: some View {
        SpecimenSection(
            "HARDWARE KEY",
            note: "PRESS 50MS LINEAR · RELEASE SPRING 0.18/0.55 · TRAVEL 1.5PT"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                SpecimenRow("VARIANTS") {
                    HStack(spacing: 12) {
                        HardwareKey("NEUTRAL", accessibilityLabel: "Neutral key") {}
                        HardwareKey("ACCENT", variant: .accent, accessibilityLabel: "Accent key") {}
                        HardwareKey("DARK", variant: .dark, accessibilityLabel: "Dark key") {}
                    }
                }
                SpecimenRow("LATCHED") {
                    HStack(spacing: 12) {
                        HardwareKey("LOOP", isOn: true, accessibilityLabel: "Loop, on") {}
                        HardwareKey("MON", variant: .accent, isOn: true, accessibilityLabel: "Monitor, on") {}
                        HardwareKey("ALT", variant: .dark, isOn: true, accessibilityLabel: "Alt, on") {}
                    }
                }
                SpecimenRow("UNAVAILABLE") {
                    HStack(spacing: 12) {
                        HardwareKey("NEUTRAL", accessibilityLabel: "Neutral, unavailable") {}
                            .disabled(true)
                        HardwareKey("REC", variant: .accent, accessibilityLabel: "Record, unavailable") {}
                            .disabled(true)
                        HardwareKey("DARK", variant: .dark, accessibilityLabel: "Dark, unavailable") {}
                            .disabled(true)
                    }
                }
                SpecimenRow("SHAPES") {
                    HStack(spacing: 12) {
                        HardwareKey("LOZENGE") {}
                        HardwareKey("PILL", shape: .pill) {}
                        HardwareKey("A", size: .custom(CGSize(width: 44, height: 44)), shape: .round) {}
                    }
                }
                SpecimenRow("STYLE ADOPTION") {
                    HStack(spacing: 12) {
                        Button("PLAIN BUTTON") {}
                            .buttonStyle(HardwareKeyStyle(size: .large))
                        Button {} label: {
                            Image(systemName: "power")
                        }
                        .buttonStyle(
                            HardwareKeyStyle(
                                variant: .accent,
                                size: .custom(CGSize(width: 44, height: 44)),
                                shape: .round
                            )
                        )
                        .accessibilityLabel("Power")
                    }
                }
            }
        }
    }
}

// MARK: - Components

@available(macOS 15, *)
private struct SegmentSpecimen: View {
    var body: some View {
        SpecimenSection(
            "SEGMENT DISPLAY",
            note: "GHOST SEGMENTS, FIXED CELL COUNT, DECLARED GLYPH REPERTOIRE"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                display("SEVEN SEG · DIGITS") {
                    SegmentLCD("0123456789", size: 26)
                }
                display("SEVEN SEG · LETTERS") {
                    SegmentLCD("ABCDEFGHIJLNOPRSTUY", size: 18)
                }
                display("CAPACITY · TRAILING") {
                    SegmentLCD("42", size: 26, capacity: 6, alignment: .trailing)
                }
                display("CAPACITY · LEADING") {
                    SegmentLCD("42", size: 26, capacity: 6, alignment: .leading)
                }
                display("NO GHOST") {
                    SegmentLCD("0:12.4", size: 26, capacity: 7, showsGhostSegments: false)
                }
                display("NO GLOW") {
                    SegmentLCD("0:12.4", size: 26, capacity: 7, hasGlow: false)
                }
                display("DOT MATRIX · A-Z") {
                    SegmentLCD("ABCDEFGHIJKLM", face: .dotMatrix, size: 14)
                }
                display("DOT MATRIX · MIXED") {
                    SegmentLCD("PATTERN A2 / 1-16", face: .dotMatrix, size: 12)
                }
                display("REPERTOIRE CHECK") {
                    ScreenPrintLabel(repertoireNote, scale: .micro, emphasis: .dim)
                }
            }
        }
    }

    private var repertoireNote: String {
        let unsupported = SegmentFace.sevenSegment.unsupportedCharacters(in: "WORKSHOP KIT")
        return unsupported.isEmpty
            ? "SEVEN SEGMENT COVERS THIS STRING"
            : "SEVEN SEGMENT APPROXIMATES \(String(unsupported)) — USE DOT MATRIX"
    }

    private func display(_ caption: String, @ViewBuilder content: () -> some View) -> some View {
        HStack(alignment: .center, spacing: 16) {
            ScreenPrintLabel(caption, scale: .micro, emphasis: .dim)
                .frame(width: 150, alignment: .leading)
            content()
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.poHex(0x141B12))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .poBezel(corner: 4)
            Spacer(minLength: 0)
        }
    }
}

@available(macOS 15, *)
private struct DisplaySpecimen: View {
    var body: some View {
        SpecimenSection(
            "LCD PANEL",
            note: "PUBLISHES ITS INK — INVERT FLIPS EVERYTHING INSIDE AT ONCE"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                LCDPanel(accessibilityLabel: "Transport display") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SegmentLCD(
                                "0:03.2",
                                size: 30,
                                capacity: 7,
                                alignment: .trailing,
                                accessibilityLabel: "Elapsed",
                                accessibilityValue: "3.2 seconds"
                            )
                            Spacer()
                            SegmentLCD("REC", size: 16, accessibilityValue: "Recording")
                                .poBlink(isActive: true)
                        }
                        HStack(spacing: 12) {
                            LCDLevelBar(level: 0.58, peak: 0.79)
                            BarWaveform(
                                samples: POSampleData.waveform(seed: 9, count: 90),
                                mode: .trailing
                            )
                            .frame(height: 22)
                        }
                    }
                }
                HStack(spacing: 12) {
                    LCDPanel(isInverted: true, height: 54) {
                        SegmentLCD("SAVED", size: 22, accessibilityValue: "Saved")
                    }
                    LCDPanel(height: 54) {
                        SegmentLCD("----", size: 22, capacity: 4, accessibilityValue: "No signal")
                    }
                }
                SpecimenRow("TYPED REVEAL") {
                    LCDPanel(height: 44) {
                        TypedText("PRESET RECALLED") { partial in
                            SegmentLCD(partial, face: .dotMatrix, size: 12)
                        }
                    }
                }
                SpecimenRow("LEVEL BAR") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach([0.0, 0.35, 0.7, 1.0], id: \.self) { level in
                            LCDLevelBar(level: level, peak: min(1, level + 0.1))
                        }
                    }
                    .padding(10)
                    .background(Color.poHex(0x141B12))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .poBezel(corner: 4)
                }
            }
        }
    }
}

@available(macOS 15, *)
private struct MeterSpecimen: View {
    var body: some View {
        SpecimenSection(
            "VU METER",
            note: "ATTACK 90MS · RELEASE 350MS — DRIVEN UP, SPRUNG DOWN"
        ) {
            HStack(alignment: .top, spacing: 16) {
                meter("VU BALLISTICS") {
                    VUMeter(
                        level: { POSampleData.level(at: Date.now.timeIntervalSince1970) },
                        ballistics: .vu,
                        accessibilityLabel: "Programme level"
                    )
                }
                meter("PEAK BALLISTICS") {
                    VUMeter(
                        level: { POSampleData.level(at: Date.now.timeIntervalSince1970) },
                        ballistics: .peak,
                        legend: "PPM",
                        accessibilityLabel: "Peak level"
                    )
                }
                meter("NO BALLISTICS") {
                    VUMeter(
                        level: { POSampleData.level(at: Date.now.timeIntervalSince1970) },
                        ballistics: .instant,
                        legend: "RAW",
                        accessibilityLabel: "Raw level"
                    )
                }
                meter("WIDE SCALE · STATIC") {
                    VUMeter(
                        level: { 0.72 },
                        scale: .wide,
                        legend: "DB",
                        accessibilityLabel: "Static level"
                    )
                }
            }
        }
    }

    private func meter(_ caption: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
                .frame(width: 150, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .poBezel(corner: 3)
            ScreenPrintLabel(caption, scale: .micro, emphasis: .dim)
        }
    }
}

@available(macOS 15, *)
private struct ContinuousSpecimen: View {
    @State private var gain = 0.7
    @State private var mix = 0.4
    @State private var position = 0.42
    @State private var coarse = 0.5

    var body: some View {
        SpecimenSection(
            "CONTINUOUS CONTROLS",
            note: "CUT SLOT, NOT A FILLED TRACK · ARROW KEYS STEP ONE DETENT"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 34) {
                    Fader(value: $gain, length: 130, label: "GAIN", accessibilityValue: gainLabel)
                    LabelledControl("RANGE", accessibilityLabel: "Range") {
                        Fader(value: $coarse, detents: 4, length: 130, label: "")
                    }
                    Fader(value: .constant(0.5), length: 130, label: "AUX")
                        .disabled(true)
                    VStack(alignment: .leading, spacing: 18) {
                        Fader(value: $mix, orientation: .horizontal, length: 220, label: "MIX")
                        VStack(alignment: .leading, spacing: 6) {
                            ScreenPrintLabel("POSITION", isDecorative: true)
                            TickRuler(value: $position, label: "Position")
                                .frame(width: 220)
                        }
                    }
                }
                SpecimenRow("WAVEFORMS") {
                    VStack(alignment: .leading, spacing: 10) {
                        BarWaveform(
                            samples: POSampleData.waveform(seed: 23),
                            progress: position,
                            tint: .poHex(0xFF6600)
                        )
                        .frame(width: 340, height: 56)
                        BarWaveform(samples: POSampleData.waveform(seed: 41))
                            .frame(width: 340, height: 30)
                        BarWaveform(
                            samples: POSampleData.waveform(seed: 5, count: 60),
                            mode: .trailing
                        )
                        .frame(width: 340, height: 22)
                    }
                }
            }
        }
    }

    private func gainLabel(_ value: Double) -> String {
        String(format: "%.1f decibels", (value - 1) * 40)
    }
}

@available(macOS 15, *)
private struct GridSpecimen: View {
    @State private var latched: Set<Int> = [1, 4]

    var body: some View {
        SpecimenSection(
            "KEY GRID AND SPEC GRID",
            note: "UNIFORM PITCH IN ONE BED · SPEC BLOCK STATES FACTS, NOT STATUS"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 20) {
                    KeyGrid(
                        (0..<8).map { index in
                            KeyGridItem(
                                id: "pad-\(index)",
                                legend: String(format: "%02d", index + 1),
                                accessibilityLabel: "Pad \(index + 1)",
                                isOn: latched.contains(index),
                                action: { toggle(index) }
                            )
                        },
                        columns: 4,
                        keySize: .compact,
                        caption: "LATCHING PADS"
                    )
                    KeyGrid(
                        [
                            KeyGridItem(legend: "SRC", accessibilityLabel: "Source", action: {}),
                            KeyGridItem(legend: "FMT", accessibilityLabel: "Format", action: {}),
                            KeyGridItem.blank(id: "blank"),
                            KeyGridItem(
                                legend: "REC",
                                accessibilityLabel: "Record",
                                variant: .accent,
                                action: {}
                            ),
                            KeyGridItem(
                                legend: "LIB",
                                accessibilityLabel: "Library",
                                isEnabled: false,
                                action: {}
                            ),
                        ],
                        columns: 3,
                        keySize: .compact,
                        caption: "FUNCTION BLOCK · BLANK AND UNAVAILABLE"
                    )
                }
                SpecGrid([
                    SpecCell(label: "MODE", value: "SEQ", accessibilityLabel: "Mode"),
                    SpecCell(label: "BPM", value: "128", accessibilityLabel: "Tempo"),
                    SpecCell(label: "STEP", value: "16", accessibilityLabel: "Step count"),
                    SpecCell(label: "SWING", value: "54", accessibilityLabel: "Swing"),
                    SpecCell(label: "BANK", value: "A2", accessibilityLabel: "Bank"),
                ])
                .frame(width: 440)
            }
        }
    }

    private func toggle(_ index: Int) {
        if latched.contains(index) { latched.remove(index) } else { latched.insert(index) }
    }
}

@available(macOS 15, *)
private struct TransportSpecimen: View {
    var body: some View {
        SpecimenSection(
            "TRANSPORT",
            note: "EVERY PHASE CARRIED BY LEGEND, LAMP, AND CAP MATERIAL TOGETHER"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(TransportPhase.allCases, id: \.self) { phase in
                    HStack(spacing: 16) {
                        ScreenPrintLabel(
                            String(describing: phase).uppercased(),
                            scale: .micro,
                            emphasis: .dim
                        )
                        .frame(width: 100, alignment: .leading)
                        TransportKeys(
                            phase: phase,
                            keySize: .compact,
                            onRecord: {},
                            onStop: {},
                            onPlay: {}
                        )
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

@available(macOS 15, *)
private struct SignalSpecimen: View {
    var body: some View {
        SpecimenSection(
            "STATE SIGNALS",
            note: "THE WORD IS FOR THE DISPLAY · THE SENTENCE IS FOR THE SCREEN READER"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(TransportPhase.allCases, id: \.self) { phase in
                    let signal = POStateSignal.standard(for: phase)
                    HStack(spacing: 16) {
                        IndicatorLamp(signal.lampMode, role: signal.lampRole)
                        SegmentLCD(signal.word, size: 13, accessibilityValue: signal.spoken)
                            .frame(width: 60, alignment: .leading)
                        ScreenPrintLabel(signal.spoken, scale: .micro, emphasis: .dim)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(12)
            .background(Color.poHex(0x0A0A0A))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .poEtchedFrame(corner: 4)
        }
    }
}

@available(macOS 15, *)
private struct AssemblySpecimen: View {
    var body: some View {
        SpecimenSection(
            "ASSEMBLED DEVICE",
            note: "THE SAME COMPONENTS, COMPOSED · SECOND FACE IS A THEME SWAP ONLY"
        ) {
            HStack(alignment: .top, spacing: 24) {
                DeviceFaceSpecimen()
                DeviceFaceSpecimen()
                    .pocketOperatorTheme(.amberService)
            }
        }
    }
}

@available(macOS 15, *)
#Preview("Gallery") {
    PocketOperatorKitGallery()
        .frame(width: 1180, height: 900)
}

@available(macOS 15, *)
#Preview("Gallery — amber") {
    PocketOperatorKitGallery()
        .pocketOperatorTheme(.amberService)
        .frame(width: 1180, height: 900)
}

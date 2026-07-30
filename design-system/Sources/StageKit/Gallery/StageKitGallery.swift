import SwiftUI

/// Every token, primitive and component in every state, plus a working stage.
///
/// The gallery is the kit's own test harness: if a state cannot be reached
/// here, it is not a supported state. Keep it exhaustive — a design system's
/// gallery is the only place where "what does disabled-and-focused look like"
/// has a cheap answer.
@available(macOS 15.0, *)
public struct StageKitGallery: View {
    @State private var themeName: String = "DARK"
    @State private var demoState = StageDemoState()
    @State private var tabSelection: String = "b"
    @State private var segmentedValue: String = "COZY"

    public init() {}

    private var theme: StageTheme {
        switch themeName {
        case "LIGHT": .light
        case "PRESENT": .presentation
        default: .dark
        }
    }

    /// API identifiers keep their casing — `controlFillActive` uppercased is
    /// an unreadable run of letters, and the gallery is documentation.
    private var codeStyle: StageTextStyle {
        StageTextStyle(size: theme.typography.hint.size, tracking: 0.2, isUppercased: false)
    }

    private var headingStyle: StageTextStyle {
        StageTextStyle(size: theme.typography.caption.size + 2, weight: .semibold,
                       tracking: 0.4, isUppercased: false)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                header
                colorSection
                typographySection
                metricsSection
                labelSection
                chipSection
                tabSection
                dividerSection
                keyHintSection
                segmentedSection
                tabBarSection
                scrubberSection
                frameSection
                stageSection
                scenarioSection
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.colors.stage)
        .stageTheme(theme)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            StageLabel("StageKit \(StageKit.version)", style: theme.typography.title, tone: .strong)
            StageLabel(
                "Prototype-showcase chrome. Neutral by construction.",
                style: theme.typography.hint,
                tone: .muted
            )
            StageSegmentedControl(
                selection: $themeName,
                segments: [.init("DARK", "DARK"), .init("LIGHT", "LIGHT"), .init("PRESENT", "PRESENT")],
                accessibilityLabel: "Stage theme"
            )
            .padding(.top, 4)
        }
    }

    // MARK: Tokens

    private var colorSection: some View {
        section("Colour roles", "Achromatic by policy. Focus is the one hue.") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(colorRows, id: \.0) { name, color in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: 56, height: 22)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(theme.colors.separator, lineWidth: 1)
                            )
                        StageLabel(name, style: codeStyle, tone: .primary)
                    }
                }
            }
        }
    }

    private var colorRows: [(String, Color)] {
        let c = theme.colors
        return [
            ("stage", c.stage), ("chrome", c.chrome), ("separator", c.separator),
            ("controlFill", c.controlFill), ("controlFillHover", c.controlFillHover),
            ("controlFillActive", c.controlFillActive), ("controlFillDisabled", c.controlFillDisabled),
            ("labelStrong", c.labelStrong), ("label", c.label), ("labelMuted", c.labelMuted),
            ("labelDisabled", c.labelDisabled), ("labelOnActive", c.labelOnActive),
            ("focus", c.focus),
        ]
    }

    private var typographySection: some View {
        section("Type scale", "Mono-led. Six roles, nothing bigger than 13pt.") {
            VStack(alignment: .leading, spacing: 8) {
                typeRow("title", theme.typography.title)
                typeRow("tab", theme.typography.tab)
                typeRow("chip", theme.typography.chip)
                typeRow("caption", theme.typography.caption)
                typeRow("key", theme.typography.key)
                typeRow("hint", theme.typography.hint)
            }
        }
    }

    private func typeRow(_ name: String, _ style: StageTextStyle) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            StageLabel(name, style: codeStyle, tone: .disabled)
                .frame(width: 60, alignment: .leading)
            StageLabel("The quick brown fox 0123", style: style, tone: .primary)
            Spacer(minLength: 0)
            StageLabel(
                "\(Int(style.size))pt · tracking \(String(format: "%.1f", style.tracking))",
                style: theme.typography.hint,
                tone: .disabled
            )
        }
    }

    private var metricsSection: some View {
        section("Metrics", "4pt grid. Hit targets exceed painted size.") {
            VStack(alignment: .leading, spacing: 10) {
                metricRow("controlHeight", theme.metrics.controlHeight)
                metricRow("minHitTarget", theme.metrics.minHitTarget)
                metricRow("chipSpacing", theme.metrics.chipSpacing)
                metricRow("tabSpacing", theme.metrics.tabSpacing)
                metricRow("groupSpacing", theme.metrics.groupSpacing)
                metricRow("barPaddingHorizontal", theme.metrics.barPaddingHorizontal)
                metricRow("controlRadius", theme.metrics.controlRadius)
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(theme.colors.focus.opacity(0.18))
                        .frame(width: 90, height: theme.metrics.minHitTarget)
                        .overlay {
                            Rectangle()
                                .fill(theme.colors.controlFill)
                                .frame(height: theme.metrics.controlHeight)
                        }
                    StageLabel(
                        "painted \(Int(theme.metrics.controlHeight))pt inside \(Int(theme.metrics.minHitTarget))pt target",
                        style: theme.typography.hint,
                        tone: .muted
                    )
                    .padding(.leading, 12)
                }
            }
        }
    }

    private func metricRow(_ name: String, _ value: CGFloat) -> some View {
        HStack(spacing: 12) {
            StageLabel(name, style: codeStyle, tone: .muted)
                .frame(width: 170, alignment: .leading)
            Rectangle()
                .fill(theme.colors.controlFill)
                .frame(width: value, height: 6)
            StageLabel("\(Int(value))", style: theme.typography.hint, tone: .disabled)
        }
    }

    // MARK: Primitives

    private var labelSection: some View {
        section("StageLabel", "Every string in the harness goes through here.") {
            HStack(spacing: 18) {
                ForEach(StageTone.allCases, id: \.self) { tone in
                    VStack(alignment: .leading, spacing: 4) {
                        StageLabel(toneName(tone), tone: tone)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(tone == .onActive ? theme.colors.controlFillActive : .clear)
                        StageLabel(toneName(tone), style: codeStyle, tone: .disabled)
                    }
                }
            }
        }
    }

    private func toneName(_ tone: StageTone) -> String {
        switch tone {
        case .strong: "strong"
        case .primary: "primary"
        case .muted: "muted"
        case .disabled: "disabled"
        case .onActive: "onActive"
        }
    }

    private var chipSection: some View {
        section("StageChip", "Idle · active · disabled · focused · cycling.") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: theme.metrics.chipSpacing) {
                    StageChip("IDLE") {}
                    StageChip("ACTIVE", state: .active) {}
                    StageChip("DISABLED", state: .disabled) {}
                }
                HStack(spacing: theme.metrics.chipSpacing) {
                    StageChip("FOCUSED", isKeyboardFocused: true) {}
                    StageChip("ACTIVE FOCUSED", state: .active, isKeyboardFocused: true) {}
                    StageChip("DISABLED FOCUSED", state: .disabled, isKeyboardFocused: true) {}
                }
                HStack(spacing: theme.metrics.chipSpacing) {
                    StageChip("FAULT", glyph: "▸") {}
                    StageChip("FAULT SENSOR", state: .active, glyph: "▸") {}
                    StageChip("FAULT", state: .disabled, glyph: "▸") {}
                }
            }
        }
    }

    private var tabSection: some View {
        section("StageTab", "Text only. Selection carried by weight, not by fill.") {
            HStack(spacing: theme.metrics.tabSpacing) {
                StageTab(index: 1, title: "Unselected", isSelected: false) {}
                StageTab(index: 2, title: "Selected", isSelected: true) {}
                StageTab(index: 3, title: "Focused", isSelected: false, isKeyboardFocused: true) {}
                StageTab(index: nil, title: "Unnumbered", isSelected: false) {}
            }
        }
    }

    private var dividerSection: some View {
        section("StageDivider", "Hairline. Structural, not decorative.") {
            VStack(alignment: .leading, spacing: 12) {
                StageDivider().frame(width: 320)
                StageDivider(inset: 60).frame(width: 320)
                HStack(spacing: 12) {
                    StageLabel("left", tone: .muted)
                    StageDivider(.vertical).frame(height: 16)
                    StageLabel("right", tone: .muted)
                }
            }
        }
    }

    private var keyHintSection: some View {
        section("StageKeyHint · StageKeyHintBar", "The quietest row on the stage.") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    StageKeyHint("⌘R", "record")
                    StageKeyHint("1–9", "concept")
                    StageKeyHint("⇥")
                }
                StageKeyHintBar([
                    .init("1–4", "concept"), .init("\\", "screen"),
                    .init("o", "offline"), .init("f", "fault"),
                ])
            }
        }
    }

    private var segmentedSection: some View {
        section("StageSegmentedControl", "For values that form a scale.") {
            HStack(spacing: 20) {
                StageSegmentedControl(
                    selection: $segmentedValue,
                    segments: [.init("TIGHT", "TIGHT"), .init("COZY", "COZY"), .init("AIRY", "AIRY")],
                    accessibilityLabel: "Density"
                )
                StageSegmentedControl(
                    selection: .constant("COZY"),
                    segments: [.init("TIGHT", "TIGHT"), .init("COZY", "COZY"), .init("AIRY", "AIRY")],
                    enabled: false,
                    accessibilityLabel: "Density, unavailable"
                )
            }
        }
    }

    // MARK: Components

    private var tabBarSection: some View {
        section("StageTabBar", "Numbered switching plus a trailing slot.") {
            StageTabBar(
                items: [
                    .init(id: "a", title: "Dial", number: 1),
                    .init(id: "b", title: "Slab", number: 2),
                    .init(id: "c", title: "Sheet", number: 3),
                ],
                selection: $tabSelection
            ) {
                StageChip("CONTROL", state: .active) {}
            }
            .frame(width: 520)
        }
    }

    private var scrubberSection: some View {
        section(
            "StageScrubber",
            "Generated from declared axes — toggle, cycle, chips, segmented, dependent."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                StageScrubber(
                    groups: StageDemo.axisGroups.filter { $0.id != "screen" },
                    state: $demoState,
                    hints: [.init("1–2", "concept"), .init("o", "offline"), .init("f", "fault")]
                )
                .frame(width: 620)

                StageLabel(
                    "state · \(Int(demoState.setpoint))° · \(demoState.mode.label)"
                        + " · \(demoState.isOffline ? "OFFLINE" : "ONLINE")"
                        + " · fault \(demoState.fault?.label ?? "NONE")"
                        + " · \(demoState.density.label)",
                    style: theme.typography.hint,
                    tone: .muted
                )
                StageLabel(
                    "PRESET greys out while OFFLINE is on — a dependent axis stays visible so the row never reflows.",
                    style: theme.typography.hint,
                    tone: .disabled
                )
            }
        }
    }

    private var frameSection: some View {
        section("StageFrame", "Tab bar · fixed content well · scrubber.") {
            StageFrame(stageSize: CGSize(width: 300, height: 120)) {
                StageTabBar(
                    items: [.init(id: "x", title: "Concept", number: 1)],
                    selection: .constant("x")
                )
            } content: {
                VStack(spacing: 6) {
                    StageLabel("content well", style: theme.typography.caption, tone: .muted)
                    StageLabel("300 × 120 — pinned for capture", style: theme.typography.hint, tone: .disabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } scrubber: {
                StageBar {
                    HStack(spacing: theme.metrics.chipSpacing) {
                        StageChip("ONE") {}
                        StageChip("TWO", state: .active) {}
                        Spacer(minLength: 0)
                        StageKeyHintBar([.init("1", "concept")])
                    }
                }
            }
            .fixedSize()
        }
    }

    private var stageSection: some View {
        section(
            "End-to-end stage",
            "Two toy concepts, six declared axes, no hand-written chrome."
        ) {
            StageKitDemoStage(stageSize: CGSize(width: 360, height: 400))
                .fixedSize()
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(theme.colors.separator, lineWidth: 1)
                )
        }
    }

    private var scenarioSection: some View {
        let scenarios = StageDemo.scenarios()
        return section(
            "Scenarios",
            "\(scenarios.count) generated from the same declaration — this is what a snapshot run writes."
        ) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(scenarios.prefix(14)) { scenario in
                    StageLabel("\(scenario.id).png", style: codeStyle, tone: .muted)
                }
                if scenarios.count > 14 {
                    StageLabel("+ \(scenarios.count - 14) more", style: theme.typography.hint, tone: .disabled)
                }
            }
        }
    }

    // MARK: Section chrome

    private func section<Content: View>(
        _ title: String,
        _ note: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                StageLabel(title, style: headingStyle, tone: .strong)
                StageLabel(note, style: theme.typography.hint, tone: .disabled)
            }
            StageDivider()
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(macOS 15.0, *)
#Preview("StageKit gallery") {
    StageKitGallery()
        .frame(width: 900, height: 1000)
}

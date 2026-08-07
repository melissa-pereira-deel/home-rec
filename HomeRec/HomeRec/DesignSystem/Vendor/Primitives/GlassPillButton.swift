import SwiftUI

// MARK: - Emphasis

/// What kind of action this is — never how it wants to look.
///
/// The kit has exactly three levels of button emphasis, and they are carried
/// by **fill luminance alone**. No resting control draws a border. That is a
/// deliberate constraint rather than a style preference:
///
/// - A 1px outline is the first thing lost to a dim monitor, a low-vision
///   user, greyscale, or a screenshot resized into a deck. Luminance survives
///   all four.
/// - Outline-vs-fill reads as *two different kinds of object*, not as two
///   ranks of the same object, so users hunt for the difference instead of
///   seeing it.
/// - It leaves the stroke free for the one job a stroke is genuinely better
///   at: the focus ring (WCAG 2.4.11), which must be distinguishable from
///   every resting state to mean anything.
///
/// The levels:
///
/// - **Primary** — the one action the screen is recommending. At most one per
///   view. `primary` spends the brand accent; `primaryNeutral` is the same
///   rank rendered in near-white, for groups where the accent is already spent
///   or would misread (a red pill inside an error notice makes a recoverable
///   problem look like a failure).
/// - **Secondary** — the real alternative. Light grey: obviously pressable,
///   obviously not the recommendation.
/// - **Tertiary** — dismissals and escapes. No resting fill at all; the plate
///   appears on hover. Present, not advertised.
///
/// `blocked` is not a fourth rank. It is the *primary* control rendered
/// unavailable-by-state — a record pill that cannot record. It takes a dark
/// neutral fill precisely so it cannot be mistaken for the pill that can.
public enum GlassButtonEmphasis: Equatable {
    case primary
    /// Primary in a status colour — a destructive or warning default action
    /// that must read as consequential without borrowing the record red.
    case primaryTinted(Color)
    case primaryNeutral
    case secondary
    case tertiary
    case blocked
}

extension GlassButtonEmphasis {
    /// Label + spinner ink for this emphasis. Lives here rather than in the
    /// style body because the loading spinner is composed alongside the label,
    /// and the two must never disagree about what colour the pill's ink is.
    func foreground(_ colors: GlassColors, isEnabled: Bool) -> Color {
        switch self {
        case .primary, .primaryTinted:
            // A disabled control is exempt from WCAG contrast (1.4.3), but it
            // still has to be readable enough to tell you *what* is disabled —
            // hence 75% rather than a token dim.
            colors.textOnAccent.opacity(isEnabled ? 1 : 0.75)
        case .primaryNeutral, .secondary:
            // Dark-on-light: 17:1 on the near-white, 13:1 on the light grey.
            colors.textOnNeutralControl.opacity(isEnabled ? 1 : 0.55)
        case .tertiary, .blocked:
            isEnabled ? colors.textPrimary : colors.textSecondary
        }
    }
}

// MARK: - Size

/// Pill sizes. Each is a height, a horizontal padding and a type role — never
/// a free-form combination, so two pills at the same size are always the same
/// pill.
public enum GlassPillSize: String, CaseIterable, Hashable, Sendable {
    /// 44pt — the primary transport control.
    case large
    /// 36pt — secondary card actions (open System Settings).
    case medium
    /// 32pt — in-row transport (play/pause).
    case small
    /// 30pt — recording-bar stop.
    case compact
    /// 26pt visual / 28pt hit — inline confirmations and notice actions.
    case mini

    func height(_ metrics: GlassMetrics) -> CGFloat {
        switch self {
        case .large: metrics.controlHeightLarge
        case .medium: metrics.controlHeightMedium
        case .small: metrics.controlHeightSmall
        case .compact: metrics.controlHeightCompact
        case .mini: metrics.controlHeightMini
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .large: GlassSpacing.xxxl - GlassSpacing.xxs   // 26
        case .medium: GlassSpacing.xxl - GlassSpacing.xxs   // 20
        case .small: GlassSpacing.xl - GlassSpacing.xxs     // 16
        case .compact: GlassSpacing.xl - GlassSpacing.xxs   // 16
        case .mini: GlassSpacing.md                          // 12
        }
    }

    var textRole: GlassTextRole {
        switch self {
        case .large: .control
        case .medium: .bodyEmphasized
        case .small, .compact: .controlCompact
        case .mini: .captionSmall
        }
    }

    /// Symbol point size. Symbols sit optically large next to lowercase type,
    /// so they run ~5pt below the label size at every step.
    var symbolSize: CGFloat {
        switch self {
        case .large: 9
        case .medium: 10
        case .small: 9
        case .compact: 8
        case .mini: 8
        }
    }

    /// Gap between symbol and label. Tighter at small sizes so the pair reads
    /// as one word-shape rather than two objects.
    var iconSpacing: CGFloat {
        switch self {
        case .large: GlassSpacing.sm + 3   // 9
        case .medium, .small: GlassSpacing.sm + 1   // 7
        case .compact, .mini: GlassSpacing.sm       // 6
        }
    }

    /// Spinner diameter for the loading state — sized to the cap height so the
    /// pill's width barely moves when a label is swapped for a spinner.
    var spinnerSize: CGFloat {
        switch self {
        case .large: 15
        case .medium: 14
        case .small, .compact: 12
        case .mini: 11
        }
    }
}

// MARK: - Button style

/// The flat pill, in all five interaction states.
///
/// | State | Treatment |
/// |---|---|
/// | initial | fill by emphasis, no stroke |
/// | hover | +3% scale, pointing-hand cursor; tertiary gains its plate |
/// | focus | 2pt accent ring, offset 2pt — the only stroke a pill ever draws |
/// | pressed | −3% scale, −6% brightness |
/// | disabled | dimmed, no hover, no cursor, not focusable |
/// | loading | spinner joins the label, hit-blocked, announced as busy |
///
/// Focus and hover are independent: a pill can be keyboard-focused while the
/// pointer is elsewhere, and both must be visible at once. Loading is a
/// distinct state rather than `disabled`, because "working on it" and "not
/// available" are different facts and a screen reader must not conflate them.
public struct GlassPillButtonStyle: ButtonStyle {
    public var emphasis: GlassButtonEmphasis
    public var size: GlassPillSize
    /// Stretches the pill to its container. Off by default: a capsule that
    /// spans a panel stops reading as a button.
    public var isFullWidth: Bool
    /// Work is in flight. The control keeps its footprint and stops accepting
    /// input; it does not become `disabled`, which would say something false.
    public var isLoading: Bool

    public init(
        emphasis: GlassButtonEmphasis = .primary,
        size: GlassPillSize = .large,
        isFullWidth: Bool = false,
        isLoading: Bool = false
    ) {
        self.emphasis = emphasis
        self.size = size
        self.isFullWidth = isFullWidth
        self.isLoading = isLoading
    }

    public func makeBody(configuration: Configuration) -> some View {
        GlassPillBody(
            configuration: configuration,
            emphasis: emphasis,
            size: size,
            isFullWidth: isFullWidth,
            isLoading: isLoading
        )
    }
}

public extension ButtonStyle where Self == GlassPillButtonStyle {
    static var glassPill: GlassPillButtonStyle { GlassPillButtonStyle() }

    static func glassPill(
        _ emphasis: GlassButtonEmphasis,
        size: GlassPillSize = .large,
        isFullWidth: Bool = false,
        isLoading: Bool = false
    ) -> GlassPillButtonStyle {
        GlassPillButtonStyle(
            emphasis: emphasis, size: size,
            isFullWidth: isFullWidth, isLoading: isLoading
        )
    }
}

private struct GlassPillBody: View {
    let configuration: ButtonStyle.Configuration
    let emphasis: GlassButtonEmphasis
    let size: GlassPillSize
    let isFullWidth: Bool
    let isLoading: Bool

    @Environment(\.glassTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    @FocusState private var isFocused: Bool

    /// Loading is not disabled, but it is not pressable either.
    private var acceptsInput: Bool { isEnabled && !isLoading }

    // HOMEREC-LOCAL: the focus ring became a permanent border on the record
    // control. SwiftUI grants focus on a *mouse* click and keeps it after the
    // window resigns key, so once the user clicked record the pill kept an
    // accent ring around an accent fill — indistinguishable from the resting
    // border this kit says it never draws, on the one control that matters most.
    // Gating on Full Keyboard Access keeps the indicator for people who navigate
    // by keyboard, which is who 2.4.11 is for, and removes it from ordinary
    // mouse use. The real fix belongs upstream in ui-explorations — probably
    // a ring colour that contrasts with the fill it surrounds, plus clearing
    // focus on window resign. See docs/design-system-vendoring.md.
    private static var showsFocusRing: Bool {
        NSApplication.shared.isFullKeyboardAccessEnabled
    }
    // HOMEREC-LOCAL-END

    var body: some View {
        label
            .padding(.horizontal, size.horizontalPadding)
        .frame(maxWidth: isFullWidth ? .infinity : nil)
        .frame(height: size.height(theme.metrics))
        .background(fill, in: Capsule())
        // The one stroke in the component, and only when focused. Drawn
        // outside the capsule so it never eats into the fill or shifts the
        // label, and in the accent so it cannot be confused with a resting
        // treatment — no resting state in this kit is stroked at all.
        .overlay {
            Capsule()
                .strokeBorder(theme.colors.accent, lineWidth: 2)
                .padding(-4)
                .opacity(isFocused && Self.showsFocusRing ? 1 : 0)
        }
        // Visual capsule first, then the hit region is grown to the minimum
        // target. The scale effects below deliberately sit *outside* the
        // content shape: a hit region that grows on hover makes the pointer
        // chase its own hover state at the boundary.
        .contentShape(Capsule())
        .padding(.vertical, hitPadding)
        .contentShape(Capsule())
        .scaleEffect(scale)
        .brightness(configuration.isPressed && acceptsInput ? -0.06 : 0)
        .glassAnimation(.hover, value: isHovering)
        .glassAnimation(.press, value: configuration.isPressed)
        .glassAnimation(.hover, value: isFocused)
        .glassHover($isHovering, showsPointingHand: acceptsInput)
        // Only reachable by keyboard when it can actually be actioned.
        .focusable(acceptsInput)
        .focused($isFocused)
        // The kit draws its own ring above; the system's would double it.
        .focusEffectDisabled()
        .opacity(isEnabled ? 1 : 0.85)
        // "Busy" and "unavailable" are different sentences. VoiceOver gets the
        // right one.
        .accessibilityAddTraits(isLoading ? .updatesFrequently : [])
        .accessibilityValue(isLoading ? Text("Loading") : Text(""))
        .allowsHitTesting(acceptsInput)
    }

    private var label: some View {
        configuration.label
            .glassText(size.textRole)
            .fontWeight(size == .mini ? .semibold : nil)
            .foregroundStyle(foreground)
            // Optical centering. Inter's cap height sits low in a capsule of
            // this proportion, so a mathematically centred label reads 1pt
            // low. Only applied when Inter is actually the resolved face —
            // SF is centred correctly and would be pushed *off* centre.
            .offset(y: opticalOffset)
    }

    /// Grows a sub-minimum control's hit region to `minimumHitTarget` without
    /// changing what you see. The mini pill is 26pt of capsule and 28pt of
    /// target.
    private var hitPadding: CGFloat {
        max(0, (theme.metrics.minimumHitTarget - size.height(theme.metrics)) / 2)
    }

    private var opticalOffset: CGFloat {
        theme.typography.usesCustomUIFamily && size == .large ? -1 : 0
    }

    private var scale: CGFloat {
        guard acceptsInput, !reduceMotion else { return 1 }
        if configuration.isPressed { return 0.97 }
        return isHovering ? 1.03 : 1.0
    }

    private var fill: Color {
        let pressed = configuration.isPressed && acceptsInput
        switch emphasis {
        case .primary:
            if !isEnabled { return theme.colors.accentMuted }
            return pressed ? theme.colors.accentStrong : theme.colors.accent
        case .primaryTinted(let tint):
            return isEnabled ? tint : tint.opacity(0.45)
        case .primaryNeutral:
            return theme.colors.controlPrimaryNeutral.opacity(isEnabled ? 1 : 0.45)
        case .secondary:
            return theme.colors.controlSecondary.opacity(isEnabled ? 1 : 0.4)
        case .tertiary:
            // No resting fill. The plate is the hover state, which is what
            // makes tertiary quiet without making it invisible — the label
            // itself still carries full text contrast at rest.
            return isHovering && acceptsInput ? theme.colors.surfaceInset : .clear
        case .blocked:
            return theme.colors.surfaceCard.opacity(isEnabled ? 1 : 0.7)
        }
    }

    private var foreground: Color {
        emphasis.foreground(theme.colors, isEnabled: isEnabled)
    }
}

// MARK: - Loading indicator

/// A determinate-looking indeterminate spinner.
///
/// `ProgressView` is the obvious choice and the wrong one here: its macOS
/// rendering ignores the pill's foreground colour, so it lands as a grey
/// smudge on a near-white fill. This draws an arc in whatever ink the pill is
/// already using, and freezes to a static ring under Reduce Motion — where a
/// spinner is exactly the thing a user asked not to see.
struct GlassPillSpinner: View {
    let diameter: CGFloat
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                ring(sweep: 1).opacity(0.45)
            } else {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    // A short arc reads as a stray comma at 11pt. Three
                    // quarters of a ring is unmistakably a spinner at every
                    // size the kit offers.
                    ring(sweep: 0.72)
                        .rotationEffect(.degrees(t.truncatingRemainder(dividingBy: 1) * 360))
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    private func ring(sweep: Double) -> some View {
        Circle()
            .trim(from: 0, to: sweep)
            .stroke(color, style: StrokeStyle(lineWidth: max(1.5, diameter * 0.12), lineCap: .round))
            .padding(max(1.5, diameter * 0.12) / 2)
    }
}

// MARK: - Convenience view

/// A pill button with the kit's label composition: optional SF Symbol, then a
/// lowercase label, never wrapping.
public struct GlassPillButton: View {
    private let title: String
    private let systemImage: String?
    private let emphasis: GlassButtonEmphasis
    private let size: GlassPillSize
    private let isFullWidth: Bool
    private let isLoading: Bool
    private let action: () -> Void

    @Environment(\.glassTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    public init(
        _ title: String,
        systemImage: String? = nil,
        emphasis: GlassButtonEmphasis = .primary,
        size: GlassPillSize = .large,
        isFullWidth: Bool = false,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.emphasis = emphasis
        self.size = size
        self.isFullWidth = isFullWidth
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: size.iconSpacing) {
                if isLoading {
                    // The spinner takes the symbol's slot rather than the
                    // label's. "saving…" with a spinner beside it says what is
                    // happening; a bare spinner says only that something is.
                    GlassPillSpinner(
                        diameter: size.spinnerSize,
                        color: emphasis.foreground(theme.colors, isEnabled: isEnabled)
                    )
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: size.symbolSize, weight: .bold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    // A control label that wraps has stopped being a control.
                    // Truncation here is a bug report, not a layout: it means
                    // the label is too long for the register.
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .buttonStyle(
            GlassPillButtonStyle(
                emphasis: emphasis, size: size,
                isFullWidth: isFullWidth, isLoading: isLoading
            )
        )
    }
}

#Preview("Pill buttons — emphasis × size") {
    GlassPreviewStage {
        VStack(alignment: .leading, spacing: GlassSpacing.l) {
            ForEach(GlassPillSize.allCases, id: \.self) { size in
                HStack(spacing: GlassSpacing.m) {
                    Text(size.rawValue)
                        .glassText(.metaSmall, color: .textTertiary)
                        .frame(width: 60, alignment: .leading)
                    GlassPillButton("record", systemImage: "circle.fill", emphasis: .primary, size: size) {}
                    GlassPillButton("choose folder…", emphasis: .primaryNeutral, size: size) {}
                    GlassPillButton("keep", emphasis: .secondary, size: size) {}
                    GlassPillButton("dismiss", emphasis: .tertiary, size: size) {}
                    GlassPillButton("blocked", emphasis: .blocked, size: size) {}
                    GlassPillButton("saving…", emphasis: .primary, size: size, isLoading: true) {}
                    GlassPillButton("disabled", emphasis: .primary, size: size) {}.disabled(true)
                }
            }
        }
    }
}

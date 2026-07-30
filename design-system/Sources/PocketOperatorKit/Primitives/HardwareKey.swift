import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

/// Which part a key cap is moulded from.
///
/// A variant is a *material*, not a severity level. That distinction matters
/// for disabled state: hardware cannot fade a button, so an unavailable
/// control is shown as a duller cap — a different part fitted to the same
/// chassis — rather than a translucent one.
public enum HardwareKeyVariant: Sendable, Equatable {
    /// Anodised aluminium. The default key.
    case neutral
    /// The one saturated cap in the system. Reserved for the control that
    /// commits, arms, or destroys — never for navigation.
    case accent
    /// A blacked-out cap for modifiers and secondary functions that should
    /// sit back into the bed.
    case dark
}

/// Cap footprint.
public enum HardwareKeySize: Sendable, Equatable {
    case compact
    case regular
    case large
    case custom(CGSize)

    public func dimensions(_ metrics: POMetrics) -> CGSize {
        switch self {
        case .compact: metrics.keyCompactSize
        case .regular: metrics.keyRegularSize
        case .large: metrics.keyLargeSize
        case .custom(let size): size
        }
    }
}

/// Cap outline.
public enum HardwareKeyShape: Sendable, Equatable {
    /// Rounded rectangle — the standard moulded cap.
    case lozenge
    /// Fully rounded ends, for a single isolated control.
    case pill
    /// Circular; sized from the shorter edge of the footprint.
    case round

    func corner(for size: CGSize, metrics: POMetrics) -> CGFloat {
        switch self {
        case .lozenge: metrics.keyCorner
        case .pill, .round: min(size.width, size.height) / 2
        }
    }
}

/// The press physics and cap rendering, as a `ButtonStyle`.
///
/// Exposed separately from `HardwareKey` so an existing `Button` — including
/// one carrying a custom label, an image, or a menu — can adopt the hardware
/// feel without being rebuilt:
///
/// ```swift
/// Button("ARM") { arm() }
///     .buttonStyle(HardwareKeyStyle(variant: .accent))
/// ```
@available(macOS 15, *)
public struct HardwareKeyStyle: ButtonStyle {
    public var variant: HardwareKeyVariant
    public var size: HardwareKeySize
    public var shape: HardwareKeyShape
    /// Latched state, for keys that stay down until pressed again.
    public var isOn: Bool
    public var providesHaptics: Bool

    public init(
        variant: HardwareKeyVariant = .neutral,
        size: HardwareKeySize = .regular,
        shape: HardwareKeyShape = .lozenge,
        isOn: Bool = false,
        providesHaptics: Bool = true
    ) {
        self.variant = variant
        self.size = size
        self.shape = shape
        self.isOn = isOn
        self.providesHaptics = providesHaptics
    }

    public func makeBody(configuration: Configuration) -> some View {
        KeyCap(
            configuration: configuration,
            variant: variant,
            size: size,
            shape: shape,
            isOn: isOn,
            providesHaptics: providesHaptics
        )
    }
}

/// The cap itself. A separate `View` because a `ButtonStyle` cannot read the
/// environment, and every token this needs lives there.
@available(macOS 15, *)
private struct KeyCap: View {
    let configuration: ButtonStyleConfiguration
    let variant: HardwareKeyVariant
    let size: HardwareKeySize
    let shape: HardwareKeyShape
    let isOn: Bool
    let providesHaptics: Bool

    @Environment(\.poTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var dynamicTypeRatio: CGFloat = 1

    var body: some View {
        let metrics = theme.metrics
        let dimensions = footprint
        let corner = shape.corner(for: dimensions, metrics: metrics)
        let capShape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        let palette = palette
        let offset = travelOffset
        let hitPadding = metrics.hitTargetPadding(for: dimensions)

        cap(shape: capShape, palette: palette, dimensions: dimensions)
            .offset(y: offset)
            // Contact shadow tightens as the cap approaches the plinth; the
            // gap closing is most of what sells the travel.
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.35 : 0.5),
                radius: configuration.isPressed ? 1.5 : 5,
                y: configuration.isPressed ? 1 : 3
            )
            .background(alignment: .bottom) {
                plinth(corner: corner)
            }
            .overlay {
                capShape
                    .fill(.black.opacity(configuration.isPressed ? 0.08 : 0))
                    .frame(width: dimensions.width, height: dimensions.height)
                    .offset(y: offset)
                    .allowsHitTesting(false)
            }
            .overlay {
                if isFocused {
                    capShape
                        .strokeBorder(theme.colors.focusRing, lineWidth: 2)
                        .frame(width: dimensions.width + 5, height: dimensions.height + 5)
                        .offset(y: offset)
                        .allowsHitTesting(false)
                }
            }
            .animation(
                reduceMotion ? nil : theme.motion.keyTransition(isPressed: configuration.isPressed),
                value: configuration.isPressed
            )
            // A cap smaller than the minimum target keeps its printed size and
            // grows only its hit region, so touch and pointer accuracy never
            // depend on how small the legend happens to be.
            .padding(.horizontal, hitPadding.width)
            .padding(.vertical, hitPadding.height)
            .contentShape(Rectangle())
            .onChange(of: configuration.isPressed) { _, pressed in
                guard pressed, providesHaptics else { return }
                performKeyHaptic()
            }
    }

    private func cap(
        shape capShape: RoundedRectangle,
        palette: KeyPalette,
        dimensions: CGSize
    ) -> some View {
        configuration.label
            .font(labelRole.font(scale: theme.typography.clamped(dynamicTypeRatio)))
            .tracking(labelRole.tracking(scale: theme.typography.clamped(dynamicTypeRatio)))
            .foregroundStyle(palette.label)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: dimensions.width, height: dimensions.height)
            .background {
                capShape.fill(
                    LinearGradient(
                        colors: [palette.top, palette.bottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .overlay {
                // Machined top edge. The highlight runs only from the top to
                // the middle: light from above catches the upper chamfer and
                // nothing else, and a full-perimeter stroke immediately reads
                // as a border rather than as a bevel.
                capShape.strokeBorder(
                    LinearGradient(
                        colors: [theme.colors.keyBevel.opacity(palette.bevelOpacity), .clear],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: theme.metrics.hairline
                )
            }
            .overlay(alignment: .topTrailing) {
                if isOn {
                    Circle()
                        .fill(theme.colors.lampActive)
                        .frame(width: 4, height: 4)
                        .padding(4)
                        .allowsHitTesting(false)
                }
            }
    }

    private func plinth(corner: CGFloat) -> some View {
        // Sits one point proud on each side and two below, so the cap never
        // exposes chassis through the gap at the bottom of its travel.
        RoundedRectangle(cornerRadius: corner + 1, style: .continuous)
            .fill(theme.colors.keyPlinth)
            .padding(.horizontal, -1)
            .padding(.top, 2)
            .padding(.bottom, -2)
    }

    private var footprint: CGSize {
        size.dimensions(theme.metrics)
    }

    /// Free, latched, or fully pressed. A latched key rests part-way down —
    /// the physical record of a toggle that is currently on.
    private var travelOffset: CGFloat {
        if configuration.isPressed { return theme.metrics.keyTravel }
        return isOn ? theme.metrics.keyLatchedTravel : 0
    }

    private var labelRole: POTypography.Role {
        variant == .accent ? theme.typography.keyCapEmphasis : theme.typography.keyCap
    }

    private struct KeyPalette {
        var top: Color
        var bottom: Color
        var label: Color
        var bevelOpacity: Double
    }

    private var palette: KeyPalette {
        let colors = theme.colors
        guard isEnabled else {
            return switch variant {
            case .accent:
                KeyPalette(
                    top: colors.mutedKeyTop,
                    bottom: colors.mutedKeyBottom,
                    label: colors.mutedKeyLabel,
                    bevelOpacity: 0.35
                )
            case .neutral, .dark:
                KeyPalette(
                    top: colors.disabledKeyTop,
                    bottom: colors.disabledKeyBottom,
                    label: colors.disabledKeyLabel,
                    bevelOpacity: 0.3
                )
            }
        }
        return switch variant {
        case .neutral:
            KeyPalette(
                top: colors.keyCapTop,
                bottom: colors.keyCapBottom,
                label: colors.keyLabel,
                bevelOpacity: 1
            )
        case .accent:
            KeyPalette(
                top: colors.accentKeyTop,
                bottom: colors.accentKeyBottom,
                label: colors.accentKeyLabel,
                bevelOpacity: 1
            )
        case .dark:
            KeyPalette(
                top: colors.darkKeyTop,
                bottom: colors.darkKeyBottom,
                label: colors.darkKeyLabel,
                bevelOpacity: 0.6
            )
        }
    }

    private func performKeyHaptic() {
        #if canImport(AppKit)
        // Fires on press, not on release: a real key's detent is felt on the
        // way down, and feedback on release lands after the action has already
        // been taken.
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
}

/// A hardware key: a moulded cap on a plinth, with a printed legend and real
/// travel.
///
/// The signature control of the language. Everything about it is an argument
/// that the interface is an object: the cap has a light source, an edge, a
/// depth it can travel through, and a legend that was printed on it before it
/// ever knew what it would do.
///
/// ```swift
/// HardwareKey("REC", variant: .accent, accessibilityLabel: "Record") {
///     transport.toggle()
/// }
/// ```
///
/// - Note: Legends are abbreviations. Always pass `accessibilityLabel` when the
///   printed text is not a word — "FMT" is unreadable to a screen reader and
///   meaningless to anyone who has not used the device.
@available(macOS 15, *)
public struct HardwareKey<Label: View>: View {
    private let variant: HardwareKeyVariant
    private let size: HardwareKeySize
    private let shape: HardwareKeyShape
    private let isOn: Bool
    private let providesHaptics: Bool
    private let accessibilityLabel: String?
    private let accessibilityHint: String?
    private let action: () -> Void
    private let label: Label

    public init(
        variant: HardwareKeyVariant = .neutral,
        size: HardwareKeySize = .regular,
        shape: HardwareKeyShape = .lozenge,
        isOn: Bool = false,
        providesHaptics: Bool = true,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.variant = variant
        self.size = size
        self.shape = shape
        self.isOn = isOn
        self.providesHaptics = providesHaptics
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.action = action
        self.label = label()
    }

    public var body: some View {
        Button(action: action) { label }
            .buttonStyle(
                HardwareKeyStyle(
                    variant: variant,
                    size: size,
                    shape: shape,
                    isOn: isOn,
                    providesHaptics: providesHaptics
                )
            )
            .poAccessibilityLabel(accessibilityLabel)
            .poAccessibilityHint(accessibilityHint)
            .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

@available(macOS 15, *)
public extension HardwareKey where Label == Text {
    /// A key with a printed text legend.
    ///
    /// - Parameters:
    ///   - legend: Text printed on the cap. Rendered uppercase.
    ///   - accessibilityLabel: Spoken name. Defaults to the legend, which is
    ///     only adequate when the legend is a real word.
    init(
        _ legend: String,
        variant: HardwareKeyVariant = .neutral,
        size: HardwareKeySize = .regular,
        shape: HardwareKeyShape = .lozenge,
        isOn: Bool = false,
        providesHaptics: Bool = true,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            variant: variant,
            size: size,
            shape: shape,
            isOn: isOn,
            providesHaptics: providesHaptics,
            accessibilityLabel: accessibilityLabel ?? legend,
            accessibilityHint: accessibilityHint,
            action: action,
            label: { Text(legend.uppercased()) }
        )
    }
}

@available(macOS 15, *)
#Preview("Hardware keys") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            HardwareKey("01") {}
            HardwareKey("REC", variant: .accent, accessibilityLabel: "Record") {}
            HardwareKey("ALT", variant: .dark) {}
        }
        HStack(spacing: 12) {
            HardwareKey("LOOP", isOn: true, accessibilityLabel: "Loop") {}
            HardwareKey("REC", variant: .accent) {}.disabled(true)
            HardwareKey("SET") {}.disabled(true)
        }
        HStack(spacing: 12) {
            HardwareKey("BACK", size: .compact) {}
            HardwareKey("A", size: .custom(CGSize(width: 22, height: 20)), shape: .round) {}
            HardwareKey("ENTER", size: .large, shape: .pill) {}
        }
    }
    .padding(30)
    .background(Color.poHex(0x161616))
}

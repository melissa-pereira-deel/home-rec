import SwiftUI

/// A legend printed onto the chassis.
///
/// Screen print is *not* UI text. It is applied to the shell at manufacture,
/// so it never changes, never wraps, never truncates with an ellipsis, and is
/// always uppercase — the reference process cannot hold lowercase counters at
/// these sizes. Text that varies at runtime belongs in a display, not in print.
@available(macOS 15, *)
public struct ScreenPrintLabel: View {

    /// Which printed size to use.
    public enum Scale: Sendable {
        /// 7pt — secondary annotation only.
        case micro
        /// 8pt — the default legend.
        case regular
        /// 9pt — section legend.
        case large
        /// 9pt — product or model mark.
        case brand
    }

    /// How strongly the print is pigmented.
    public enum Emphasis: Sendable {
        /// Standard print grey.
        case normal
        /// Near-white; for a brand mark or the one legend that leads a panel.
        case strong
        /// Half-strength; for a legend that is present but not being used yet.
        case dim
    }

    @Environment(\.poTheme) private var theme
    @ScaledMetric(relativeTo: .caption2) private var dynamicTypeRatio: CGFloat = 1

    private let text: String
    private let scale: Scale
    private let emphasis: Emphasis
    private let isDecorative: Bool

    /// - Parameters:
    ///   - text: Legend text. Uppercased on render; pass it however reads best
    ///     in source.
    ///   - isDecorative: Hides the legend from assistive technology. Set this
    ///     only when an enclosing component already speaks the same words as
    ///     part of a combined element — never to hide information.
    public init(
        _ text: String,
        scale: Scale = .regular,
        emphasis: Emphasis = .normal,
        isDecorative: Bool = false
    ) {
        self.text = text
        self.scale = scale
        self.emphasis = emphasis
        self.isDecorative = isDecorative
    }

    public var body: some View {
        let role = role(for: scale)
        let ratio = theme.typography.clamped(dynamicTypeRatio)
        Text(text.uppercased())
            .font(role.font(scale: ratio))
            .tracking(role.tracking(scale: ratio))
            .foregroundStyle(color)
            // Print cannot reflow: a legend that wraps has stopped looking
            // manufactured. It stays on one line and shrinks slightly first.
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityHidden(isDecorative)
    }

    private func role(for scale: Scale) -> POTypography.Role {
        switch scale {
        case .micro: theme.typography.microLabel
        case .regular: theme.typography.label
        case .large: theme.typography.labelLarge
        case .brand: theme.typography.brand
        }
    }

    private var color: Color {
        switch emphasis {
        case .normal: theme.colors.screenPrint
        case .strong: theme.colors.screenPrintEmphasis
        case .dim: theme.colors.screenPrint.opacity(0.6)
        }
    }
}

/// A printed value — the right-hand half of a label/value pair.
///
/// Kept separate from `ScreenPrintLabel` because it is a different ink: values
/// are brighter than their labels so a dense spec block resolves into pairs
/// without needing any additional rules or spacing.
@available(macOS 15, *)
public struct ScreenPrintValue: View {
    @Environment(\.poTheme) private var theme
    @ScaledMetric(relativeTo: .caption) private var dynamicTypeRatio: CGFloat = 1

    private let text: String
    private let isLarge: Bool
    private let isDecorative: Bool

    public init(_ text: String, isLarge: Bool = false, isDecorative: Bool = false) {
        self.text = text
        self.isLarge = isLarge
        self.isDecorative = isDecorative
    }

    public var body: some View {
        let role = isLarge ? theme.typography.readoutLarge : theme.typography.readout
        let ratio = theme.typography.clamped(dynamicTypeRatio)
        Text(text)
            .font(role.font(scale: ratio))
            .tracking(role.tracking(scale: ratio))
            .foregroundStyle(theme.colors.readout)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityHidden(isDecorative)
    }
}

@available(macOS 15, *)
#Preview("Screen print") {
    VStack(alignment: .leading, spacing: 10) {
        ScreenPrintLabel("POCKET OPERATOR KIT", scale: .brand, emphasis: .strong)
        ScreenPrintLabel("SECTION LEGEND", scale: .large)
        ScreenPrintLabel("STANDARD LEGEND")
        ScreenPrintLabel("MICRO ANNOTATION", scale: .micro, emphasis: .dim)
        HStack(spacing: 6) {
            ScreenPrintLabel("RATE", scale: .micro)
            ScreenPrintValue("48K")
        }
    }
    .padding(24)
    .background(Color.poHex(0x0A0A0A))
}

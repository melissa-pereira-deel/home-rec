import SwiftUI

/// # Panel hierarchy
///
/// Every surface in this language occupies exactly one of four levels, and the
/// composition reads as an object only if that ordering is never violated:
///
/// ```
/// chassis   the moulded shell            largest radius, edge highlight, faint grain
///   panel   a raised sub-assembly        one radius step down, one tone up, no grain
///     well  a milled recess              inner shadow, black cut line, lit lip
///       control  a fitted part           cap, lens, glass, needle
/// ```
///
/// The rules that follow from it:
///
/// - **A control is always in a well, or directly on the chassis — never on a
///   panel edge.** Parts are mounted through holes; a key floating on flat
///   shell reads as a sticker.
/// - **Radius decreases with depth.** Shell 10, panel/well 8, cut glass 4.
///   A recess with a larger radius than the thing containing it is impossible
///   to manufacture and the eye knows it immediately.
/// - **Light comes from directly above, always.** Every bevel highlights on
///   its top edge, every inner shadow falls from the top wall, every drop
///   shadow goes down. One inconsistent gradient flattens a whole panel.
/// - **Nesting stops at four.** A well inside a well inside a well is not a
///   deeper hierarchy, it is a mistake; split the panel instead.
/// - **Levels are not decoration.** Do not use a well for emphasis. A recess
///   means "parts are fitted here", and using it to highlight a paragraph is
///   the fastest route back to app chrome.
///
/// ## Elevation
///
/// Use `POElevation` to state a surface's level explicitly when composing a
/// custom container, so the intent survives later edits.
public enum POElevation: Int, Sendable, CaseIterable, Comparable {
    case chassis = 0
    case panel = 1
    case well = 2
    case control = 3

    public static func < (lhs: POElevation, rhs: POElevation) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The corner radius appropriate to this level.
    public func corner(_ metrics: POMetrics) -> CGFloat {
        switch self {
        case .chassis: metrics.chassisCorner
        case .panel: metrics.panelCorner
        case .well: metrics.wellCorner
        case .control: metrics.keyCorner
        }
    }
}

/// A complete device face: shell, branding row, working area, printed footer.
///
/// The standard arrangement, and the one the language was designed around —
/// identity at the top edge, the display directly beneath it, controls in the
/// middle where hands go, and the permanent specification along the bottom.
/// A product is free to deviate, but the ordering encodes something real:
/// printed matter belongs at the edges of a device, and moving parts belong in
/// the middle.
///
/// ```swift
/// DeviceFace(brand: "ACME", model: "AK-2", subtitle: "STEP SEQUENCER") {
///     LCDPanel { … }
///     KeyGrid(pads)
/// } footer: {
///     SpecGrid(specs)
/// }
/// ```
@available(macOS 15, *)
public struct DeviceFace<Content: View, Footer: View>: View {
    @Environment(\.poTheme) private var theme

    private let brand: String
    private let model: String?
    private let subtitle: String?
    private let content: Content
    private let footer: Footer

    public init(
        brand: String,
        model: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.brand = brand
        self.model = model
        self.subtitle = subtitle
        self.content = content()
        self.footer = footer()
    }

    public var body: some View {
        ChassisSurface {
            VStack(spacing: theme.metrics.spacing.panel) {
                brandingRow
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                footer
            }
        }
    }

    private var brandingRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.metrics.spacing.base) {
            ScreenPrintLabel(brand, scale: .brand, emphasis: .strong)
            if let model {
                ScreenPrintLabel(model, scale: .brand, emphasis: .dim)
            }
            Spacer(minLength: theme.metrics.spacing.key)
            if let subtitle {
                ScreenPrintLabel(subtitle, scale: .micro, emphasis: .dim)
            }
        }
        // Branding is manufactured identity, not a heading. Combining it into
        // one element stops a screen reader announcing three separate scraps
        // of text before any of the actual controls.
        .accessibilityElement(children: .combine)
    }
}

@available(macOS 15, *)
public extension DeviceFace where Footer == EmptyView {
    init(
        brand: String,
        model: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            brand: brand,
            model: model,
            subtitle: subtitle,
            content: content,
            footer: { EmptyView() }
        )
    }
}

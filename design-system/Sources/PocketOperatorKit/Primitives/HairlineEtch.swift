import SwiftUI

/// A one-point etched rule.
///
/// Etch is the system's only divider. There are no filled separators, no
/// tinted section backgrounds and no shadow-based grouping — a milled line is
/// how a panel is subdivided, and keeping to it is most of what stops the
/// language sliding back toward app chrome.
@available(macOS 15, *)
public struct HairlineEtch: View {
    @Environment(\.poTheme) private var theme

    private let axis: Axis
    private let tint: Color?
    private let length: CGFloat?

    public init(_ axis: Axis = .horizontal, tint: Color? = nil, length: CGFloat? = nil) {
        self.axis = axis
        self.tint = tint
        self.length = length
    }

    public var body: some View {
        let weight = theme.metrics.hairline
        Rectangle()
            .fill(tint ?? theme.colors.etch)
            .frame(
                width: axis == .vertical ? weight : length,
                height: axis == .horizontal ? weight : length
            )
            .frame(
                maxWidth: axis == .horizontal && length == nil ? .infinity : nil,
                maxHeight: axis == .vertical && length == nil ? .infinity : nil
            )
            .accessibilityHidden(true)
    }
}

/// An etched frame around a block of printed data.
@available(macOS 15, *)
public struct POEtchedFrame: ViewModifier {
    @Environment(\.poTheme) private var theme
    let corner: CGFloat
    let tint: Color?

    public func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(tint ?? theme.colors.etch, lineWidth: theme.metrics.hairline)
        }
    }
}

@available(macOS 15, *)
public extension View {
    /// Draw an etched frame around this view.
    func poEtchedFrame(corner: CGFloat = 0, tint: Color? = nil) -> some View {
        modifier(POEtchedFrame(corner: corner, tint: tint))
    }
}

@available(macOS 15, *)
#Preview("Etch") {
    VStack(spacing: 12) {
        HairlineEtch()
        HStack(spacing: 12) {
            ScreenPrintLabel("LEFT")
            HairlineEtch(.vertical, length: 18)
            ScreenPrintLabel("RIGHT")
        }
        ScreenPrintLabel("FRAMED BLOCK")
            .padding(10)
            .poEtchedFrame(corner: 2)
    }
    .padding(24)
    .frame(width: 240)
    .background(Color.poHex(0x0A0A0A))
}

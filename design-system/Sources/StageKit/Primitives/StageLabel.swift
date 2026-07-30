import SwiftUI

/// Mono, uppercase, tracked chrome text.
///
/// Every string in the harness goes through here. Casing and tracking are
/// applied by the primitive rather than by callers so that a stage cannot drift
/// into mixed conventions, and so the *un*cased original stays available for
/// accessibility labels at the call site.
@available(macOS 15.0, *)
public struct StageLabel: View {
    private let text: String
    private let explicitStyle: StageTextStyle?
    private let tone: StageTone

    @Environment(\.stageTheme) private var theme

    /// - Parameters:
    ///   - style: defaults to the theme's chip style, the most common role.
    public init(_ text: String, style: StageTextStyle? = nil, tone: StageTone = .primary) {
        self.text = text
        self.explicitStyle = style
        self.tone = tone
    }

    public var body: some View {
        let style = explicitStyle ?? theme.typography.chip
        Text(style.rendered(text))
            .font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(theme.colors.color(tone))
            // Chrome labels are short and fixed; wrapping one would shift the
            // whole bar and break capture determinism.
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

@available(macOS 15.0, *)
#Preview("StageLabel tones") {
    VStack(alignment: .leading, spacing: 6) {
        ForEach(StageTone.allCases, id: \.self) { tone in
            StageLabel("tone \(String(describing: tone))", tone: tone)
        }
    }
    .padding(20)
    .background(StageTheme.dark.colors.chrome)
}

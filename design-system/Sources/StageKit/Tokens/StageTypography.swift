import SwiftUI

/// One entry in the stage type scale.
///
/// The scale is mono-led and small on purpose. Monospace signals "instrument
/// panel, not product" at a glance, which is the fastest way to tell a reviewer
/// that a label belongs to the harness and not to the design under review.
/// Generous tracking is what keeps 9–11pt uppercase mono legible.
@available(macOS 15.0, *)
public struct StageTextStyle: Equatable {
    public var size: CGFloat
    public var weight: Font.Weight
    /// Letter spacing in points. Uppercase mono at these sizes reads as a solid
    /// block without it.
    public var tracking: CGFloat
    /// Applied at render time rather than asked of the caller, so that
    /// accessibility labels keep the original casing — VoiceOver should say
    /// "Pocket Op", not spell out "P-O-C-K-E-T".
    public var isUppercased: Bool
    public var design: Font.Design

    public init(
        size: CGFloat,
        weight: Font.Weight = .regular,
        tracking: CGFloat = 0,
        isUppercased: Bool = true,
        design: Font.Design = .monospaced
    ) {
        self.size = size
        self.weight = weight
        self.tracking = tracking
        self.isUppercased = isUppercased
        self.design = design
    }

    public var font: Font { .system(size: size, weight: weight, design: design) }

    public func rendered(_ text: String) -> String {
        isUppercased ? text.uppercased() : text
    }
}

/// The stage type scale. Six roles, four sizes — a harness that needs more type
/// variety than this is drawing attention to itself.
@available(macOS 15.0, *)
public struct StageTypography: Equatable {
    /// Numbered concept tabs.
    public var tab: StageTextStyle
    /// Scrubber chips and segmented-control segments.
    public var chip: StageTextStyle
    /// Group captions in the scrubber, section headers in the gallery.
    public var caption: StageTextStyle
    /// The keyboard-hint row.
    public var hint: StageTextStyle
    /// The key glyph itself inside a hint (`⌘R`, `1–9`). Slightly heavier than
    /// its description so the key is scannable in a run-on row.
    public var key: StageTextStyle
    /// Stage title / window identity, when a stage chooses to show one.
    public var title: StageTextStyle

    public init(
        tab: StageTextStyle,
        chip: StageTextStyle,
        caption: StageTextStyle,
        hint: StageTextStyle,
        key: StageTextStyle,
        title: StageTextStyle
    ) {
        self.tab = tab
        self.chip = chip
        self.caption = caption
        self.hint = hint
        self.key = key
        self.title = title
    }

    public static let `default` = StageTypography(
        tab: StageTextStyle(size: 10, tracking: 1.0),
        chip: StageTextStyle(size: 10, tracking: 1.0),
        caption: StageTextStyle(size: 9, tracking: 1.4),
        hint: StageTextStyle(size: 9, tracking: 0.4),
        key: StageTextStyle(size: 9, weight: .medium, tracking: 0.4),
        title: StageTextStyle(size: 11, weight: .medium, tracking: 1.6)
    )

    /// Every role bumped two points for projection or for reviewers sitting
    /// further from the screen than the author was.
    public static let large = StageTypography(
        tab: StageTextStyle(size: 12, tracking: 1.1),
        chip: StageTextStyle(size: 12, tracking: 1.1),
        caption: StageTextStyle(size: 11, tracking: 1.5),
        hint: StageTextStyle(size: 11, tracking: 0.5),
        key: StageTextStyle(size: 11, weight: .medium, tracking: 0.5),
        title: StageTextStyle(size: 13, weight: .medium, tracking: 1.8)
    )
}

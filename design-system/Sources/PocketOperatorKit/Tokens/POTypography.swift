import SwiftUI

/// The type system: one monospaced family, six small sizes, wide tracking.
///
/// Everything is monospaced because the language is dense with codes, counts
/// and abbreviations that must stay column-aligned and must not reflow when a
/// value changes width. Everything is small and letter-spaced because these
/// are *screen-printed* legends, and pad printing on plastic needs generous
/// letterfit to stay readable at 7pt.
public struct POTypography: Sendable, Equatable {

    /// One printed style: size, weight, tracking, and the Dynamic Type step it
    /// scales against.
    public struct Role: Sendable, Equatable {
        public var size: CGFloat
        public var weight: Font.Weight
        /// Extra letterspacing in points. Positive everywhere in this system;
        /// tight monospace at these sizes reads as a smudge.
        public var tracking: CGFloat
        public var design: Font.Design
        /// The text style this role tracks when the user scales system type.
        public var textStyle: Font.TextStyle

        public init(
            size: CGFloat,
            weight: Font.Weight = .medium,
            tracking: CGFloat = 0,
            design: Font.Design = .monospaced,
            textStyle: Font.TextStyle = .caption2
        ) {
            self.size = size
            self.weight = weight
            self.tracking = tracking
            self.design = design
            self.textStyle = textStyle
        }

        public func font(scale: CGFloat = 1) -> Font {
            .system(size: size * scale, weight: weight, design: design)
        }

        /// Tracking scaled with the type, so letterfit stays proportional
        /// rather than collapsing as the glyphs grow.
        public func tracking(scale: CGFloat = 1) -> CGFloat {
            tracking * scale
        }
    }

    /// Product or model mark on the chassis.
    public var brand: Role
    /// The smallest legible screen print. Reserved for secondary annotation —
    /// never for anything a user must read to operate the device.
    public var microLabel: Role
    /// Default screen-printed legend.
    public var label: Role
    /// Section legend, or a label that must survive across a whole panel.
    public var labelLarge: Role
    /// Legend printed on a key cap.
    public var keyCap: Role
    /// Legend on the armed key — heavier, because it is the one control a user
    /// looks for without reading.
    public var keyCapEmphasis: Role
    /// A printed value in a spec block.
    public var readout: Role
    /// A printed value that heads a group.
    public var readoutLarge: Role
    /// Human-language content (names, titles) inside an otherwise coded UI.
    public var dataTitle: Role
    /// Human-language secondary content.
    public var dataMeta: Role

    /// Ceiling applied to Dynamic Type scaling of printed labels.
    ///
    /// Screen print sits in fixed milled space — a 7pt legend that grows to
    /// 3× does not get more readable, it overruns the panel it names and
    /// collides with the control it belongs to. Labels scale up to this factor
    /// and then stop; anything a user must be able to read at any size belongs
    /// in the accessibility label, not in the print. See the accessibility
    /// section of the design documentation.
    public var maxDynamicTypeScale: CGFloat

    public init(
        brand: Role,
        microLabel: Role,
        label: Role,
        labelLarge: Role,
        keyCap: Role,
        keyCapEmphasis: Role,
        readout: Role,
        readoutLarge: Role,
        dataTitle: Role,
        dataMeta: Role,
        maxDynamicTypeScale: CGFloat
    ) {
        self.brand = brand
        self.microLabel = microLabel
        self.label = label
        self.labelLarge = labelLarge
        self.keyCap = keyCap
        self.keyCapEmphasis = keyCapEmphasis
        self.readout = readout
        self.readoutLarge = readoutLarge
        self.dataTitle = dataTitle
        self.dataMeta = dataMeta
        self.maxDynamicTypeScale = maxDynamicTypeScale
    }

    /// Clamp a measured Dynamic Type ratio to the print ceiling.
    public func clamped(_ scale: CGFloat) -> CGFloat {
        min(max(1, scale), maxDynamicTypeScale)
    }

    public static let standard = POTypography(
        brand: Role(size: 9, weight: .medium, tracking: 1.2, textStyle: .caption),
        microLabel: Role(size: 7, weight: .medium, tracking: 1.2),
        label: Role(size: 8, weight: .medium, tracking: 1.2),
        labelLarge: Role(size: 9, weight: .medium, tracking: 1.2, textStyle: .caption),
        keyCap: Role(size: 10, weight: .medium, tracking: 0.5, textStyle: .caption),
        keyCapEmphasis: Role(size: 11, weight: .bold, tracking: 0.6, textStyle: .caption),
        readout: Role(size: 10, weight: .semibold, tracking: 0.5, textStyle: .caption),
        readoutLarge: Role(size: 13, weight: .semibold, tracking: 0.5, textStyle: .footnote),
        dataTitle: Role(size: 14, weight: .regular, tracking: 0, design: .default, textStyle: .body),
        dataMeta: Role(size: 11, weight: .regular, tracking: 0.2, textStyle: .footnote),
        maxDynamicTypeScale: 1.6
    )
}

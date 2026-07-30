import CoreGraphics

/// Spacing, sizing and hit-target tokens.
///
/// Everything derives from a 4pt unit. The one number that is not a multiple of
/// the unit is ``minHitTarget``, which is a hard accessibility floor rather than
/// a rhythm decision.
@available(macOS 15.0, *)
public struct StageMetrics: Equatable {
    /// Base grid unit. All spacing tokens are multiples of this.
    public var unit: CGFloat

    // MARK: Controls

    /// Painted height of a chip or segment. Deliberately smaller than
    /// ``minHitTarget``: the chrome should look light even though it is easy to
    /// hit. See ``minHitTarget``.
    public var controlHeight: CGFloat
    public var controlPaddingHorizontal: CGFloat
    public var controlRadius: CGFloat

    /// Minimum interactive area in points, in both axes.
    ///
    /// Chips paint at ``controlHeight`` but are wrapped in a transparent slab of
    /// this size with `contentShape(Rectangle())`. Growing the pill instead
    /// would make the chrome heavier than the concept, which defeats the point;
    /// growing only the hit area costs nothing visually.
    public var minHitTarget: CGFloat

    // MARK: Bars

    public var barPaddingHorizontal: CGFloat
    public var barPaddingVertical: CGFloat
    /// Gap between tabs in the tab bar. Wider than ``chipSpacing`` because tabs
    /// have no fill to define their edges — whitespace is the only separator.
    public var tabSpacing: CGFloat
    public var chipSpacing: CGFloat
    /// Vertical gap between scrubber rows.
    public var rowSpacing: CGFloat
    /// Gap between an axis group and the next one in the same row.
    public var groupSpacing: CGFloat

    // MARK: Lines and focus

    public var hairline: CGFloat
    public var focusRingWidth: CGFloat
    /// How far the focus ring sits outside the control it decorates.
    public var focusRingInset: CGFloat

    public init(
        unit: CGFloat = 4,
        controlHeight: CGFloat = 20,
        controlPaddingHorizontal: CGFloat = 8,
        controlRadius: CGFloat = 4,
        minHitTarget: CGFloat = 28,
        barPaddingHorizontal: CGFloat = 16,
        barPaddingVertical: CGFloat = 6,
        tabSpacing: CGFloat = 14,
        chipSpacing: CGFloat = 8,
        rowSpacing: CGFloat = 2,
        groupSpacing: CGFloat = 16,
        hairline: CGFloat = 1,
        focusRingWidth: CGFloat = 1.5,
        focusRingInset: CGFloat = 2
    ) {
        self.unit = unit
        self.controlHeight = controlHeight
        self.controlPaddingHorizontal = controlPaddingHorizontal
        self.controlRadius = controlRadius
        self.minHitTarget = minHitTarget
        self.barPaddingHorizontal = barPaddingHorizontal
        self.barPaddingVertical = barPaddingVertical
        self.tabSpacing = tabSpacing
        self.chipSpacing = chipSpacing
        self.rowSpacing = rowSpacing
        self.groupSpacing = groupSpacing
        self.hairline = hairline
        self.focusRingWidth = focusRingWidth
        self.focusRingInset = focusRingInset
    }

    public static let `default` = StageMetrics()

    /// Roomier chrome for stages driven by touch-style input or shown at a
    /// distance. Pairs with `StageTypography.large`.
    public static let comfortable = StageMetrics(
        controlHeight: 24,
        controlPaddingHorizontal: 10,
        minHitTarget: 32,
        barPaddingHorizontal: 20,
        barPaddingVertical: 8,
        tabSpacing: 18,
        chipSpacing: 10,
        rowSpacing: 4,
        groupSpacing: 20
    )
}

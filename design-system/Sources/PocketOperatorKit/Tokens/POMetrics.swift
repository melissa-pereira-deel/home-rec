import SwiftUI

/// Spacing scale. Every gap in the system is one of these values; the point of
/// a fixed ladder is that a panel laid out by two different people still looks
/// like it came off one production line.
public struct POSpacing: Sendable, Equatable {
    /// Gap between an etched rule and what it separates.
    public var hair: CGFloat
    public var tight: CGFloat
    public var snug: CGFloat
    public var base: CGFloat
    public var cozy: CGFloat
    /// Gap between adjacent key caps — the moulded web between two buttons.
    public var key: CGFloat
    /// Inset from a well's wall to the controls it holds.
    public var panel: CGFloat
    /// Gap between two functional groups on the same panel.
    public var section: CGFloat
    /// Inset from the chassis edge to anything printed or mounted on it.
    public var chassis: CGFloat

    public init(
        hair: CGFloat = 2,
        tight: CGFloat = 4,
        snug: CGFloat = 6,
        base: CGFloat = 8,
        cozy: CGFloat = 10,
        key: CGFloat = 12,
        panel: CGFloat = 14,
        section: CGFloat = 18,
        chassis: CGFloat = 22
    ) {
        self.hair = hair
        self.tight = tight
        self.snug = snug
        self.base = base
        self.cozy = cozy
        self.key = key
        self.panel = panel
        self.section = section
        self.chassis = chassis
    }

    public static let standard = POSpacing()
}

/// Corner radii, sizes, travel and hit targets.
///
/// Corner radius encodes *manufacturing scale*: the moulded outer shell has
/// the largest radius, a milled recess less, a cut display window least of
/// all. Keeping that ordering is what stops the composition reading as nested
/// rounded rectangles and starts it reading as parts.
public struct POMetrics: Sendable, Equatable {

    public var spacing: POSpacing

    // MARK: - Corners

    /// Outer shell.
    public var chassisCorner: CGFloat
    /// A raised sub-panel.
    public var panelCorner: CGFloat
    /// A milled recess.
    public var wellCorner: CGFloat
    /// A cut display window — nearly square, because glass is cut, not moulded.
    public var displayCorner: CGFloat
    /// A key cap.
    public var keyCorner: CGFloat

    // MARK: - Strokes

    public var hairline: CGFloat

    // MARK: - Keys

    public var keyRegularSize: CGSize
    public var keyCompactSize: CGSize
    public var keyLargeSize: CGSize
    /// Vertical distance a cap moves when pressed.
    ///
    /// 1.5pt is the smallest offset that survives a 1× display and still reads
    /// as travel rather than as a jitter. Any more and the cap looks like it
    /// falls into the chassis; the reference hardware has roughly 0.6 mm of
    /// key travel, and this is that at typical viewing distance.
    public var keyTravel: CGFloat
    /// Extra offset a latched key rests at, between free and fully pressed —
    /// a toggle that has been switched on physically stays down.
    public var keyLatchedTravel: CGFloat
    /// Minimum edge of an interactive region, regardless of how small the
    /// printed cap is. Sub-target keys grow their hit area, not their cap.
    public var minimumHitTarget: CGFloat

    // MARK: - Fader

    public var faderTrackWidth: CGFloat
    public var faderLength: CGFloat
    public var faderCapSize: CGSize
    public var faderDetentTickLength: CGFloat
    /// Lateral gap from the track centreline to the printed detent ladder.
    public var faderDetentOffset: CGFloat

    // MARK: - Display

    public var displayHeight: CGFloat
    /// Glyph cell width as a fraction of cap height for a seven-segment face.
    public var segmentAspect: CGFloat
    /// Gap between glyph cells as a fraction of cap height.
    public var segmentGapRatio: CGFloat
    /// Segment bar thickness as a fraction of cap height.
    public var segmentThicknessRatio: CGFloat
    /// Glyph cell width as a fraction of cap height for a 5x7 dot-matrix face.
    public var dotMatrixAspect: CGFloat

    // MARK: - Meters

    public var levelBarSegmentSize: CGSize
    public var levelBarSpacing: CGFloat
    public var lampDiameter: CGFloat

    public init(
        spacing: POSpacing = .standard,
        chassisCorner: CGFloat = 10,
        panelCorner: CGFloat = 8,
        wellCorner: CGFloat = 8,
        displayCorner: CGFloat = 4,
        keyCorner: CGFloat = 7,
        hairline: CGFloat = 1,
        keyRegularSize: CGSize = CGSize(width: 68, height: 44),
        keyCompactSize: CGSize = CGSize(width: 56, height: 30),
        keyLargeSize: CGSize = CGSize(width: 92, height: 52),
        keyTravel: CGFloat = 1.5,
        keyLatchedTravel: CGFloat = 0.75,
        minimumHitTarget: CGFloat = 28,
        faderTrackWidth: CGFloat = 4,
        faderLength: CGFloat = 168,
        faderCapSize: CGSize = CGSize(width: 26, height: 14),
        faderDetentTickLength: CGFloat = 8,
        faderDetentOffset: CGFloat = 16,
        displayHeight: CGFloat = 96,
        segmentAspect: CGFloat = 0.55,
        segmentGapRatio: CGFloat = 0.18,
        segmentThicknessRatio: CGFloat = 0.085,
        dotMatrixAspect: CGFloat = 0.72,
        levelBarSegmentSize: CGSize = CGSize(width: 5, height: 14),
        levelBarSpacing: CGFloat = 2.5,
        lampDiameter: CGFloat = 8
    ) {
        self.spacing = spacing
        self.chassisCorner = chassisCorner
        self.panelCorner = panelCorner
        self.wellCorner = wellCorner
        self.displayCorner = displayCorner
        self.keyCorner = keyCorner
        self.hairline = hairline
        self.keyRegularSize = keyRegularSize
        self.keyCompactSize = keyCompactSize
        self.keyLargeSize = keyLargeSize
        self.keyTravel = keyTravel
        self.keyLatchedTravel = keyLatchedTravel
        self.minimumHitTarget = minimumHitTarget
        self.faderTrackWidth = faderTrackWidth
        self.faderLength = faderLength
        self.faderCapSize = faderCapSize
        self.faderDetentTickLength = faderDetentTickLength
        self.faderDetentOffset = faderDetentOffset
        self.displayHeight = displayHeight
        self.segmentAspect = segmentAspect
        self.segmentGapRatio = segmentGapRatio
        self.segmentThicknessRatio = segmentThicknessRatio
        self.dotMatrixAspect = dotMatrixAspect
        self.levelBarSegmentSize = levelBarSegmentSize
        self.levelBarSpacing = levelBarSpacing
        self.lampDiameter = lampDiameter
    }

    public static let standard = POMetrics()

    /// Padding needed on each axis to bring a control of `size` up to the
    /// minimum hit target without enlarging its printed cap.
    public func hitTargetPadding(for size: CGSize) -> CGSize {
        CGSize(
            width: max(0, (minimumHitTarget - size.width) / 2),
            height: max(0, (minimumHitTarget - size.height) / 2)
        )
    }
}

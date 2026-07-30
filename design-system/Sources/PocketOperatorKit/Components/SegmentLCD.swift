import SwiftUI

/// A driven segment display.
///
/// Three details separate this from "text in a green font", and all three are
/// load-bearing:
///
/// - **Unlit segments stay visible.** A real LCD's dead segments are still
///   printed on the glass. Without that ghost, a display is a label; with it,
///   a `1` obviously occupies the same cell as an `8`.
/// - **Cells are fixed-width and countable.** `capacity` reserves a physical
///   digit count, so a value changing from `9` to `10` does not reflow the
///   panel around it — the display has that many digits whether or not they
///   are in use.
/// - **The face has a repertoire.** A seven-segment part cannot form every
///   letter; see `SegmentFace`.
///
/// ```swift
/// SegmentLCD("0:03.2", size: 30, capacity: 6, alignment: .trailing)
/// SegmentLCD("KITCHEN", face: .dotMatrix, size: 13)
/// ```
@available(macOS 15, *)
public struct SegmentLCD: View {
    @Environment(\.poTheme) private var theme
    @Environment(\.poDisplayInk) private var inheritedInk

    private let text: String
    private let face: SegmentFace
    private let size: CGFloat
    private let capacity: Int?
    private let alignment: HorizontalAlignment
    private let onColor: Color?
    private let offOpacity: Double?
    private let showsGhostSegments: Bool
    private let hasGlow: Bool
    private let accessibilityLabel: String?
    private let accessibilityValue: String?

    /// - Parameters:
    ///   - text: The value to display. Uppercased on render.
    ///   - face: The display part this is pretending to be.
    ///   - size: Glyph cap height in points; cell width follows from the face.
    ///   - capacity: Number of physical cells. Extra cells render as unlit
    ///     ghosts. `nil` sizes the display to the text, which is right for a
    ///     status word and wrong for a counter.
    ///   - alignment: Which end the text sits at when `capacity` exceeds it.
    ///   - accessibilityValue: What the display currently reads. Defaults to
    ///     `text`; override when the raw string is not speakable — a timecode
    ///     is better spoken as "3.2 seconds" than as "zero colon zero three".
    public init(
        _ text: String,
        face: SegmentFace = .sevenSegment,
        size: CGFloat = 24,
        capacity: Int? = nil,
        alignment: HorizontalAlignment = .leading,
        onColor: Color? = nil,
        offOpacity: Double? = nil,
        showsGhostSegments: Bool = true,
        hasGlow: Bool = true,
        accessibilityLabel: String? = nil,
        accessibilityValue: String? = nil
    ) {
        self.text = text
        self.face = face
        self.size = size
        self.capacity = capacity
        self.alignment = alignment
        self.onColor = onColor
        self.offOpacity = offOpacity
        self.showsGhostSegments = showsGhostSegments
        self.hasGlow = hasGlow
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
    }

    public var body: some View {
        let layout = SegmentLayout(
            text: text,
            face: face,
            size: size,
            capacity: capacity,
            alignment: alignment,
            metrics: theme.metrics
        )
        let ink = onColor ?? inheritedInk ?? theme.colors.displayOn
        let ghost = offOpacity ?? theme.colors.displayOffOpacity

        Canvas(opaque: false) { context, _ in
            draw(
                layout: layout,
                ink: ink,
                ghostOpacity: showsGhostSegments ? ghost : 0,
                in: &context
            )
        }
        .frame(width: layout.totalWidth, height: size)
        // A `Canvas` is a single opaque rectangle to assistive technology.
        // Without this the display — usually the most important information on
        // the panel — is simply absent.
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel ?? "Display")
        .accessibilityValue(accessibilityValue ?? text)
    }

    /// Draws the whole string in three passes rather than per glyph.
    ///
    /// The glow is a blurred layer, and a blur is the expensive operation
    /// here; accumulating every lit segment into one path means a six-digit
    /// counter costs one blur per frame instead of forty-two.
    private func draw(
        layout: SegmentLayout,
        ink: Color,
        ghostOpacity: Double,
        in context: inout GraphicsContext
    ) {
        var lit = Path()
        var unlit = Path()

        for cell in layout.cells {
            switch face.kind {
            case .sevenSegment:
                appendSevenSegment(cell: cell, lit: &lit, unlit: &unlit)
            case .dotMatrix:
                appendDotMatrix(cell: cell, lit: &lit, unlit: &unlit)
            }
        }

        if ghostOpacity > 0 && !unlit.isEmpty {
            context.fill(unlit, with: .color(ink.opacity(ghostOpacity)))
        }
        guard !lit.isEmpty else { return }
        if hasGlow {
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: size * 0.12))
                layer.fill(lit, with: .color(ink.opacity(0.55)))
            }
        }
        context.fill(lit, with: .color(ink))
    }

    private func appendSevenSegment(cell: SegmentLayout.Cell, lit: inout Path, unlit: inout Path) {
        guard cell.character != " " else { return }

        if cell.character == ":" || cell.character == "." {
            let dot = cell.width * 0.55
            let x = cell.x + (cell.width - dot) / 2
            let ys: [CGFloat] = cell.character == ":"
                ? [size * 0.25, size * 0.66]
                : [size - dot * 1.4]
            for y in ys {
                let rect = CGRect(x: x, y: y, width: dot, height: dot)
                if cell.isLit {
                    lit.addEllipse(in: rect)
                } else {
                    unlit.addEllipse(in: rect)
                }
            }
            return
        }

        let mask = cell.isLit
            ? (face.sevenSegmentGlyphs[cell.character] ?? 0)
            : 0
        let thickness = max(1.6, size * theme.metrics.segmentThicknessRatio)
        // Segment ends are chamfered rather than square, and each bar is
        // inset from the cell edge — the wedge-shaped gap between adjacent
        // bars is the visual signature of a segment display.
        let inset = thickness * 0.6
        let width = cell.width
        let mid = size / 2

        func horizontal(_ y: CGFloat) -> Path {
            var path = Path()
            let x0 = cell.x + inset + thickness * 0.7
            let x1 = cell.x + width - inset - thickness * 0.7
            path.move(to: CGPoint(x: x0 - thickness / 2, y: y))
            path.addLine(to: CGPoint(x: x0, y: y - thickness / 2))
            path.addLine(to: CGPoint(x: x1, y: y - thickness / 2))
            path.addLine(to: CGPoint(x: x1 + thickness / 2, y: y))
            path.addLine(to: CGPoint(x: x1, y: y + thickness / 2))
            path.addLine(to: CGPoint(x: x0, y: y + thickness / 2))
            path.closeSubpath()
            return path
        }

        func vertical(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: x, y: y0 - thickness / 2))
            path.addLine(to: CGPoint(x: x + thickness / 2, y: y0))
            path.addLine(to: CGPoint(x: x + thickness / 2, y: y1))
            path.addLine(to: CGPoint(x: x, y: y1 + thickness / 2))
            path.addLine(to: CGPoint(x: x - thickness / 2, y: y1))
            path.addLine(to: CGPoint(x: x - thickness / 2, y: y0))
            path.closeSubpath()
            return path
        }

        let bars: [Path] = [
            horizontal(inset + thickness / 2),
            vertical(cell.x + width - inset - thickness / 2, inset + thickness, mid - thickness),
            vertical(cell.x + width - inset - thickness / 2, mid + thickness, size - inset - thickness),
            horizontal(size - inset - thickness / 2),
            vertical(cell.x + inset + thickness / 2, mid + thickness, size - inset - thickness),
            vertical(cell.x + inset + thickness / 2, inset + thickness, mid - thickness),
            horizontal(mid),
        ]

        for (bit, bar) in bars.enumerated() {
            if mask & (1 << bit) != 0 {
                lit.addPath(bar)
            } else {
                unlit.addPath(bar)
            }
        }
    }

    private func appendDotMatrix(cell: SegmentLayout.Cell, lit: inout Path, unlit: inout Path) {
        let rows = cell.isLit ? (face.dotMatrixGlyphs[cell.character] ?? []) : []
        let columns = 5
        let rowCount = 7
        let pitchX = cell.width / CGFloat(columns)
        let pitchY = size / CGFloat(rowCount)
        let diameter = min(pitchX, pitchY) * 0.78

        for row in 0..<rowCount {
            let bits = row < rows.count ? rows[row] : 0
            for column in 0..<columns {
                let rect = CGRect(
                    x: cell.x + (CGFloat(column) + 0.5) * pitchX - diameter / 2,
                    y: (CGFloat(row) + 0.5) * pitchY - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                if bits & (1 << (columns - 1 - column)) != 0 {
                    lit.addEllipse(in: rect)
                } else {
                    unlit.addEllipse(in: rect)
                }
            }
        }
    }
}

/// Cell geometry for one rendered string.
///
/// Computed as a value up front so the `Canvas` closure does no layout, and so
/// the view can report an exact intrinsic width — a display whose width
/// depends on its content would shove its neighbours around every time a digit
/// changed.
@available(macOS 15, *)
struct SegmentLayout {
    struct Cell {
        var character: Character
        var x: CGFloat
        var width: CGFloat
        /// Ghost cells beyond the value render their segments unlit.
        var isLit: Bool
    }

    let cells: [Cell]
    let totalWidth: CGFloat

    init(
        text: String,
        face: SegmentFace,
        size: CGFloat,
        capacity: Int?,
        alignment: HorizontalAlignment,
        metrics: POMetrics
    ) {
        let characters = Array(text.uppercased())
        let padding = max(0, (capacity ?? characters.count) - characters.count)
        let leadingGhosts = alignment == .trailing ? padding : 0
        let trailingGhosts = padding - leadingGhosts

        let sequence: [(Character, Bool)] =
            Array(repeating: (Character("8"), false), count: leadingGhosts)
            + characters.map { ($0, true) }
            + Array(repeating: (Character("8"), false), count: trailingGhosts)

        let gap = size * metrics.segmentGapRatio
        var cells: [Cell] = []
        var x: CGFloat = 0

        for (index, entry) in sequence.enumerated() {
            let width = Self.cellWidth(
                for: entry.0,
                face: face,
                size: size,
                metrics: metrics
            )
            cells.append(Cell(character: entry.0, x: x, width: width, isLit: entry.1))
            x += width
            if index < sequence.count - 1 { x += gap }
        }

        self.cells = cells
        self.totalWidth = max(0, x)
    }

    /// Punctuation gets a narrow cell on a seven-segment face — a colon
    /// occupies its own slim slot on real panels rather than a full digit.
    /// A dot-matrix part has uniform cells, so it does not.
    private static func cellWidth(
        for character: Character,
        face: SegmentFace,
        size: CGFloat,
        metrics: POMetrics
    ) -> CGFloat {
        switch face.kind {
        case .sevenSegment:
            switch character {
            case ":", ".": size * metrics.segmentAspect * 0.4
            case " ": size * metrics.segmentAspect * 0.5
            default: size * metrics.segmentAspect
            }
        case .dotMatrix:
            character == " " ? size * metrics.dotMatrixAspect * 0.6 : size * metrics.dotMatrixAspect
        }
    }
}

@available(macOS 15, *)
#Preview("Segment faces") {
    VStack(alignment: .leading, spacing: 16) {
        SegmentLCD("0:03.2", size: 34, capacity: 7, alignment: .trailing)
        SegmentLCD("REC", size: 20)
        SegmentLCD("----", size: 24, capacity: 4)
        SegmentLCD("PATTERN 04", face: .dotMatrix, size: 14)
        SegmentLCD("QUANTIZE 1/16", face: .dotMatrix, size: 11)
    }
    .padding(24)
    .background(Color.poHex(0x141B12))
}

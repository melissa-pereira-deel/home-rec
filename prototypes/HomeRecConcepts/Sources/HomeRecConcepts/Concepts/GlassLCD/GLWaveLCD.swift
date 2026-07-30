import SwiftUI

/// The Pocket Operator's display, transplanted into the glass panel: same
/// recessed bed, black bezel, aluminium ring and screen-green phosphor — but
/// where the PO shows 7-seg status words, this shows only the waveform.
///
/// The adaptation that makes it read as an LCD rather than a tinted copy of
/// `BarWaveform` is quantisation: each column is snapped onto a fixed
/// nine-cell segment grid, and unquantised cells stay faintly visible the way
/// unlit LCD segments do. A bar can only be 1, 3, 5, 7 or 9 cells tall, always
/// symmetric about the centre row, so the capture steps rather than curves.
struct GLWaveLCD: View {
    var samples: [Float]
    /// Live capture scrolls in from the trailing edge (the ring buffer's
    /// newest sample); a finished take is resampled to fill the whole grid.
    var scrolling: Bool
    /// Dimmed for the frozen `.stopping` frame — never a dead black screen.
    var intensity: Double = 1

    /// Odd, so a bar can be centred on a single row at rest.
    private let rows = 9
    private let cellWidth: CGFloat = 3
    private let columnGap: CGFloat = 2
    private let rowGap: CGFloat = 1.5
    /// Unlit segments never disappear on a real LCD — they sit just above the
    /// bed. This is the tell that separates the panel from a black rectangle.
    private let ghostOpacity = 0.075

    var body: some View {
        Canvas { context, size in
            let pitch = cellWidth + columnGap
            let columns = max(1, Int((size.width + columnGap) / pitch))
            let cellHeight = (size.height - rowGap * CGFloat(rows - 1)) / CGFloat(rows)
            guard cellHeight > 0 else { return }

            var litPath = Path()
            var ghostPath = Path()
            let centreRow = (rows - 1) / 2

            for column in 0..<columns {
                let litRows = litRowCount(column: column, of: columns)
                let reach = (litRows - 1) / 2
                for row in 0..<rows {
                    let rect = CGRect(
                        x: CGFloat(column) * pitch,
                        y: CGFloat(row) * (cellHeight + rowGap),
                        width: cellWidth,
                        height: cellHeight
                    )
                    let cell = Path(roundedRect: rect, cornerRadius: 0.5)
                    if abs(row - centreRow) <= reach {
                        litPath.addPath(cell)
                    } else {
                        ghostPath.addPath(cell)
                    }
                }
            }

            context.fill(ghostPath, with: .color(POTheme.lcdLit.opacity(ghostOpacity)))
            // Bloom pass first, crisp segments over it — phosphor, not stickers.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 2.4))
                layer.fill(litPath, with: .color(POTheme.lcdLit.opacity(0.5 * intensity)))
            }
            context.fill(litPath, with: .color(POTheme.lcdLit.opacity(intensity)))
        }
        .frame(height: 52)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(POTheme.lcdBed)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        // Bezel: hard black edge inside, brushed ring outside — the PO's
        // recess, reproduced so the screen sits *in* the glass, not on it.
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(.black.opacity(0.9), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                .padding(-1)
        )
        .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
        .accessibilityHidden(true)
    }

    /// How many cells of a column light, snapped to the odd ladder so bars
    /// stay symmetric: 1 · 3 · 5 · 7 · 9.
    private func litRowCount(column: Int, of columns: Int) -> Int {
        guard !samples.isEmpty else { return 1 }
        let sample: Float
        if scrolling {
            // Trailing window of the ring buffer, right-aligned: the newest
            // sample is always at the right edge, older ones march left.
            let start = samples.count - columns
            let index = start + column
            sample = index >= 0 ? samples[index] : 0
        } else {
            sample = samples[min(samples.count - 1, column * samples.count / columns)]
        }
        // Modest gain: quiet passages should still lift off the centre line
        // rather than flattening into an indistinguishable idle screen.
        let magnitude = min(1, Double(sample) * 1.15)
        let steps = ((magnitude * Double(rows)).rounded() + 1) / 2
        return min(rows, max(1, Int(steps) * 2 - 1))
    }
}

#Preview("Wave LCD") {
    VStack(spacing: 18) {
        GLWaveLCD(samples: WaveformFactory.identity(seed: 23), scrolling: false)
        GLWaveLCD(samples: Array(repeating: 0.04, count: 96), scrolling: false)
    }
    .padding(30)
    .frame(width: 420)
    .background(Color(red: 0.11, green: 0.11, blue: 0.12))
}

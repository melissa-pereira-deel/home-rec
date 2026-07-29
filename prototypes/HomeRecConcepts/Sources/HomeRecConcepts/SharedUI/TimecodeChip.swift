import SwiftUI

/// Floating timecode capsule that rides the playhead — the untitled.stream
/// detail. The capsule clamps inside the bounds (measured, not guessed) but
/// the stem stays on the TRUE playhead x so it never points at empty space.
/// Format is pinned to the recording's duration so width never jumps.
struct TimecodeChip: View {
    var time: TimeInterval
    /// 0...1 position across the parent width.
    var progress: Double
    /// Total duration — decides the timecode format (tenths / m:ss / h:mm:ss).
    var duration: TimeInterval = 0

    var body: some View {
        GeometryReader { geo in
            let text = Formatters.timecode(time, matching: max(duration, time))
            // SF Mono 10pt medium: ~6.1pt per glyph + capsule padding.
            let chipWidth = CGFloat(text.count) * 6.1 + 16
            let trueX = geo.size.width * progress
            let clampedX = min(max(trueX, chipWidth / 2), geo.size.width - chipWidth / 2)

            ZStack {
                Text(text)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.8), in: Capsule())
                    .position(x: clampedX, y: geo.size.height / 2 - 3)
                // Stem tick down to the actual playhead.
                Rectangle()
                    .fill(.white.opacity(0.7))
                    .frame(width: 1, height: 5)
                    .position(x: trueX, y: geo.size.height - 2.5)
            }
            .animation(.linear(duration: 1 / 30), value: progress)
        }
        .frame(height: 26)
    }
}

#Preview("Timecode chip") {
    VStack(spacing: 20) {
        TimecodeChip(time: 151, progress: 0.42, duration: 154)
            .frame(width: 380)
        TimecodeChip(time: 20, progress: 0.02, duration: 4323)
            .frame(width: 380)
        TimecodeChip(time: 4200, progress: 0.98, duration: 4323)
            .frame(width: 380)
    }
    .padding(30)
    .background(Color.black)
}

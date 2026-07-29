import SwiftUI

/// Floating timecode capsule that rides the playhead — the untitled.stream
/// detail. Clamped so it never leaves the waveform's bounds.
struct TimecodeChip: View {
    var time: TimeInterval
    /// 0...1 position across the parent width.
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            let x = min(max(geo.size.width * progress, 26), geo.size.width - 26)
            VStack(spacing: 0) {
                Text(Formatters.timecode(time, tenths: time < 60))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.8), in: Capsule())
                // Stem tick down to the playhead.
                Rectangle()
                    .fill(.white.opacity(0.7))
                    .frame(width: 1, height: 5)
            }
            .position(x: x, y: geo.size.height / 2)
            .animation(.linear(duration: 1 / 30), value: progress)
        }
        .frame(height: 26)
    }
}

#Preview("Timecode chip") {
    VStack {
        TimecodeChip(time: 151, progress: 0.42)
            .frame(width: 380)
    }
    .padding(30)
    .background(Color.black)
}

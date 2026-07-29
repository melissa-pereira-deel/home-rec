import SwiftUI

/// Tick-ruler slider in the untitled.stream style: no filled track, just a
/// field of hairline ticks and one accent indicator. Drag anywhere to set.
struct TickRuler: View {
    @Binding var value: Double   // 0...1
    var accent: Color
    var tickColor: Color = .white
    /// Fired with `true` on the first drag change, `false` on release — lets
    /// the owner suspend a playback task so it can't fight the drag.
    var onEditingChanged: ((Bool) -> Void)? = nil

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let pitch: CGFloat = 3
                let count = Int(size.width / pitch)
                for i in 0...count {
                    let x = CGFloat(i) * pitch
                    let major = i.isMultiple(of: 10)
                    let h: CGFloat = major ? 8 : 4
                    context.fill(
                        Path(CGRect(x: x, y: (size.height - h) / 2, width: 1, height: h)),
                        with: .color(tickColor.opacity(major ? 0.5 : 0.3))
                    )
                }
                // Accent indicator: triangle above a full-height line.
                let x = size.width * value
                context.fill(
                    Path(CGRect(x: x - 0.75, y: 2, width: 1.5, height: size.height - 4)),
                    with: .color(accent)
                )
                var triangle = Path()
                triangle.move(to: CGPoint(x: x - 3.5, y: 0))
                triangle.addLine(to: CGPoint(x: x + 3.5, y: 0))
                triangle.addLine(to: CGPoint(x: x, y: 4))
                triangle.closeSubpath()
                context.fill(triangle, with: .color(accent))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isDragging {
                            isDragging = true
                            onEditingChanged?(true)
                        }
                        value = min(1, max(0, drag.location.x / geo.size.width))
                    }
                    .onEnded { _ in
                        isDragging = false
                        onEditingChanged?(false)
                    }
            )
        }
        .frame(height: 18)
        // A Canvas + DragGesture is invisible to assistive tech; expose it
        // as the slider it behaves as.
        .accessibilityRepresentation {
            Slider(value: $value, in: 0...1) {
                Text("position")
            }
        }
    }
}

#Preview("Tick ruler") {
    struct Host: View {
        @State private var v = 0.42
        var body: some View {
            TickRuler(value: $v, accent: Color(red: 1.0, green: 0.24, blue: 0.24))
                .frame(width: 380)
                .padding(30)
                .background(Color.black)
        }
    }
    return Host()
}

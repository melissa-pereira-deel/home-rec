import SwiftUI

/// Vertical gain fader: 4pt track, scored cap, light snap to ten detents.
struct POFader: View {
    @Binding var value: Double   // 0...1, 1 = top

    private let trackHeight: CGFloat = 168
    private let capSize = CGSize(width: 26, height: 14)

    var body: some View {
        VStack(spacing: 8) {
            POTheme.microLabel("GAIN")
            GeometryReader { geo in
                ZStack {
                    // Detent ticks.
                    ForEach(0..<11, id: \.self) { i in
                        Rectangle()
                            .fill(POTheme.rule)
                            .frame(width: 8, height: 1)
                            .position(
                                x: geo.size.width / 2 + 16,
                                y: y(for: Double(i) / 10, in: geo.size.height)
                            )
                    }
                    // Track.
                    Capsule()
                        .fill(.black)
                        .frame(width: 4)
                        .overlay(
                            Capsule().strokeBorder(Color(white: 0.16), lineWidth: 1)
                        )
                    // Cap: aluminum block with a scored center line.
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [POTheme.aluTop, POTheme.aluBottom],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: capSize.width, height: capSize.height)
                        .overlay(
                            Rectangle()
                                .fill(.black.opacity(0.55))
                                .frame(height: 1.5)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                        .position(x: geo.size.width / 2, y: y(for: value, in: geo.size.height))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let fraction = Double(drag.location.y / geo.size.height)
                            value = min(1, max(0, 1 - fraction))
                        }
                        .onEnded { _ in
                            // Light detent snap.
                            withAnimation(.spring(response: 0.15, dampingFraction: 0.9)) {
                                value = (value * 10).rounded() / 10
                            }
                        }
                )
            }
            .frame(width: 44, height: trackHeight)
        }
    }

    private func y(for value: Double, in height: CGFloat) -> CGFloat {
        let inset = capSize.height / 2
        return inset + (1 - value) * (height - inset * 2)
    }
}

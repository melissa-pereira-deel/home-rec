import SwiftUI
import AppKit

/// A physical key: cap over plinth, real travel on press. Press-in is fast
/// (keys go down instantly), release springs back with a slight clack.
/// Concepts style the cap; this owns the physics.
struct PressableKeyStyle: ButtonStyle {
    var travel: CGFloat = 1.5
    var cornerRadius: CGFloat = 7
    var baseColor: Color = Color(white: 0.05)
    var hapticOnPress = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? travel : 0)
            .shadow(
                color: .black.opacity(configuration.isPressed ? 0.35 : 0.5),
                radius: configuration.isPressed ? 1.5 : 5,
                y: configuration.isPressed ? 1 : 3
            )
            .background(alignment: .bottom) {
                // Plinth the cap sinks toward.
                RoundedRectangle(cornerRadius: cornerRadius + 1)
                    .fill(baseColor)
                    .padding(.horizontal, -1)
                    .padding(.top, 2)
                    .padding(.bottom, -2)
            }
            .overlay {
                // Darken the cap face slightly while pressed.
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.black.opacity(configuration.isPressed ? 0.08 : 0))
                    .offset(y: configuration.isPressed ? travel : 0)
                    .allowsHitTesting(false)
            }
            .animation(
                configuration.isPressed
                    ? .easeOut(duration: 0.05)
                    : .spring(response: 0.18, dampingFraction: 0.55),
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && hapticOnPress {
                    NSHapticFeedbackManager.defaultPerformer
                        .perform(.generic, performanceTime: .now)
                }
            }
    }
}

#Preview("Pressable keys") {
    HStack(spacing: 20) {
        Button {} label: {
            Text("REC")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.black.opacity(0.8))
                .frame(width: 52, height: 36)
                .background(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.47, blue: 0.10),
                                 Color(red: 0.88, green: 0.36, blue: 0.02)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 7)
                )
        }
        .buttonStyle(PressableKeyStyle())

        Button {} label: {
            Text("STOP")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.black.opacity(0.7))
                .frame(width: 44, height: 28)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.78, green: 0.80, blue: 0.82),
                                 Color(red: 0.61, green: 0.63, blue: 0.65)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 7)
                )
        }
        .buttonStyle(PressableKeyStyle())
    }
    .padding(40)
    .background(Color(white: 0.09))
}

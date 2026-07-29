import SwiftUI

/// One lozenge key: aluminum (or orange) cap on the rubber bed, printed
/// label, real press travel via PressableKeyStyle.
struct POChassisKey: View {
    enum Kind {
        case aluminum
        case orange
        case orangeDisarmed
    }

    var label: String
    var kind: Kind = .aluminum
    var width: CGFloat = 68
    var height: CGFloat = 44
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(
                    size: kind == .aluminum ? 10 : 11,
                    weight: kind == .aluminum ? .medium : .bold,
                    design: .monospaced
                ))
                .tracking(0.5)
                .foregroundStyle(.black.opacity(kind == .aluminum ? 0.65 : 0.8))
                .frame(width: width, height: height)
                .background(capGradient, in: RoundedRectangle(cornerRadius: 7))
                .overlay(
                    // Top bevel highlight — the machined edge.
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .clear],
                                startPoint: .top, endPoint: .center
                            ),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(PressableKeyStyle())
    }

    private var capGradient: LinearGradient {
        switch kind {
        case .aluminum:
            LinearGradient(
                colors: [POTheme.aluTop, POTheme.aluBottom],
                startPoint: .top, endPoint: .bottom
            )
        case .orange:
            LinearGradient(
                colors: [POTheme.orange, POTheme.orangeBottom],
                startPoint: .top, endPoint: .bottom
            )
        case .orangeDisarmed:
            LinearGradient(
                colors: [POTheme.orangeDisarmed, POTheme.orangeDisarmed.opacity(0.8)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}

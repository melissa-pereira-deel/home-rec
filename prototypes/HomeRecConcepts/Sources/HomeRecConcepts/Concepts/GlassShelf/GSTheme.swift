import SwiftUI

/// Glass shelf, metal heart: frosted materials, warm charcoal cards, and the
/// brand red — the single accent — reserved for the record state.
enum GSTheme {
    /// Brand red, pulled ~5% darker than the wordmark's #FF3E3E — large
    /// solid fills (the pills) read hotter than thin strokes, so the flat
    /// UI wants a slightly deeper tone.
    static let accent = Color(red: 0.949, green: 0.227, blue: 0.227)      // #F23A3A
    static let accentDeep = Color(red: 0.78, green: 0.13, blue: 0.13)
    static let card = Color(red: 0.110, green: 0.110, blue: 0.118)        // #1C1C1E
    static let metalBase = Color(red: 0.557, green: 0.573, blue: 0.596)   // #8E9298
    static let textDim = Color(red: 0.557, green: 0.557, blue: 0.576)     // #8E8E93
    /// Warning tone (long-recording notice) — amber, distinct from the error red.
    static let warnAmber = Color(red: 0.92, green: 0.66, blue: 0.18)
    /// Confirmation tone (permission granted) — systemGreen's dark-mode value.
    static let okGreen = Color(red: 0.188, green: 0.820, blue: 0.345)      // #30D158

    /// The backdrop the glass has something to blur: a quiet deep-blue mesh.
    @ViewBuilder
    static var backdrop: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.55, 0.45], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                Color(red: 0.05, green: 0.07, blue: 0.13),
                Color(red: 0.10, green: 0.12, blue: 0.22),
                Color(red: 0.05, green: 0.06, blue: 0.10),
                Color(red: 0.08, green: 0.10, blue: 0.19),
                Color(red: 0.13, green: 0.14, blue: 0.25),
                Color(red: 0.06, green: 0.08, blue: 0.14),
                Color(red: 0.04, green: 0.05, blue: 0.09),
                Color(red: 0.07, green: 0.08, blue: 0.15),
                Color(red: 0.05, green: 0.06, blue: 0.11),
            ]
        )
    }

    static func lowercase(_ text: String, size: CGFloat = 12) -> some View {
        Text(text)
            .font(.custom("Inter", size: size, relativeTo: .body))
            .foregroundStyle(.white.opacity(0.9))
    }

    static func mono(_ text: String, size: CGFloat = 10) -> some View {
        Text(text)
            .font(.system(size: size, design: .monospaced))
            .foregroundStyle(textDim)
    }
}

/// Navigation text with real affordance: 24pt hit area, hover background,
/// pointing-hand cursor — interactive text must not read as metadata.
struct GSNavLink: View {
    let label: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(hovering ? .white.opacity(0.9) : GSTheme.textDim)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(
                    hovering ? Color.white.opacity(0.07) : .clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            if isHovering, !hovering { NSCursor.pointingHand.push() }
            if !isHovering, hovering { NSCursor.pop() }
            hovering = isHovering
        }
        .onDisappear {
            if hovering {
                NSCursor.pop()
                hovering = false
            }
        }
    }
}

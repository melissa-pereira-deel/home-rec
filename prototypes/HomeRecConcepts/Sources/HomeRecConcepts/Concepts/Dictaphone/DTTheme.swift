import SwiftUI

/// Warm tape-machine palette: charcoal chassis, cream faceplate, signal-red
/// lamp, amber counter — mechanical and reassuring.
enum DTTheme {
    static let chassis = Color(red: 0.169, green: 0.165, blue: 0.157)      // #2B2A28
    static let cream = Color(red: 0.929, green: 0.902, blue: 0.839)        // #EDE6D6
    static let creamShadow = Color(red: 0.839, green: 0.808, blue: 0.741)
    static let lampRed = Color(red: 0.878, green: 0.227, blue: 0.184)      // #E03A2F
    static let lampDead = Color(red: 0.353, green: 0.169, blue: 0.153)     // #5A2B27
    static let amber = Color(red: 1.0, green: 0.690, blue: 0.125)          // #FFB020
    static let counterBed = Color(red: 0.114, green: 0.090, blue: 0.071)   // #1D1712
    static let tape = Color(red: 0.090, green: 0.082, blue: 0.075)         // #171513
    static let ink = Color(red: 0.169, green: 0.169, blue: 0.169)          // #2B2B2B

    static func engraved(_ text: String, size: CGFloat = 9) -> some View {
        Text(text)
            .font(.custom("Inter", size: size, relativeTo: .caption2))
            .tracking(0.8)
            .foregroundStyle(cream.opacity(0.45))
    }
}

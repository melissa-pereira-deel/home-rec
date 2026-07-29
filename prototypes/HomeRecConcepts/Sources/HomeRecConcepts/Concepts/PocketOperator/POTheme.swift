import SwiftUI

/// The five-color contract, TE-style: black chassis, industrial orange for
/// the armed thing, aluminum structure, screen-green display, printed grey.
enum POTheme {
    static let chassis = Color(red: 0.039, green: 0.039, blue: 0.039)      // #0A0A0A
    static let panelInset = Color(red: 0.067, green: 0.071, blue: 0.078)   // #111214
    static let rubberBed = Color(red: 0.086, green: 0.086, blue: 0.086)    // #161616
    static let aluTop = Color(red: 0.784, green: 0.800, blue: 0.816)       // #C8CCD0
    static let aluBottom = Color(red: 0.608, green: 0.627, blue: 0.651)    // #9BA0A6
    static let orange = Color(red: 1.0, green: 0.40, blue: 0.0)            // #FF6600
    static let orangeBottom = Color(red: 0.761, green: 0.306, blue: 0.008) // #C24E00
    static let orangeDisarmed = Color(red: 0.353, green: 0.290, blue: 0.243) // #5A4A3E
    static let lcdBed = Color(red: 0.078, green: 0.106, blue: 0.071)       // #141B12
    static let lcdLit = Color(red: 0.608, green: 0.910, blue: 0.439)       // #9BE870
    static let label = Color(red: 0.478, green: 0.498, blue: 0.522)        // #7A7F85
    static let rule = Color(red: 0.227, green: 0.227, blue: 0.227)         // #3A3A3A

    static func microLabel(_ text: String, size: CGFloat = 8) -> some View {
        Text(text)
            .font(.system(size: size, weight: .medium, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(label)
    }
}

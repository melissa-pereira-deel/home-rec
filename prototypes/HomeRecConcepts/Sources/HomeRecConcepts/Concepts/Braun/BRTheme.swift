import SwiftUI

/// Rams-calm palette: warm greys, black ink, one red dot, one green dot.
/// Tactility through restraint — nothing pulses at idle.
enum BRTheme {
    static let chassis = Color(red: 0.910, green: 0.894, blue: 0.863)   // #E8E4DC
    static let face = Color(red: 0.949, green: 0.937, blue: 0.914)      // #F2EFE9
    static let grilleDot = Color(red: 0.839, green: 0.824, blue: 0.788) // #D6D2C9
    static let rim = Color(red: 0.788, green: 0.769, blue: 0.729)       // #C9C4BA
    static let label = Color(red: 0.431, green: 0.416, blue: 0.384)     // #6E6A62
    static let ink = Color(red: 0.169, green: 0.169, blue: 0.169)       // #2B2B2B
    static let recordRed = Color(red: 0.851, green: 0.231, blue: 0.169) // #D93B2B
    static let readyGreen = Color(red: 0.243, green: 0.557, blue: 0.318) // #3E8E51
    static let cardBorder = Color(red: 0.867, green: 0.847, blue: 0.808) // #DDD8CE

    static func engraved(_ text: String, size: CGFloat = 9) -> some View {
        Text(text)
            .font(.custom("Inter", size: size, relativeTo: .caption2))
            .tracking(0.8)
            .foregroundStyle(label)
    }
}

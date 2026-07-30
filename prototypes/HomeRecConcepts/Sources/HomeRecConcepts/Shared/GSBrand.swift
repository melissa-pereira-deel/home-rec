import SwiftUI

/// The brand lockup, as homerec.app publishes it.
///
/// The site is the brand's published form, so the app matches the site rather
/// than the other way round. Two things come from it verbatim:
///
/// - **The name is "Home Rec".** The lowercase register everywhere else in
///   this UI is the *interface voice* — labels, controls, metadata. A product
///   name is not a UI label, and "home rec" in the header was the interface
///   voice leaking onto the brand.
/// - **The wordmark is Archivo medium at −0.02em**, matching `.logo-name` in
///   the site's stylesheet (`font-weight: 500; letter-spacing: -0.02em`).
///
/// Mirrored in GlassKit as `GlassBrand` / `GlassBrandLockup`; the two are kept
/// deliberately identical, and the design system is the copy that ships.
enum GSBrand {
    static let name = "Home Rec"

    /// Wordmark text at any size. Tracking is −0.02em, resolved per size.
    static func wordmark(size: CGFloat) -> some View {
        Text(name)
            .font(.custom("Archivo", size: size, relativeTo: .body).weight(.medium))
            .tracking(size * -0.02)
            .lineLimit(1)
    }
}

/// The Home Rec mark: rounded square, red record dot.
///
/// A direct port of the site's `favicon.svg` — every proportion is the SVG's
/// number over its 32-unit viewBox (`rx="7"`, dot `r="6.5"`, square stroke
/// `1.5`, inset `0.75`), so it is exact at any point size.
///
/// Drawn rather than the shipped PNG: the 180pt touch icon carries its own
/// white canvas, which at 18pt has to be oversized and re-clipped to look
/// right — a fudge that lands within half a pixel instead of on it. This needs
/// no asset and no correction.
struct GSBrandMark: View {
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 7 / 32, style: .continuous)
                .fill(Color(red: 0.165, green: 0.165, blue: 0.165))       // #2A2A2A
                .overlay(
                    RoundedRectangle(cornerRadius: size * 7 / 32, style: .continuous)
                        .strokeBorder(
                            Color(red: 0.502, green: 0.502, blue: 0.502), // #808080
                            lineWidth: size * 1.5 / 32
                        )
                )
                .padding(size * 0.75 / 32)

            Circle()
                .fill(Color(red: 1.0, green: 0.243, blue: 0.243))         // #FF3E3E
                .frame(width: size * 13 / 32, height: size * 13 / 32)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

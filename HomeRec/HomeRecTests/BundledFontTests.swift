//
//  BundledFontTests.swift
//  HomeRecTests
//
//  That the bundled fonts resolve by the names the code asks for.
//
//  This guards a failure that is otherwise completely silent. Fonts are
//  registered at runtime from the app bundle, and both the app's own views and
//  the design system look them up by name — the design system through
//  `NSFont(name:)`, whose result it caches for the process lifetime. A miss
//  throws nothing and logs nothing: SwiftUI simply falls back to the system font
//  at the same size, so the app stays correctly proportioned and quietly wears
//  the wrong face.
//
//  It is also not a hypothetical mismatch. `Inter.ttf` carries the PostScript
//  name "Inter-Regular" but the family name "Inter", and `Archivo-Variable.ttf`
//  reports the family "Archivo SemiBold" with "Archivo" only as its typographic
//  family. The two name tables are genuinely different shapes, and the lookups
//  depend on which one resolution finds.
//

import Testing
import AppKit
@testable import HomeRec

@MainActor
struct BundledFontTests {

    /// The names used across the app's views and by `GlassTypography`.
    @Test("Bundled font families resolve by the names the code uses", arguments: ["Inter", "Archivo"])
    func familiesResolve(_ family: String) {
        #expect(
            NSFont(name: family, size: 12) != nil,
            """
            \(family) did not resolve. Everything still renders — in the system \
            font — so this will not look broken, only wrong.
            """
        )
    }

    /// The design system applies a 1pt optical correction to its largest button
    /// label, but only when the custom face actually loaded. If the fonts stop
    /// resolving, that correction has to stop with them, or the label sits a
    /// point off centre in a font that never needed the nudge.
    @Test("The design system agrees that the custom family is available")
    func designSystemSeesCustomFamily() {
        #expect(GlassTypography.standard.usesCustomUIFamily)
    }
}

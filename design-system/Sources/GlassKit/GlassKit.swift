//
//  GlassKit
//
//  A SwiftUI design system for Home Rec's "Glass" register: frosted panels
//  over a quiet deep-blue ground, warm charcoal cards, monospace metadata,
//  lowercase controls, and exactly one accent — brand red — spent on the
//  record state and nothing else.
//
//  The kit is organised in four layers, each of which may only depend on the
//  ones above it:
//
//    Tokens      colour roles, type scale, spacing, radii, materials, motion
//    Primitives  surfaces, pills, chips, badges, labels, icon buttons, links
//    Components  transport control, timecode, waveform, take row, notices…
//    Patterns    cross-cutting rules that are behaviour, not pixels
//
//  Nothing below Tokens may contain a literal colour, font size, corner
//  radius or duration. If a component needs a number that isn't in the token
//  layer, that number is either local geometry (documented at its use site)
//  or a missing token.
//
//  Theme injection
//  ---------------
//  Every component resolves its look from `EnvironmentValues.glassTheme`.
//  Host apps that want to re-skin the kit pass their own `GlassTheme`:
//
//      ContentView().glassTheme(.standard)
//
//  Platform
//  --------
//  macOS 15+. The package's deployment target already guarantees this, so
//  per-declaration `@available` is only spelled out where a symbol depends on
//  an OS feature newer than the kit's own floor (see `GlassBackdrop`).
//

import SwiftUI

/// Kit-level metadata, surfaced in the gallery so a specimen sheet can never
/// be mistaken for a different version of the system than the one it renders.
public enum GlassKit {
    /// Semantic version of the design system contract (tokens + public API).
    public static let version = "1.0.0"

    /// Human-readable name used in the gallery header and documentation.
    public static let name = "GlassKit"
}

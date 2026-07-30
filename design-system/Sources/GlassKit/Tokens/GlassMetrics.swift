import SwiftUI

// MARK: - Spacing

/// The spacing scale.
///
/// A 2pt base with a deliberate gap above 14: the kit has *dense* rhythms
/// (metadata lines, chip rows) and *architectural* ones (panel padding,
/// window inset), and nothing in between reads as intentional. Values in the
/// dense band step by 2, the architectural band by 4–6.
///
/// | token | pt | typical use |
/// |---|---|---|
/// | `xxs` | 2 | badge inner padding, hairline offsets |
/// | `xs`  | 4 | icon-to-label inside a dense row |
/// | `sm`  | 6 | shelf card stack, chip row |
/// | `s`   | 8 | notice action row, waveform inset |
/// | `m`   | 10 | row content spacing |
/// | `md`  | 12 | the default gap between siblings |
/// | `l`   | 14 | expanded card padding |
/// | `xl`  | 18 | panel padding |
/// | `xxl` | 22 | window inset around the panel |
/// | `xxxl`| 28 | modal card padding, major separations |
public enum GlassSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 6
    public static let s: CGFloat = 8
    public static let m: CGFloat = 10
    public static let md: CGFloat = 12
    public static let l: CGFloat = 14
    public static let xl: CGFloat = 18
    public static let xxl: CGFloat = 22
    public static let xxxl: CGFloat = 28

    /// Ordered scale, for token inspectors and the gallery.
    public static let all: [(name: String, value: CGFloat)] = [
        ("xxs", xxs), ("xs", xs), ("sm", sm), ("s", s), ("m", m),
        ("md", md), ("l", l), ("xl", xl), ("xxl", xxl), ("xxxl", xxxl),
    ]
}

// MARK: - Radii

/// Corner radii.
///
/// The system nests three radii and the relationship between them is the
/// rule: an inner corner is always *smaller* than the corner it sits inside,
/// by roughly the padding between them, so the two curves stay concentric.
/// Panel 22 − 18pt padding ≈ card 12 is not a coincidence.
public enum GlassRadius {
    /// The floating window itself.
    public static let window: CGFloat = 12
    /// Frosted panels and modal cards.
    public static let panel: CGFloat = 22
    /// Expanded/active cards — one step up from `card` so a row that expands
    /// visibly gains hierarchy rather than just height.
    public static let cardLarge: CGFloat = 14
    /// Cards, rows, notices.
    public static let card: CGFloat = 12
    /// Cards nested inside cards (shelf entries, inline explainers).
    public static let inner: CGFloat = 10
    /// Small hit-area backgrounds (nav link hover).
    public static let control: CGFloat = 6
    /// Pills and chips use a true capsule, never a large fixed radius: a
    /// capsule stays a capsule when Dynamic Type grows the control.
    public static let pill: CGFloat = .infinity

    public static let all: [(name: String, value: CGFloat)] = [
        ("control", control), ("inner", inner), ("card", card),
        ("cardLarge", cardLarge), ("window", window), ("panel", panel),
    ]
}

// MARK: - Metrics

/// Control sizing, hit targets, stroke widths and the shared geometry that
/// more than one component depends on.
public struct GlassMetrics {

    // MARK: Hit targets

    /// The floor for any interactive element. macOS has no 44pt convention,
    /// but it does have people with tremor and trackpads: 28pt is the size at
    /// which the kit's own icon buttons and mini pills stop being a coin toss,
    /// and every control expands its *hit* region to at least this even when
    /// its *visual* is smaller.
    public var minimumHitTarget: CGFloat = 28

    // MARK: Control heights

    /// Primary transport pill.
    public var controlHeightLarge: CGFloat = 44
    /// Secondary actions (open settings, onboarding neutral pill).
    public var controlHeightMedium: CGFloat = 36
    /// In-row transport (play/pause).
    public var controlHeightSmall: CGFloat = 32
    /// Recording-bar stop, notice actions.
    public var controlHeightCompact: CGFloat = 30
    /// Inline confirmations (delete/keep, dismiss). Visually 26; the hit
    /// region is padded out to `minimumHitTarget`.
    public var controlHeightMini: CGFloat = 26

    // MARK: Strokes

    /// Every border in the system is 1pt. Hairlines differ by *opacity*, not
    /// by width — a 0.5pt line disappears on a non-Retina display and a 2pt
    /// line reads as a frame.
    public var hairline: CGFloat = 1

    // MARK: Waveform

    /// Bar width for every waveform variant. Shared so a thumbnail and the
    /// player read as the same instrument at two sizes.
    public var waveformBarWidth: CGFloat = 2
    public var waveformBarSpacing: CGFloat = 1
    /// Opacity of the unplayed portion of a waveform.
    public var waveformDimOpacity: Double = 0.28
    /// Thumbnail size in a take row.
    public var waveformThumbnailSize = CGSize(width: 96, height: 28)
    /// The live trace on the recorder face.
    public var waveformLiveHeight: CGFloat = 44
    /// The player waveform in an expanded row.
    public var waveformPlayerHeight: CGFloat = 72

    // MARK: Fixed slots

    /// Height of the onboarding card's conditional slot.
    ///
    /// Fixed on purpose. The slot swaps between "open System Settings" (a
    /// pill plus a two-line caption) and "Ready to record" (one line) the
    /// instant permission lands — often while the user is looking at it. A
    /// flexible slot would move the primary CTA out from under the cursor.
    public var onboardingSlotHeight: CGFloat = 76
    /// Onboarding card size — a modal card, not a resizable window.
    public var onboardingCardSize = CGSize(width: 420, height: 430)

    /// Diameter of the recording-bar pulse dot.
    public var pulseDotSize: CGFloat = 9
    /// Height of the scrub ruler's tick field.
    public var rulerHeight: CGFloat = 18
    /// Horizontal pitch between ruler ticks.
    public var rulerTickPitch: CGFloat = 3

    public init() {}

    public static let standard = GlassMetrics()
}

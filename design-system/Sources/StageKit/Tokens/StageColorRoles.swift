import SwiftUI

/// Semantic weight of a piece of stage text.
///
/// Tones exist instead of raw colours so that a component never has to know
/// which theme it is drawn in — it asks for "muted" and the theme decides.
@available(macOS 15.0, *)
public enum StageTone: Hashable, CaseIterable {
    /// The single element in a group that is currently selected.
    case strong
    /// Default chrome text: readable, but clearly subordinate to the concept.
    case primary
    /// Keyboard hints, captions, counts — present but not competing.
    case muted
    /// Unavailable controls. Still legible: a disabled chip must remain
    /// readable, because "this axis exists but is not applicable right now" is
    /// information the reviewer needs.
    case disabled
    /// Text drawn on top of an active (filled) control.
    case onActive
}

/// The stage's colour roles.
///
/// The palette is achromatic by design. Chrome that carries hue starts
/// competing with the concept it frames — a red chip next to a red record
/// button makes the reviewer read them as related. The one exception is
/// ``focus``: keyboard focus must be unmistakable and must never be confused
/// with the "active" fill, so it is allowed the system's only hue.
@available(macOS 15.0, *)
public struct StageColorRoles: Equatable {
    /// The well the hosted concept floats in. Darkest surface in the system, so
    /// that a concept with its own dark background still separates from it.
    public var stage: Color
    /// Tab bar and scrubber bars. One step lighter than ``stage`` — the chrome
    /// reads as furniture sitting in front of the well.
    public var chrome: Color
    /// Hairline between chrome and well.
    public var separator: Color

    /// Resting chip / segment fill.
    public var controlFill: Color
    /// Pointer-hover fill. A 6% lift: enough to confirm the target, not enough
    /// to read as a state change.
    public var controlFillHover: Color
    /// Active fill. Inverted rather than tinted — a light slab with dark text
    /// is the loudest thing achromatic chrome can do, and it survives being
    /// photographed, projected, and screenshotted at any size.
    public var controlFillActive: Color
    /// Fill for an axis that exists but is not currently applicable.
    public var controlFillDisabled: Color

    public var labelStrong: Color
    public var label: Color
    public var labelMuted: Color
    public var labelDisabled: Color
    public var labelOnActive: Color

    /// Keyboard focus ring. The only chromatic token in the system.
    public var focus: Color

    public init(
        stage: Color,
        chrome: Color,
        separator: Color,
        controlFill: Color,
        controlFillHover: Color,
        controlFillActive: Color,
        controlFillDisabled: Color,
        labelStrong: Color,
        label: Color,
        labelMuted: Color,
        labelDisabled: Color,
        labelOnActive: Color,
        focus: Color
    ) {
        self.stage = stage
        self.chrome = chrome
        self.separator = separator
        self.controlFill = controlFill
        self.controlFillHover = controlFillHover
        self.controlFillActive = controlFillActive
        self.controlFillDisabled = controlFillDisabled
        self.labelStrong = labelStrong
        self.label = label
        self.labelMuted = labelMuted
        self.labelDisabled = labelDisabled
        self.labelOnActive = labelOnActive
        self.focus = focus
    }

    public func color(_ tone: StageTone) -> Color {
        switch tone {
        case .strong: labelStrong
        case .primary: label
        case .muted: labelMuted
        case .disabled: labelDisabled
        case .onActive: labelOnActive
        }
    }
}

@available(macOS 15.0, *)
extension StageColorRoles {
    /// The default. Near-black chrome, mid-grey labels.
    public static let dark = StageColorRoles(
        stage: Color(white: 0.02),
        chrome: Color(white: 0.08),
        separator: Color(white: 0.16),
        controlFill: Color(white: 0.14),
        controlFillHover: Color(white: 0.20),
        controlFillActive: Color(white: 0.75),
        controlFillDisabled: Color(white: 0.10),
        labelStrong: Color(white: 1.0),
        label: Color(white: 0.62),
        labelMuted: Color(white: 0.38),
        labelDisabled: Color(white: 0.28),
        labelOnActive: Color(white: 0.06),
        focus: Color(.sRGB, red: 0.42, green: 0.64, blue: 0.96, opacity: 1)
    )

    /// For concepts that are themselves dark. Inverting the chrome restores the
    /// figure/ground separation the dark theme normally provides.
    public static let light = StageColorRoles(
        stage: Color(white: 0.97),
        chrome: Color(white: 0.90),
        separator: Color(white: 0.78),
        controlFill: Color(white: 0.84),
        controlFillHover: Color(white: 0.78),
        controlFillActive: Color(white: 0.18),
        controlFillDisabled: Color(white: 0.88),
        labelStrong: Color(white: 0.04),
        label: Color(white: 0.34),
        labelMuted: Color(white: 0.52),
        labelDisabled: Color(white: 0.68),
        labelOnActive: Color(white: 0.97),
        focus: Color(.sRGB, red: 0.10, green: 0.36, blue: 0.86, opacity: 1)
    )

    /// For projection and for reviewers who need more separation than the
    /// default's deliberately quiet contrast provides.
    public static let highContrast = StageColorRoles(
        stage: Color(white: 0.0),
        chrome: Color(white: 0.10),
        separator: Color(white: 0.34),
        controlFill: Color(white: 0.22),
        controlFillHover: Color(white: 0.30),
        controlFillActive: Color(white: 0.95),
        controlFillDisabled: Color(white: 0.14),
        labelStrong: Color(white: 1.0),
        label: Color(white: 0.82),
        labelMuted: Color(white: 0.60),
        labelDisabled: Color(white: 0.42),
        labelOnActive: Color(white: 0.0),
        focus: Color(.sRGB, red: 0.55, green: 0.78, blue: 1.0, opacity: 1)
    )
}

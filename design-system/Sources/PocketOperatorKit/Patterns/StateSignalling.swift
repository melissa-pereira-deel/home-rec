import SwiftUI

/// # Signalling state physically
///
/// An application shows state with chrome: banners, spinners, toasts, badges,
/// modal sheets. A device has none of those. It has lamps, keys that stay
/// down, a display, and meters that move — and everything it needs to tell you
/// has to be said with one of those four.
///
/// The mapping this kit assumes:
///
/// | Kind of state                     | Physical signal                      |
/// |-----------------------------------|--------------------------------------|
/// | Running / not running             | Lamp mode, plus a blinking display word |
/// | A mode that is currently selected | Key latched down, lamp on the cap    |
/// | A value, a count, a name          | Display                              |
/// | A continuous quantity             | Meter or fader position              |
/// | Function unavailable              | Duller cap material, dark lamp       |
/// | An action was committed           | One display invert flash             |
/// | A fault                           | Warning lamp, plus a display word    |
///
/// ## Redundancy is mandatory, not optional
///
/// Every state above must be carried by **at least two** of: colour, legend
/// text, lamp mode, and physical position. Colour alone excludes anyone with a
/// colour vision deficiency; blink alone disappears under Reduce Motion;
/// position alone is invisible to a screen reader. `TransportKeys` is the
/// worked example — the record key changes its legend *and* its lamp *and* its
/// cap material, so removing any one channel still leaves the state readable.
///
/// ## Things not to reach for
///
/// - No spinners. A device that is busy says so on its display and blinks a
///   lamp; it does not grow a rotating shape it does not physically have.
/// - No toasts. There is nowhere for one to come from.
/// - No disabled-by-opacity. Translucent hardware does not exist; use the
///   muted cap variant, which is what `HardwareKey` does automatically when
///   `.disabled(true)` is applied.
/// - No progress bars for indeterminate work. Blink the relevant lamp.
@available(macOS 15, *)
public struct POStateSignal {

    /// A device-wide status word, at most five characters so it fits a
    /// seven-segment annunciator field.
    public var word: String
    public var lampMode: IndicatorLamp.Mode
    public var lampRole: IndicatorLamp.Role
    /// The full sentence a screen reader should hear; the word alone is not it.
    public var spoken: String

    public init(
        word: String,
        lampMode: IndicatorLamp.Mode,
        lampRole: IndicatorLamp.Role,
        spoken: String
    ) {
        self.word = word
        self.lampMode = lampMode
        self.lampRole = lampRole
        self.spoken = spoken
    }

    /// The standard signal for a transport phase, as a starting point for a
    /// product's own vocabulary.
    public static func standard(for phase: TransportPhase) -> POStateSignal {
        switch phase {
        case .unavailable:
            POStateSignal(word: "N/A", lampMode: .off, lampRole: .warning, spoken: "Unavailable")
        case .idle:
            POStateSignal(word: "RDY", lampMode: .on, lampRole: .armed, spoken: "Ready")
        case .arming:
            POStateSignal(word: "ARM", lampMode: .blinking, lampRole: .active, spoken: "Arming")
        case .recording:
            POStateSignal(word: "REC", lampMode: .blinking, lampRole: .active, spoken: "Recording")
        case .playing:
            POStateSignal(word: "PLAY", lampMode: .on, lampRole: .armed, spoken: "Playing")
        case .paused:
            POStateSignal(word: "PAUSE", lampMode: .on, lampRole: .armed, spoken: "Paused")
        case .finishing:
            POStateSignal(word: "WAIT", lampMode: .blinking, lampRole: .active, spoken: "Finishing")
        }
    }
}

/// Punctuates a committed action with a single display invert.
///
/// Attach to the state that changes when the action lands. The flash is the
/// only "success" feedback in the language — there is no checkmark, no toast,
/// and no sheet, because a device acknowledges by momentarily doing something
/// to its own screen.
@available(macOS 15, *)
public struct POCommitFlash: ViewModifier {
    @Environment(\.poTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let trigger: AnyHashable
    @Binding var isInverted: Bool

    public func body(content: Content) -> some View {
        content.task(id: trigger) {
            guard !reduceMotion else { return }
            isInverted = true
            try? await Task.sleep(for: .seconds(theme.motion.displayFlashDuration))
            isInverted = false
        }
    }
}

@available(macOS 15, *)
public extension View {
    /// Invert the enclosed display briefly whenever `trigger` changes.
    ///
    /// - Parameter isInverted: Bound to the display's `isInverted` input, so
    ///   the flash and the display share one source of truth.
    func poCommitFlash(on trigger: some Hashable, isInverted: Binding<Bool>) -> some View {
        modifier(POCommitFlash(trigger: AnyHashable(trigger), isInverted: isInverted))
    }
}

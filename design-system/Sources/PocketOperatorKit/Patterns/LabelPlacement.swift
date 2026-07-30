import SwiftUI

/// # Label placement
///
/// Screen print is applied to the shell, so its position is decided by where
/// there is *room on the moulding*, not by reading order. The conventions:
///
/// - **Above a continuous control**, centred on its axis — faders, knobs,
///   rulers. There is no room beside a fader and none below it.
/// - **On the cap** for a key. A key's name is printed on the key; a caption
///   underneath means the legend was too long, which means the wrong word was
///   chosen.
/// - **Left of a value**, in a horizontal pair, for printed data. Label dim,
///   value bright, both monospaced.
/// - **Top-left of the chassis** for identity; **top-right** for the
///   device's function statement.
/// - **Never inside a display.** The display is driven; anything printed on it
///   would be printed on the glass, which real devices do only for fixed
///   annunciator legends.
///
/// Everything is uppercase, tracked out, and one line. A legend that needs two
/// lines is a description, and descriptions do not get screen printed.
///
/// ## Abbreviation and the accessibility consequence
///
/// This language runs on three- and four-letter codes: SRC, FMT, RATE, BPM.
/// That is authentic and it is also unreadable to anyone who has not learned
/// the device. Every abbreviation in this kit therefore takes a spoken name
/// alongside the printed one, and the printed one is never the only source of
/// meaning. When adding a component, assume the legend conveys nothing and
/// make sure the accessibility label carries the whole message.
@available(macOS 15, *)
public struct LabelledControl<Control: View>: View {
    @Environment(\.poTheme) private var theme

    private let legend: String
    private let alignment: HorizontalAlignment
    private let accessibilityLabel: String?
    private let control: Control

    /// - Parameter accessibilityLabel: The spoken name for the group. Supply
    ///   it whenever `legend` is an abbreviation.
    public init(
        _ legend: String,
        alignment: HorizontalAlignment = .center,
        accessibilityLabel: String? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.legend = legend
        self.alignment = alignment
        self.accessibilityLabel = accessibilityLabel
        self.control = control()
    }

    public var body: some View {
        VStack(alignment: alignment, spacing: theme.metrics.spacing.base) {
            // Hidden from assistive technology because the control below it
            // already announces the same name — announcing both makes every
            // control on the panel read twice.
            ScreenPrintLabel(legend, isDecorative: true)
            control
        }
        .accessibilityElement(children: .contain)
        .poAccessibilityLabel(accessibilityLabel)
    }
}

/// A printed label/value pair.
@available(macOS 15, *)
public struct PrintedPair: View {
    @Environment(\.poTheme) private var theme

    private let label: String
    private let value: String
    private let accessibilityLabel: String?

    public init(_ label: String, value: String, accessibilityLabel: String? = nil) {
        self.label = label
        self.value = value
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: theme.metrics.spacing.snug) {
            ScreenPrintLabel(label, scale: .micro, isDecorative: true)
            ScreenPrintValue(value, isDecorative: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? label)
        .accessibilityValue(value)
    }
}

@available(macOS 15, *)
#Preview("Label placement") {
    struct Host: View {
        @State private var level = 0.6
        var body: some View {
            HStack(alignment: .top, spacing: 32) {
                LabelledControl("GAIN", accessibilityLabel: "Input gain") {
                    Fader(value: $level, label: "")
                }
                VStack(alignment: .leading, spacing: 8) {
                    PrintedPair("RATE", value: "48K", accessibilityLabel: "Sample rate")
                    PrintedPair("BIT", value: "24", accessibilityLabel: "Bit depth")
                    PrintedPair("SRC", value: "LINE", accessibilityLabel: "Source")
                }
            }
            .padding(30)
            .background(Color.poHex(0x0A0A0A))
        }
    }
    return Host()
}

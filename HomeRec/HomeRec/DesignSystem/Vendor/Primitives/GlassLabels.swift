import SwiftUI

/// Monospace metadata: sample rates, bit depths, file sizes, dates, counts.
///
/// The register is the message. Anything a machine measured is set in mono
/// and in `textTertiary`; anything a person wrote is set in Inter and in
/// `textPrimary`. A take's *name* and a take's *spec line* are two different
/// kinds of fact, and the type says so before you've read either.
///
/// Metadata never wraps — it truncates. A wrapped spec line turns a fixed-row
/// list into a jittering one.
public struct GlassMetaLabel: View {
    private let text: String
    private let role: GlassTextRole
    private let colorRole: GlassColorRole

    public init(
        _ text: String,
        role: GlassTextRole = .meta,
        color: GlassColorRole = .textTertiary
    ) {
        self.text = text
        self.role = role
        self.colorRole = color
    }

    public var body: some View {
        Text(text)
            .glassText(role, color: colorRole)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

/// A section label: `recent`, `format`, `all takes`.
///
/// Lowercase mono, not uppercase. Uppercase eyebrows shout, and this panel
/// spends its only shout on the record button. The label is
/// `accessibilityHidden` by default and the section it names is expected to
/// carry the heading trait instead — a VoiceOver user should hear one heading,
/// not a heading and a stray word.
public struct GlassEyebrow: View {
    private let text: String
    private let isAccessibilityHeading: Bool

    public init(_ text: String, isAccessibilityHeading: Bool = true) {
        self.text = text
        self.isAccessibilityHeading = isAccessibilityHeading
    }

    public var body: some View {
        Text(text)
            .glassText(.meta, color: .textTertiary)
            .lineLimit(1)
            .accessibilityAddTraits(isAccessibilityHeading ? .isHeader : [])
    }
}

/// A hairline. `GlassDivider` rather than `Divider` because the system's
/// separator is an opacity on white, not the platform's grey, and because a
/// divider inside a card needs to inset from the card's own stroke.
public struct GlassDivider: View {
    public enum Axis { case horizontal, vertical }

    private let axis: Axis
    private let colorRole: GlassColorRole

    @Environment(\.glassTheme) private var theme

    public init(_ axis: Axis = .horizontal, color: GlassColorRole = .line) {
        self.axis = axis
        self.colorRole = color
    }

    public var body: some View {
        Rectangle()
            .fill(theme.colors[colorRole])
            .frame(
                width: axis == .vertical ? theme.metrics.hairline : nil,
                height: axis == .horizontal ? theme.metrics.hairline : nil
            )
            .frame(
                maxWidth: axis == .horizontal ? .infinity : nil,
                maxHeight: axis == .vertical ? .infinity : nil
            )
            .accessibilityHidden(true)
    }
}

#Preview("Labels") {
    GlassPreviewStage {
        VStack(alignment: .leading, spacing: GlassSpacing.m) {
            GlassEyebrow("recent")
            GlassMetaLabel("48kHz · 16-bit · wav · 26.4MB")
            GlassMetaLabel("2:08:09", color: .textSecondary)
            GlassMetaLabel("v4 · active", role: .metaSmall, color: .textAccent)
            GlassDivider()
            Text("kitchen radio, morning").glassText(.body, color: .textPrimary)
        }
    }
}

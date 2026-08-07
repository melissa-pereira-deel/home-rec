import SwiftUI

// MARK: - Width class

/// The three widths a timecode can have.
///
/// Pinning the *format* to the recording's total duration — rather than to the
/// value currently displayed — is the whole trick. A player counting up from
/// zero would otherwise render `0:59.9` and then `1:00`, changing character
/// count mid-scrub and shifting every element to its right. Choose the class
/// once per recording; the string then never changes width.
public enum GlassTimecodeWidthClass: String, CaseIterable, Hashable, Sendable {
    /// `m:ss.t` — under a minute. Tenths, because at this length tenths are
    /// the difference a user can hear.
    case tenths
    /// `m:ss` — under an hour.
    case minutes
    /// `h:mm:ss` — an hour or more.
    case hours

    /// Characters in the rendered string, for width reservation.
    public var characterCount: Int {
        switch self {
        case .tenths: 6   // 0:07.4
        case .minutes: 4  // 2:34
        case .hours: 7    // 1:12:03
        }
    }

    /// The class a recording of this duration should use for its whole life.
    public static func forDuration(_ duration: TimeInterval) -> GlassTimecodeWidthClass {
        if duration >= 3600 { return .hours }
        if duration < 60 { return .tenths }
        return .minutes
    }
}

// MARK: - Formatting

/// Timecode formatting.
///
/// Deliberately arithmetic rather than `DateComponentsFormatter`: the app's
/// own formatter shipped without hour rollover (`90:00` for a 90-minute take)
/// and a recorder that can't count past an hour is a recorder people stop
/// trusting. These four lines are also allocation-free, which matters when
/// they run 30× a second for hours.
public enum GlassTimecode {

    /// Formats `time` in an explicit width class.
    public static func string(_ time: TimeInterval, widthClass: GlassTimecodeWidthClass) -> String {
        let clamped = max(0, time)
        let total = Int(clamped)
        switch widthClass {
        case .hours:
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        case .minutes:
            return String(format: "%d:%02d", total / 60, total % 60)
        case .tenths:
            let tenths = Int((clamped - clamped.rounded(.down)) * 10)
            return String(format: "%d:%02d.%d", total / 60, total % 60, tenths)
        }
    }

    /// Formats `time` in the class pinned by a recording's total `duration`.
    /// This is what a player must use.
    public static func string(_ time: TimeInterval, matching duration: TimeInterval) -> String {
        string(time, widthClass: .forDuration(max(duration, time)))
    }

    /// Formats a running capture: tenths under an hour, `h:mm:ss` past it.
    ///
    /// The one place the class is allowed to change mid-value, because a live
    /// capture has no known total — and the change happens exactly once, at
    /// the hour mark, in a control that is already being watched.
    public static func live(_ elapsed: TimeInterval) -> String {
        string(elapsed, widthClass: elapsed >= 3600 ? .hours : .tenths)
    }

    /// A duration, spoken.
    ///
    /// VoiceOver reads `1:12:03` as "one twelve oh three", which is a phone
    /// number. Any timecode exposed to assistive technology goes through here.
    public static func spoken(_ time: TimeInterval) -> String {
        let total = Int(max(0, time).rounded())
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        if seconds > 0 || parts.isEmpty { parts.append("\(seconds) second\(seconds == 1 ? "" : "s")") }
        return parts.joined(separator: " ")
    }
}

// MARK: - Display

/// The hero timecode on the recorder face.
///
/// Two states, one component: **live** (full-strength, updating) and
/// **dwelling** (dimmed, showing the last take's duration). The dwell is a
/// product decision worth keeping: snapping to `0:00.0` the moment a take
/// finishes erases the number the user just made, 1.4 seconds after it
/// appeared.
public struct GlassTimecodeDisplay: View {
    private let time: TimeInterval
    private let isLive: Bool
    private let widthClass: GlassTimecodeWidthClass?
    private let role: GlassTextRole

    @Environment(\.glassTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        time: TimeInterval,
        isLive: Bool,
        widthClass: GlassTimecodeWidthClass? = nil,
        role: GlassTextRole = .timer
    ) {
        self.time = time
        self.isLive = isLive
        self.widthClass = widthClass
        self.role = role
    }

    public var body: some View {
        Text(text)
            .glassText(role)
            .monospacedDigit()
            .foregroundStyle(isLive ? theme.colors.textPrimary : theme.colors.textSecondary)
            // Digits cross-fade in place rather than sliding: a timer whose
            // numerals travel is a timer you can't read at a glance.
            .contentTransition(reduceMotion ? .identity : .numericText())
            .accessibilityElement()
            .accessibilityLabel(isLive ? "Recording time" : "Last take duration")
            .accessibilityValue(GlassTimecode.spoken(time))
            // Tells VoiceOver to re-read this element without the user moving
            // focus — and, just as importantly, tells it *not* to interrupt
            // itself on every tick.
            .accessibilityAddTraits(isLive ? .updatesFrequently : [])
    }

    private var text: String {
        if let widthClass { return GlassTimecode.string(time, widthClass: widthClass) }
        return GlassTimecode.live(time)
    }
}

// MARK: - Chip

/// The floating timecode capsule that rides a playhead.
///
/// Two details carry it. The capsule **clamps** inside the waveform's bounds
/// so it never hangs off the edge — but the **stem stays on the true
/// playhead**, so a clamped chip still points at the exact position rather
/// than lying about it. And the label's width class is pinned to the
/// recording's duration, so the capsule never resizes under the cursor.
public struct GlassTimecodeChip: View {
    private let time: TimeInterval
    private let progress: Double
    private let duration: TimeInterval

    @Environment(\.glassTheme) private var theme

    public init(time: TimeInterval, progress: Double, duration: TimeInterval) {
        self.time = time
        self.progress = progress
        self.duration = duration
    }

    public var body: some View {
        GeometryReader { geometry in
            let text = GlassTimecode.string(time, matching: duration)
            let width = estimatedWidth(characters: text.count)
            let trueX = geometry.size.width * progress.clampedToUnitInterval
            let clampedX = min(max(trueX, width / 2), max(width / 2, geometry.size.width - width / 2))

            ZStack {
                Text(text)
                    .glassText(.timecodeChip, color: .textOnAccent)
                    .monospacedDigit()
                    .padding(.horizontal, GlassSpacing.sm + 1)
                    .padding(.vertical, GlassSpacing.xxs + 1)
                    // Near-black rather than a card fill: the chip sits *on*
                    // the waveform, and a translucent capsule over moving bars
                    // is unreadable.
                    .background(.black.opacity(0.8), in: Capsule())
                    .position(x: clampedX, y: geometry.size.height / 2 - 3)

                Rectangle()
                    .fill(theme.colors.textPrimary.opacity(0.7))
                    .frame(width: theme.metrics.hairline, height: 5)
                    .position(x: trueX, y: geometry.size.height - 2.5)
            }
            .glassAnimation(.playhead, value: progress)
        }
        .frame(height: 26)
        // The chip duplicates the player's own timecode readout, which is
        // already exposed. Two VoiceOver stops for one number is noise.
        .accessibilityHidden(true)
    }

    /// Width of the capsule for a given character count.
    ///
    /// Estimated rather than measured because the value is needed *during*
    /// layout to compute the clamp, and a measurement pass would introduce a
    /// frame of lag on a control that moves 30× a second. SF Mono's advance is
    /// a stable 0.61 × point size, and the role is fixed-size (`maxScale` 1.0)
    /// precisely so this arithmetic stays valid under Dynamic Type.
    private func estimatedWidth(characters: Int) -> CGFloat {
        let pointSize = theme.typography.size(.timecodeChip)
        let advance = pointSize * 0.61
        let horizontalPadding = (GlassSpacing.sm + 1) * 2
        return CGFloat(characters) * advance + horizontalPadding
    }
}

extension Double {
    var clampedToUnitInterval: Double { Swift.min(1, Swift.max(0, self)) }
}

#Preview("Timecode") {
    GlassPreviewStage {
        VStack(alignment: .leading, spacing: GlassSpacing.l) {
            GlassTimecodeDisplay(time: 8.7, isLive: true)
            GlassTimecodeDisplay(time: 4323, isLive: true)
            GlassTimecodeDisplay(time: 154, isLive: false)
            GlassDivider()
            ForEach([0.02, 0.42, 0.98], id: \.self) { progress in
                GlassTimecodeChip(time: 4323 * progress, progress: progress, duration: 4323)
                    .frame(width: 320)
            }
        }
    }
}

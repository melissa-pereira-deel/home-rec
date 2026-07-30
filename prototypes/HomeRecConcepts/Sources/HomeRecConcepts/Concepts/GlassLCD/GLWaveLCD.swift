import SwiftUI

/// The Pocket Operator's display, transplanted into the glass panel: same
/// recessed bed, black bezel, aluminium ring, same phosphor green — showing
/// the waveform where the PO shows status words.
///
/// The waveform is rendered exactly as the PO renders it, with `LiveWaveform`
/// and `BarWaveform` at their native resolution. An earlier pass quantised the
/// samples onto a coarse segment grid; it read as low-resolution and threw
/// away the motion, because the PO's LCD never quantised its capture trace in
/// the first place — only its 7-seg glyphs are segmented. What makes the panel
/// an LCD here is the bed, the bezel and the phosphor bloom, not a pixel grid.
struct GLWaveLCD: View {
    var samples: [Float]
    /// Live capture scrolls in from the trailing edge (the ring buffer's
    /// newest sample); a finished take is resampled to fill the screen.
    var scrolling: Bool
    /// Dimmed for the frozen `.stopping` frame — never a dead black screen.
    var intensity: Double = 1

    var body: some View {
        ZStack {
            // Bloom under, crisp trace over: phosphor glows, ink doesn't.
            // Same two-pass treatment `SegmentLCD` gives its lit segments.
            trace.blur(radius: 2.2).opacity(0.55)
            trace
        }
        // Same trace height as the Glass card this replaces, so the face's
        // vertical rhythm is unchanged.
        .frame(height: 44)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(POTheme.lcdBed)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        // Bezel: hard black edge inside, brushed ring outside — the PO's
        // recess, reproduced so the screen sits *in* the glass, not on it.
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(.black.opacity(0.9), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                .padding(-1)
        )
        .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
        .accessibilityHidden(true)
    }

    private var lit: Color {
        POTheme.lcdLit.opacity(intensity)
    }

    @ViewBuilder
    private var trace: some View {
        if scrolling {
            // The PO's own live trace, at the PO's own bar geometry.
            LiveWaveform(samples: samples, accent: lit.opacity(0.85))
        } else {
            BarWaveform(samples: samples, accent: lit, progress: nil, dimOpacity: 0.85)
        }
    }
}

#Preview("Wave LCD") {
    VStack(spacing: 18) {
        GLWaveLCD(samples: WaveformFactory.identity(seed: 23), scrolling: false)
        GLWaveLCD(samples: Array(repeating: 0.05, count: 96), scrolling: false)
    }
    .padding(30)
    .frame(width: 420)
    .background(Color(red: 0.11, green: 0.11, blue: 0.12))
}

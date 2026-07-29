import SwiftUI

/// Direction 3 — Braun Utility. A T3-proportioned pocket appliance: grille
/// above, controls below, one dial, two lamps, black ink. Nothing moves
/// unless it is doing something.
struct BRFace: View {
    @EnvironmentObject private var store: PrototypeStateStore

    var body: some View {
        VStack(spacing: 0) {
            grille
                .padding(.bottom, 20)
            controlDeck
            Spacer(minLength: 0)
            waveformStrip
        }
        .padding(24)
        .frame(width: 450, height: 450)
        .background(BRTheme.chassis)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(BRTheme.rim, lineWidth: 1)
        )
        .overlay(alignment: .bottom) { indexCard }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Grille (the T3 proportion: upper 40%)

    private var grille: some View {
        TextureCanvas.dotGrille(dotColor: BRTheme.grilleDot)
            .frame(height: 158)
            .background(BRTheme.face)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(BRTheme.rim, lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                BRTheme.engraved("home rec", size: 8)
                    .padding(8)
            }
    }

    // MARK: - Controls

    private var controlDeck: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 18) {
                BRStatusDots()
                timer
                recordKey
                if store.transport == .disarmed {
                    BRTheme.engraved("grant permission to arm", size: 8)
                        .opacity(0.7)
                }
            }
            Spacer()
            VStack(spacing: 6) {
                BRDial(value: $store.gain)
                BRTheme.engraved("gain", size: 8)
            }
        }
    }

    private var timer: some View {
        Text(Formatters.timecode(timerValue, tenths: timerValue < 3600))
            .font(.system(size: 20, weight: .medium, design: .monospaced))
            .foregroundStyle(BRTheme.ink)
            .monospacedDigit()
    }

    private var timerValue: TimeInterval {
        if case .saved(let recording) = store.transport { return recording.duration }
        return store.elapsed
    }

    @ViewBuilder
    private var recordKey: some View {
        let disarmed = store.transport == .disarmed
        Button {
            store.toggleRecording()
        } label: {
            Text(store.transport.isRecording ? "stop" : "record")
                .font(.custom("Inter", size: 11, relativeTo: .caption))
                .tracking(0.8)
                .foregroundStyle(BRTheme.ink.opacity(disarmed ? 0.35 : 0.8))
                .frame(width: 128, height: 34)
                .background(BRTheme.face, in: RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(BRTheme.rim, lineWidth: 1)
                )
        }
        // Subtle travel — a Braun key clicks quietly.
        .buttonStyle(PressableKeyStyle(travel: 1, cornerRadius: 5, baseColor: BRTheme.rim, hapticOnPress: true))
        .disabled(disarmed)
    }

    // MARK: - Waveform: needle-thin polyline, ink on chassis

    private var waveformStrip: some View {
        Canvas { context, size in
            let samples = store.liveSamples
            guard samples.count > 1 else { return }
            var path = Path()
            let midY = size.height / 2
            for (i, sample) in samples.enumerated() {
                let x = size.width * CGFloat(i) / CGFloat(samples.count - 1)
                // Alternate polarity so the line oscillates around center.
                let polarity: CGFloat = i.isMultiple(of: 2) ? 1 : -1
                let y = midY + polarity * CGFloat(sample) * midY * 0.9
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(path, with: .color(BRTheme.ink), lineWidth: 1)
        }
        .frame(height: 44)
        .opacity(store.transport.isRecording ? 1 : 0.35)
    }

    // MARK: - Saved beat: the index card

    @ViewBuilder
    private var indexCard: some View {
        if case .saved(let recording) = store.transport {
            HStack {
                Text(recording.name)
                    .font(.custom("Inter", size: 12, relativeTo: .caption))
                    .foregroundStyle(BRTheme.ink)
                Spacer()
                Text(Formatters.timecode(recording.duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(BRTheme.label)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(BRTheme.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 40)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

#Preview("BR face") {
    BRFace()
        .environmentObject(PrototypeStateStore.shared)
        .padding(30)
        .background(Color.black)
}

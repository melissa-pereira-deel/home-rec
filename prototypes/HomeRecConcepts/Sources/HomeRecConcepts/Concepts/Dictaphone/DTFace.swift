import SwiftUI

/// Direction 2 — Dictaphone Deck. Recording is tape: reels spin and hold
/// their angle across takes, the lamp glows, the VU needle swings, and a
/// saved take slides out as a paper slip.
struct DTFace: View {
    @EnvironmentObject private var store: PrototypeStateStore

    var body: some View {
        VStack(spacing: 18) {
            reelDeck
            faceplate
            transportRow
            HStack {
                DTTheme.engraved("home rec")
                DTTheme.engraved("·").opacity(0.5)
                DTTheme.engraved("dictaphone deck")
                Spacer()
                DTTheme.engraved(store.selectedFormat.rawValue)
            }
        }
        .padding(24)
        .frame(width: 450, height: 450)
        .background(
            // Soft-shadowed mechanical chassis with a faint top sheen.
            ZStack {
                DTTheme.chassis
                LinearGradient(
                    colors: [.white.opacity(0.05), .clear],
                    startPoint: .top, endPoint: .center
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.black.opacity(0.5), lineWidth: 1)
        )
        .overlay(alignment: .bottom) { paperSlip }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Reel deck

    private var reelDeck: some View {
        ZStack {
            // Tape path between the reels, running under two guide posts.
            tapePath
            HStack(spacing: 76) {
                // Supply carries more tape than take-up: it moves between them.
                DTReelView(speedFactor: 1, tapeFill: 0.92)
                DTReelView(speedFactor: 1.15, tapeFill: 0.68)
            }
            DTLamp()
                .offset(y: 34)
        }
        .frame(height: 118)
    }

    private var tapePath: some View {
        Canvas { context, size in
            let y = size.height * 0.82
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.18, y: y))
            path.addLine(to: CGPoint(x: size.width * 0.82, y: y))
            context.stroke(path, with: .color(DTTheme.tape), lineWidth: 3)
            // Guide posts.
            for x in [size.width * 0.32, size.width * 0.68] {
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)),
                    with: .color(DTTheme.creamShadow)
                )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Faceplate: VU + counter

    private var faceplate: some View {
        HStack(spacing: 16) {
            VUNeedle(
                level: { store.currentLevel },
                faceColor: DTTheme.cream,
                inkColor: DTTheme.ink,
                redZoneColor: DTTheme.lampRed
            )
            .frame(width: 176, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.black.opacity(0.35), lineWidth: 1)
            )
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                DTCounter()
                DTTheme.engraved("counter", size: 8)
                    .foregroundStyle(DTTheme.ink.opacity(0.5))
            }
        }
        .padding(16)
        .background(
            // The cream faceplate: raised plate with soft drop and top light.
            RoundedRectangle(cornerRadius: 10)
                .fill(DTTheme.cream)
                .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .clear],
                        startPoint: .top, endPoint: .center
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Transport

    private var transportRow: some View {
        HStack(spacing: 14) {
            pianoKey("REC", accent: true) { store.toggleRecording() }
            pianoKey("STOP") { store.stop() }
            pianoKey("PLAY") {
                store.screen = .library
                if let first = store.library.first {
                    store.togglePlayback(for: first)
                }
            }
            Spacer()
        }
    }

    private func pianoKey(_ label: String, accent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                if accent {
                    Circle()
                        .fill(DTTheme.lampRed)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .font(.custom("Inter", size: 9, relativeTo: .caption2))
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundStyle(DTTheme.ink.opacity(0.75))
            }
            .frame(width: 92, height: 42)
            .background(
                LinearGradient(
                    colors: [DTTheme.cream, DTTheme.creamShadow],
                    startPoint: .top, endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .clear],
                            startPoint: .top, endPoint: .center
                        ),
                        lineWidth: 1
                    )
            )
        }
        // Piano keys travel deeper than PO lozenges.
        .buttonStyle(PressableKeyStyle(travel: 2.5, cornerRadius: 6, baseColor: .black.opacity(0.7)))
    }

    // MARK: - Saved beat: the paper slip

    @ViewBuilder
    private var paperSlip: some View {
        if case .saved(let recording) = store.transport {
            HStack {
                Text(recording.name)
                    .font(.custom("Inter", size: 12, relativeTo: .caption))
                    .foregroundStyle(DTTheme.ink)
                Spacer()
                Text(Formatters.timecode(recording.duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DTTheme.ink.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                // Paper: flat white-cream with a torn-edge hint at the top.
                UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3)
                    .fill(Color(red: 0.97, green: 0.955, blue: 0.915))
                    .shadow(color: .black.opacity(0.35), radius: 8, y: -3)
            )
            .padding(.horizontal, 48)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

#Preview("DT face") {
    DTFace()
        .environmentObject(PrototypeStateStore.shared)
        .padding(30)
        .background(Color.black)
}

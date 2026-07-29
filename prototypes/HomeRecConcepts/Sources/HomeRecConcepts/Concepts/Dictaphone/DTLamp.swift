import SwiftUI

/// The record lamp: a glass dome that is dead brown at rest and glows signal
/// red while recording. The glow breathes on a slow sine — the lamp itself
/// never blinks.
struct DTLamp: View {
    @EnvironmentObject private var store: PrototypeStateStore
    var size: CGFloat = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let lit = store.transport.isRecording
            let breathe = 0.88 + 0.12 * sin(context.date.timeIntervalSince1970 * .pi)
            Circle()
                .fill(
                    RadialGradient(
                        colors: lit
                            ? [DTTheme.lampRed.opacity(breathe), DTTheme.lampRed.opacity(0.75 * breathe)]
                            : [DTTheme.lampDead, DTTheme.lampDead.opacity(0.8)],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0, endRadius: size
                    )
                )
                .overlay(
                    // Glass highlight.
                    Circle()
                        .fill(.white.opacity(lit ? 0.5 : 0.18))
                        .frame(width: size * 0.28, height: size * 0.28)
                        .offset(x: -size * 0.18, y: -size * 0.2)
                )
                .overlay(Circle().strokeBorder(.black.opacity(0.5), lineWidth: 1))
                .shadow(
                    color: DTTheme.lampRed.opacity(lit ? 0.6 * breathe : 0),
                    radius: 10
                )
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

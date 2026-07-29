import SwiftUI

/// The one skeuomorphic element in the glass: a physical brand-red key seated
/// in a recessed brushed-metal well. While recording, the cap holds a
/// depressed, lit state — armed and glowing in the glass.
struct GSHeroKey: View {
    @EnvironmentObject private var store: PrototypeStateStore

    var body: some View {
        Button {
            store.toggleRecording()
        } label: {
            keyCap
        }
        .buttonStyle(PressableKeyStyle(travel: 2, cornerRadius: 9, baseColor: .black.opacity(0.8)))
        .padding(10)
        .background {
            // The metal well.
            ZStack {
                TextureCanvas.brushedMetal(baseColor: GSTheme.metalBase)
                // Recess shading: dark upper lip, light lower lip.
                LinearGradient(
                    colors: [.black.opacity(0.45), .clear, .white.opacity(0.15)],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(.black.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        }
    }

    private var keyCap: some View {
        let recording = store.transport.isRecording
        return ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(
                    LinearGradient(
                        colors: recording
                            ? [GSTheme.accent, GSTheme.accent.opacity(0.85)]
                            : [GSTheme.accent, GSTheme.accentDeep],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            // Inner glow while armed.
            if recording {
                RoundedRectangle(cornerRadius: 9)
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.35), .clear],
                            center: .center, startRadius: 0, endRadius: 36
                        )
                    )
            }
            Image(systemName: recording ? "stop.fill" : "record.circle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
        }
        .frame(width: 64, height: 44)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .clear],
                        startPoint: .top, endPoint: .center
                    ),
                    lineWidth: 1
                )
        )
        // The armed key throws light onto the glass around it.
        .shadow(color: GSTheme.accent.opacity(recording ? 0.7 : 0), radius: 14)
        .offset(y: recording ? 1.2 : 0)
    }
}

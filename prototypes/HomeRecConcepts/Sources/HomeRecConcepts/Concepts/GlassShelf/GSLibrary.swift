import SwiftUI

/// Glass library: the scaffold nearly raw — it IS the untitled.stream
/// structure — on frosted glass, with working chip filters.
struct GSLibrary: View {
    @EnvironmentObject private var store: PrototypeStateStore

    private var style: LibraryStyle {
        LibraryStyle(
            rowFill: GSTheme.card.opacity(0.85),
            rowStroke: .white.opacity(0.07),
            title: .white.opacity(0.92),
            meta: GSTheme.textDim,
            accent: GSTheme.accent,
            cornerRadius: 12,
            thumb: .white.opacity(0.8)
        )
    }

    var body: some View {
        ZStack {
            GSTheme.backdrop
            VStack(spacing: 12) {
                // Recording must stay visible and stoppable while browsing.
                RecordingBar(
                    accent: GSTheme.accent,
                    cardFill: GSTheme.card.opacity(0.85)
                )
                LibraryScaffold(style: style, showsChips: true) {
                    header
                }
            }
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 30, y: 18)
            .padding(22)
        }
        .frame(width: 450, height: 620)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var header: some View {
        HStack {
            GSTheme.lowercase("all takes", size: 13)
            Spacer()
            Button {
                store.screen = .recorder
            } label: {
                GSTheme.mono("← record", size: 10)
            }
            .buttonStyle(.plain)
        }
    }
}

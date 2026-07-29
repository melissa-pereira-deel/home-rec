import SwiftUI

/// Dictaphone library: the tape archive. Mini static reels in the header,
/// warm charcoal rows with cream text, amber accent.
struct DTLibrary: View {
    @EnvironmentObject private var store: PrototypeStateStore

    private var style: LibraryStyle {
        LibraryStyle(
            rowFill: Color(red: 0.135, green: 0.131, blue: 0.125),
            rowStroke: .black.opacity(0.4),
            title: DTTheme.cream,
            meta: DTTheme.cream.opacity(0.45),
            accent: DTTheme.amber,
            cornerRadius: 8,
            thumb: DTTheme.cream.opacity(0.7)
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            LibraryScaffold(style: style) {
                header
            }
        }
        .padding(24)
        .frame(width: 450, height: 620)
        .background(
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
    }

    private var header: some View {
        HStack {
            // Mini reel pair — static; the archive isn't running.
            HStack(spacing: 12) {
                miniReel(fill: 0.9)
                miniReel(fill: 0.65)
            }
            DTTheme.engraved("the tape archive", size: 10)
                .padding(.leading, 6)
            Spacer()
            Button {
                store.screen = .recorder
            } label: {
                DTTheme.engraved("← deck", size: 10)
            }
            .buttonStyle(.plain)
        }
    }

    private func miniReel(fill: CGFloat) -> some View {
        ZStack {
            Circle().fill(DTTheme.tape)
                .frame(width: 26 * fill + 6, height: 26 * fill + 6)
            Circle().fill(DTTheme.cream)
                .frame(width: 10, height: 10)
            Circle().fill(DTTheme.tape)
                .frame(width: 3, height: 3)
        }
        .frame(width: 32, height: 32)
    }
}

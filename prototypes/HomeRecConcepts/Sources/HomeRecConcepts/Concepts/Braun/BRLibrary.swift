import SwiftUI

/// Braun library: white index cards in the warm grey chassis — a card file,
/// not a tape rack. Ink on cream, red reserved for playback.
struct BRLibrary: View {
    @EnvironmentObject private var store: PrototypeStateStore

    private var style: LibraryStyle {
        LibraryStyle(
            rowFill: .white,
            rowStroke: BRTheme.cardBorder,
            title: BRTheme.ink,
            meta: BRTheme.label,
            accent: BRTheme.recordRed,
            cornerRadius: 4,
            thumb: BRTheme.ink.opacity(0.65),
            rowShadow: .black.opacity(0.07)
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
        .background(BRTheme.chassis)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(BRTheme.rim, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("recordings")
                    .font(.custom("Inter", size: 15, relativeTo: .headline))
                    .foregroundStyle(BRTheme.ink)
                BRTheme.engraved("\(store.library.count) items", size: 9)
            }
            Spacer()
            Button {
                store.screen = .recorder
            } label: {
                BRTheme.engraved("← recorder", size: 10)
            }
            .buttonStyle(.plain)
        }
    }
}

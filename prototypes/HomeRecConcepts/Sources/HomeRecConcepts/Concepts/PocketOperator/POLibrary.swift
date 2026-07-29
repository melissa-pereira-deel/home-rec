import SwiftUI

/// PO library: the scaffold seated in the black chassis, headed by a small
/// LCD readout, rows ruled like a spec sheet.
struct POLibrary: View {
    @EnvironmentObject private var store: PrototypeStateStore

    private var style: LibraryStyle {
        LibraryStyle(
            rowFill: POTheme.panelInset,
            rowStroke: POTheme.rule,
            title: Color(white: 0.88),
            meta: POTheme.label,
            accent: POTheme.orange,
            cornerRadius: 4,
            thumb: POTheme.lcdLit.opacity(0.8),
            accentLabel: .black.opacity(0.8)
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            LibraryScaffold(style: style) {
                header
            }
        }
        .padding(22)
        .frame(width: 450, height: 620)
        .background(POTheme.chassis)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(white: 0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                SegmentLCD(text: "LIB", color: POTheme.lcdLit, size: 16)
                SegmentLCD(
                    text: String(format: "%02d", store.library.count),
                    color: POTheme.lcdLit, size: 16
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(POTheme.lcdBed, in: RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(.black, lineWidth: 1)
            )
            Spacer()
            POChassisKey(label: "BACK", width: 56, height: 30) {
                store.screen = .recorder
            }
        }
    }
}

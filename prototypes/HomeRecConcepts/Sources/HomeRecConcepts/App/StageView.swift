import SwiftUI

/// The design stage: a neutral dark canvas that presents each concept's panel
/// at real size, with chrome for switching concepts, screens, and states.
/// Chrome stays deliberately quiet (SF Mono, dark grey) so it never competes
/// with the concepts under review.
struct StageView: View {
    var body: some View {
        VStack(spacing: 0) {
            stageChrome
            Spacer()
            // Concept panel host — placeholder until faces land.
            Text("Home Rec")
                .font(.custom("Archivo", size: 34, relativeTo: .largeTitle))
                .foregroundStyle(.white)
            Text("concept stage — scaffold")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            Spacer()
        }
        .frame(width: 620, height: 780)
        .background(Color(red: 0.02, green: 0.02, blue: 0.02))
    }

    private var stageChrome: some View {
        HStack {
            Text("HOME REC CONCEPTS")
                .font(.system(size: 10, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(white: 0.08))
    }
}

#Preview {
    StageView()
}

import SwiftUI

/// Direction 1 — Pocket Operator. The menu-bar panel as a tiny hardware
/// device face: LCD strip, lozenge key grid on a rubber bed, gain fader,
/// printed spec grid. Number keys are ordinal shortcuts into recent takes.
struct POFace: View {
    @EnvironmentObject private var store: PrototypeStateStore

    var body: some View {
        VStack(spacing: 0) {
            brandingRow
                .padding(.bottom, 10)
            POLCDStrip()
                .padding(.bottom, 14)
            HStack(alignment: .center, spacing: 14) {
                keyBed
                POFader(value: $store.gain)
            }
            .frame(maxHeight: .infinity)
            .padding(.bottom, 14)
            POSpecGrid()
        }
        .padding(22)
        .frame(width: 450, height: 450)
        .background(POTheme.chassis)
        .overlay(
            // Machined panel edge.
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(white: 0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var brandingRow: some View {
        HStack {
            POTheme.microLabel("HOME REC", size: 9)
            POTheme.microLabel("HR-01", size: 9)
                .opacity(0.6)
            Spacer()
            POTheme.microLabel("SYSTEM AUDIO RECORDER", size: 7)
                .opacity(0.6)
        }
    }

    /// 4×3 lozenge grid seated in the speckled rubber bed. Rows 1–2 are
    /// ordinal take shortcuts; row 3 is SRC · FMT · LIB · REC.
    private var keyBed: some View {
        VStack(spacing: 12) {
            gridRow(labels: ["01", "02", "03", "04"], startIndex: 0)
            gridRow(labels: ["05", "06", "07", "08"], startIndex: 4)
            HStack(spacing: 12) {
                POChassisKey(label: "SRC", action: {})
                POChassisKey(label: "FMT") { store.cycleFormat() }
                POChassisKey(label: "LIB") { store.screen = .library }
                recKey
            }
        }
        .padding(14)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(POTheme.rubberBed)
                TextureCanvas.speckle()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.black.opacity(0.6), lineWidth: 1)
        )
    }

    private func gridRow(labels: [String], startIndex: Int) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(labels.enumerated()), id: \.offset) { offset, label in
                POChassisKey(label: label) {
                    store.openLibrary(at: startIndex + offset)
                }
            }
        }
    }

    @ViewBuilder
    private var recKey: some View {
        let disarmed = store.transport == .disarmed
        POChassisKey(
            label: store.transport.isRecording ? "STOP" : "REC",
            kind: disarmed ? .orangeDisarmed : .orange
        ) {
            store.toggleRecording()
        }
        .disabled(disarmed)
    }
}

#Preview("PO face") {
    POFace()
        .environmentObject(PrototypeStateStore.shared)
        .padding(30)
        .background(Color.black)
}

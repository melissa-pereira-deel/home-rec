import SwiftUI

/// The device's display: 7-seg timer, status word, 12-segment level meter,
/// and a live capture trace — all in one recessed screen-green LCD.
/// Saved beat: the whole screen inverts for a flash, then the filename types
/// in character by character.
struct POLCDStrip: View {
    @EnvironmentObject private var store: PrototypeStateStore

    @State private var inverted = false
    @State private var typedCount = 0

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .background(inverted ? POTheme.lcdLit : POTheme.lcdBed)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(.black, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color(white: 0.165), lineWidth: 1)
                    .padding(-1)
            )
            .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
            .task(id: store.transport) { await runSavedBeat() }
    }

    private var glyphColor: Color {
        inverted ? POTheme.lcdBed : POTheme.lcdLit
    }

    @ViewBuilder
    private var content: some View {
        switch store.transport {
        case .disarmed:
            row(top: {
                SegmentLCD(text: "----", color: glyphColor, size: 30)
                Spacer()
                SegmentLCD(text: "PERM", color: glyphColor, size: 16)
            }, bottom: {
                POTheme.microLabel("GRANT SCREEN RECORDING TO ARM", size: 7)
                    .foregroundStyle(glyphColor.opacity(0.65))
                Spacer()
            })
        case .idle:
            row(top: {
                SegmentLCD(text: "0:00.0", color: glyphColor, size: 30)
                Spacer()
                SegmentLCD(text: "RDY", color: glyphColor, size: 16)
            }, bottom: {
                levelMeter(level: 0)
                Spacer()
            })
        case .starting:
            row(top: {
                SegmentLCD(text: Formatters.timecode(0, tenths: true), color: glyphColor, size: 30)
                Spacer()
                SegmentLCD(text: "ARM", color: glyphColor, size: 16)
            }, bottom: {
                levelMeter(level: 0)
                Spacer()
            })
        case .recording:
            row(top: {
                SegmentLCD(
                    text: Formatters.timecode(store.elapsed, tenths: store.elapsed < 3600),
                    color: glyphColor, size: 30
                )
                Spacer()
                blinking { SegmentLCD(text: "REC", color: glyphColor, size: 16) }
            }, bottom: {
                levelMeter(level: store.currentLevel)
                LiveWaveform(samples: store.liveSamples, accent: glyphColor.opacity(0.85))
                    .frame(height: 22)
            })
        case .stopping:
            row(top: {
                SegmentLCD(text: Formatters.timecode(store.elapsed, tenths: true), color: glyphColor, size: 30)
                Spacer()
                SegmentLCD(text: "---", color: glyphColor, size: 16)
            }, bottom: {
                levelMeter(level: 0)
                Spacer()
            })
        case .saved(let recording):
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SegmentLCD(text: "SAVED", color: glyphColor, size: 22)
                    Spacer()
                    SegmentLCD(text: Formatters.timecode(recording.duration), color: glyphColor, size: 16)
                }
                // Filename types in, 7-seg glyph by glyph.
                SegmentLCD(
                    text: String(typedName(recording).prefix(typedCount)),
                    color: glyphColor, size: 13
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func row(
        @ViewBuilder top: () -> some View,
        @ViewBuilder bottom: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, content: top)
            HStack(alignment: .center, spacing: 12, content: bottom)
        }
    }

    /// 12-segment level bar with lit count from the live level.
    private func levelMeter(level: Float) -> some View {
        HStack(spacing: 2.5) {
            ForEach(0..<12, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(glyphColor.opacity(Float(i) < level * 12 ? 1 : 0.09))
                    .frame(width: 5, height: 14)
            }
        }
    }

    /// Hard square-wave blink at 2Hz — LCDs don't fade.
    private func blinking(@ViewBuilder _ content: @escaping () -> some View) -> some View {
        TimelineView(.animation(minimumInterval: 0.25)) { context in
            let on = Int(context.date.timeIntervalSince1970 * 2).isMultiple(of: 2)
            content().opacity(on ? 1 : 0.07)
        }
    }

    /// 7-seg-safe filename (dots read badly mid-name; keep it terse).
    private func typedName(_ recording: FakeRecording) -> String {
        String(recording.name.prefix(18))
    }

    private func runSavedBeat() async {
        guard case .saved = store.transport else {
            inverted = false
            typedCount = 0
            return
        }
        // Flash-invert, then type.
        inverted = true
        try? await Task.sleep(for: .milliseconds(120))
        inverted = false
        guard case .saved(let recording) = store.transport else { return }
        for i in 0...typedName(recording).count {
            typedCount = i
            try? await Task.sleep(for: .milliseconds(30))
        }
    }
}

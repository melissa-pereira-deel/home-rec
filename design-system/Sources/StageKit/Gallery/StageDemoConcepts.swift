import SwiftUI

// Two competing directions on the same state — the situation a stage exists
// for. Note that neither one uses a StageKit token: concepts speak their own
// visual language, and the harness stays out of it. If a concept reached for
// `stageTheme` it would start looking like part of the chrome, which is exactly
// the confusion the kit is built to prevent.

/// Direction A: radial, one gesture, everything on one face.
@available(macOS 15.0, *)
struct StageDemoDialConcept: View {
    @Binding var state: StageDemoState

    private let range: ClosedRange<Double> = 4...30

    var body: some View {
        VStack(spacing: state.density.padding) {
            header
            if state.screen == .control {
                dial
                modeRow
            } else {
                scheduleList
            }
            if let fault = state.fault {
                notice(fault.message)
            }
            Spacer(minLength: 0)
        }
        .padding(state.density.padding + 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(white: 0.11))
        .opacity(state.isOffline ? 0.45 : 1)
        .overlay(alignment: .top) {
            if state.isOffline { offlineBanner }
        }
    }

    private var header: some View {
        HStack {
            Text("living room")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Text(state.screen.label.lowercased())
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color(white: 0.55))
        }
    }

    private var dial: some View {
        ZStack {
            Circle()
                .stroke(Color(white: 0.18), lineWidth: 14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(state.setpoint))")
                    .font(.system(size: 52, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(state.isCalling ? state.mode.label.lowercased() : "idle")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color(white: 0.55))
            }
        }
        .frame(width: 168, height: 168)
    }

    private var modeRow: some View {
        HStack(spacing: 6) {
            ForEach(StageDemoMode.allCases, id: \.self) { mode in
                Button {
                    state.mode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(mode == state.mode ? Color.black : Color(white: 0.7))
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(
                            mode == state.mode ? accent : Color(white: 0.17),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(mode.rawValue))
                .accessibilityAddTraits(mode == state.mode ? [.isSelected] : [])
            }
        }
    }

    private var scheduleList: some View {
        VStack(spacing: 6) {
            ForEach(state.schedule, id: \.0) { entry in
                HStack {
                    Text(entry.0)
                        .font(.system(size: 12, design: .rounded))
                        .monospacedDigit()
                    Spacer()
                    Text("\(entry.1)°")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(Color(white: 0.78))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: 17))
            }
        }
        .frame(maxWidth: 220)
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(Color(white: 0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.36, green: 0.24, blue: 0.10), in: RoundedRectangle(cornerRadius: 10))
    }

    private var offlineBanner: some View {
        Text("OFFLINE")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.25), in: Capsule())
            .padding(.top, 10)
    }

    private var progress: Double {
        let span = range.upperBound - range.lowerBound
        return min(max((state.setpoint - range.lowerBound) / span, 0), 1)
    }

    private var accent: Color {
        switch state.mode {
        case .off: Color(white: 0.45)
        case .heat: Color(red: 0.95, green: 0.55, blue: 0.20)
        case .cool: Color(red: 0.35, green: 0.68, blue: 0.95)
        }
    }
}

/// Direction B: flat, list-led, everything legible at a glance.
@available(macOS 15.0, *)
struct StageDemoSlabConcept: View {
    @Binding var state: StageDemoState

    var body: some View {
        VStack(alignment: .leading, spacing: state.density.padding) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Living Room")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Text(state.isOffline ? "Offline" : (state.isCalling ? state.mode.rawValue.capitalized : "Idle"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(state.isOffline ? Color(white: 0.45) : accent)
            }
            .foregroundStyle(Color(white: 0.12))

            if state.screen == .control {
                readout
                stepper
            } else {
                scheduleTable
            }

            if let fault = state.fault {
                HStack(spacing: 8) {
                    Rectangle().fill(Color(red: 0.80, green: 0.45, blue: 0.10)).frame(width: 3)
                    Text(fault.message).font(.system(size: 11))
                }
                .foregroundStyle(Color(white: 0.30))
                .frame(height: 34)
                .background(Color(white: 0.93))
            }
            Spacer(minLength: 0)
        }
        .padding(state.density.padding + 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(white: 0.97))
        .grayscale(state.isOffline ? 1 : 0)
    }

    private var readout: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(Int(state.setpoint))")
                .font(.system(size: 64, weight: .light))
                .monospacedDigit()
            Text("°C")
                .font(.system(size: 20, weight: .light))
        }
        .foregroundStyle(Color(white: 0.12))
    }

    private var stepper: some View {
        HStack(spacing: 8) {
            stepButton("−", delta: -1)
            stepButton("+", delta: 1)
            Spacer()
            ForEach(StageDemoMode.allCases, id: \.self) { mode in
                Button { state.mode = mode } label: {
                    Text(mode.rawValue.capitalized)
                        .font(.system(size: 11, weight: mode == state.mode ? .semibold : .regular))
                        .foregroundStyle(mode == state.mode ? Color(white: 0.98) : Color(white: 0.35))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(
                            mode == state.mode ? Color(white: 0.15) : Color(white: 0.90),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(mode.rawValue))
                .accessibilityAddTraits(mode == state.mode ? [.isSelected] : [])
            }
        }
    }

    private func stepButton(_ glyph: String, delta: Double) -> some View {
        Button {
            state.setpoint = min(max(state.setpoint + delta, 4), 30)
        } label: {
            Text(glyph)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(white: 0.20))
                .frame(width: 32, height: 28)
                .background(Color(white: 0.90), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(delta > 0 ? "Warmer" : "Cooler"))
    }

    private var scheduleTable: some View {
        VStack(spacing: 0) {
            ForEach(Array(state.schedule.enumerated()), id: \.element.0) { index, entry in
                HStack {
                    Text(entry.0).monospacedDigit()
                    Spacer()
                    Text("\(entry.1)°").monospacedDigit()
                }
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.25))
                .frame(height: 32)
                .background(index.isMultiple(of: 2) ? Color(white: 0.94) : .clear)
            }
        }
    }

    private var accent: Color {
        switch state.mode {
        case .off: Color(white: 0.45)
        case .heat: Color(red: 0.78, green: 0.36, blue: 0.08)
        case .cool: Color(red: 0.12, green: 0.42, blue: 0.72)
        }
    }
}

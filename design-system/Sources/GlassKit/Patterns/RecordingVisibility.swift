import SwiftUI

/// **The invariant: a capture is never invisible, and never more than one
/// click from stop.**
///
/// Every screen this kit can build — the recorder face, the library, a future
/// settings sheet, a menu-bar popover — must show an in-flight capture and
/// must offer to stop it. Not "should": a recorder that is quietly writing to
/// disk while the user browses somewhere else is the failure mode people never
/// forgive, and it is one navigation push away at all times.
///
/// The modifier makes the invariant the default rather than a rule to
/// remember. Apply it once, at the root of a screen:
///
/// ```swift
/// LibraryView()
///     .glassRecordingVisible(
///         state: model.transport,
///         elapsed: model.elapsed,
///         samples: model.liveSamples,
///         onStop: model.stop
///     )
/// ```
///
/// ### Why a modifier and not a component
/// A component you place by hand is a component someone forgets on the next
/// screen. A modifier that wraps the whole screen can be required by review,
/// grepped for, and — if a host wants — applied once at the window root so
/// that no future screen can opt out by accident.
///
/// ### Placement
/// The bar pins to the **top** of the screen, above content, and pushes rather
/// than overlays. An overlay would cover the first row of a list, and this bar
/// can be on screen for hours.
public struct GlassRecordingVisibilityModifier: ViewModifier {
    let state: GlassTransportState
    let elapsed: TimeInterval
    let samples: [Float]
    let copy: GlassTransportCopy
    let onStop: () -> Void

    public func body(content: Content) -> some View {
        VStack(spacing: GlassSpacing.md) {
            GlassRecordingBar(
                state: state,
                elapsed: elapsed,
                samples: samples,
                copy: copy,
                onStop: onStop
            )
            content
        }
        .glassAnimation(.swap, value: state.isCapturing)
    }
}

public extension View {
    /// Pins a recording bar above this screen whenever a capture is in
    /// flight. See `GlassRecordingVisibilityModifier` for the invariant this
    /// enforces.
    func glassRecordingVisible(
        state: GlassTransportState,
        elapsed: TimeInterval,
        samples: [Float] = [],
        copy: GlassTransportCopy = .standard,
        onStop: @escaping () -> Void
    ) -> some View {
        modifier(
            GlassRecordingVisibilityModifier(
                state: state,
                elapsed: elapsed,
                samples: samples,
                copy: copy,
                onStop: onStop
            )
        )
    }
}

/// Compile-time-checkable statement of the interaction table from the Glass
/// spec (§2), so a screen can *ask* what is permitted instead of re-deriving
/// it — which is how two surfaces end up disagreeing.
public enum GlassTransportPermissions {
    /// Can a new capture be started from this state?
    public static func canRecord(_ state: GlassTransportState) -> Bool {
        GlassTransportMachine.canStartRecording(in: state)
    }

    /// Can the current capture be stopped?
    public static func canStop(_ state: GlassTransportState) -> Bool {
        GlassTransportMachine.canStopRecording(in: state)
    }

    /// Can a take be played? **Always** — see `GlassMonitoringPolicy`.
    public static func canPlay(_ state: GlassTransportState) -> Bool { true }

    /// Can the output format be changed? Locked for the whole capture,
    /// including `arming` and `stopping`.
    public static func canChangeFormat(_ state: GlassTransportState) -> Bool {
        state.allowsFormatChange
    }

    /// Should quitting be guarded? A capture in flight means an unfinalised
    /// file, and for some formats an unfinalised file is unplayable.
    public static func shouldGuardQuit(_ state: GlassTransportState) -> Bool {
        state.isCapturing
    }

    /// The tooltip a locked format control should carry. A disabled control
    /// with no reason is indistinguishable from a broken one.
    public static func formatLockReason(_ state: GlassTransportState) -> String? {
        state.allowsFormatChange
            ? nil
            : "The format is set when a recording starts. Stop recording to change it."
    }
}

#Preview("Recording visibility") {
    ZStack {
        GlassBackdrop()
        GlassPanel {
            VStack(spacing: GlassSpacing.md) {
                GlassEyebrow("all takes")
                GlassTakeRow(take: GlassSampleTakes.all[0])
                GlassTakeRow(take: GlassSampleTakes.all[1])
            }
            .glassRecordingVisible(
                state: .recording(startedAt: .now),
                elapsed: 73.1,
                samples: GlassSampleWaveforms.live(count: 60),
                onStop: {}
            )
        }
        .padding(GlassSpacing.xxl)
    }
    .frame(width: 480, height: 360)
}

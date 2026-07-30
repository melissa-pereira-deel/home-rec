import SwiftUI

/// A complete, working stage in about as many lines as the docs promise.
///
/// Two competing thermostat directions, six declared axes, and nothing else —
/// no hand-written chip, no shortcut wiring, no snapshot list. Everything the
/// chrome shows is derived from ``StageDemo``'s declaration.
@available(macOS 15.0, *)
public struct StageKitDemoStage: View {
    @StateObject private var driver: StageDriver<StageDemoState>
    private let stageSize: CGSize?

    public init(stageSize: CGSize? = CGSize(width: 360, height: 420)) {
        self.stageSize = stageSize
        _driver = StateObject(wrappedValue: StageDemo.makeDriver())
    }

    public var body: some View {
        StageWindow(driver: driver, stageSize: stageSize)
    }
}

@available(macOS 15.0, *)
#Preview("End-to-end stage") {
    StageKitDemoStage()
}

@available(macOS 15.0, *)
#Preview("End-to-end stage · light chrome") {
    StageKitDemoStage()
        .stageTheme(.light)
}

@available(macOS 15.0, *)
#Preview("End-to-end stage · presentation") {
    StageKitDemoStage()
        .stageTheme(.presentation)
}

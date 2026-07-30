import SwiftUI

/// The full chrome: tab bar, content well, scrubber.
///
/// Unopinionated about what goes in the three slots, so it is usable for
/// hand-built chrome as well as under ``StageWindow``.
///
/// ## Why the well is fixed-size
///
/// A stage that resizes with its window produces screenshots that cannot be
/// compared: the same design captured on two machines lands at two sizes, and a
/// diff between review rounds shows layout noise instead of design change.
/// Passing `stageSize` pins the well, so every capture of every concept is
/// pixel-comparable, and the window sizes itself to fit.
@available(macOS 15.0, *)
public struct StageFrame<TabBar: View, Content: View, Scrubber: View>: View {
    private let stageSize: CGSize?
    private let tabBar: TabBar
    private let content: Content
    private let scrubber: Scrubber

    @Environment(\.stageTheme) private var theme

    /// - Parameter stageSize: exact size of the content well. `nil` lets the
    ///   well fill the window, which is fine for exploration but gives up
    ///   capture determinism.
    public init(
        stageSize: CGSize? = nil,
        @ViewBuilder tabBar: () -> TabBar,
        @ViewBuilder content: () -> Content,
        @ViewBuilder scrubber: () -> Scrubber
    ) {
        self.stageSize = stageSize
        self.tabBar = tabBar()
        self.content = content()
        self.scrubber = scrubber()
    }

    public var body: some View {
        VStack(spacing: 0) {
            tabBar
            StageDivider()
            well
            StageDivider()
            scrubber
        }
        .background(theme.colors.stage)
    }

    @ViewBuilder
    private var well: some View {
        if let stageSize {
            content
                .frame(width: stageSize.width, height: stageSize.height)
                .clipped()
                .background(theme.colors.stage)
        } else {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.colors.stage)
        }
    }
}

@available(macOS 15.0, *)
extension StageFrame where Scrubber == EmptyView {
    public init(
        stageSize: CGSize? = nil,
        @ViewBuilder tabBar: () -> TabBar,
        @ViewBuilder content: () -> Content
    ) {
        self.init(stageSize: stageSize, tabBar: tabBar, content: content) { EmptyView() }
    }
}

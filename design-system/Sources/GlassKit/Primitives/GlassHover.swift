import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

/// Tracks hover and, optionally, swaps in the pointing-hand cursor.
///
/// The push/pop bookkeeping is the whole reason this exists: `NSCursor.push()`
/// without a matching `pop()` leaves the pointer stuck as a hand over the rest
/// of the app, and a view that disappears while hovered (a row that scrolls
/// away, a pill that swaps out on a state change — which happens constantly in
/// this kit) will do exactly that unless it pops on `onDisappear`.
struct GlassHoverTracker: ViewModifier {
    @Binding var isHovering: Bool
    var showsPointingHand: Bool = true

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                #if canImport(AppKit)
                if showsPointingHand {
                    if hovering, !isHovering { NSCursor.pointingHand.push() }
                    if !hovering, isHovering { NSCursor.pop() }
                }
                #endif
                isHovering = hovering
            }
            .onDisappear {
                #if canImport(AppKit)
                if showsPointingHand, isHovering { NSCursor.pop() }
                #endif
                isHovering = false
            }
    }
}

extension View {
    /// Reports hover state and manages the pointing-hand cursor.
    func glassHover(_ isHovering: Binding<Bool>, showsPointingHand: Bool = true) -> some View {
        modifier(GlassHoverTracker(isHovering: isHovering, showsPointingHand: showsPointingHand))
    }
}

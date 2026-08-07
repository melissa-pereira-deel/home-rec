//
//  GlassWindowGround.swift
//  HomeRec
//
//  The app's ground: real glass over the desktop. One view, used by every
//  surface, because the alternative was tried and it showed.
//
//  The popover, the sheets and the floating panel originally took a flat
//  opaque fill instead, on the reasoning that a popover already draws its own
//  vibrancy and a second material stacked on it would read as mud. The
//  reasoning was sound and the result was still wrong: an opaque fill *covers*
//  the host's vibrancy rather than adding to it, so those surfaces came out
//  visibly darker than the window they belong to. Consistency here is not a
//  matter of taste — two panels of the same app in the same glance should be
//  made of the same material.
//
//  Two AppKit facts shape the implementation, because SwiftUI has no lever for
//  either:
//
//  1. SwiftUI's `Material` blends *within* the window — it blurs in-window
//     content behind the view. A ground has nothing in-window behind it, so a
//     SwiftUI material resolves to flat grey no matter how transparent the
//     window is: the "frosted panel over flat black is just a grey rectangle"
//     case, wearing a different hat. Glass that samples the *desktop* is
//     `NSVisualEffectView` with `.behindWindow` blending, and nothing else.
//
//  2. A window only lets that blur through if it stops painting its own
//     background (`isOpaque = false`, clear `backgroundColor`). That is true of
//     the main window, the panel, the sheets and the popover alike, which is
//     why the configurator below applies to all of them and asks the window
//     what it is rather than being told.
//

import SwiftUI
import AppKit

struct GlassWindowGround: View {

    @Environment(\.glassTheme) private var theme

    var body: some View {
        ZStack {
            DesktopBlur()

            // Tint sits *over* the blur — deliberately the opposite of
            // GlassSurface's tint-under-material rule. That rule is for
            // within-window materials, which sample what is below them in the
            // window; a behind-window effect view samples the desktop and
            // ignores in-window layers entirely, so the only place a tint can
            // do its job is on top, pulling the blurred desktop down to the
            // brand's tone. This opacity is the one dial between "more glass"
            // and "more brand".
            theme.colors.surfacePanel
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .background(GlassWindowConfigurator())
    }
}

/// The desktop-sampling blur layer.
private struct DesktopBlur: NSViewRepresentable {

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        // `.hudWindow` is the most translucent of the dark materials — the
        // whole point over `.underWindowBackground`, which is opaque enough
        // that the desktop stops reading through it.
        view.material = .hudWindow
        // Always active: the default follows key-window state, so the glass
        // would flatten to grey the moment the user clicks elsewhere — which,
        // for a recorder left running in the corner, is most of its life. It
        // also matters for the popover and the floating panel, neither of which
        // is ever the key window while it is being read.
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// Window-level switches the glass depends on. Zero-sized: a hook for reaching
/// AppKit, never a participant in layout — the window's fixed size comes from
/// its content, and a flexible view here would take that away again.
private struct GlassWindowConfigurator: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        // The window does not exist until the view joins the hierarchy.
        DispatchQueue.main.async {
            guard let window = view.window else { return }

            // Non-opaque, or the behind-window blur has nothing to punch
            // through. This is what the flat-ground surfaces were missing: they
            // sat on a window still painting its own background.
            window.isOpaque = false
            window.backgroundColor = .clear

            // Only the app's own resizable/titled windows need dragging by the
            // body — they are the ones whose titlebar was hidden. A popover, a
            // sheet and a floating panel are positioned by their host, and
            // making them background-draggable would let the user tear them
            // away from whatever they are anchored to.
            if window.styleMask.contains(.titled) {
                window.isMovableByWindowBackground = true
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

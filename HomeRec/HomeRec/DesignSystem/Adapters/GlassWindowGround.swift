//
//  GlassWindowGround.swift
//  HomeRec
//
//  The main window's ground: real glass over the desktop, one surface from the
//  titlebar down.
//
//  Two AppKit facts shape everything here, because SwiftUI has no lever for
//  either:
//
//  1. SwiftUI's `Material` blends *within* the window — it blurs in-window
//     content behind the view. This ground has nothing in-window behind it, so
//     a SwiftUI material resolves to a flat grey no matter how transparent the
//     window is: the "frosted panel over flat black is just a grey rectangle"
//     case, wearing a different hat. Glass that samples the *desktop* is
//     `NSVisualEffectView` with `.behindWindow` blending, and nothing else.
//
//  2. The titlebar is a separate AppKit surface with its own background. For
//     the window to read as one material, the titlebar must stop painting
//     (`titlebarAppearsTransparent`) and the content must extend under it
//     (`.fullSizeContentView`) so this ground reaches the very top. The title
//     and traffic lights stay; only their private background band goes.
//

import SwiftUI
import AppKit

struct GlassWindowGround: View {

    @Environment(\.glassTheme) private var theme

    var body: some View {
        ZStack {
            DesktopBlur()

            // Tint sits *over* the blur here — deliberately the opposite of
            // GlassSurface's tint-under-material rule. That rule exists for
            // within-window materials, which sample whatever is below them in
            // the window; a behind-window effect view samples the desktop and
            // ignores in-window layers entirely, so the only place a tint can
            // do its job is on top, pulling the blurred desktop down to the
            // brand's tone.
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
        // for a recorder left running in the corner, is most of its life.
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// Window-level switches the glass depends on. Zero-sized: a hook for reaching
/// AppKit, never a participant in layout — the fixed 450pt window comes from
/// the content, and a flexible view here would take that away again.
private struct GlassWindowConfigurator: NSViewRepresentable {

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        // The window does not exist until the view joins the hierarchy.
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            // Non-opaque, or the behind-window blur has nothing to punch
            // through and the corners flash solid on resize.
            window.isOpaque = false
            window.backgroundColor = .clear
            // With the titlebar hidden (`.windowStyle(.hiddenTitleBar)`) there
            // is no band left to drag the window by, so the body has to take
            // that job or the window becomes immovable.
            window.isMovableByWindowBackground = true
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

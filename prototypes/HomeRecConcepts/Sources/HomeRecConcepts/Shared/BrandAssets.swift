import AppKit
import SwiftUI

/// Real brand artwork, pulled from homerec.app (apple-touch-icon.png).
/// The SwiftPM process carries the generic executable icon, so
/// `NSApp.applicationIconImage` is useless here — load the shipped mark
/// from the bundle instead. The shipping app would keep using its asset
/// catalog icon; this exists so the prototype shows the true brand.
enum BrandAssets {
    /// 180×180 rounded-square mark with the red record dot. Nil only if the
    /// resource copy is broken, in which case callers show their fallback.
    static let appIcon: NSImage? = Bundle.module.url(
        forResource: "AppIcon", withExtension: "png", subdirectory: "Brand"
    ).flatMap { NSImage(contentsOf: $0) }
}

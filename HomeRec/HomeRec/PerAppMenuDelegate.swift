//
//  PerAppMenuDelegate.swift
//  HomeRec
//
//  Populates the Per-App submenu on open, without ever blocking (BL-111).
//
//  Two hazards shape this file, and both are measured rather than theorised:
//
//  1. **Enumerating apps costs a permission prompt.** `SCShareableContent`
//     bypasses `PermissionProviding`, can raise the system dialog, and registers
//     the app with TCC. So it runs only behind a deliberate submenu open, and
//     only when permission is already granted. A plain right-click on the status
//     item — which never opens this submenu — does zero enumeration.
//
//  2. **`menuNeedsUpdate` is synchronous, on the main thread, inside AppKit's
//     menu-tracking loop.** Bridging the `async` enumeration with a semaphore is
//     a *guaranteed deadlock*, not a slow menu: the `Task { @MainActor }` is
//     enqueued on the main actor's executor while `wait()` blocks the very
//     thread that would drain it. Measured: it never completes. The only correct
//     shape is return-immediately-from-cache, then refresh out of band.
//

import AppKit

/// In-memory list of running apps, shared between menu opens.
///
/// Deliberately holds *only* the probe result. Display names live on
/// `AudioSourceManager`, which persists them — a second copy here would be the
/// same fact in two stores, diverging the moment one is updated and the other
/// isn't, and would be lost on relaunch besides.
///
/// Deliberately a reference type held by `MenuBarController`: the menu is rebuilt
/// per open, so a cache owned by the menu would be cold every single time and the
/// first open would always show a placeholder.
@MainActor
final class PerAppListCache {
    /// nil until the first successful enumeration — which is *not* the same as
    /// an empty list, and the menu renders the two differently.
    private(set) var apps: [RunningAppInfo]?
    func update(_ apps: [RunningAppInfo]) {
        self.apps = apps
    }
}

/// Fills the Per-App submenu when it opens, in place, without blocking.
@MainActor
final class PerAppMenuDelegate: NSObject, NSMenuDelegate {

    private let cache: PerAppListCache
    private let source: AudioSourceProviding
    private let makeContext: @MainActor () -> OverflowContext

    init(
        cache: PerAppListCache,
        source: AudioSourceProviding,
        makeContext: @escaping @MainActor () -> OverflowContext
    ) {
        self.cache = cache
        self.source = source
        self.makeContext = makeContext
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let context = makeContext()

        // Hard permission gate, before anything else: with permission missing we
        // must not enumerate at all, or *hovering* this submenu raises a dialog —
        // worse than the click-triggered prompt BL-085 removed.
        guard context.permissionGranted else {
            OverflowMenu.populate(menu, with: OverflowMenu.perAppSubmenu(context).entries)
            return
        }

        // Populate from whatever the cache holds and return immediately. On the
        // very first open that is the "Looking for open apps…" placeholder, which
        // the refresh below replaces in place a moment later.
        OverflowMenu.populate(menu, with: OverflowMenu.perAppSubmenu(context).entries)

        // Out-of-band refresh. No `await` on this path, no semaphore, nothing
        // that blocks the tracking loop.
        Task { @MainActor [weak self, weak menu] in
            guard let self else { return }
            guard let apps = try? await self.source.availableApps() else { return }
            self.cache.update(apps)
            // The user may have dismissed the menu while this was in flight;
            // `menu` is weak precisely so that is a no-op rather than a crash.
            guard let menu else { return }
            OverflowMenu.populate(
                menu,
                with: OverflowMenu.perAppSubmenu(self.makeContext()).entries
            )
        }
    }
}

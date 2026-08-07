# The Glass design system, as Home Rec ships it

How the app's visual language works after the v1.2.0 reskin: where each value
comes from, and — because they carry the least obvious decisions — exactly how
the **background colour** and the **glass effect** are built.

The full language (every token, contrast table, and rationale) lives upstream in
[ui-explorations](https://github.com/melissa-pereira-deel/ui-explorations)
at `design-system/docs/glass.md`. This document covers *this app's adoption*:
what we took, what we composed ourselves, and the three places we deliberately
deviated. How the code is vendored and kept in sync is
[design-system-vendoring.md](design-system-vendoring.md).

## The shape of it

```
Tokens      DesignSystem/Vendor/Tokens/       colours, type, metrics, motion, theme
Primitives  DesignSystem/Vendor/Primitives/   surfaces, pills, chips, labels, brand
Components  DesignSystem/Vendor/Components/   the live waveform (+ timecode, unused)
Adapters    DesignSystem/Adapters/            app-owned: everything below
```

Vendored files are byte-identical to upstream and never edited (one recorded
exception, below). Everything the app decided for itself lives in `Adapters/`
and is named without the `Glass` prefix's upstream meaning — see the vendoring
doc for that convention.

Theme plumbing: `GlassTheme` rides the SwiftUI environment (`\.glassTheme`,
default `.standard`). Every surface root applies
`.glassThemeAdaptingToContrast()`, which swaps the palette to `.highContrast`
when macOS **Increase Contrast** is on. That modifier paints nothing — it is
the theme injector, not a material.

**Dark-only, deliberately.** The system has no light palette and upstream says
it never will. `NSApp.appearance = .darkAqua` is pinned in `AppDelegate` — one
line that also darkens everything SwiftUI cannot reach: the capture-source
`NSMenu`, the alerts, Sparkle's dialogs. Out of reach and left alone: the
menu-bar icon (follows the menu bar), `NSOpenPanel` and TCC prompts
(out-of-process, follow the system).

## The background colour

Two grounds exist, and choosing between them is the recurring decision:

| Ground | What it is | Where |
|---|---|---|
| `GlassWindowGround` | Real glass: desktop-sampling blur + tint (below) | Main window only |
| `GlassFlatGround` | Opaque fill of `ground` = **`#0D1119`** | Menu-bar popover, onboarding sheet, install-notice panel, recovery window |

The rule behind the split: **glass needs something to sample, and only the main
window has it** (the desktop behind a non-opaque window). The popover cannot
take glass because `NSPopover` already draws its own vibrancy — a second
material is two blurs over unknown content, which reads as mud. Sheets and
panels sit inside or over other surfaces and take the flat ground for the same
reason.

The upstream mesh backdrop (`GlassBackdrop`, a 3×3 `MeshGradient`) is vendored
but **unused**. Its stated purpose is to give a frosted *panel* tonal variation
to sample; this app's window has no inner panel, so the mesh just read as blue
wallpaper. If the layout ever grows a real glass panel, the mesh earns its
place back — that reasoning is recorded at the call site in `HomeRecApp.swift`.

Related tokens, for reference (all in `Vendor/Tokens/GlassColors.swift`):
`ground #0D1119` · `surfacePanel #1A1C22 @ 55%` · `surfaceCard #1C1C1E` ·
accent `#F23A3A` (record/stop and failure, nothing else — "Open System
Settings" and "Reveal in Finder" wear the neutral fills precisely so the
accent stays spent on one control at a time, which `RecordingState` guarantees
by construction).

## The glass effect

`Adapters/GlassWindowGround.swift`. Three layers, and each exists because the
obvious alternative fails:

1. **`NSVisualEffectView`, `.behindWindow` blending, `.hudWindow` material.**
   Not SwiftUI's `.ultraThinMaterial` — SwiftUI materials blend *within* the
   window, and with nothing in-window behind the ground they resolve to flat
   grey no matter how transparent the window is. Behind-window blending is the
   Control Center mechanism: the window server blurs the actual desktop.
   `.hudWindow` because it is the most translucent of the dark materials.
   `state = .active` is pinned — the default tracks key-window status, and the
   glass would flatten to grey whenever the user clicks elsewhere, which for a
   recorder left running in a corner is most of its life.

2. **`surfacePanel` tint (`#1A1C22 @ 55%`) *over* the blur.** ⚠️ This inverts
   upstream's tint-*under*-material rule on purpose. That rule exists for
   within-window materials, which sample whatever sits below them in the
   window; a behind-window effect view samples the desktop and ignores
   in-window layers entirely, so the only place a tint can do its job is on
   top. The tint's opacity is the one dial for "more glass" vs "more brand
   tone".

3. **A non-opaque window** (`isOpaque = false`, clear background), set by a
   zero-sized `NSViewRepresentable` hook. Zero-sized is load-bearing: an
   earlier version used a flexible ZStack sibling and the infinitely-flexible
   ground broke the window's fixed 450pt width. Backgrounds are sized *by*
   content, never the reverse — that invariant is what keeps the window small.

The titlebar is gone (`.windowStyle(.hiddenTitleBar)` — the SwiftUI lever;
AppKit-level titlebar overrides get reasserted from under you on scene
updates), so the glass runs to the top edge, the traffic lights float on it,
and the body drags the window (`isMovableByWindowBackground`). The app's name
lives in the header's brand lockup (`GlassBrandLockup`, the site's favicon +
wordmark, drawn not rasterised), which is why hiding the title text costs
nothing.

**Performance note.** The ground is attached at the window root in
`HomeRecApp.swift`, outside `RecorderView`'s body. `RecorderViewModel` is an
`ObservableObject` republishing waveform samples ~47×/sec during a take; a
ground inside the observing body would be dragged through every one of those
invalidations.

## The other adapters, briefly

- **`RecorderWaveformAdapter`** — signed samples → 0…1 bar magnitudes:
  peak-per-bucket (means flatten speech), then a **decibel** mapping with a
  −60 dBFS floor. The dB curve is not taste: the renderer floors bars at 2pt,
  so linear amplitude made everything under −29.6 dBFS — i.e. most real
  program material — indistinguishable from silence. Measured live before the
  fix: file at −8.6 dBFS peak drew a flat line. Fully unit-tested; the audio
  pipeline (`WaveformDownsampler`, `AudioRecorder`) is untouched.
- **`SettingsPopover`** — the header's settings control. Composed from
  primitives (`GlassEyebrow` + `GlassChip` row + `GlassNavLink`) because the
  system deliberately ships no picker component. Its background is the system
  popover material, not a Glass surface — same two-blurs rule as the menu-bar
  popover. Hidden during a take, exactly as the old shelf was.
- **`GlassPreviewFixtures`** — `#if DEBUG` sample data so vendored `#Preview`s
  compile without shipping fake data in a release build.

## The recorded deviations

1. **Pill focus ring shows only under Full Keyboard Access** — the one patch to
   a vendored file (`GlassPillButton.swift`; patch in
   `scripts/design-system/patches/`). SwiftUI grants focus on mouse click and
   keeps it past window-resign, so the accent ring became a permanent border on
   the accent-filled record control. Belongs upstream eventually: a ring colour
   that contrasts with the fill it surrounds.
2. **Tint over blur** in `GlassWindowGround` — see above; adapter-side, not a
   patch.
3. **White-on-accent measures ≈3.9:1**, under WCAG AA 1.4.3 for the pill
   label. Inherited from upstream, documented there, and an improvement on the
   ~3.5:1 the app shipped before; under Increase Contrast the fill becomes
   `accentStrong` and measures 5.7:1. Disclosed here so the trade-off stays a
   decision rather than becoming an oversight.

## Verifying any of this

`scripts/design-system/check-vendor-drift.sh` proves the vendored set is
byte-identical (plus the one recorded patch). `BundledFontTests` proves Inter
and Archivo actually resolve — a failed font lookup falls back to SF silently.
The visual states themselves are human-verified: see the reskin block in
[manual-acceptance.md](manual-acceptance.md).

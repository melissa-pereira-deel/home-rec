> **Current scope:** apply these visual tokens to the single fixed-window design in [SINGLE-WINDOW-DESIGN.md](SINGLE-WINDOW-DESIGN.md). References below to a detached naming panel or companion window describe the former presentation. Reuse the existing root material once on the stable host; Recorder’s visible output remains unchanged.

# Concept A — Recording Library color and token contract

Proposed app-owned Library specification, 5 September 2026. [color-tokens.json](color-tokens.json) is the machine-readable design handoff. It is not a new runtime theme loader. **The recorder view, its window root, colors, typography, geometry and interaction remain exactly as shipped.** No production source or vendored design-system file was changed for this proposal.

## Preserve the material, extend the library

Reuse the existing `GlassTheme` environment and contrast adaptation. Library window chrome and the detached naming panel use the existing `GlassWindowGround()` at their root, outside frequent recording-state updates. The scrolling library canvas is an explicit opaque `ground` plane (`#0D1119`) with opaque `surfaceCard` plates (`#1C1C1E`). This is an intentional readability surface inside the shared material; it is not a separate dark theme or a replacement for the recorder's glass. No card owns a separate blur or material view.

Actual source takes precedence over stale prose in `docs/design-system.md`: `GlassWindowGround.swift` now explicitly describes one shared desktop-sampling ground across surfaces. `MenuBarPopoverView.swift:173`, `RecoveryView.swift:29`, `OnboardingView.swift:116` and `SettingsPopover.swift:54` all use it. Its `.behindWindow` / `.hudWindow` effect, active material state, overlaid `surfacePanel` tint and nonopaque window configuration remain untouched. Do not introduce the earlier document's flat-root split into these shipped surfaces.

The token typography documentation describes Archivo as a brand family, but the actual recorder currently uses Archivo 18/34 and `Color.red`, with additional Archivo usage in menu/onboarding surfaces. These are **frozen existing behavior**, not cleanup tasks. New Library components use existing token roles; the palette does not authorize normalizing existing components.

Proposed app-owned implementation names: `RecordingLibraryPalette` and `RecordingArtworkPalette`, located in an app-owned adapter/component area. Do not add a new `Glass…` type, edit Vendor, replace the global theme, or reinterpret `GlassColorRole` across the application.

## Inherited aliases

Values below are verified from `DesignSystem/Vendor/Tokens/GlassColors.swift`; opacities are part of the color, not an instruction to fade the whole view. High Contrast means macOS Increase Contrast through the existing theme environment. Dark-only remains the shared language.

| Library alias / use | Existing token | Standard | High Contrast |
|---|---|---|---|
| Canvas | `ground` | `#0D1119` | same |
| Reserved mesh reference; not a new background | `groundRaised` | `#21243F` | same |
| Root material tint, renderer unchanged | `surfacePanel` | `#1A1C22` at 55% | same |
| Card / opaque naming field plate | `surfaceCard` | `#1C1C1E` at 100% | same |
| Subtle inset / numeric hover overlay reuse | `surfaceInset` | white 6% | same |
| Modal scrim if needed | `surfaceScrim` | black 45% | same |
| Decorative separator | `line` | white 8% | white 16% |
| Decorative edge light | `lineStrong` | white 18% | white 30% |
| Filename, heading, focused icon | `textPrimary` | white 92% | same |
| Supporting copy; metadata on interactive card states | `textSecondary` | white 65% | white 78% |
| Metadata on resting opaque card/canvas | `textTertiary` | `#8E8E93` | `#AEAEB2` |
| Play / principal neutral action fill | `controlPrimaryNeutral` | `#F2F2F5` | same |
| Companion action fill | `controlSecondary` | `#C2C2CA` | same |
| Glyph/label on either light control | `textOnNeutralControl` | `#0D0D0F` | same |
| Neutral status decoration only | `statusNeutral` | white 25% | same |
| Existing recording / stop fill | `accent` | `#F23A3A` | `#C72121` |
| Existing pressed recording fill | `accentStrong` | `#C72121` | same |
| Existing disabled recording fill | `accentMuted` | `#F23A3A` at 45% | same |
| Real error indicator | `statusDanger` | `#F23A3A` | same |
| Error/accent text where needed | `textAccent` | `#FF6B6B` | same |
| Existing text on recording fill | `textOnAccent` | white | same |
| Real warning indicator | `statusWarning` | `#EBA82E` | same |
| Real success indicator | `statusSuccess` | `#30D158` | same |

Red remains reserved for recording and actual errors. Play, pause, selected cards, pagination, search, focus and active format filters are neutral. An unavailable file is described with words and an icon; do not spend error red on every unavailable catalog entry. Use an error treatment only when an attempted operation fails. Decorative hairlines do not claim to meet interactive-boundary contrast requirements.

## Proposed Library-only states

These are new semantic aliases, even when their numbers reuse a vendor token. They do not change upstream role definitions. State overlays apply to `surfaceCard`, not to artwork, controls or the whole view tree. Resolve a single state with precedence **selected > pressed > hover > rest**; never accumulate several white overlays.

| State | New app-owned treatment | Composite on `#1C1C1E` | Metadata |
|---|---|---|---|
| Rest | Opaque card | `#1C1C1E` | `textTertiary` |
| Hover | White 6%; numeric reuse of `surfaceInset` | approximately `#2A2A2C` | `textSecondary` |
| Pressed | White 8%; proposed fill, not an alias to `line` | approximately `#2E2E30` | `textSecondary` |
| Selected | White 12%; proposed fill | approximately `#373739` | `textSecondary` |
| Selected boundary | 1 pt `textSecondary` on the dark card perimeter | 6.04:1 standard against selected fill | Selected accessibility trait too |
| Keyboard focus | 2 pt `textPrimary`, 2 pt dark separation outside target | at least 10.30:1 against specified dark states | No new bright-blue focus token |
| Disabled action | Existing `textTertiary.opacity(0.5)` convention for its glyph only | Not used for readable metadata | Explain why with readable normal text |

The focus width/offset are proposed app-local accessibility geometry. Existing ordinary hairlines remain 1 pt. Place the focus ring on a dark exterior plate with separation around light buttons or decorative covers; white directly over a pale gradient does not have the asserted contrast. The selected boundary and external focus ring have distinct placement and width. Selection persists without focus; a color change alone is not the only selection cue.

In High Contrast, keep these opaque state fills and use the inherited brighter text/line variants. Do not repurpose the vendor `line` role for a state fill: its opacity changes to 16% in High Contrast. A white 6/8/12% fill is subtle and is not by itself the accessible selected-state boundary.

Play is an opaque 32 pt neutral disc, using `controlHeightSmall`, with an ink symbol and a distinct accessible button label. It may overlap the cover edge, but its glyph never relies on the cover's color. Hover/press darken its fill using proposed black 6%/8% overlays, preserving the label; do not animate the artwork. More-actions symbols use at least the inherited 28 pt hit target. A selected card's menu and play controls remain visually distinguishable.

## Restrained artwork family

The reference's pink direction (`#F4AFD6` → `#D774D8`) is inspiration, not a claimed sampled or existing brand token. The following **new app-owned decorative palette** reduces saturation and introduces quiet variety:

| Family | Top-leading | Bottom-trailing | Intent |
|---|---|---|---|
| Rose | `#D6A0BB` | `#AF739E` | Closest to the supplied reference |
| Iris | `#ABA5CC` | `#797394` | Soft violet, distinct from recording red |
| Mist | `#AAC0BF` | `#729197` | Cool desaturated balance |
| Sand | `#D0BD9D` | `#A28A71` | Warm quiet counterpoint |

The artwork is an opaque two-stop diagonal gradient. No filename, metadata, status label or focus ring is placed directly on it. Its only job is stable visual identity; it never signals format, availability, recording state or importance. No inferred artist/creator text, audio fingerprinting or decoding is needed.

For palette version 1, sum the 16 UUID bytes and use modulo 4 against the fixed order Rose, Iris, Mist, Sand. This is deterministic across launches and renames; Swift's randomized `Hasher` is unsuitable. Palette assignment need not be unique—four decorative groups are not record identities. Retain the version so future visual revisions are deliberate. Keep colors unchanged under Increase Contrast and Reduce Transparency: accessible meaning lives in the separate opaque controls and text, and the art is already opaque.

## Calculated contrast, with scope made explicit

Ratios were computed for the specified opaque Library planes using a script, not measured from a rendered native screenshot. Source-over composition is `C = alpha × foreground + (1 − alpha) × background` in encoded sRGB; the composite channels are then linearized with the WCAG sRGB transfer function. Relative luminance is `0.2126 R + 0.7152 G + 0.0722 B`, and contrast is `(lighter + 0.05)/(darker + 0.05)`. Ratios use unrounded channels; hex composites and displayed ratios are rounded for documentation.

We use 4.5:1 for normal Library text and 3:1 for meaningful graphical indicators as design checks. This math is not a claim that all keyboard, low-vision or native accessibility requirements have been tested. [W3C text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), [W3C non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html).

| Opaque backdrop | Primary 92% | Secondary 65% | Tertiary `#8E8E93` | HC secondary 78% | HC tertiary `#AEAEB2` |
|---|---:|---:|---:|---:|---:|
| Canvas `#0D1119` | 15.99 | 8.29 | 5.80 | 11.60 | 8.55 |
| Resting card `#1C1C1E` | 14.51 | 7.81 | 5.22 | 10.71 | 7.69 |
| Card + white 6% hover | 12.41 | 6.97 | **4.42 — insufficient** | 9.34 | 6.51 |
| Card + white 8% pressed | 11.69 | 6.67 | **4.15 — insufficient** | 8.86 | 6.12 |
| Card + white 12% selected | 10.30 | 6.04 | **3.63 — insufficient** | 7.91 | 5.35 |

Therefore metadata **must promote to `textSecondary` whenever hover, pressed or selected treatment covers its backdrop**. An alternative component composition may keep the metadata strip at the unchanged opaque card value, but must not mix these contracts accidentally. Even the 6% hover is enough to put standard tertiary text below 4.5:1. Avoid whole-card opacity for unavailable/disabled states because it dims required filename and metadata too.

`textOnNeutralControl` measures **17.38:1** on `controlPrimaryNeutral` and **10.97:1** on `controlSecondary`. The play-disc hover and pressed treatments retain approximately **15.23:1** and **14.55:1** respectively. The neutral focus color exceeds 3:1 on all listed dark planes; these results do not apply when the ring is drawn directly over art or a white control.

The shipped recorder's white label on `#F23A3A` measures **3.86:1**; white on its High Contrast `#C72121` measures **5.73:1**. This is an existing documented exception, not a passing normal-text combination. **Recorder freeze takes precedence: do not change its color or label, and do not replicate this exception in new Library controls.** None of these flat-plane ratios certify text over the actual desktop-sampling glass; Library chrome/naming text needs a separate native visual check on light, dark and high-detail desktops, with opaque inset backing where necessary in those new surfaces only.

## Reuse type, geometry and motion

Use theme typography: Library heading `.title` (Inter 14 medium), card name `.bodyEmphasized` (Inter 13 medium), supporting labels `.caption` (Inter 12 regular), controls `.controlCompact` (Inter 12 semibold), and machine metadata `.meta` (system monospaced 10 regular). Honor existing role scaling and font fallback. These are default point sizes, not fixed CSS assumptions or an invitation to shrink content to fit. New Library captions should not invent a 9 pt language-text role.

Reuse `GlassSpacing`: 2/4/6/8/10/12/14/18/22/28 pt. Proposed mappings: content gap or applicable internal component padding 12 (`md`), grid gap 18 (`xl`), window content inset 22 (`xxl`). **The reference-led tile has no additional padded card shell.** The 12 pt spacing alias must not add a second container around cover and captions. Ordinary card/state plates use radius 12; the artwork alone uses **22 pt as an explicit Library media exception**, numerically reusing the existing panel-radius value without redefining its global meaning. Reuse inner radius 10, control radius 6 and capsule behavior for pills. Minimum action target remains 28 pt. Keep this artwork exception and app-local focus geometry explicit instead of changing shared metrics.

Reuse motion `.press` 100 ms, `.hover` 120 ms, `.quick` 150 ms and `.reveal` 200 ms, all ease-out. Hover changes luminance, not scale/position. No new spring, pulse, shifting gradient, blur animation, tilt or cover bounce is introduced. The delightful part is consistent feedback and stable arrangement.

## Accessibility and window state

- **Reduce Motion:** press/hover appearance changes become immediate; other reveals can use at most the existing 150 ms opacity transition. No translation/scale or art motion remains.
- **Reduce Transparency:** content is already opaque. New Library/naming host composition can use opaque inherited `ground` in place of its root effect for this setting, without editing the shared renderer or changing the recorder. The existing renderer has no explicit app-side Reduce Transparency branch; do not claim one exists or silently patch it under this ticket.
- **Increase Contrast:** use the existing high-contrast palette, visible selection boundary and neutral external focus ring; verify native menu/control behavior separately.
- **Inactive Library window:** retain text contrast and selected identity. Suppress the Library keyboard-focus ring when the window is not key, retaining its selected boundary. Do not flatten the shared material or dim an entire gallery because the recorder became active.
- **Unavailable media / disabled preview during capture:** retain legible names, metadata and reason labels. Disable only the action that cannot run. Status includes words/icons and VoiceOver state; hue is supplementary.

## Acceptance criteria for implementation handoff

1. Recorder source, root, layouts, existing token values and vendored files are unchanged; no global theme override is added.
2. Library chrome reuses the current ground renderer; the scrolling canvas and cards use the specified opaque planes with zero per-card blur.
3. All colors in new components resolve through inherited semantic roles or the explicitly proposed app-owned artwork/state values in the JSON; red never indicates playback, selection or focus.
4. Card state precedence avoids opacity stacking; metadata follows the contrast rule. Focus remains visible on the dark plate around artwork and light controls.
5. Native standard/Increase Contrast, Reduce Motion, Reduce Transparency, inactive-window and keyboard-focus screenshots are reviewed. Mathematical contrast alone does not complete this check.
6. UUID-derived artwork is identical before/after rename and across process launches; there are no audio reads, gradient animations, or external image requests for library browsing.

# GlassKit

**The Glass design system for Home Rec.** Frosted panels over a quiet deep-blue ground, warm charcoal cards, monospace metadata, lowercase controls, and exactly one accent — brand red — spent on the record state and nothing else.

- **Package:** `GlassKit` (macOS 15+, SwiftUI)
- **Source:** `design-system/Sources/GlassKit`
- **Specimen sheet:** `GlassKitGallery()` — every token, primitive, component and state on one scrollable surface
- **Extracted from:** the Glass Shelf concept in `prototypes/HomeRecConcepts`, and the product spec at `prototypes/HomeRecConcepts/docs/glass-spec.md`

```swift
import GlassKit

struct RecorderFace: View {
    var body: some View {
        ZStack {
            GlassBackdrop()
            GlassPanel { … }
        }
        .glassThemeAdaptingToContrast()
    }
}
```

---

## 1. Visual language and tone

### What the interface is trying to be

A recorder that a musician leaves open in the corner of a screen for six hours. That single sentence decides most of what follows: nothing may blink for attention, nothing may be ambiguous about whether audio is being written to disk, and the panel must be legible at a glance from across a room without ever being loud.

Four commitments:

**1. Glass over something.** The panel is `.ultraThinMaterial` over a deep-blue mesh ground. This is not decoration — it is how the panel says *I am floating above your work, not replacing it*. A frosted panel over flat black is just a grey rectangle; the material has nothing to sample. If you put a Glass panel on an opaque background, use `GlassFlatGround` and accept that it will read as a card, not as glass.

**2. One accent, and it is expensive.** Brand red (`#F23A3A`) means *record*, *stop*, *the playhead*, or *this failed*. It appears on at most one control at a time. The moment a second red control exists on screen, the first has stopped meaning anything. Everything else is a grey — and the greys carry an enormous amount of the design's work.

**3. Two type registers, and the difference is information.** Anything a person wrote is Inter (`kitchen radio, morning`). Anything a machine measured is SF Mono (`48kHz · 16-bit · wav · 26.4MB`, `1:12:03`, `2h`). A reader knows which is which before reading either. This is also why monospace here is not a retro affectation: it stops columns of changing numbers from dancing.

**4. Lowercase controls, sentence-case prose.** `record`, `stop`, `all takes →`, `show all` — the control register is lowercase, which reads as calm and slightly technical. Notice messages and onboarding copy are sentence case with real punctuation, because they are sentences, and a lowercase error message reads as flippant when someone has just lost a take.

### Tone of voice

| Register | Example | Rule |
|---|---|---|
| Controls | `record` · `stop` · `saving…` | lowercase, one or two words, verb-first |
| Navigation | `all takes →` · `← record` | lowercase, arrow shows direction |
| Metadata | `48kHz · 16-bit · wav · 26.4MB` | mono, `·` separated, never wraps |
| Empty states | `nothing here yet.` / `record something.` | lowercase, full stop, invitational |
| Notices | `Home Rec couldn't start recording. Make sure some audio is playing, then try again.` | sentence case, says what happened *and* what to do |

Notice and error copy is **verbatim product copy** and the kit ships none of it. Error strings are already written, reviewed and localised in the app; a design system that paraphrases them creates two sources of truth for the same sentence.

### Dark only, on purpose

There is no light theme and there will not be one. This is a panel that floats over whatever the user is actually looking at — a DAW, a browser, a video — and a light variant would put a bright rectangle in front of that. `GlassColors.highContrast` is a *variant* of the dark palette, applied automatically when the system reports increased contrast; it is not a second theme.

---

## 2. Colour

Roles are named for the job the colour does, never for the colour it is. `accent` can be re-skinned to teal without a rename; `red` could not.

### The palette

| Role | Value | Use | Contrast on card |
|---|---|---|---|
| `ground` | `#0D1119` | Window ground; darkest node of the backdrop mesh | — |
| `groundRaised` | `#21243F` | Brightest mesh node; the blue the glass picks up | — |
| `surfacePanel` | `#1A1C22` @ 55% | Tint **under** the panel material. Reads ≈ `#26282E` through glass | — |
| `surfaceCard` | `#1C1C1E` | Cards, rows, notices, neutral pills. **The contrast baseline** | — |
| `surfaceInset` | white 6% | Containers carved *into* the panel (onboarding permission row, ghost pills, hover plates) | — |
| `surfaceScrim` | black 45% | Scrim behind modal cards | — |
| `line` | white 8% | Interior hairlines between cards and rows | — |
| `lineStrong` | white 18% | Panel edge-light; must survive the material | — |
| `textPrimary` | white 92% | Titles, take names, control labels | **14.5:1** |
| `textSecondary` | white 65% | Supporting copy, subtitles | **7.8:1** |
| `textTertiary` | `#8E8E93` | Monospace metadata, eyebrows, timestamps | **5.2:1** |
| `textOnAccent` | `#FFFFFF` | Labels on accent fills | 3.9:1 on `accent` — see §8 |
| `textAccent` | `#FF6B6B` | Accent-coloured **words** | **6.1:1** |
| `accent` | `#F23A3A` | Record/stop fill, playhead, live waveform. **Fills only** | 4.4:1 |
| `accentStrong` | `#C72121` | Pressed accent; accent fill under increased contrast | — |
| `accentMuted` | `#F23A3A` @ 45% | Accent fill inside a disabled control | — |
| `statusDanger` | `#F23A3A` | Error notices | 4.4:1 |
| `statusWarning` | `#EBA82E` | Long-recording warning | **8.3:1** |
| `statusSuccess` | `#30D158` | Permission granted / ready | **8.4:1** |
| `statusNeutral` | white 25% | Secondary notice actions, terminal blocks | — |

Ratios are measured against `surfaceCard` (`#1C1C1E`), which is the most common text background and the more conservative of the two. On the lighter panel surface (≈ `#26282E`) every ratio drops about 12%: `textTertiary` becomes 4.5:1, still AA.

### Decisions worth explaining

**Why `accent` is `#F23A3A` and not the wordmark's `#FF3E3E`.** Large solid fills read hotter than thin strokes. At 44 × 130pt the wordmark red vibrates against a dark panel; pulled ~5% darker it sits at the same *perceived* intensity as the logo does at its size. If you ever put the accent on a thin stroke at small size, the wordmark red is the correct value — but the kit has no such use, so it is not a token.

**Why `textAccent` exists.** `#F23A3A` reaches only 4.4:1 on the card, which fails WCAG AA for body text. Rather than let accent-coloured words ship at a failing ratio, the system defines a lighter tint for type (`#FF6B6B`, 6.1:1) and reserves `accent` itself for fills, strokes and indicators — which need 3:1, not 4.5:1. **If you are colouring text with `accent`, you want `textAccent`.**

**Why amber and not a second red for warnings.** The long-recording nudge and a capture failure must be distinguishable *without reading them* — and for a colour-blind user, without relying on hue. `#EBA82E` and `#F23A3A` separate in greyscale (8.3:1 vs 4.4:1 luminance against the same card); two reds would not.

**Why `textTertiary` is a hue and every other text colour is an opacity.** White-at-opacity composites differently over the card and over the panel, and metadata is the one text role that lands on both. A fixed grey holds its ratio in both places.

---

## 3. Type

Three families, fourteen roles, no free-form sizes.

- **Inter** — UI. Language: names, copy, control labels.
- **SF Mono** — data. Anything a machine produced.
- **Archivo** — the wordmark, and only the wordmark.

Inter and Archivo are optional at runtime. If a host has not registered them, `GlassTypography` falls back to the system font at the same size, so the kit is correctly *proportioned* even in SF. Everything else — spacing, hit targets, the pill's optical offset — adapts (`GlassTypography.usesCustomUIFamily`).

### The scale

| Role | Family | Size | Weight | Tracking | Leading | Max scale | Use |
|---|---|---|---|---|---|---|---|
| `wordmark` | Archivo | 26 | semibold | −0.3 | — | 2.0 | Onboarding brand lockup |
| `appTitle` | Inter | 13 | bold | — | — | 2.0 | Panel header wordmark |
| `timer` | SF Mono | 30 | light | — | — | **1.4** | Hero timecode |
| `timerCompact` | SF Mono | 14 | medium | — | — | 2.0 | Recording-bar timer |
| `title` | Inter | 14 | medium | — | — | 2.0 | Expanded take title |
| `body` | Inter | 13 | regular | — | — | 2.0 | Take names, supporting copy |
| `bodyEmphasized` | Inter | 13 | medium | — | — | 2.0 | The permission ask |
| `control` | Inter | 14 | semibold | +0.1 | — | 2.0 | Primary pill label |
| `controlCompact` | Inter | 12 | semibold | +0.1 | — | 2.0 | Compact pill labels |
| `caption` | Inter | 12 | regular | — | — | 2.0 | Chips, secondary labels |
| `captionSmall` | Inter | 11 | regular | — | +2 | 2.0 | Notice messages, hints |
| `meta` | SF Mono | 10 | regular | — | — | 2.0 | Metadata, eyebrows, nav links |
| `metaSmall` | SF Mono | 9 | regular | — | — | 2.0 | Badges, densest metadata |
| `timecodeChip` | SF Mono | 10 | medium | — | — | **1.0 (fixed)** | Floating timecode capsule |

```swift
Text("kitchen radio, morning").glassText(.body, color: .textPrimary)
Text("48kHz · 16-bit · wav").glassText(.meta, color: .textTertiary)
Text("record").glassText(.control)          // colour comes from the pill
```

Passing `color: nil` (the default) leaves the foreground alone. That matters: an inner `foregroundStyle` silently beats an outer one, so a parent tint — a notice, a selected row, an accent fill — must be able to reach the text through the modifier.

### Decisions worth explaining

**Why `timer` is light weight at 30pt.** The number is already the largest thing on the panel. Weight on top of size makes the recorder shout its own chrome; light at 30pt is authoritative without being loud, and monospace digits at light weight stay perfectly legible because they never touch.

**Why `control` carries +0.1 tracking.** Lowercase Inter semibold at 14pt closes up inside a solid capsule — `record` starts to blot. A tenth of a point of air fixes it and is invisible as a decision.

**Why `captionSmall` carries +2 leading.** Notice copy is the only text in the kit that regularly wraps to three lines. At 11pt with default leading it sets too tight to scan under stress, which is exactly when it is read.

**Where fixed sizing is deliberate.** Two roles cap their Dynamic Type growth:

- `timer` caps at ×1.4. The recorder face is a fixed-size floating panel; a 2× timer pushes the transport control off it. Capping keeps the control reachable, which matters more than the timer being larger still.
- `timecodeChip` does not scale at all. Its horizontal clamp is computed from a known glyph advance (SF Mono's stable 0.61 × point size) *during* layout, because a measurement pass would put a frame of lag into a control that moves 30 times a second. Fixed size is what keeps that arithmetic honest.

Everything else scales, including 9–10pt monospace metadata. macOS has no per-app text-size slider, but `dynamicTypeSize` is a real environment value that hosts, previews and the gallery can set, and honouring it costs nothing.

---

## 4. Space, radius, layout

### Spacing scale

A 2pt base in two bands. The gap between 14 and 18 is deliberate — the kit has dense rhythms and architectural ones, and nothing in between reads as intentional.

| Token | pt | Band | Typical use |
|---|---|---|---|
| `xxs` | 2 | dense | Badge inner padding |
| `xs` | 4 | dense | Icon-to-label in a dense row |
| `sm` | 6 | dense | Shelf card stack, chip row |
| `s` | 8 | dense | Notice action row, waveform inset |
| `m` | 10 | dense | Row content spacing |
| `md` | 12 | dense | **The default gap between siblings** |
| `l` | 14 | dense | Expanded card padding |
| `xl` | 18 | architectural | Panel padding |
| `xxl` | 22 | architectural | Window inset around the panel |
| `xxxl` | 28 | architectural | Modal card padding |

### Radii

| Token | pt | Use |
|---|---|---|
| `control` | 6 | Small hover plates (nav link, icon button) |
| `inner` | 10 | Cards nested inside cards |
| `card` | 12 | Cards, rows, notices |
| `cardLarge` | 14 | Expanded / active cards |
| `window` | 12 | The floating window itself |
| `panel` | 22 | Frosted panels and modal cards |
| `pill` | capsule | All pills and chips |

**The nesting rule:** an inner corner is always smaller than the corner it sits inside, by roughly the padding between them, so the two curves stay concentric. Panel 22 − 18pt padding ≈ card 12 is not a coincidence. If you nest a card inside a card at the same radius, the inner one will look wrong and no one will be able to say why.

Pills use a true `Capsule`, never a large fixed radius, so they stay capsules when Dynamic Type grows them.

### Layout rules

- **The panel does not resize to fit its content.** The recorder face is a fixed 450 × 450 floating window. Content adapts to the panel, not the other way round.
- **One notice slot per surface, and it is shared.** A notice takes the slot that secondary content (the recent-takes shelf) normally occupies rather than adding height. See §11.2.
- **Metadata truncates, never wraps.** A wrapped spec line turns a fixed-height list into a jittering one. Notice copy is the single exception — it must never truncate, because the truncated half is always the part that says what to do.
- **Control labels never wrap and never truncate.** If a label doesn't fit, it is too long for the register — that is a copy bug, not a layout problem.
- **Right-hand metadata columns are age over duration**, both mono, both right-aligned, so a list scans as a table without drawing one.

---

## 5. Elevation and materials

Depth is carried by three cues *at once* — shadow, edge-light opacity, and material. A level that changes only one of the three reads as a rendering bug.

| Level | Shadow | Edge-light | Material |
|---|---|---|---|
| `flush` | none | `line` | none |
| `row` | 4pt / y2 @ 18% | `line` | opaque card |
| `raised` | 6pt / y3 @ 22% | tinted (accent for active rows) | opaque card |
| `panel` | 30pt / y18 @ 35% | `lineStrong` | ultraThin + tint |
| `modal` | 30pt / y18 @ 40% | `lineStrong` | ultraThin + black 35% underlay |

### Surfaces

`GlassSurfaceStyle` is the declarative description; `.glassSurface(_:)` applies it in the one order that produces a correct result — stroke before clip, clip before shadow. Swap any two and you get a clipped border, or a shadow cast by the content instead of the card.

| Style | What it is |
|---|---|
| `.panel` | The frosted top-level container |
| `.modal` | A card floating over a scrimmed panel |
| `.card` | Notices, live card, containers inside a panel |
| `.row` | A list row |
| `.rowActive(tint:)` | Selected / playing / renaming row — one step up in radius *and* elevation |
| `.inner` | A card inside a card |
| `.inset` | Carved into the panel rather than stacked on it |
| `.live` | The capture card: top-lit gradient stroke, no shadow |
| `.notice(tint:)` | A notice, tinted by severity |
| `.popover` | Settings popovers |

**Why the panel tint sits under the material, not over it.** Over, the tint flattens the blur into a solid colour and the glass stops sampling the ground. Under, the material still blurs the mesh and the tint gives the glass a body. Bare `.ultraThinMaterial` over a dark ground reads as washed-out grey.

**Why modal cards get a black underlay.** Without it, the controls of the panel *behind* the card ghost through the glass as bright bands — most visibly, the record pill appears as a red smear behind the onboarding CTA.

**Why the live card is top-lit instead of stroked.** It is a window into the signal, not an object on the panel. A gradient edge-light that fades to nothing by the vertical centre reads as glass under a light; a flat 1pt border reads as a box.

**Why the onboarding CTA's shadow is red.** It is the only non-black shadow in the kit. The card already casts a 30pt black shadow, so a second black shadow disappears into the first; a soft accent glow separates the button from the card without adding a border.

---

## 6. Motion

This is a recorder. Motion has exactly one job: to make a state change legible in the moment it happens. Nothing decorates, nothing bounces for character, and nothing animates a value the user is reading.

| Token | Curve | Used for |
|---|---|---|
| `press` | 0.10s easeOut | Press feedback (scale 0.97, brightness −0.06) |
| `hover` | 0.12s easeOut | Hover (scale 1.03) |
| `quick` | 0.15s easeOut | Chip selection, small reveals, transport label swap |
| `swap` | 0.18s easeOut | The notice slot exchanging content |
| `reveal` | 0.20s easeOut | Modal presentation, onboarding slot flip |
| `expand` | spring 0.35 / 0.80 | A row expanding into the player |
| `materialize` | spring 0.40 / 0.75 | The beat when a fresh take lands |
| `playhead` | linear 1/30s | Playhead and live-trace updates |

Springs are reserved for things that change **size**, where a linear curve looks mechanical. `playhead` is linear because the value *is* time, and easing time is a lie.

### State durations

These are not curves; they are how long a state lasts, and they are part of the product contract.

| Timing | Value | Why |
|---|---|---|
| `minimumArming` | 250ms | A state that flickers past is worse than one that never appeared |
| `minimumStopping` | 450ms | A saved file should feel saved |
| `savedDwell` | 1.4s | The number the user just made shouldn't evaporate — **and the control is armed for the whole dwell** |

### Reduce Motion

**The rule: position and scale changes are removed; opacity changes are kept.** A user who asked for less motion still needs to see that the notice row replaced the shelf — they just shouldn't have to watch it travel. Press and hover feedback are dropped entirely (the pill's colour change already carries them); the pulsing record dot becomes a steady dot at the *bright* end of its breath, never the dim end, because a permanently dim dot says "idle".

Use `.glassAnimation(_:value:)` rather than `.animation(_:value:)` everywhere — it reads `accessibilityReduceMotion` for you. For imperative calls, `GlassMotionToken.quick.resolved(reduceMotion:)`.

---

## 7. Theming

Every component resolves its look from `EnvironmentValues.glassTheme`. Components never reference `GlassColors.standard` directly — that indirection is the difference between a design system and a namespace of constants.

```swift
public struct GlassTheme {
    public var colors: GlassColors
    public var typography: GlassTypography
    public var metrics: GlassMetrics
    public var materials: GlassMaterials
    public static let standard: GlassTheme
    public static let highContrast: GlassTheme
}

ContentView().glassTheme(.standard)          // explicit
ContentView().glassThemeAdaptingToContrast() // standard, swapping on increased contrast
```

Apply one of these once at the root of a Glass surface. The default value is `.standard`, so a component works with no setup at all — injection is for re-skinning, not for booting.

---

## 8. Accessibility

### Contrast

| Text role | On card `#1C1C1E` | On panel ≈ `#26282E` | Verdict |
|---|---|---|---|
| `textPrimary` | 14.5:1 | 12.6:1 | AAA |
| `textSecondary` | 7.8:1 | 6.8:1 | AAA |
| `textTertiary` | 5.2:1 | 4.5:1 | AA |
| `textAccent` | 6.1:1 | 5.3:1 | AA |
| `statusWarning` | 8.3:1 | 7.1:1 | AAA |
| `statusSuccess` | 8.4:1 | 7.3:1 | AAA |
| `accent` (as fill) | 4.4:1 | 3.8:1 | AA for graphics (3:1) — **not for text** |

**The one known deviation, stated plainly.** White on the `accent` fill measures **3.9:1**. The primary pill's label is 14pt semibold, which is not "large text", so this fails WCAG AA 1.4.3 as text. It is kept because the pill also satisfies 1.4.11 (non-text contrast, 3:1) as a graphical object, carries a redundant icon, and is announced by VoiceOver with a full sentence. The mitigation is real, not theoretical: under increased contrast the accent fill swaps to `accentStrong` (`#C72121`), where white measures **5.7:1** and passes. If your product cannot accept the standard-contrast deviation, ship `GlassTheme.highContrast` unconditionally.

Disabled controls sit near 3:1 by design and are exempt under 1.4.3 (inactive components), but they stay readable enough to tell you *what* is disabled — 75% white rather than a token dim.

### Hit targets

28pt is the floor for every interactive element. macOS has no 44pt convention, but it does have people with tremor and trackpads. Controls whose *visual* is smaller grow their *hit region* to the floor without moving the visual:

- Mini pill: 26pt capsule, 28pt target
- Chip: ~24pt capsule, 28pt target
- Nav link: 24pt hover plate, 28pt target (a 28pt plate next to 10pt mono reads as a button and unbalances the header row)
- Icon button: 12pt glyph, 28pt square target, hit-tested as a rectangle so the empty corners count

Scale effects on hover deliberately sit *outside* the content shape. A hit region that grows on hover makes the pointer chase its own hover state at the boundary.

### Screen reader commitments

| Commitment | Where |
|---|---|
| Rows read as **one** element | `GlassTakeRow` — `children: .ignore` plus a composed label. Five elements per row makes a 50-item library unnavigable |
| Notices read as **containers** with a severity prefix | `GlassNoticeRow` — `children: .contain`, label `"Problem"`/`"Warning"`/`"Blocked"`, value = the message. Actions stay individually reachable |
| Live timers are marked `.updatesFrequently` | `GlassTimecodeDisplay` when `isLive` |
| Timecodes are **spoken**, not read as digits | `GlassTimecode.spoken(_:)` — VoiceOver reads `1:12:03` as "one twelve oh three", which is a phone number |
| Custom scrubbers are represented as Sliders | `GlassScrubRuler` — a `Canvas` + `DragGesture` is completely invisible to assistive tech. `.accessibilityRepresentation { Slider… }` gives arrow-key adjustment and a spoken position |
| Icon buttons **cannot** be created without a label | `GlassIconButton(systemImage:accessibilityLabel:)` — the label is a required initialiser argument, not an optional modifier |
| Selection is a trait, not a colour | `GlassChip` and active rows add `.isSelected` |
| Decorative elements are hidden | Waveforms, pulse dots, badges that decorate a neighbour, the timecode chip (it duplicates the player's own readout) |
| The monitoring badge is **not** hidden | It is a guarantee about the recording, not decoration: "Monitoring only. This playback is not being recorded." |
| Reduce Motion is honoured everywhere | `.glassAnimation(_:value:)`; see §6 |
| Format locks are disabled **with a reason** | `GlassTransportPermissions.formatLockReason(_:)` feeds a `help` tooltip. A disabled control with no reason is indistinguishable from a broken one |

---

## 9. Primitives

### `GlassPanel` / `GlassCard` / `.glassSurface(_:)`

```swift
GlassPanel(padding: CGFloat? = nil, style: GlassSurfaceStyle = .panel) { … }
GlassCard(padding: EdgeInsets = …, style: GlassSurfaceStyle = .card) { … }
func glassSurface(_ style: GlassSurfaceStyle) -> some View
```

**Use** `GlassPanel` once per screen as the outermost container. **Don't** nest panels for grouping — use `.card` or `.inner`. **Don't** put a Glass panel on an opaque light background; it has nothing to blur.

### `GlassPillButton` / `GlassPillButtonStyle`

```swift
GlassPillButton(_ title: String,
                systemImage: String? = nil,
                variant: GlassPillVariant = .solid,
                size: GlassPillSize = .large,
                isFullWidth: Bool = false,
                action: @escaping () -> Void)

// or on any Button:
.buttonStyle(.glassPill(.neutral, size: .mini))
```

Variants: `.solid` (accent), `.solidTinted(Color)` (status), `.neutral` (card fill), `.ghost` (outline).
Sizes: `.large` 44 · `.medium` 36 · `.small` 32 · `.compact` 30 · `.mini` 26.

**Use** `.solid` for the one primary control on screen. **Don't** put two solid pills on one surface — the second one steals the first one's meaning. **Don't** use `.solid` for a blocked or waiting state: a pill that can't record must not look like the pill that can. **Don't** hand-roll a capsule button; the hover/press vocabulary and the hit-target growth are in the style.

The pill applies a **1pt optical offset** to its label at `.large` when Inter is the resolved face — Inter's cap height sits low in a capsule of that proportion, so a mathematically centred label reads 1pt low. The offset is skipped for the SF fallback, which is centred correctly and would be pushed *off* centre by it.

### `GlassChip`

```swift
GlassChip(_ title: String, isSelected: Bool, help: String? = nil, action: @escaping () -> Void)
```

**Use** for a small, mutually exclusive, always-visible option set. **Don't** use a chip to *do* something — chips choose, pills act. **Don't** hide the unselected chips behind a menu; a hidden filter is a filter nobody knows exists.

### `GlassBadge` / `GlassPulseDot`

```swift
GlassBadge(_ title: String, style: .outline | .filled, tint: GlassColorRole = .textTertiary, textRole: GlassTextRole = .metaSmall)
GlassPulseDot(isAnimating: Bool = true)
```

Badges are outlined by default because a filled badge at this size competes with the pills, and in a recorder nothing may compete with the pills. Badges are `accessibilityHidden` — the row that contains one folds it into its own label. **Don't** un-hide a badge unless it carries information the row's label doesn't (`GlassMonitoringBadge` is the one case).

### `GlassMetaLabel` / `GlassEyebrow` / `GlassDivider`

```swift
GlassMetaLabel(_ text: String, role: GlassTextRole = .meta, color: GlassColorRole = .textTertiary)
GlassEyebrow(_ text: String, isAccessibilityHeading: Bool = true)
GlassDivider(_ axis: .horizontal | .vertical, color: GlassColorRole = .line)
```

**Use** `GlassMetaLabel` for anything a machine produced. **Don't** use it for a take name — that is `body` in Inter, and the register is the information.

### `GlassIconButton` / `GlassNavLink`

```swift
GlassIconButton(systemImage: String,
                accessibilityLabel: String,          // required
                accessibilityHint: String? = nil,
                symbolSize: CGFloat = 12,
                color: GlassColorRole = .textTertiary,
                action: @escaping () -> Void)

GlassNavLink(_ title: String, accessibilityHint: String? = nil, action: @escaping () -> Void)
```

**Use** `GlassNavLink` whenever text is interactive. **Don't** style a plain `Text` as a link — interactive text without a hover state and a pointer cursor reads as metadata, and users won't click it.

---

## 10. Components

### 10.1 Transport control — the state machine

**The highest-value component in the kit.**

```swift
public enum GlassTransportState: Hashable, Sendable {
    case idle
    case arming
    case recording(startedAt: Date)
    case stopping
    case saved
    case blockedByPermission(GlassPermissionBlock)   // .notDetermined | .denied | .openingSettings
    case blockedByInstall
}

public enum GlassTransportIntent { case startRecording, stopRecording, openSystemSettings, revealInFinder, none }

GlassTransportControl(state: GlassTransportState,
                      size: GlassPillSize = .large,
                      copy: GlassTransportCopy = .standard,
                      action: @escaping (GlassTransportIntent) -> Void)
```

```swift
GlassTransportControl(state: model.transport) { intent in
    switch intent {
    case .startRecording:     model.record()
    case .stopRecording:      model.stop()
    case .openSystemSettings: model.openSettings()
    case .revealInFinder:     model.revealApp()
    case .none:               break
    }
}
```

**Why an enum and not booleans.** The shipping app modelled this with `isRecording`, `isStarting`, `isOpeningSystemSettings`, a separate permission enum and a translocation flag. The inevitable happened: combinations that can't occur were representable, combinations that do occur were unhandled, and the primary control displayed "Start recording" *while stopping*. A control that lies about what it will do is worse than a control that is missing. One value with seven cases makes every impossible state unrepresentable, and every visual property a pure function of it.

**Why the action takes an intent.** The component resolves state → intent; the host maps intent → behaviour. That split is why the control drops into a real app without the kit knowing anything about `SCStream`, permissions, or the file system — and why the menu-bar item, a popover and a Touch Bar can all read `state.presentation()` instead of re-deriving the truth and disagreeing with each other.

**Presentation table.**

| State | Label | Icon | Enabled | Fill | Intent |
|---|---|---|---|---|---|
| `idle` | `record` | `circle.fill` | ✓ | accent | `startRecording` |
| `arming` | `arming…` | — | ✕ | accent | `none` |
| `recording` | `stop` | `stop.fill` | ✓ | accent | `stopRecording` |
| `stopping` | `saving…` | — | ✕ | accent | `none` |
| `saved` | `record` | `circle.fill` | ✓ | accent | `startRecording` |
| `blockedByPermission(.notDetermined)` | `allow audio capture` | `circle.fill` | ✓ | accent | `openSystemSettings` |
| `blockedByPermission(.denied)` | `grant permission` | — | ✓ | neutral | `openSystemSettings` |
| `blockedByPermission(.openingSettings)` | `opening settings…` | — | ✕ | neutral | `none` |
| `blockedByInstall` | `reveal in finder` | `arrow.up.forward.square` | ✓ | neutral | `revealInFinder` |

Precedence is **install block → permission → transport**. A translocated app with a denied permission has one honest thing to say, and it isn't "grant permission" — moving the app is the prerequisite.

`.saved` shares `.idle`'s presentation on purpose. The saved beat is carried by the waveform and the timer, not by disabling the control: you can start the next take the instant the last one lands. **`.saved` is never a dead state.**

**Copy** is overridable via `GlassTransportCopy` so product can revise or localise without forking the view.

**Don't** disable the control for a condition you can't verify — a disk-full refusal happens *on press*, as a notice, never as a pre-emptively dead button.

### 10.2 Timecode

```swift
GlassTimecodeDisplay(time: TimeInterval, isLive: Bool, widthClass: GlassTimecodeWidthClass? = nil, role: GlassTextRole = .timer)
GlassTimecodeChip(time: TimeInterval, progress: Double, duration: TimeInterval)

GlassTimecode.string(_:widthClass:)   // explicit
GlassTimecode.string(_:matching:)     // pinned to a recording's duration — what a player must use
GlassTimecode.live(_:)                // tenths under an hour, h:mm:ss past it
GlassTimecode.spoken(_:)              // "1 hour 12 minutes 3 seconds"
```

**Width classes:** `.tenths` (`0:07.4`, 6 chars) · `.minutes` (`2:34`, 4 chars) · `.hours` (`1:12:03`, 7 chars). Pin the class to the recording's **total duration**, not to the value being displayed — otherwise a player counting up renders `0:59.9` then `1:00`, changing character count mid-scrub and shifting everything to its right.

The chip **clamps** inside its bounds but its **stem stays on the true playhead**, so a clamped chip still points at the exact position instead of lying about it.

The display has two states: live (full strength, `.updatesFrequently`) and dwelling (dimmed, showing the last take's duration). Keep the dwell — snapping to `0:00.0` erases the number the user just made, 1.4 seconds after it appeared.

Formatting is arithmetic, not `DateComponentsFormatter`: the app's own formatter shipped without hour rollover (`90:00` for a 90-minute take), and it runs 30 times a second for hours, so it is allocation-free.

### 10.3 Waveform

```swift
GlassWaveform(samples: [Float], progress: Double? = nil, style: GlassWaveformStyle = .standard, tint: GlassColorRole = .accent)
GlassLiveWaveform(samples: [Float], style: GlassWaveformStyle = .standard, tint: GlassColorRole = .accent, opacity: Double = 1)
GlassWaveform.idleSamples(count: Int = 96)
```

One component covers the thumbnail and the player because **they are the same object at two sizes** — a take's waveform is its identity, the way an album cover is, and a thumbnail that doesn't match its player breaks that recognition. Sampling is nearest-neighbour, not averaged: averaging flattens a 96pt thumbnail into a grey sausage and every take starts looking alike.

Bars have a 2pt floor — silence is still signal, and a zero-height bar reads as a gap in the file rather than a quiet passage. Both variants draw in a single `Canvas`: one draw call for hundreds of bars, no view-identity churn while a capture streams at 30fps.

**During `stopping`, freeze the last live frame at 45% opacity** — never a dead flat line between "recording" and "saved".

### 10.4 Take row

```swift
public protocol GlassTakeRepresentable: Identifiable {
    var title: String { get }        // what a person wrote
    var metadata: String { get }     // what a machine measured
    var duration: TimeInterval { get }
    var timestamp: String { get }    // pre-formatted age — GlassRelativeDate.string(for:) if you want the kit's
    var waveform: [Float] { get }
    var versionCount: Int { get }
}

public struct GlassTakeSummary: GlassTakeRepresentable { … }   // ready-made value type

GlassTakeRow(take: Take, mode: GlassTakeRowMode = .idle, actions: GlassTakeRowActions = .init())
```

Modes: `.idle` · `.selected` · `.playing` · `.renaming` · `.confirmingDelete`. Mutually exclusive by construction — a row cannot be renaming *and* confirming a delete, and modelling it as one value means it can never try.

Column order is fixed and load-bearing: **waveform, name, metadata, then age over duration**. Waveform first because it is how you find a take you can't name.

- **Rename** replaces the title in place. The row doesn't grow, nothing below it moves, and the take you are renaming stays where your eye already is. Return commits, Escape cancels.
- **Delete** morphs the row into `delete "…"? · delete / keep` — no system alert. The confirmation stays in the register of the thing it is confirming, and it can't be dismissed by clicking somewhere unrelated. The safe choice sits second, so a muscle-memory click lands on the reversible option.
- **Hover is a hairline, not a fill.** A filled hover on a translucent row reads as selection, and this list already has a selected state.

`GlassTakePlayer` is the expanded form — waveform, riding timecode, scrub ruler, transport, monitoring affordances. It renders *in place of* the collapsed row so opening a take doesn't push the list, and its title row is the collapse affordance.

### 10.5 Scrub ruler

```swift
GlassScrubRuler(value: Binding<Double>,
                accessibilityLabel: String = "Playback position",
                accessibilityValue: @escaping (Double) -> String = …,
                onEditingChanged: ((Bool) -> Void)? = nil)
```

No filled track: a progress-bar-shaped scrubber implies "how much is done", a ruler implies "where in the material you are". A tap is a scrub-to-here (`minimumDistance: 0`) — on a timeline, a click that does nothing until you move feels broken.

**Hosts must use `onEditingChanged` to suspend their playback ticker.** Otherwise the playhead advances into the drag and the two fight over the same value, which feels like the control is resisting you.

### 10.6 Filter chip bar and empty states

```swift
GlassFilterChipBar(options: [GlassFilterOption<ID>], selection: Binding<ID>, accessibilityLabel: String = "Filter")

GlassEmptyState.nothingYet(title: String = "nothing here yet.", hint: String = "record something.")
GlassEmptyState.noMatches(filterLabel: String, resetTitle: String = "show all", onReset: @escaping () -> Void)
```

**These are two states, not one.** "You have no recordings" and "your filter matched none of your recordings" feel identical to render and completely different to receive: the first needs an invitation, the second needs a way out. Collapsing them into "No items" is the most common way a library loses a user — they conclude their files are gone.

A related rule the host owns: **filtering away the selected or playing row must auto-deselect and stop playback.** An invisible player is a player nobody can stop.

### 10.7 Notice row

```swift
public enum GlassNoticeKind { case error, warning, blocked, info }   // also the priority order

GlassNotice(id: String, kind: GlassNoticeKind, message: String, actions: [GlassNoticeAction] = [], isDismissible: Bool = true)
GlassNoticeRow(_ notice: GlassNotice, dismissTitle: String = "dismiss", onDismiss: @escaping () -> Void)
GlassNoticeSlot(notices: [GlassNotice], onDismiss: …) { defaultContent }
```

**Rows on the surface, never alerts.** Alerts are modal, they can only appear on a window, and a menu-bar-only user never sees them — which is exactly why the shipping app's disk-full and permission errors were invisible in the popover. A row renders anywhere the kit renders.

`blocked` notices are never dismissible: dismissing a terminal condition leaves a permanently broken app looking fine.

### 10.8 Recording bar

```swift
GlassRecordingBar(state: GlassTransportState, elapsed: TimeInterval, samples: [Float] = [], copy: GlassTransportCopy = .standard, onStop: @escaping () -> Void)
```

Renders whenever `state.isCapturing` — which deliberately includes `arming` and `stopping`, so there is no window in which a capture exists and the UI doesn't say so. Prefer the `.glassRecordingVisible(…)` modifier over placing this by hand (§11.3).

### 10.9 Onboarding card

```swift
GlassOnboardingCard(state: .granted | .needsPermission(isOpeningSettings: Bool),
                    copy: GlassOnboardingCopy = .standard,
                    isFixedSize: Bool = true,
                    icon: () -> Icon,                      // hosts supply their own mark
                    onOpenSettings: @escaping () -> Void,
                    onPrimary: @escaping () -> Void)
```

Element order is fixed: **icon → title → supporting copy → permission info → conditional slot → primary CTA.**

**The conditional slot is a fixed 76pt in both states, and that is the entire design of this component.** Permission can land while the card is on screen — the user grants it in System Settings and comes back, or a grant watcher notices — and when it does, the slot swaps from "open System Settings" + hint to "Ready to record". A flexible slot would shrink by ~30pt at that moment and pull the primary button up out from under the cursor, which is how a first-run flow ends with an accidental click on nothing.

The macOS settings-list gotcha ("Look under *Screen & System Audio Recording* — not the audio-only list") appears **only** in the not-granted state, attached to the action that sends you there. A permanent gotcha is noise; a contextual one is help.

The permission ask and its reassurance live in one inset container, because the worry they answer is a single worry. Splitting them into a bullet list is what made the original card a wall of text.

---

## 11. Patterns

### 11.1 The transport state machine

```swift
GlassTransportMachine.next(from: GlassTransportState, on: GlassTransportEvent, now: Date = .now) -> GlassTransportState?
GlassTransportMachine.canStartRecording(in:) / canStopRecording(in:) / elapsed(in:now:)
```

Pure, synchronous and free of SwiftUI, so it can be unit-tested exhaustively.

| From | Event | To |
|---|---|---|
| `idle` / `saved` | `primaryPressed` | `arming` |
| `arming` | `captureStarted(at:)` | `recording(startedAt:)` |
| `arming` | `failed` | `idle` |
| `arming` | `primaryPressed` | — (refused, not queued) |
| `recording` | `primaryPressed` / `failed` | `stopping` |
| `stopping` | `captureFinalized` / `failed` | `saved` |
| `saved` | `savedDwellElapsed` | `idle` |
| any (not install-blocked) | `permissionChanged(_)` | `blockedByPermission(_)` |
| blocked | `permissionGranted` | `idle` |
| any | `installBlocked` | `blockedByInstall` |

Returning `nil` rather than the current state distinguishes "nothing changed" from "handled, and happened to be a no-op" — exactly the distinction you want when something odd shows up in a log.

**Why failures are not transport states.** It is tempting to add `.error`. Don't. An error is orthogonal to what the transport is doing — a save-location failure happens *while the recording continues* — and folding it in would force a choice between "recording" and "error" when the truth is both. Errors are notices; the transport is a transport; the two compose.

**Elapsed time is derived from `startedAt`, never accumulated from ticks.** Tick accumulation drifts measurably over a long session, and a recorder whose timer disagrees with its own file length loses the user's trust in everything else it says.

**A press during `arming` is refused, not queued.** Queueing makes the button feel like it remembered a click the user has already given up on.

### 11.2 Notice priority

```swift
GlassNoticeQueue.topmost(of: [GlassNotice]) -> GlassNotice?
GlassNoticeQueue.ordered(_:) -> [GlassNotice]
```

**A Glass surface has one notice slot, and it is the same slot secondary content occupies.** The recorder face is a fixed-size floating panel, so a notice that *adds* height either overflows the window or pushes the transport control off it. Yielding a slot keeps the geometry constant no matter how much goes wrong.

Priority: **error → warning → blocked → info.** Ties break by insertion order, oldest first, so a burst of failures doesn't hide the one that started it.

`blocked` ranks last despite being the most severe, because it is *static*: it was true before the session started and will still be true after the error is dismissed, whereas an error is news.

The slot cross-fades (`.swap`, opacity) rather than sliding. The two contents are different heights, and a slide would make the panel's centre of gravity jump on every error.

### 11.3 The recording-visibility invariant

> **A capture is never invisible, and never more than one click from stop.**

```swift
LibraryView()
    .glassRecordingVisible(state: model.transport,
                           elapsed: model.elapsed,
                           samples: model.liveSamples,
                           onStop: model.stop)
```

Every screen this kit can build — recorder face, library, settings sheet, menu-bar popover — must show an in-flight capture and must offer to stop it. Not "should". A recorder quietly writing to disk while the user browses somewhere else is the failure mode people never forgive, and it is one navigation push away at all times.

**Why a modifier, not a component.** A component you place by hand is a component someone forgets on the next screen. A modifier that wraps a whole screen can be required by review, grepped for, and applied once at the window root so no future screen can opt out by accident.

The bar pins to the **top** and **pushes** rather than overlays — an overlay would cover the first row of a list, and this bar can be on screen for hours.

The companion `GlassTransportPermissions` encodes the interaction table so a screen can *ask* instead of re-deriving:

```swift
GlassTransportPermissions.canRecord(state)         // idle, saved
GlassTransportPermissions.canStop(state)           // recording only — nothing to stop while arming
GlassTransportPermissions.canPlay(state)           // always true
GlassTransportPermissions.canChangeFormat(state)   // locked for the whole capture, arming through stopping
GlassTransportPermissions.shouldGuardQuit(state)   // any capture in flight
GlassTransportPermissions.formatLockReason(state)  // tooltip for the disabled control
```

Format stays **disabled with a reason**, never hidden. Hiding it makes the control flicker back during `stopping`, and a control that vanishes is a control users think they imagined.

### 11.4 Monitoring — playback during capture

> **Playback during a capture is allowed, and the guarantee is made visible.**

```swift
GlassMonitoringPolicy.isMonitoring(transport:isPlaying:)
GlassMonitoringPolicy.allowsPlayback(during:)   // always true
GlassMonitoringBadge()        // "monitoring · not recorded"
GlassMonitoringExplainer(onDismiss:)   // one-time, dismissible forever
```

The capture excludes the app's own audio from the stream (`SCStreamConfiguration.excludesCurrentProcessAudio`), so in-app playback is provably not in the file.

The alternatives were both worse. Hard mutual exclusion punishes the user for a problem that is already solved in the capture layer. Allowing it silently leaves a load-bearing invariant invisible: a user who hears an old take while recording has every reason to assume it is being recorded, and no way to find out that it isn't.

**Two engineering conditions must hold, or the UI is lying:**

1. A **regression test** asserting `excludesCurrentProcessAudio` on the built stream configuration. It is one boolean between "correct" and "silently records itself".
2. Playback must run **in-process** (AVAudioPlayer / AVAudioEngine), never in a helper process — a helper's audio is a different process's audio and the exclusion would not apply.

**Known limit, stated plainly:** the exclusion is at the tap, not in the room. A microphone-equipped setup could still acoustically re-record speaker output. Home Rec captures system audio only, so this does not apply today; revisit if microphone capture ships.

---

## 12. Building a screen

A complete recorder face, using nothing but the kit:

```swift
struct RecorderFace: View {
    @State private var model = RecorderModel()

    var body: some View {
        ZStack {
            GlassBackdrop()

            GlassPanel {
                VStack(spacing: GlassSpacing.md) {
                    // Header: wordmark, format, settings
                    HStack(spacing: GlassSpacing.m) {
                        Text("home rec").glassText(.appTitle, color: .textPrimary)
                        Spacer()
                        GlassMetaLabel("\(model.format) · 48kHz")
                        GlassIconButton(systemImage: "slider.horizontal.3",
                                        accessibilityLabel: "settings",
                                        accessibilityHint: "Format and save location") {
                            model.showSettings = true
                        }
                    }

                    Spacer(minLength: 0)

                    // Centrepiece: timer, live card, transport
                    GlassTimecodeDisplay(time: model.displayedTime, isLive: model.transport.isRecording)

                    Group {
                        if model.transport.isCapturing {
                            GlassLiveWaveform(samples: model.liveSamples,
                                              opacity: model.transport == .stopping ? 0.45 : 1)
                        } else {
                            GlassWaveform(samples: model.lastTake?.waveform ?? GlassWaveform.idleSamples(),
                                          style: .thumbnail,
                                          tint: model.lastTake == nil ? .textPrimary : .accent)
                        }
                    }
                    .frame(height: 44)
                    .padding(.horizontal, GlassSpacing.l)
                    .padding(.vertical, GlassSpacing.s)
                    .frame(maxWidth: .infinity)
                    .glassSurface(.live)

                    GlassTransportControl(state: model.transport, action: model.handle)

                    Spacer(minLength: 0)

                    // The shared slot: notices take it, the shelf gets it back
                    GlassNoticeSlot(notices: model.notices, onDismiss: model.dismiss) {
                        VStack(spacing: GlassSpacing.sm) {
                            HStack {
                                GlassEyebrow("recent")
                                Spacer()
                                GlassNavLink("all takes →") { model.screen = .library }
                            }
                            ForEach(model.recentTakes) { take in
                                GlassTakeRow(take: take, actions: .init(onActivate: { model.open(take) }))
                            }
                        }
                    }
                }
            }
            .padding(GlassSpacing.xxl)
        }
        .frame(width: 450, height: 450)
        .clipShape(RoundedRectangle(cornerRadius: GlassRadius.window, style: .continuous))
        .glassThemeAdaptingToContrast()
    }
}
```

The library screen is the same panel with `.glassRecordingVisible(…)` applied, a `GlassFilterChipBar`, a `LazyVStack` of `GlassTakeRow`s, and a `GlassEmptyState` for each of the two empty cases.

### Checklist for a correct Glass screen

- [ ] `GlassBackdrop` (or `GlassFlatGround`) behind a `GlassPanel`
- [ ] `.glassThemeAdaptingToContrast()` once at the root
- [ ] `.glassRecordingVisible(…)` on any screen that isn't the recorder face
- [ ] At most one `.solid` pill on screen
- [ ] Notices go through `GlassNoticeSlot`, not into a new row of their own
- [ ] Metadata in mono via `GlassMetaLabel`; names in Inter via `.glassText(.body)`
- [ ] No literal hex, font size, radius or duration anywhere in the file
- [ ] Every icon button has an `accessibilityLabel` (the initialiser will make sure)
- [ ] Animations go through `.glassAnimation(_:value:)`

---

## 13. Deliberately not in the kit

| Not included | Why |
|---|---|
| A light theme | See §1. The panel floats over the user's real work |
| Error / notice copy | Product surface area, already written and reviewed in the app. Two sources of truth for one sentence is worse than none |
| Brand assets (icon, fonts) | The package ships no resources. Fonts fall back to system; `GlassBrandMarkPlaceholder` is visibly a placeholder |
| Version *stacks* (the expandable list under a take) | Implies a versioning model that doesn't exist yet. The `v4` badge ships; the stack waits for product to define what a version is |
| Menu-bar icon states, ⌘Q guard | Spec-only in the source material, and not SwiftUI views. `GlassTransportPermissions.shouldGuardQuit(_:)` and `state.presentation()` give the host everything it needs to build them consistently |
| A settings popover component | The composition is three primitives (`GlassEyebrow`, `GlassChip`, `GlassNavLink`) on `.popover` and differs per product; a component here would be a layout opinion with no design content |
| Sample takes / waveform generators | `internal` to the gallery. The moment fake data is public API, it ships in a release build |
| Playback, capture, permissions | The kit renders state and reports intent. It never owns behaviour |

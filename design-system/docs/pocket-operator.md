# Pocket Operator

**PocketOperatorKit** — a SwiftUI design system for interfaces that read as
hardware instruments rather than as applications.

- Module: `PocketOperatorKit`
- Platform: macOS 15+
- Dependencies: none (SwiftUI and AppKit only)
- Language version: `PocketOperatorKit.languageVersion` — `1.0.0`

---

## 1. The language and where it comes from

The line runs from Teenage Engineering's Pocket Operator and OP-1 back through
1970s studio and test equipment: exposed board-like chassis, screen-printed
micro-legends, hard-edged keys with real travel, a segment LCD, an analogue
meter, one saturated colour on the one control that matters, and a monospaced,
coded vocabulary that assumes you will learn the device rather than be guided
through it.

What the lineage supplies is not a look, it is a **stance**: the object exists
before the software does. A Pocket Operator is a PCB with keys on it and the
silkscreen was applied at the factory. That is why the legends are permanent
and cryptic, why the display is a driven part rather than a text field, why
nothing fades, and why there is no chrome — a device has no room for chrome,
only for parts.

Adopting the language means accepting the stance. Half-adopting it — hardware
keys with a modal sheet behind them, a segment display next to a progress
spinner — reads worse than not adopting it at all, because the eye notices the
one thing that could not have been manufactured.

### The rules, in short

1. **Every surface is a level.** Chassis → panel → well → control. Radius
   decreases with depth, tone lightens with height, and a control is always
   fitted into a recess or through the shell, never floating on it.
2. **Light comes from directly above, always.** Every bevel highlights on its
   top edge, every inner shadow falls from the top wall, every drop shadow goes
   down. One inconsistent gradient flattens a whole panel.
3. **Print is permanent; displays are driven.** Anything that changes at
   runtime goes on a display or a lamp. Anything printed is uppercase,
   monospaced, tracked out, one line, and could have been applied at the
   factory.
4. **One saturated colour, on the control with consequences.** The accent is a
   material property of one key. Spending it on navigation is how the language
   dies.
5. **State is physical and redundant.** A lamp, a key that stays down, a word
   on the display, a needle. At least two channels per state, so removing
   colour, or motion, or sight, still leaves it readable.
6. **Nothing eases the way software eases.** Keys bottom out and spring back.
   Segments switch. Needles integrate. Motion reports; it does not delight.

---

## 2. Colour

Five families and nothing else: a chassis black, one structural metal, one
saturated accent, one phosphor, one print grey. Hardware gets its legibility
from *material contrast* — dark body, bright cap, glowing screen — so every
additional hue dilutes the effect. If a design seems to need a sixth colour,
the answer is almost always a different elevation or a lamp.

Literal values exist only in `Tokens/POColors.swift`. No component body names a
pigment; every one resolves through `@Environment(\.poTheme)`.

### Standard palette

| Role | Hex | Purpose |
|---|---|---|
| `chassis` | `#0A0A0A` | Device body. Near-black, so the well and plinth still have somewhere darker to go |
| `chassisEdge` | `#242424` | Machined outer edge hairline |
| `panel` | `#111214` | Raised sub-assembly |
| `panelEdge` | `#1C1D20` | Sub-assembly edge |
| `well` | `#161616` | Milled recess (key bed, cavity) |
| `wellRim` | `#2A2A2A` | Lit chamfer on the recess lip |
| `wellShadow` | black 60% | Inner shadow cast into a recess |
| `keyCapTop` | `#C8CCD0` | Anodised cap, top of ramp |
| `keyCapBottom` | `#9BA0A6` | Anodised cap, bottom of ramp |
| `keyBevel` | white 35% | Machined top edge highlight |
| `keyLabel` | black 65% | Legend printed on a light cap |
| `keyPlinth` | `#0D0D0D` | The base the cap travels toward |
| `accentKeyTop` | `#FF6600` | The armed key |
| `accentKeyBottom` | `#C24E00` | |
| `accentKeyLabel` | black 80% | |
| `mutedKeyTop` | `#5A4A3E` | Accent key when its function is unavailable |
| `mutedKeyBottom` | `#483A30` | |
| `mutedKeyLabel` | black 55% | |
| `disabledKeyTop` | `#5A5D60` | Neutral key when unavailable |
| `disabledKeyBottom` | `#4A4D50` | |
| `disabledKeyLabel` | black 40% | |
| `darkKeyTop` | `#2E3033` | Blacked-out cap for modifiers |
| `darkKeyBottom` | `#1F2124` | |
| `darkKeyLabel` | `#B6BABE` | |
| `displayBed` | `#141B12` | Unlit LCD substrate, tinted toward the phosphor |
| `displayOn` | `#9BE870` | Lit segment |
| `displayOffOpacity` | `0.07` | Ghost opacity for an unlit segment |
| `displayRim` | `#2A2A2A` | Display cavity lip |
| `displayGlass` | white 3% | Cover-glass sheen |
| `screenPrint` | `#84898F` | Printed legend |
| `screenPrintEmphasis` | `#C7CACD` | Brand mark, leading legend |
| `readout` | `#C7C7C7` | Printed *value* (brighter than its label) |
| `etch` | `#3A3A3A` | Milled hairline: rules, dividers, detent ladders |
| `lampOff` | `#2A2A2A` | |
| `lampActive` | `#FF6600` | Something is happening now |
| `lampArmed` | `#9BE870` | Ready, nominal |
| `lampWarn` | `#D93B2B` | Fault, clipping, attention |
| `meterFace` | `#EDE6D6` | Painted meter face — the one warm light surface |
| `meterInk` | `#2B2B2B` | Printed scale and needle |
| `meterRedZone` | `#D93B2B` | |
| `focusRing` | `#FF6600` | Keyboard focus; borrows the armed colour deliberately |

`screenPrint` is one step lighter than the source concept's `#7A7F85`. The
original measured **4.48:1** on the key bed — just under AA for 7–9pt print.
`#84898F` clears 4.5:1 on every surface a legend can land on and is visually
indistinguishable in situ. Legibility of a 7pt legend is not the place to save
4% of luma.

### Re-skinning

`POColors.amberService` ships as a second palette — warm graphite body, amber
phosphor, signal-red accent — for no reason other than to prove the roles carry
the language and the pigments do not. Adopting it is one line and no component
changes:

```swift
DeviceFaceSpecimen()
    .pocketOperatorTheme(.amberService)
```

To build a third: copy `POColors.standard`, keep the *relationships* (chassis
darker than well darker than plinth; cap ramp light-to-dark downward; exactly
one saturated accent; phosphor tint carried into the substrate), and change the
hues. Verify with the contrast table in §9 before shipping.

---

## 3. Type

One monospaced family, six small sizes, wide tracking, always uppercase for
print.

Monospaced because the language is dense with codes, counts and abbreviations
that must stay column-aligned and must not reflow when a value changes width.
Small and letter-spaced because these are *screen-printed* legends, and pad
printing on plastic needs generous letterfit to survive at 7pt.

| Role | Size | Weight | Tracking | Use |
|---|---|---|---|---|
| `brand` | 9 | medium | 1.2 | Product or model mark |
| `microLabel` | 7 | medium | 1.2 | Secondary annotation only — never load-bearing |
| `label` | 8 | medium | 1.2 | Default legend |
| `labelLarge` | 9 | medium | 1.2 | Section legend |
| `keyCap` | 10 | medium | 0.5 | Legend on a neutral cap |
| `keyCapEmphasis` | 11 | bold | 0.6 | Legend on the accent cap |
| `readout` | 10 | semibold | 0.5 | Printed value |
| `readoutLarge` | 13 | semibold | 0.5 | Printed value heading a group |
| `dataTitle` | 14 | regular | 0 | Human-language content (system font, not mono) |
| `dataMeta` | 11 | regular | 0.2 | Human-language secondary |

`dataTitle` and `dataMeta` are the escape hatch. When a device has to show a
user's own words — a file name, a preset name — those words are not screen
print and must not be forced into it. They get the system font at a readable
size, inside the panel, and the coded vocabulary stays around them.

Rules that come with the scale:

- Print never wraps. `ScreenPrintLabel` is `lineLimit(1)` with a 0.85 minimum
  scale factor and no truncation. A legend that needs two lines is a
  description, and descriptions are not screen printed.
- Print is never the sole carrier of meaning (see §9).
- Nothing below 7pt exists in the system, at any Dynamic Type setting.

---

## 4. Layout and panel hierarchy

```
chassis     the moulded shell        radius 10, edge highlight, faint grain
  panel     a raised sub-assembly    radius  8, one tone up, no grain
    well    a milled recess          radius  8, inner shadow, black cut line, lit lip
      control   a fitted part        radius  7 (key) / 4 (cut glass)
```

Corner radius encodes manufacturing scale: a moulded shell has the largest
radius, a milled recess less, a cut glass window least. A recess with a larger
radius than its container is impossible to make, and the eye knows it
immediately.

Rules:

- **Controls sit in wells or through the shell — never on a panel edge.** Parts
  are mounted through holes; a key floating on flat shell reads as a sticker.
- **Nesting stops at four levels.** A well inside a well inside a well is not a
  deeper hierarchy, it is a mistake. Split the panel instead.
- **Levels are structural, not decorative.** A recess means "parts are fitted
  here". Using one to emphasise a paragraph is the fastest route back to app
  chrome.

### Spacing ladder

`2 · 4 · 6 · 8 · 10 · 12 · 14 · 18 · 22`, named on `POSpacing` as
`hair · tight · snug · base · cozy · key · panel · section · chassis`.

`key` (12) is the moulded web between two caps. `panel` (14) is the inset from a
recess wall to its contents. `chassis` (22) is the inset from the shell edge to
anything printed or mounted on it. A panel laid out by two people using the
ladder still looks like it came off one production line.

### Label placement conventions

- **Above** a continuous control, centred on its axis (faders, rulers). There
  is no room beside a fader and none below it.
- **On the cap** for a key. A caption under a key means the legend was too
  long, which means the wrong word was chosen.
- **Left of a value** for printed data — label dim, value bright, both mono.
- **Top-left** of the chassis for identity, **top-right** for the device's
  function statement.
- **Never inside a display.** The display is driven; print on it would be print
  on the glass, which real devices reserve for fixed annunciator legends.

### The standard face

`DeviceFace` encodes the default arrangement: identity at the top edge, display
beneath it, controls in the middle where hands go, printed specification along
the bottom. Deviating is fine, but the ordering encodes something true —
printed matter belongs at the edges of a device and moving parts belong in the
middle.

---

## 5. Controls: sizing and physics

### Footprints

| Size | Dimensions |
|---|---|
| `.compact` | 56 × 30 |
| `.regular` | 68 × 44 |
| `.large` | 92 × 52 |
| `.custom(CGSize)` | anything |

Pitch between caps is `spacing.key` = 12. Cap radius is 7 for `.lozenge`;
`.pill` and `.round` derive theirs from the shorter edge.

**Minimum hit target is 28pt**, enforced independently of the printed cap. A
cap smaller than that keeps its printed size and grows only its *hit region* —
`POMetrics.hitTargetPadding(for:)` computes the padding and `HardwareKeyStyle`
applies it inside the button's content shape. Pointer and touch accuracy never
depend on how small a legend happens to be.

### Key press physics

This is the detail that decides whether the whole thing works.

| Parameter | Value | Why |
|---|---|---|
| Travel | 1.5pt | The smallest offset that survives a 1× display and still reads as travel rather than jitter. It is roughly the reference hardware's 0.6 mm at typical viewing distance. More, and the cap looks like it falls into the chassis |
| Press | `easeOut`, 50 ms, **no spring** | A finger is far stiffer than a key's return spring, so the down-stroke is dominated by the finger and simply stops at the plinth. Springing the press makes caps feel like jelly — the single fastest way to lose the illusion |
| Release | `spring(response: 0.18, dampingFraction: 0.55)` | The cap is pushed back by its own dome: light, lightly damped, slightly overshooting. That overshoot is the visual equivalent of the clack. Below ~0.5 damping it visibly double-bounces and reads as rubber; above ~0.7 it reads as a screen animation |
| Contact shadow | radius 5→1.5, y 3→1 | The gap closing between cap and plinth is most of what sells the travel |
| Face darkening | +8% black while pressed | The contact patch falls into its own shadow |
| Latched rest | 0.75pt | Half travel. A toggle that is on physically stays down |
| Haptic | on press, not release | A real detent is felt on the way down; feedback on release lands after the action has already been taken |

The plinth is drawn behind the cap, inset −1pt horizontally and +2/−2pt
vertically, so the cap never exposes chassis through the gap at the bottom of
its travel.

Under Reduce Motion the offsets are kept and the animation is dropped: a press
still shows as depressed, it just gets there instantly.

### Fader physics

The slot is a **cut, not a filled track** — a fader's position is read from
where the cap is, not from how much of something is coloured in. The detent
ladder is etched *beside* the slot, as it is silkscreened on a mixer, never on
it. The cap casts a shadow into the slot, which is what puts it on top of the
panel rather than in it, and carries a scored centre line that is both the
moulded grip and the index mark you read the value off.

Release snaps to the nearest detent on `spring(0.15, 0.9)` — stiff and
well-damped, because a physical detent catches, it does not glide. Under Reduce
Motion the snap is instantaneous.

---

## 6. Displays

Three details separate a segment display from green text in a monospaced font,
and all three are load-bearing:

**Unlit segments stay visible.** A real LCD's dead segments are still printed on
the glass. Without the ghost (default 7% of the phosphor colour) a display is a
label; with it, a `1` obviously occupies the same cell an `8` would.

**Cells are fixed-width and countable.** `capacity:` reserves a physical digit
count, so a value going from `9` to `10` does not shove the panel around it.
The display *has* that many digits whether or not they are in use — which is
also why `alignment:` matters: a counter is `.trailing`, a status word is
`.leading`.

**The face has a repertoire.** A seven-segment part physically cannot form a K,
a W or an X. `SegmentFace` models that as a value:

```swift
SegmentFace.sevenSegment.supports("K")                       // false-ish: approximated
SegmentFace.sevenSegment.unsupportedCharacters(in: "WORKSHOP")
SegmentFace.dotMatrix                                        // full A–Z, 5×7
```

Assert on `unsupportedCharacters(in:)` in a test for any string that ships. A
display silently mangling half a status word is a defect that otherwise only
surfaces in a screenshot. **Any user-supplied text uses `.dotMatrix`.**

Custom symbols go through `overriding(sevenSegment:)` / `overriding(dotMatrix:)`
— a battery cell, a degree sign, a logotype glyph.

### Rendering

The whole string draws in **one `Canvas`, in three passes**: all ghost segments,
one blurred glow layer over the union of lit segments, then the lit segments.
The glow is the expensive operation, so accumulating every lit path into one
`Path` means a six-digit counter costs one blur per frame instead of forty-two.
`SegmentLayout` computes cell geometry as a value up front, so the canvas
closure does no layout and the view reports an exact intrinsic width.

### The panel

`LCDPanel` publishes its ink and substrate into the environment
(`\.poDisplayInk`, `\.poDisplayBed`), so nested `SegmentLCD`, `LCDLevelBar` and
`BarWaveform` pick up the right phosphor without threading a palette — and, more
importantly, so `isInverted` flips *everything on the screen at once*, the way a
display driver actually inverts.

---

## 7. Meters

### Why the VU ballistics are asymmetric

The needle rises with a ~90 ms time constant and falls with a ~350 ms one. That
ratio is not a style choice.

A moving-coil movement is *driven* toward the signal by current, so it rises as
fast as the circuit allows. It returns only under its hairspring against its own
damping, so it falls slowly. Every meter anyone has ever watched behaves this
way, which is why the asymmetry reads as "real" long before it is consciously
noticed. Symmetric smoothing — the obvious implementation — looks like a
progress bar, and no amount of styling recovers from it.

It is also what makes the meter *useful*. A symmetric filter fast enough to
catch a transient is too fast to read; one slow enough to read misses the
transient. Splitting the two lets the needle snap to a peak and then hold long
enough for an eye to take a value off it.

`POBallistics` exposes the pair, because the pair *is* the character of the
instrument:

| Preset | Attack | Release | Character |
|---|---|---|---|
| `.vu` | 0.09 | 0.35 | Averages; reads programme loudness |
| `.peak` | 0.004 | 0.85 | Catches transients, falls back readably (PPM) |
| `.instant` | 0 | 0 | Follows exactly — correct for a digital bar, wrong for a needle |

### Implementation notes

Integration is per frame with the **actual elapsed interval**, not a fixed
per-frame coefficient (`k = 1 − exp(−dt/τ)`), so the feel is identical at 60 Hz,
120 Hz, or through a dropped frame.

The level is a **closure**, not a published value. A property updating at 60 Hz
invalidates the whole enclosing view tree sixty times a second; a closure read
inside a `TimelineView` costs one canvas redraw and touches nothing else on the
panel.

The integrator is a plain class in `@State` (`BallisticIntegrator`). SwiftUI
does not observe it, so it can be stepped during drawing with no invalidation —
the `TimelineView` is already redrawing, so nothing needs to be told. Writing it
back through a binding would cost a publish and a second layout pass every
frame.

The needle overshoots the arc by 3pt, because a needle reads *past* its scale;
stopping it exactly on the arc makes it look printed on.

---

## 8. Motion and texture

### Motion

Four kinds of movement exist, and nothing else does:

1. **Travel** — a key down fast and linear, up on a light spring. The only
   transform applied to a control.
2. **Switching** — lamps and segments change state instantaneously, square-wave
   when blinking. Nothing on a display fades. `poBlink` derives phase from wall
   clock, so every blinking element on a panel is in lockstep as a shared clock
   line would make them.
3. **Integration** — meter needles, stepped per frame from a signal, never
   `withAnimation`-ed.
4. **Punctuation** — a committed action is marked by one display invert flash of
   ~120 ms (`poCommitFlash`) and nothing else.

Deliberately absent: screen cross-fades, opacity easing, scale-in appearances,
spinners, toasts, and any motion whose purpose is delight. A device that
animates for pleasure stops reading as a device.

### Texture

Texture is what stops large flat fills reading as dark rectangles. It is
deliberately near-invisible: at the intended density you should not be able to
resolve individual speckles, only notice the surface is not perfectly uniform.
If you can see the pattern, it is too strong.

- Key bed / control wells: speckle at density `0.02` — moulded rubber.
- Chassis shell: speckle at `0.004`, an order below — a smooth moulding.
- `dotGrille` and `brushedMetal` are available for perforated and machined
  parts.

Each painter is a `Canvas` whose closure reads **no observed state**, so SwiftUI
rasterises it once at a given size and never invalidates it. A device face can
be covered in texture and still cost nothing while idle. The seed is fixed so a
surface renders identically across launches and snapshots — texture that
shimmers between runs reads as television static, not as a finish.

`POTheme.flat` disables texture entirely, for snapshot diffing or for a host
that does not want a large always-on canvas.

---

## 9. Accessibility

This style is the easiest in the world to get wrong. It is built on 7pt
abbreviations, colour-coded caps, blinking lamps and canvas-drawn displays —
four things that are, by default, invisible or meaningless to a significant
number of users. Everything below is implemented in the kit, not aspirational.

### Canvas-drawn content is invisible unless you make it visible

A `Canvas` is one opaque rectangle to assistive technology. Every drawn
component in the kit therefore declares itself:

- `SegmentLCD` is an accessibility element with a label and a **value** — the
  display, usually the most important information on the panel, reads as text.
  Pass `accessibilityValue:` whenever the raw string is not speakable: a
  timecode is better as "3.2 seconds" than "zero colon zero three point two".
- `VUMeter` reports a formatted reading; `accessibilityValue:` takes a closure
  so a calibrated scale can report dB rather than percent.
- `LCDLevelBar` reports a percentage.
- `TickRuler` and `Fader` are adjustable elements with
  `accessibilityAdjustableAction`, so VoiceOver can operate them.
- `BarWaveform` is **hidden by default** and only becomes an element if given a
  label. It is decoration unless it carries meaning the surrounding text does
  not — and announcing "waveform" on every row is worse than silence.

### Abbreviations need spoken names

The vocabulary is SRC, FMT, RATE, BPM, LIB. That is authentic and it is also
meaningless to anyone who has not learned the device. Every component that
takes a printed legend also takes `accessibilityLabel:`:

```swift
HardwareKey("FMT", accessibilityLabel: "Recording format") { … }
SpecCell(label: "BPM", value: "128", accessibilityLabel: "Tempo")
KeyGridItem(legend: "01", accessibilityLabel: "Pad 1", isOn: true) { … }
```

Assume the legend conveys nothing. The rule for extending the kit: if a new
component prints an abbreviation, it must accept a spoken name in the same
initialiser.

Where a legend and its control would announce twice — `LabelledControl`,
`LampAnnunciator`, `PrintedPair`, `SpecGrid` cells — the printed part is marked
`isDecorative` and the group announces once as a label/value pair.
`ScreenPrintLabel` is readable by default; `isDecorative: true` is only for
suppressing that duplication, never for hiding information.

### State is never carried by one channel

`TransportKeys` is the reference implementation: the record key changes its
**legend** (REC → STOP), the annunciator changes its **lamp mode**, and an
unavailable transport changes the cap **material**. Remove colour, remove
motion, or remove sight, and the state is still readable. Any new state signal
must survive the same three deletions.

Disabled controls are shown with a **duller cap material**, not with opacity —
which is both more honest to the metaphor and more robust, since translucency
is easy to miss. The `.disabled(true)` modifier drives it, so the accessibility
tree gets the standard disabled trait for free.

### Reduced motion

`@Environment(\.accessibilityReduceMotion)` is honoured everywhere:

| Element | Behaviour |
|---|---|
| Key press | Offsets kept, animation dropped — still visibly depressed |
| Blinking lamp / display word | Renders **steady on**, because the blink carries state and losing it would lose information |
| `VUMeter` | Switches from display-refresh to a 0.25 s cadence and drops the ballistic lag, so the value is unambiguous |
| Fader detent snap | Applied instantly, no spring |
| `poCommitFlash` | Skipped; the display goes straight to its new content |
| `TypedText` | Reveals the whole string immediately |

Nothing is removed outright — a reduced-motion user sees the same *information*,
delivered without movement.

### Dynamic Type

Printed labels scale with `@ScaledMetric(relativeTo:)` and are **clamped at
1.6×** (`POTypography.maxDynamicTypeScale`).

The clamp is deliberate and it is a trade-off worth stating plainly. Screen
print sits in fixed milled space: a 7pt legend that grows to 3× does not become
more readable, it overruns the panel it names and collides with the control it
belongs to. So the print stops growing — and the consequence is that **printed
legends must never be the only source of any information**. That is why every
component carries a spoken label, why values live in `readout` and `dataTitle`
rather than in `microLabel`, and why `.micro` is documented as "secondary
annotation only".

A product that needs fully-scaling text should present that content in
`dataTitle`/`dataMeta` (system font, unclamped by design) inside a panel, not as
screen print.

### Keyboard

- Every key is a `Button`, so it is focusable and activatable by default. A
  focus ring is drawn explicitly around the cap — custom `ButtonStyle`s lose the
  system ring — in the accent colour, **outside** the cap footprint, where it
  measures 6.16:1 against the well rather than 1.44:1 against a light cap.
- `Fader` and `TickRuler` are `focusable()` with arrow-key stepping (one detent
  per press), plus Home/End. A control that can only be dragged is a control
  some people cannot use at all.
- Keyboard step size and the printed detent ladder are the same number by
  construction, so the two cannot disagree.

### Contrast, measured

Standard palette, WCAG 2.1 ratios:

| Pair | Ratio | Verdict |
|---|---|---|
| `screenPrint` on `chassis` | **5.62:1** | AA normal text |
| `screenPrint` on `well` | **5.13:1** | AA normal text |
| `screenPrintEmphasis` on `chassis` | 12.03:1 | AAA |
| `readout` on `chassis` | 11.71:1 | AAA |
| `displayOn` on `displayBed` | 11.86:1 | AAA |
| `keyLabel` on neutral cap | 5.11:1 | AA |
| `accentKeyLabel` on accent cap | 4.70:1 | AA |
| `darkKeyLabel` on dark cap | 7.56:1 | AAA |
| `meterInk` on `meterFace` | 11.39:1 | AAA |
| neutral cap vs `chassis` (component boundary) | 9.71:1 | AA non-text |
| `accent` cap vs `well` | 4.85:1 | AA non-text |
| `focusRing` vs `well` | 6.16:1 | AA non-text |
| `meterRedZone` vs `meterFace` | 3.66:1 | AA non-text |

Known low-contrast elements, and why they are acceptable:

- **`etch` on `chassis` — 1.74:1.** Etched rules are decorative separation. They
  must never be the only thing conveying a boundary or a grouping; every place
  the kit uses one, the content on either side is independently labelled.
- **`.dim` print — 2.68:1 on chassis.** `ScreenPrintLabel(emphasis: .dim)` is
  for non-essential annotation only. Never put information in it.
- **Ghost segments — 1.16:1.** They are meant to be barely visible; they carry
  no information, only the impression of a screen.
- **Disabled cap legends — ~1.7:1.** WCAG exempts disabled controls, and the
  disabled state is independently announced through the accessibility tree. The
  duller cap material is the primary signal, not the legend.

The amber re-skin measures 10.01:1 for phosphor-on-substrate, 5.48:1 for
print-on-chassis and 5.00:1 for print-on-well. Any new palette should be run
through the same table before shipping.

---

## 10. Component catalogue

### Tokens

```swift
POTheme(colors:typography:metrics:texture:motion:)
    .standard  .amberService  .flat

POColors(...)           .standard  .amberService
POTypography(...)       .standard      // .clamped(_:) applies the Dynamic Type ceiling
POMetrics(...)          .standard      // .hitTargetPadding(for:)
POSpacing(...)          .standard
POTextureTokens(...)    .standard  .disabled
POMotion(...)           .standard      // .keyPress .keyRelease .detentSnap .keyTransition(isPressed:)
POBallistics(attack:release:)          .vu  .peak  .instant

// Environment
\.poTheme          \.poDisplayInk          \.poDisplayBed
View.pocketOperatorTheme(_:)
View.pocketOperatorTheme(transform:)      // override one group without restating a theme
```

### Primitives

```swift
ChassisSurface(corner:padding:content:)        // View.poChassis(corner:padding:)
PanelSurface(corner:padding:content:)          // View.poPanel(corner:padding:)
Well(corner:padding:fill:hasTexture:content:)  // View.poWell(corner:padding:fill:hasTexture:)
View.poBezel(corner:)                          // machined lip alone

ScreenPrintLabel(_:scale:emphasis:isDecorative:)   // .micro .regular .large .brand
                                                   // .normal .strong .dim
ScreenPrintValue(_:isLarge:isDecorative:)

HardwareKey(_ legend:variant:size:shape:isOn:providesHaptics:
            accessibilityLabel:accessibilityHint:action:)
HardwareKey(variant:size:shape:isOn:…:action:label:)   // custom label
HardwareKeyStyle(variant:size:shape:isOn:providesHaptics:)   // for any Button
    HardwareKeyVariant  .neutral .accent .dark
    HardwareKeySize     .compact .regular .large .custom(CGSize)
    HardwareKeyShape    .lozenge .pill .round

IndicatorLamp(_ mode:role:diameter:accessibilityLabel:)   // .off .on .blinking
                                                          // .active .armed .warning .custom(Color)
LampAnnunciator(_ legend:mode:role:accessibilityLabel:)

HairlineEtch(_ axis:tint:length:)
View.poEtchedFrame(corner:tint:)
```

### Components

```swift
SegmentLCD(_ text:face:size:capacity:alignment:onColor:offOpacity:
           showsGhostSegments:hasGlow:accessibilityLabel:accessibilityValue:)
SegmentFace .sevenSegment .dotMatrix
    .supports(_:)  .unsupportedCharacters(in:)
    .overriding(sevenSegment:)  .overriding(dotMatrix:)

LCDPanel(isInverted:height:contentAlignment:accessibilityLabel:content:)
LCDLevelBar(level:segments:peak:accessibilityLabel:)

VUMeter(level:ballistics:scale:legend:accessibilityLabel:accessibilityValue:)
VUScale(sweep:divisions:majorEvery:redZoneStart:)   // .standard .wide

Fader(value:orientation:detents:snapsToDetents:length:label:
      accessibilityValue:onEditingChanged:)          // .vertical .horizontal
TickRuler(value:tickPitch:majorEvery:tint:label:step:
          accessibilityValue:onEditingChanged:)

KeyGrid(_ items:columns:keySize:isSeatedInWell:caption:accessibilityLabel:)
KeyGridItem(id:legend:accessibilityLabel:accessibilityHint:variant:
            isEnabled:isOn:action:)   // .blank(id:) for an unfitted position

SpecGrid(_ cells:rowHeight:accessibilityLabel:)
SpecCell(id:label:value:accessibilityLabel:)

TransportKeys(phase:showsPlay:showsAnnunciator:keySize:onRecord:onStop:onPlay:)
TransportPhase  .unavailable .idle .arming .recording .playing .paused .finishing

BarWaveform(samples:mode:progress:tint:dimOpacity:barWidth:barSpacing:
            accessibilityLabel:)      // .fitted .trailing
```

### Patterns

```swift
DeviceFace(brand:model:subtitle:content:footer:)
POElevation  .chassis .panel .well .control   // .corner(_:)

LabelledControl(_ legend:alignment:accessibilityLabel:control:)
PrintedPair(_ label:value:accessibilityLabel:)

POStateSignal(word:lampMode:lampRole:spoken:)   // .standard(for: TransportPhase)
View.poCommitFlash(on:isInverted:)
View.poBlink(isActive:hz:offOpacity:)
TypedText(_:content:)
```

### Gallery and helpers

```swift
PocketOperatorKitGallery()   // every token, primitive, component and state
DeviceFaceSpecimen()         // the assembled worked example
POSampleData.waveform(seed:count:)  .level(at:seed:)   // previews only
PORandom.unitValue(_:)  .valueNoise(_:)
```

---

## 11. Worked example: a new device face

A tempo trainer. Nothing below reaches past the public API, and no part of it
knows what product it belongs to.

```swift
import SwiftUI
import PocketOperatorKit

struct MetronomeFace: View {
    @State private var phase: TransportPhase = .idle
    @State private var tempo = 96
    @State private var volume = 0.65
    @State private var accents: Set<Int> = [0]
    @State private var isFlashing = false
    @State private var commits = 0

    var body: some View {
        DeviceFace(brand: "ACME", model: "MT-2", subtitle: "TEMPO TRAINER") {
            VStack(spacing: 14) {

                // 1. Display. Fixed cell count so 99 → 100 does not reflow.
                LCDPanel(isInverted: isFlashing, accessibilityLabel: "Tempo display") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            SegmentLCD(
                                "\(tempo)",
                                size: 30, capacity: 3, alignment: .trailing,
                                accessibilityLabel: "Tempo",
                                accessibilityValue: "\(tempo) beats per minute"
                            )
                            Spacer()
                            SegmentLCD(
                                POStateSignal.standard(for: phase).word,
                                size: 16,
                                accessibilityValue: POStateSignal.standard(for: phase).spoken
                            )
                            .poBlink(isActive: phase == .playing)
                        }
                        // User-chosen text goes on a dot-matrix face, never
                        // seven-segment.
                        SegmentLCD("SWING FEEL 4/4", face: .dotMatrix, size: 11)
                    }
                }

                HStack(alignment: .top, spacing: 14) {

                    // 2. Controls in a bed. Latched keys stay down.
                    KeyGrid(
                        (0..<8).map { beat in
                            KeyGridItem(
                                id: "beat-\(beat)",
                                legend: String(format: "%02d", beat + 1),
                                accessibilityLabel: "Beat \(beat + 1)",
                                accessibilityHint: accents.contains(beat) ? "Accented" : "Plain",
                                isOn: accents.contains(beat),
                                action: { toggle(beat) }
                            )
                        },
                        columns: 4,
                        keySize: .compact,
                        caption: "ACCENTS"
                    )

                    // 3. Legend above a continuous control, printed once.
                    LabelledControl("VOL", accessibilityLabel: "Volume") {
                        Fader(value: $volume, length: 96, label: "")
                    }
                }

                // 4. Transport: legend + lamp + material, three channels.
                TransportKeys(
                    phase: phase,
                    showsAnnunciator: true,
                    keySize: .compact,
                    onRecord: { step(+4) },          // repurposed as "faster"
                    onStop:   { commit(.idle) },
                    onPlay:   { commit(phase == .playing ? .paused : .playing) }
                )
            }
        } footer: {
            // 5. Facts about the device, never status.
            SpecGrid([
                SpecCell(label: "BPM",  value: "\(tempo)",           accessibilityLabel: "Tempo"),
                SpecCell(label: "SIG",  value: "4/4",                accessibilityLabel: "Time signature"),
                SpecCell(label: "ACC",  value: "\(accents.count)",   accessibilityLabel: "Accented beats"),
                SpecCell(label: "OUT",  value: "SPKR",               accessibilityLabel: "Output"),
            ])
        }
        .frame(width: 420)
        .poCommitFlash(on: commits, isInverted: $isFlashing)
    }

    private func toggle(_ beat: Int) {
        if accents.contains(beat) { accents.remove(beat) } else { accents.insert(beat) }
    }

    private func step(_ delta: Int) { tempo = min(240, max(30, tempo + delta)) }

    private func commit(_ next: TransportPhase) { phase = next; commits += 1 }
}
```

Re-skin the whole thing with one modifier:

```swift
MetronomeFace().pocketOperatorTheme(.amberService)
```

### Checklist for a new face

- [ ] Every printed abbreviation has an `accessibilityLabel`.
- [ ] Every state is carried by at least two of legend, lamp, material,
      position.
- [ ] Counters use `capacity:` so they do not reflow.
- [ ] Any user-supplied text uses `.dotMatrix`, or `dataTitle` outside the
      display.
- [ ] Exactly one accent-variant key on the face.
- [ ] Nesting is at most chassis → panel → well → control.
- [ ] The spec footer states facts, not status.
- [ ] Checked at 1.6× Dynamic Type and with Reduce Motion on.

---

## 12. Scope

### Generalised away from the source concept

The kit descends from a system-audio recorder prototype. Everything specific to
it has been removed or turned into a parameter:

- **Timecode** → `SegmentLCD(capacity:alignment:)` with an arbitrary glyph set.
  The kit has no time formatter and no opinion about what a counter counts.
- **The recorder transport** → `TransportPhase`, a general seven-state
  instrument transport defined inside the kit. Map an application's own states
  onto it at the boundary.
- **Recording/library domain types** → gone. `SpecCell`, `KeyGridItem`,
  `POStateSignal` and `TransportPhase` are the only data types, all minimal and
  all defined here.
- **The 4×3 key bed with ordinal take shortcuts** → `KeyGrid` with any item
  count, column count, cap size, latch state and blank positions.
- **The fixed 12-segment level meter** → `LCDLevelBar(segments:peak:)`.
- **The 450×450 panel** → `DeviceFace`, which sizes to its content.
- **The hard-coded green/orange palette** → semantic roles plus a second
  shipped palette to prove the roles are what carry the language.
- **The concept's own micro-label helper** → `ScreenPrintLabel` with a scale, an
  emphasis, Dynamic Type behaviour and an accessibility contract.

### Deliberately not included

- **A library/list scaffold.** The source prototype's library screen is a rows
  of recordings, which is application content, not device language. The parts it
  used — `BarWaveform`, `TickRuler`, `SegmentLCD`, `HardwareKey`, etch rules —
  are all here; the list itself belongs to whatever product needs one.
- **Navigation.** A device has modes, not screens. Nothing in the kit pushes,
  presents, or transitions, and the accent colour is specifically reserved
  *away* from navigation.
- **Knobs and rotary encoders.** They would fit the language, but a rotary
  control needs a gesture model, an acceleration curve and an accessibility
  story of its own, and shipping a shallow one would be worse than shipping
  none.
- **Sound.** The physical metaphor obviously wants a key click. It is
  intentionally left to the product: an audio product cannot have its UI making
  noise into its own monitoring path.
- **iOS/iPadOS support.** The physics, hit targets and haptics are tuned for a
  pointer. The token layer is platform-neutral and would carry over; the key,
  fader and focus behaviour would need a touch pass.
- **Snapshot tests.** `POTheme.flat` and the fixed texture seed exist so that
  they can be added deterministically, but the kit ships without a test target.

---

## 13. Verifying

```bash
swift build --target PocketOperatorKit
```

`PocketOperatorKitGallery()` is the visual check — every token, primitive,
component and state on one sheet, followed by the assembled device rendered
twice, once per palette. `#Preview` blocks are attached throughout the kit for
working on a component in isolation.

# StageKit

**A design system for prototype-showcase chrome.**

StageKit is the furniture that goes *around* a design concept: a numbered tab bar
for switching between competing directions, a scrubber of state chips along the
bottom for driving the design through every state it can be in, and a snapshot
runner that walks the whole matrix and writes a PNG per state.

It is not a UI kit for products. It is a kit for the harness you build around
products while you are still deciding what they should be.

- Platform: macOS 15+, SwiftUI
- Module: `import StageKit`
- Dependencies: none

---

## 1. Philosophy

### Why a prototype harness deserves its own design language

Most design prototypes are built as one-offs: a window, a hardcoded state, a
screenshot. The moment you have *two* directions to compare, or *nine* states to
check each of them in, the one-off stops working. You end up with either a
folder of eighteen half-broken build targets, or a single app with a pile of
debug buttons that nobody trusts because they set state the real app can never
reach.

The alternative is to treat the harness as a product in its own right. Give it
one job — *put any design in any state, and let me see two designs in the same
state back to back* — and design it properly. When you do, three things fall
out that you did not have before:

1. **Comparison becomes continuous.** Because every concept reads one shared
   state, switching directions mid-state does not reset anything. A running
   timer keeps running. A scroll position holds. You are comparing designs, not
   comparing two fresh launches.
2. **Edge states stop being theoretical.** A state that is one chip away gets
   looked at. A state that requires editing code and rebuilding does not.
3. **The spec writes itself.** The states you can reach from the scrubber and
   the images in the review document are generated from the same declaration,
   so they cannot drift apart.

### Why it must recede

The harness sits directly against the thing being judged. Every visual decision
it makes is a decision it is making *on behalf of* the concept, whether you
intended that or not. A blue accent in the chrome makes a blue button in the
concept look like part of the same system. A rounded, shadowed chip bar makes a
flat concept look unfinished by comparison.

So StageKit is built to lose. Specifically:

| Rule | Consequence |
|---|---|
| Achromatic | No hue anywhere except the keyboard focus ring |
| Monospace, uppercase, small | Reads instantly as "instrument panel, not product" |
| No fills on tabs | Nothing in the chrome can be mistaken for the concept's own navigation |
| Hairline separators at ~16% contrast | Structure without drawing a box around anything |
| Active state = inversion, not tint | The loudest thing achromatic chrome can do, and it survives being screenshotted, projected, or photographed |
| Six type roles, nothing over 13pt | A harness that needs more type variety than this is showing off |

The test: photograph your stage from across the room. You should be able to read
which concept and which state you are looking at, and the chrome should still be
the least interesting thing in the frame.

---

## 2. Visual language

### 2.1 Colour

Thirteen roles. All achromatic except `focus`.

| Role | Purpose | `.dark` |
|---|---|---|
| `stage` | The well the concept floats in | `white 0.02` |
| `chrome` | Tab bar and scrubber surfaces | `white 0.08` |
| `separator` | Hairlines | `white 0.16` |
| `controlFill` | Resting chip / segment | `white 0.14` |
| `controlFillHover` | Pointer hover — a 6% lift | `white 0.20` |
| `controlFillActive` | Applied state — inverted slab | `white 0.75` |
| `controlFillDisabled` | Axis present but not applicable | `white 0.10` |
| `labelStrong` | Selected tab, section headings | `white 1.00` |
| `label` | Default chrome text | `white 0.62` |
| `labelMuted` | Key glyphs, counts | `white 0.38` |
| `labelDisabled` | Unavailable controls, hint descriptions | `white 0.28` |
| `labelOnActive` | Text on an inverted control | `white 0.06` |
| `focus` | Keyboard focus ring — **the only hue** | `#6BA3F5` |

Three palettes ship: `.dark` (default), `.light` (invert the chrome when your
*concept* is dark — it restores the figure/ground separation dark chrome
normally gives you), and `.highContrast` (projection, or reviewers further from
the screen than you were).

The `focus` hue is a deliberate exception. Keyboard focus must be unmistakable
and must never be confused with "this state is applied". Sharing the achromatic
vocabulary with the active state would guarantee that confusion.

### 2.2 Type

Mono-led. Casing and tracking are applied by `StageLabel`, never by the caller —
so accessibility labels keep their original casing, and VoiceOver says
"Pocket Op" rather than spelling out uppercase.

| Role | Size | Weight | Tracking | Used by |
|---|---|---|---|---|
| `title` | 11 | medium | 1.6 | Stage identity |
| `tab` | 10 | regular | 1.0 | `StageTab` |
| `chip` | 10 | regular | 1.0 | `StageChip`, segments |
| `caption` | 9 | regular | 1.4 | Group captions |
| `key` | 9 | medium | 0.4 | Key glyphs in hints |
| `hint` | 9 | regular | 0.4 | Hint descriptions |

Generous tracking is not decoration — uppercase mono at 9–10pt reads as a solid
block without it. A `.large` scale (every role +2pt) pairs with the
`.presentation` theme.

### 2.3 Spacing and hit targets

Everything derives from a 4pt unit.

| Token | Default | Note |
|---|---|---|
| `unit` | 4 | Base grid |
| `controlHeight` | 20 | **Painted** chip height |
| `minHitTarget` | 28 | **Interactive** area, both axes |
| `controlPaddingHorizontal` | 8 | |
| `controlRadius` | 4 | |
| `chipSpacing` | 8 | Between chips of the *same* axis |
| `groupSpacing` | 16 | Between *different* axes — the wider gap is what makes a row of twelve chips parse as four groups |
| `tabSpacing` | 14 | Tabs have no fill; whitespace is their only separator |
| `barPaddingHorizontal` | 16 | |
| `barPaddingVertical` | 6 | |
| `hairline` | 1 | |

**On the 20 / 28 split.** Chips paint at 20pt but are wrapped in a transparent
28pt slab with `contentShape(Rectangle())`. Growing the pill to 28 would make
the chrome heavier than the concept, which defeats the whole point; growing only
the hit area costs nothing visually and clears the accessibility floor.

### 2.4 Theming

```swift
StageWindow(driver: driver)
    .stageTheme(.light)      // .dark (default) · .light · .presentation
```

The theme travels through `EnvironmentValues.stageTheme`, so any StageKit
primitive dropped anywhere inside a stage is themed correctly with no threading.
No StageKit view contains a literal colour or point size.

Apply the theme to a whole stage, never to individual controls.

---

## 3. Component catalogue

### 3.1 Primitives

```swift
StageLabel(_ text: String,
           style: StageTextStyle? = nil,      // defaults to typography.chip
           tone: StageTone = .primary)        // strong · primary · muted · disabled · onActive

StageChip(_ title: String,
          state: StageControlState = .idle,   // idle · active · disabled
          glyph: String? = nil,               // "▸" marks a stepping chip
          isKeyboardFocused: Bool = false,
          accessibilityLabel: String? = nil,
          accessibilityValue: String? = nil,
          accessibilityHint: String? = nil,
          action: @escaping () -> Void)

StageTab(index: Int?,                          // nil = unnumbered
         title: String,
         isSelected: Bool,
         isKeyboardFocused: Bool = false,
         accessibilityHint: String? = nil,
         action: @escaping () -> Void)

StageDivider(_ orientation: Orientation = .horizontal, inset: CGFloat = 0)

StageKeyHint(_ key: String, _ label: String? = nil)

StageSegmentedControl(selection: Binding<Value>,
                      segments: [StageSegment<Value>],
                      enabled: Bool = true,
                      accessibilityLabel: String? = nil)
```

Primitives are stateless with respect to focus: they take `isKeyboardFocused`
as a plain `Bool` and the owning component holds the `FocusState`. That is what
lets the gallery render *disabled-and-focused* without simulating anything.

`StageChip` vs `StageSegmentedControl`: chips for unrelated jumps, segments for
values that form a scale (density, size, count). A joined track tells the
reviewer the options are one dimension.

### 3.2 Components

```swift
StageBar { content }                          // the shared chrome surface

StageTabBar(items: [StageTabItem],
            selection: Binding<String>,
            @ViewBuilder trailing: () -> Trailing)

StageScrubber(groups: [StageAxisGroup<Model>],  // or axes: [StageAxis<Model>]
              state: Binding<Model>,
              hints: [StageKeyHintItem] = [])

StageKeyHintBar(_ items: [StageKeyHintItem])

StageFrame(stageSize: CGSize? = nil,
           @ViewBuilder tabBar: () -> TabBar,
           @ViewBuilder content: () -> Content,
           @ViewBuilder scrubber: () -> Scrubber)

StageWindow(driver: StageDriver<Model>,
            stageSize: CGSize? = nil,
            hints: [StageKeyHintItem] = [],
            onKeyPress: ((KeyPress) -> KeyPress.Result)? = nil)
```

`StageFrame` is layout only — use it when you want the structure but are hand-
writing the bars. `StageWindow` is the whole thing, generated from a driver.

**`stageSize` and capture determinism.** A stage that resizes with its window
produces screenshots that cannot be compared: the same design captured on two
machines lands at two sizes, and a diff between review rounds shows layout noise
instead of design change. Pass `stageSize` to pin the content well; the window
sizes itself to fit. Note that the chrome sets a *floor* on window width — if
your scrubber is wider than your `stageSize`, the well will be centred in a
wider window (which is fine, and still deterministic).

---

## 4. The driving model

This is the part that turns chrome into a system. Three types, all generic over
your own state.

### 4.1 `StageConcept<Model>` — a design the stage can host

```swift
StageConcept(id: String, title: String, subtitle: String? = nil,
             @ViewBuilder content: @escaping (Binding<Model>) -> Content)

StageConcept(_ title: String, ...)             // id derived from title
```

Concrete rather than a protocol, because a stage's whole purpose is holding
*competing* designs — necessarily different types — so any protocol version
would need erasing at the array boundary anyway. Erasing once, here, keeps the
declaration to one line per concept.

The content closure receives a `Binding` to the shared model, so concepts are
fully interactive: pressing a control inside concept 3 moves the same state the
scrubber moves, and switching to concept 1 shows the result.

If you prefer identity to live next to the view code, conform instead:

```swift
struct CardConcept: StageConceptView {
    static let conceptTitle = "Card"
    @Binding var state: AppState
    init(state: Binding<AppState>) { _state = state }
    var body: some View { … }
}

let concepts = [CardConcept.stageConcept(), ListConcept.stageConcept()]
```

### 4.2 `StageAxis<Model>` — a named state dimension

An axis is a named set of discrete positions, plus a way to read which one the
model is currently at. That is all it is — and it is enough to generate a
control, an active state, accessibility, a keyboard shortcut, a hint-bar entry,
and a column of snapshots.

```swift
public struct StageAxis<Model>: Identifiable {
    let id: String
    let title: String                          // display name and a11y label
    let presentation: StageAxisPresentation    // toggle · cycle · chips · segmented
    let placement: StageAxisPlacement          // scrubber · tabBarTrailing
    let values: [StageAxisValue<Model>]
    let baseValueID: String?                   // the neutral position
    let shortcut: Character?
    let currentValueID: (Model) -> String?
    let summaryLabel: (Model) -> String
    let isEnabled: (Model) -> Bool
}
```

You almost never write that initialiser. Six declarative constructors cover it:

```swift
// Boolean flag → one chip, inverted when on.
.toggle("EMPTY", path: \.isEmpty, shortcut: "e")

// Enum, stepped by one chip. Compact — right for long tails.
.cycle("LOCALE", path: \.locale, label: \.code)
.cycle("COUNT",  path: \.count, values: [0, 3, 50], label: { "\($0) ITEMS" })

// nil + every case. The classic "no error / error N" shape.
.optionalCycle("ERROR", path: \.error, label: \.short, shortcut: "x")

// One chip (or segment) per position. Right for 2–5 values you switch constantly.
.options("THEME", path: \.theme, label: \.name)
.options("DENSITY", path: \.density, label: \.name, presentation: .segmented)

// Compound positions that set several properties at once.
.shots("SESSION", values: [
    StageAxisValue("SIGNED OUT") { $0.user = nil; $0.cart = [] },
    StageAxisValue("TRIAL")      { $0.user = .trial; $0.daysLeft = 3 },
    StageAxisValue("EXPIRED")    { $0.user = .trial; $0.daysLeft = 0 },
])
```

Four decisions worth knowing about:

- **`apply` is a mutation, not a value.** A single position can set several
  correlated properties. A "permission denied" position that only set
  `permission = .denied` and left `transport = .recording` would put the
  prototype in a state the real app can never reach, and the review would be
  spent discussing an artefact of the harness.
- **`baseValueID` defines "active".** A chip inverts when the axis is anywhere
  *other* than its base. For `optionalCycle`, `nil` is the base — so the chip
  stays quiet on the happy path and inverts for as long as you are in a failure.
  That one rule is why you can glance at a scrubber under a screenshot and know
  it is not the happy path.
- **`currentValueID` may return `nil`.** If the model is in a combination the
  axis cannot name, no chip shows as active. Honest, and better than guessing.
- **Value ids are positional (`v0`, `v1`), not slugged labels.** Labels get
  reworded constantly during a review, and renaming a chip should not silently
  rename every snapshot file it appears in.

`isEnabled` handles dependent axes — a "sort order" axis is meaningless while
"empty list" is on. Disabled axes grey out rather than disappearing, because a
scrubber that reflows under the pointer is unusable.

Axes are grouped into scrubber rows:

```swift
StageAxisGroup(id: "primary", axes: [ … ])     // row 1
StageAxisGroup(id: "edge",    axes: [ … ])     // row 2
```

Grouping is the only editorial decision the scrubber asks of you, and it is
worth making deliberately: reviewers learn a stage by row. Put the axes you
drive a demo with on the first row and the ones you reach for when interrogating
an edge case on the second.

`placement: .tabBarTrailing` moves an axis to the trailing end of the top bar.
Reserve it for the axis that selects *what you are looking at* rather than what
state it is in — screen, route, viewport. That groups the two "which view"
controls together and keeps the scrubber purely about state.

### 4.3 `StageScenario<Model>` — a named, applied combination

```swift
public struct StageScenario<Model>: Identifiable {
    let id: String                             // becomes <id>.png
    let title: String
    let conceptID: String?                     // nil = leave current concept
    let settle: Duration
    let apply: (inout Model) -> Void
    let tags: [String]
}
```

A scenario is what you point at in a review ("look at *empty, offline, on the
compact concept*") and it is exactly the unit a snapshot run iterates. Because
both uses share the type, the picture in the spec and the state you can reach
live cannot drift.

`settle` is not a fudge factor. Animated prototypes have a settling time *and* a
meaningful mid-transition; `settle` is the knob that says which moment of the
state you meant.

Generators:

```swift
StageScenario.baseline(concepts:reset:settle:tags:)
// One per concept at rest — the "line up the directions" set.

StageScenario.sweep(concepts:axes:reset:settle:tags:)
// One per axis position per concept, everything else at base.
// n · Σvᵢ scenarios — linear, so it stays runnable as the stage grows.
// This is the default review set.

StageScenario.matrix(concepts:axes:reset:settle:tags:)
// Full cartesian product. Multiplicative — three 3-position axes across four
// concepts is 108 captures. Reach for it when you need interaction coverage,
// and filter the run rather than shortening the list.
```

Or leave it to the driver: `driver.defaultScenarios(reset:)` returns
baseline + sweep over its own concepts and axes.

### 4.4 `StageDriver<Model>` — the shared state

```swift
@MainActor
public final class StageDriver<Model>: ObservableObject {
    @Published var state: Model
    @Published private(set) var conceptID: String

    init(state: Model, concepts: [StageConcept<Model>], axes: [StageAxisGroup<Model>],
         initialConceptID: String? = nil)
    convenience init(state:concepts:axes: [StageAxis<Model>],initialConceptID:)

    func select(conceptID: String)
    func selectConcept(number: Int) -> Bool     // 1-based
    func cycleConcept(by: Int = 1)

    func mutate(_ body: (inout Model) -> Void)  // the single write path
    func apply(_ value: StageAxisValue<Model>)
    func step(_ axis: StageAxis<Model>, by: Int = 1) -> StageAxisValue<Model>?
    func resetAxes()
    func apply(_ scenario: StageScenario<Model>)

    func defaultScenarios(reset:settle:) -> [StageScenario<Model>]
    var derivedKeyHints: [StageKeyHintItem]
    func handleStageKey(_ press: KeyPress) -> KeyPress.Result
}
```

`Model` is expected to be a value type. All writes funnel through `mutate`,
which sends `objectWillChange` explicitly — so if you are adopting StageKit
around a pre-existing reference-type prototype store, in-place mutations still
refresh the stage even though `@Published` would not fire for them.

Hold the driver where both your scene and your app delegate can see it:

```swift
@MainActor
enum Stage {
    static let driver = StageDriver(state: AppState(), concepts: …, axes: …)
}
```

---

## 5. Worked example: putting your own concept on a stage

Everything below is the complete adoption. There is no other file.

```swift
import SwiftUI
import StageKit

// 1 — Your state. A plain value type.
struct AppState {
    var items: Int = 8
    var theme: Theme = .light
    var isOffline = false
    var error: LoadError?
    var screen: Screen = .list
}

// 2 — Declare your axes. Each one becomes a control, a shortcut and a snapshot column.
let axes: [StageAxisGroup<AppState>] = [
    StageAxisGroup(id: "data", axes: [
        .options("ITEMS", path: \.items, values: [0, 8, 500], label: { "\($0)" }),
        .options("THEME", path: \.theme, label: \.name),
        .toggle("OFFLINE", path: \.isOffline, shortcut: "o"),
    ]),
    StageAxisGroup(id: "edge", axes: [
        .optionalCycle("ERROR", path: \.error, label: \.short, shortcut: "x"),
        .options("SCREEN", path: \.screen, label: \.name, placement: .tabBarTrailing),
    ]),
]

// 3 — Declare your concepts.
let concepts = [
    StageConcept(id: "card", title: "Card") { CardConcept(state: $0) },
    StageConcept(id: "list", title: "List") { ListConcept(state: $0) },
]

// 4 — One driver, shared by the scene and the app delegate.
@MainActor enum Stage {
    static let driver = StageDriver(state: AppState(), concepts: concepts, axes: axes)
}

// 5 — The stage.
@main struct ConceptsApp: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate
    var body: some Scene {
        WindowGroup("Concepts") {
            StageWindow(driver: Stage.driver,
                        stageSize: CGSize(width: 420, height: 760))
        }
        .windowResizability(.contentSize)
    }
}
```

That is a working stage: numbered tabs, `1`/`2` and `⌘1`/`⌘2` shortcuts, a
two-row scrubber with eleven chips and a screen switch in the tab bar, a hint
row derived from the declaration, and — once you add the six lines in §6 —
thirty-odd deterministic PNGs.

Adding a twelfth state later means adding one line to `axes`. You do not touch
the chrome, the shortcuts, the hint row, or the snapshot list.

A live version of exactly this shape ships in the module: see `StageDemo`,
`StageKitDemoStage`, and `StageKitGallery`.

---

## 6. Snapshot workflow

```swift
final class Delegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        StageSnapshot.runIfRequested(
            driver: Stage.driver,
            scenarios: Stage.driver.defaultScenarios(reset: { $0 = AppState() }),
            configuration: StageSnapshotConfiguration(windowTitle: "Concepts")
        )
    }
}
```

Then:

```sh
STAGE_SNAPSHOT=docs/img swift run            # write every scenario, then quit
STAGE_SNAPSHOT=docs/img STAGE_SNAPSHOT_FILTER=offline swift run   # subset
STAGE_SNAPSHOT=docs/img STAGE_SNAPSHOT_TAGS=spec,regression swift run
swift run                                    # unset → ordinary interactive launch
```

Setting the environment variable is what turns an ordinary launch into a capture
run. No second executable, no test target — and therefore no second copy of the
stage to keep in sync with the one people actually review.

### Why `cacheDisplay` and not a screen capture

`NSView.cacheDisplay(in:to:)` asks the view hierarchy to draw itself into a
bitmap. It needs **no Screen Recording permission**, does not care whether the
window is frontmost or even on screen, and cannot catch a passing menu or
notification in the frame. That makes it the only capture route that works
unattended on a fresh machine and in CI — precisely when you want a hundred
design states rendered with no human present.

The trade-off: it renders this window's layer tree, so anything drawn *outside*
the window — menus, popovers, tooltips, separate sheet windows — is not
included. Prototype state that must be captured belongs inside the window.

The window is matched by title rather than "first visible", because a popover or
tooltip is its own `NSWindow` and would otherwise be captured instead of the
stage.

### API

```swift
StageSnapshotConfiguration(
    windowTitle: String? = nil,
    directoryEnvironmentKey: String = "STAGE_SNAPSHOT",
    filterEnvironmentKey:    String = "STAGE_SNAPSHOT_FILTER",
    tagEnvironmentKey:       String = "STAGE_SNAPSHOT_TAGS",
    initialSettle: Duration = .milliseconds(700),
    terminatesWhenFinished: Bool = true)

StageSnapshot.runIfRequested(driver:scenarios:configuration:)
StageSnapshot.run(driver:scenarios:outputDirectory:filter:tags:configuration:)
    async -> StageSnapshotReport            // written / skipped / failed
StageSnapshot.capture(to: URL, windowTitle: String?) -> CaptureResult
StageSnapshot.capture(window: NSWindow, to: URL) -> CaptureResult
StageSnapshot.targetWindow(titled: String?) -> NSWindow?
```

Captures are written at the window's native backing scale. `run` is separated
from `runIfRequested` so you can drive a run from a test or a menu item.

---

## 7. Accessibility

The harness is a tool people use for hours. It gets the same treatment as
shipping UI.

**Hit targets.** Every interactive control clears 28×28pt via a transparent slab
around a smaller painted pill. `minHitTarget` is a token, so a stage can raise
it without redrawing anything.

**Keyboard operability.** Every control is reachable and operable with no
pointer.

| Key | Action |
|---|---|
| `1`…`9` | Select concept N |
| `⌘1`…`⌘9` | Same — works even while a text field inside a concept is swallowing bare digits |
| `[` / `]` | Previous / next concept |
| `\` | Step the `.tabBarTrailing` axis (the screen switch) |
| *axis shortcut* | Step that axis — declared per axis, rendered into the hint row automatically |
| `←` `→` | Move focus within a tab bar, a scrubber row, or a segmented control |
| `↑` `↓` | Move focus between scrubber rows, holding the column and clamping |
| `Space` / `Return` | Activate the focused control |
| `Tab` | Standard focus traversal — never rebound, because it is the system's |

Bare-digit shortcuts are handled with `onKeyPress` on a focusable root rather
than `keyboardShortcut`, so a focused text field inside a concept consumes its
keys first and typing never switches concepts by accident.

**Focus visibility.** The system focus effect is disabled and StageKit draws its
own ring: the `focus` hue, 1.5pt, inset *outside* the control so it never shrinks
the label. The system ring is tuned for full-size AppKit controls and overwhelms
a 20pt chip.

**VoiceOver.**

- `StageTab` — label is the concept name only (the number is a shortcut
  affordance, not part of the name); `.isSelected` on the current tab; hint
  reads "Press 3".
- `StageChip` — label from the axis title, value from the current position's
  real name (`"Disk full"`, not `"On"`), `.isSelected` when active, and a
  "Steps to the next value" hint on cycle chips.
- Casing is applied at render time, so labels stay in their original case rather
  than being spelled out letter by letter.
- The tab bar, scrubber, and hint bar are labelled containers ("Concepts",
  "State scrubber", "Keyboard shortcuts").
- Dividers and the `▸` step marker are `accessibilityHidden`.

**Reduce Motion.** Every state transition in the kit — chip fill, hover, tab
selection, focus ring — reads `\.accessibilityReduceMotion` and drops to an
instant change. Nothing in the chrome animates on a loop.

**Contrast.** The `.dark` palette is deliberately low-contrast so it recedes.
Where that is the wrong trade — projection, a room, a reviewer who needs more —
`.presentation` raises every label role and enlarges the type in one line.

---

## 8. Gallery

```swift
StageKitGallery()        // every token, primitive and component in every state
StageKitDemoStage()      // a working two-concept stage driven by declared axes
StageDemo                // the declaration behind it, as a consumer would write it
```

The gallery is the kit's own test harness: **if a state cannot be reached in the
gallery, it is not a supported state.** It renders all thirteen colour roles,
all six type roles, the metric tokens, all five label tones, all nine chip
states (idle/active/disabled × plain/focused/cycling), tab states, dividers,
key hints, segmented controls enabled and disabled, a live tab bar, a live
scrubber exercising all four axis presentations plus a dependent axis, a
`StageFrame` with a pinned well, the end-to-end stage, and the generated
scenario list. A theme switcher at the top re-renders the whole page in `.dark`,
`.light` and `.presentation`.

`#Preview` blocks exist for the gallery, the demo stage in all three themes, and
each primitive.

---

## 9. Deliberately out of scope

- **iOS / iPadOS.** The snapshot harness is AppKit-specific by design, and the
  chrome assumes a pointer, a keyboard, and a resizable window. A touch stage is
  a different product.
- **Persisting or restoring stage state.** A stage should open in a known state
  every time; that is what makes two review sessions comparable.
- **Recording or diffing captures.** StageKit writes PNGs to a directory and
  stops there. Comparison belongs to whatever you already use — git, a diff
  tool, a review document.
- **A layout system for the concepts themselves.** Concepts speak their own
  visual language; if a concept reached for `stageTheme` it would start looking
  like part of the chrome, which is exactly the confusion the kit exists to
  prevent.
- **Free-form debug controls** (sliders, text fields, colour pickers). Every
  axis is discrete on purpose: a continuous control produces states you cannot
  name, cannot return to, and cannot snapshot.

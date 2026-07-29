# Home Rec — Concept Prototypes

Four tactile, skeuomorphic redesign directions for Home Rec, as one runnable
pure-UI SwiftUI prototype. No backend, no real recording — everything is
simulated (deterministic level synth, seeded identity waveforms, canned
library) so you can feel each direction in high fidelity.

## Run

```bash
cd prototypes/HomeRecConcepts
swift run -c release
```

Use `-c release` when judging animation feel — debug-build Canvas work can
stutter. ⌘Q quits.

## The stage

A 620×780 window presents each concept's panel at real size (450pt wide, the
shipping app's window width) with neutral chrome:

- **Top bar** — concept switcher + screen toggle
- **Bottom bar** — state scrubber: `DISARM · IDLE · REC · SAVE`
- **Keyboard** — `1–4` switch concept · `Tab` recorder/library ·
  `Space` record/stop · `S` replay the saved beat

The four concepts share **one live state store**: start recording in one
concept and switch to another — the take keeps running. Recordings you make
land at the top of every concept's library with the waveform you watched.

## The four directions

| # | Direction | One-liner |
|---|-----------|-----------|
| 1 | **Pocket Operator** | TE calculator-recorder: black chassis, orange REC key with real travel, screen-green segment LCD, gain fader, printed spec grid. Saved beat: LCD inverts, filename types in. |
| 2 | **Dictaphone Deck** | Recording is tape: reels spin and *hold their angle* across takes, breathing red lamp, ballistic VU needle, amber counter. Saved beat: rewind clunk + paper slip. |
| 3 | **Braun Utility** | Rams pocket appliance: dot-grid grille, one rotary dial, two lamps, ink polyline. Nothing pulses at idle. Saved beat: green double-blink + index card. |
| 4 | **Glass Shelf, Metal Heart** | Frosted glass over a mesh backdrop; recordings are charcoal cards; one physical brand-red key set in brushed metal. Saved beat: the take materializes as a card. |

Cross-cutting (especially the library): the **untitled.stream** language —
lowercase voice, waveform-as-identity thumbnails, monospace spec lines,
tick-ruler scrub with a floating timecode chip, version stacks.

## Verification snapshots

```bash
HRC_SNAPSHOT=/tmp/snaps swift run -c release
```

Drives every concept × screen × state, writes a PNG per scenario (including a
continuity sequence that hops concepts mid-recording), then quits.
`HRC_AUTORECORD=<1-4>` launches straight into a recording for perf profiling.

## Layout

- `Shared/` — `PrototypeStateStore` (30 Hz data tier, transport choreography),
  `LevelSynth`, `WaveformFactory`, fake library, `LibraryStyle`
- `SharedUI/` — reusable primitives: `PressableKeyStyle`, `SegmentLCD`,
  `VUNeedle`, `BarWaveform`/`LiveWaveform`, `TimecodeChip`, `TickRuler`,
  `TextureCanvas`, `LibraryScaffold`
- `Concepts/<Direction>/` — theme + face + library skin per direction

Deliberately out of scope (v1): real menu-bar `NSStatusItem` popover, sound,
reel-drag scrubbing, 280pt popover layout variants.

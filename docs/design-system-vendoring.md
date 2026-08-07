# Vendoring the design system

Home Rec's visual language lives in **GlassKit**, a SwiftUI design system in the
[ui-explorations](https://github.com/melissa-pereira-deel/ui-explorations) repo
(branch `explore/concept-prototypes`, directory `design-system/`). The app does not
depend on it as a Swift package. It carries a **copy** of the files it needs.

This file explains the arrangement, because the arrangement only works if everyone
touching it knows one rule.

## The rule

> **Nothing under `HomeRec/HomeRec/DesignSystem/Vendor/` is ever edited.**

Those files are byte-identical to upstream, and that property is the whole reason
the vendoring is maintainable. It means a future re-sync is `git diff` against a
known commit, not archaeology. Edit one file and nothing breaks, nothing warns —
the cost lands months later, on the day someone tries to pull upstream changes
and finds every file conflicts.

`scripts/design-system/check-vendor-drift.sh` enforces this. Run it in CI.

## Why a copy and not a package dependency

The design repo is a repo of *explorations*. Making the shipping app's build
depend on it would couple a product release to a sketchbook — and would pull in
components the app does not use (a take list, a player, a scrubber, a transport
state machine) along with the ones it does.

Copying costs a re-sync step. Depending would cost the ability to move the design
repo without breaking the build. For a solo project the first is much cheaper.

## Layout

```
HomeRec/HomeRec/DesignSystem/
  Vendor/                       byte-identical upstream. NEVER edited.
    Tokens/ Primitives/ Components/
  Adapters/                     app-owned. Edit freely.
  DesignSystemProvenance.swift  generated: repo, branch, commit, per-file blob SHAs
```

Two naming conventions do real work:

- **`Glass` is a reserved prefix.** Every `Glass*` type is upstream's; app code
  never declares one. So "is this ours?" is answerable from a type name, with no
  directory lookup. App-owned types in this folder are named for their job
  (`DesignSystemProvenance`, `RecorderWaveformAdapter`).
- **`public` is left as upstream wrote it**, even though it is inert inside a
  single-module app. Rewriting every declaration to `internal` would make every
  vendored file differ from upstream on nearly every line — destroying the clean
  diff, permanently, to satisfy a style preference. As a side effect the access
  modifier becomes free provenance: `public` is upstream's API surface, and
  anything the app adds defaults to `internal`.

### `DesignSystem/` must contain only `.swift` files

`HomeRec/HomeRec/` is a file-system-synchronized Xcode group, so **any non-source
file placed there is copied into `Contents/Resources`** and ships inside the
released app. A `README.md` or an `UPSTREAM.json` next to the vendored code would
end up in the product. That is why provenance is a generated `.swift` file and why
this document lives in `docs/`.

(The same trap is why `HomeRec/Info.plist` sits outside that directory — see the
comment in it, and `InfoPlistTests.noStrayResourceInfoPlist`.)

## Syncing

```bash
./scripts/design-system/sync.sh                 # to the branch head
./scripts/design-system/sync.sh <commit-ish>    # to a specific commit
```

This overwrites `Vendor/` and regenerates the provenance file. Afterwards: review
the diff, rebuild, run the suite.

The two repos **share history** — ui-explorations branched from home-rec at
`9745331` — so `git fetch ui-explorations` transfers only the design-system
objects; everything else is already in the object store. It also pins those
objects locally, which matters: the vendored source stays re-syncable even if the
design branch is force-pushed or the repo is archived.

To see what moved upstream since the last sync:

```bash
git diff <DesignSystemProvenance.commit>..ui-explorations/explore/concept-prototypes \
  -- design-system/Sources/GlassKit/
```

## When a vendored file genuinely must change

In preference order:

1. **Extend it.** A Swift extension in `Adapters/` adds to a vendored type without
   touching it. This covers most cases.
2. **Configure it.** `GlassTheme` is an `EnvironmentKey` with a `.standard`
   default — upstream offering the seam deliberately. Brand values, fonts, and
   metric overrides go through an injected theme, not an edit.
3. **Patch it, and record the patch.** Only if 1 and 2 genuinely fail. Keep it
   minimal, mark it in-file so it is greppable, and mirror it as a real `.patch`
   under `scripts/design-system/patches/` so a re-sync can reapply it.

```swift
// HOMEREC-LOCAL(BL-xxx): one line saying why.
…
// HOMEREC-LOCAL-END
```

**The target is zero patches.** If the count reaches three, vendoring has failed as
a strategy and the decision should be reopened — either fork GlassKit properly, or
take the package dependency after all. That threshold is the honest exit criterion;
without one, "just one more small edit" is how a copy silently becomes a fork.

## What is deliberately not vendored

The Patterns layer, `TransportMachine`, `GlassTransportState` /
`GlassTransportControl`, `GlassNotice`, take rows, the player, the scrubber, the
filter bar, and the gallery.

Those are not omitted for size. Adopting the kit's **state** vocabulary would
duplicate `RecordingState`, which the app already owns and tests — and the kit is
explicitly behaviour-free by design ("it renders state and reports intent"). The
seam holds only while app state maps to kit *view inputs*, never the reverse.

`Components/GlassTimecode.swift` is present but unused: `GlassWaveform` needs its
`Double.clampedToUnitInterval`. Taking the whole file is the rule — a hand-written
copy of that one extension would collide the moment anyone vendors the real thing.

## Previews

`#Preview` is a macro that expands into real code, so a preview referencing a
missing symbol is a *build failure*, not a preview failure. Upstream's previews
reference sample waveforms that are `internal` to the GlassKit package.

`Adapters/GlassPreviewFixtures.swift` supplies them, wrapped in `#if DEBUG`.
Upstream keeps that data `internal` precisely so it "can never ship in a release
build"; vendoring dissolves the module boundary that guaranteed it, and `#if DEBUG`
is what puts the guarantee back.

Note that fonts are registered at runtime in `HomeRecApp.init()`, which previews
never run — so previews render with system-font fallback unless that registration
is repeated in a preview helper.

# Home Rec — Design Systems

Three SwiftUI design systems extracted from the Home Rec concept prototypes.
Each is a self-contained library with its own tokens and **no dependency on the
others**, so any one can be lifted into its own repository by moving a
directory — no shared code to untangle first.

| Kit | What it is | Intended future |
|---|---|---|
| **GlassKit** | Home Rec's own language: translucent panels over a mesh ground, one accent red, structure from hairlines and alignment | The app |
| **StageKit** | Prototype-showcase chrome — the harness that frames concepts and drives them through every state | A separate product |
| **PocketOperatorKit** | Hardware-instrument language: chassis, keys with real press physics, segment displays, analogue meters | A different project |

## Documentation

- [`docs/glass.md`](docs/glass.md) — visual language, colour/type/spacing systems, component catalogue, patterns
- [`docs/stage.md`](docs/stage.md) — philosophy, the axis/scenario driving model, snapshot workflow, adoption guide
- [`docs/pocket-operator.md`](docs/pocket-operator.md) — design language and lineage, control physics, panel hierarchy, accessibility for a label-dense style

## Looking at them

A design system nobody can see cannot be reviewed, so every kit ships a public
gallery view and this package ships an app that renders all three:

```bash
swift run DesignSystemGallery
```

To capture one PNG per kit and quit — uses AppKit's `cacheDisplay`, so it needs
no Screen Recording permission:

```bash
DSG_SNAPSHOT=/tmp/gallery swift run DesignSystemGallery
```

`DesignSystemGallery` is the only target that depends on all three kits. The
kits never depend on it or on each other.

## Using a kit

```swift
.package(path: "../design-system")          // then depend on "GlassKit"
```

```swift
import GlassKit

GlassTransportControl(state: state) { intent in
    switch intent {
    case .startRecording: recorder.start()
    case .stopRecording:  recorder.stop()
    case .openSystemSettings: openSettings()
    default: break
    }
}
```

## Conventions that apply to all three

- **Tokens are semantic.** Roles are named for their job (`surfaceCard`,
  `labelMuted`, `keyCapTop`), never for a hue. No component body contains a
  literal colour — verified by grep, keep it that way.
- **Theming goes through the environment**, so a kit can be re-skinned without
  editing components.
- **Accessibility is part of the component, not a later pass.** Canvas-drawn
  content declares its own label and value; hit targets meet a 28pt floor even
  where the visual is smaller; `reduceMotion` is honoured everywhere.
- **Contrast is measured, not asserted.** Each doc carries a table of ratios,
  including the deviations and why they are acceptable.

## Provenance

Extracted from `../prototypes/HomeRecConcepts`, which remains the working
prototype. The kits carry no dependency on it, on its state store, or on its
fake data — sample data is `internal` so it can never ship in a release build.

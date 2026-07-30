# Spec page

The shareable, single-file version of [`../glass-spec.md`](../glass-spec.md) —
what gets sent to product.

| | |
|---|---|
| `template.html` | The page. Screens are `{{IMG:spec-…}}` placeholders. |
| `build.py` | Inlines every screen as a base64 JPEG → one self-contained file. |

`glass-spec.md` is the source of truth for the *content*; this directory is the
source of truth for the *artifact*. When the spec changes, both need updating —
they are deliberately separate because the markdown is for reading in the repo
and the page is for reading without one.

## Rebuild

```bash
python3 docs/spec-page/build.py
```

Writes `glass-spec-page.html` here (~1.7 MB, 26 screens). Requires macOS —
image conversion uses the built-in `sips`, so there are no dependencies to
install. The script **fails loudly** if a placeholder has no matching PNG,
rather than shipping a literal `{{IMG:…}}` into the middle of the spec.

## If the prototype changed

Regenerate the screens first, or the page will document a version of the UI
that no longer exists:

```bash
swift build -c release
HRC_SNAPSHOT=/tmp/spec HRC_SNAPSHOT_FILTER=spec- ./.build/release/HomeRecConcepts
cp /tmp/spec/*.png docs/img/
python3 docs/spec-page/build.py
```

Capture uses AppKit's `cacheDisplay`, so it needs no Screen Recording
permission and runs unattended.

## Publishing

The built file is not committed — it is a 1.7 MB derived artifact, and a binary
blob that changes wholesale on every screen tweak makes the history unreadable.
Build it and publish the result.

The current published copy lives at
`claude.ai/code/artifact/e2afdff1-ece0-4bc8-aca4-fef1a43e12ea` and is **private
until shared** from the page's own share menu.

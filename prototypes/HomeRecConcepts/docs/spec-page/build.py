#!/usr/bin/env python3
"""Build the shareable single-file version of the Glass spec.

`template.html` is the page; `../img/spec-*.png` are the screens. This script
inlines every screen as a base64 JPEG and writes one self-contained HTML file.

    python3 docs/spec-page/build.py            # -> docs/spec-page/glass-spec-page.html
    python3 docs/spec-page/build.py --out /tmp/spec.html

Why inline rather than link the PNGs: the page is shared as a single artifact
with no accompanying asset directory, and a spec whose screenshots 404 on the
reader's machine is worse than no spec. JPEG at 780px because the source PNGs
are ~1240px Retina captures totalling ~14 MB — far past what a browser should
be asked to decode inline, and the screens are read at column width anyway.

Regenerate the screens first if the prototype has changed:

    swift build -c release
    HRC_SNAPSHOT=<dir> HRC_SNAPSHOT_FILTER=spec- ./.build/release/HomeRecConcepts
    cp <dir>/*.png docs/img/
"""

from __future__ import annotations

import argparse
import base64
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
IMG_DIR = HERE.parent / "img"
TEMPLATE = HERE / "template.html"
DEFAULT_OUT = HERE / "glass-spec-page.html"

WIDTH = 780          # rendered column width; anything larger is wasted bytes
JPEG_QUALITY = 82    # visually lossless for flat UI at this size

PLACEHOLDER = re.compile(r"\{\{IMG:([a-z0-9-]+)\}\}")


def to_jpeg(png: Path, work: Path) -> Path:
    """Downscale + re-encode via `sips` (macOS built-in, no dependencies)."""
    out = work / f"{png.stem}.jpg"
    subprocess.run(
        ["sips", "-Z", str(WIDTH), "-s", "format", "jpeg",
         "-s", "formatOptions", str(JPEG_QUALITY), str(png), "--out", str(out)],
        check=True, capture_output=True,
    )
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    if shutil.which("sips") is None:
        print("error: `sips` not found — this script is macOS-only.", file=sys.stderr)
        return 1
    if not TEMPLATE.exists():
        print(f"error: missing {TEMPLATE}", file=sys.stderr)
        return 1

    template = TEMPLATE.read_text()
    missing: list[str] = []

    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp)

        def replace(match: re.Match[str]) -> str:
            name = match.group(1)
            png = IMG_DIR / f"{name}.png"
            if not png.exists():
                missing.append(name)
                return match.group(0)
            data = base64.b64encode(to_jpeg(png, work).read_bytes()).decode()
            return f'<img src="data:image/jpeg;base64,{data}" alt="{name}" loading="lazy">'

        html = PLACEHOLDER.sub(replace, template)

    if missing:
        # Fail loudly. A silently-unreplaced {{IMG:…}} ships as literal text in
        # the middle of the spec, which is the kind of thing nobody notices
        # until it is in front of the person you were trying to convince.
        print(f"error: no PNG in {IMG_DIR} for: {', '.join(sorted(set(missing)))}",
              file=sys.stderr)
        return 1

    args.out.write_text(html)
    embedded = html.count("data:image/jpeg;base64,")
    print(f"wrote {args.out}  ({len(html):,} bytes, {embedded} screens embedded)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

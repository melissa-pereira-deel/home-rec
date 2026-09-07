# Recording library and naming review package

Status: **proposal for collaborative review; no native feature implementation**

This package consolidates the architecture review, roadmap analysis, security and testing recommendations, detailed feature tickets, component specifications and interactive browser prototypes prepared in September 2026.

## Current product decisions

- Keep one fixed **450 × 450 pt** content window with Recorder, Library and Naming subpages.
- Preserve the Recorder's existing visible layout.
- Use the three-column **Contact Sheet** as the selected gallery structure.
- Continue reviewing the artwork treatment. The latest prototype compares muted color, a clear jewel case, and the **Color Disc** hybrid.
- Treat every file here as review material. Implementation, release configuration and production behavior remain unchanged.

## Start here

| Area | Document |
|---|---|
| Consolidated assessment | [Home Rec review](reports/Home-Rec-Review-2026-09-05.md) |
| Architecture decisions | [Architecture review](reports/home-rec-review-architecture.md) |
| Backlog and sequencing | [Roadmap review](reports/home-rec-review-roadmap.md) |
| Security, agent workflow and testing | [Security and testing review](reports/home-rec-review-security-testing.md) |
| Feature package overview | [Recording library specifications](feature-specs/README.md) |
| Canonical implementation backlog | [Detailed tickets and acceptance criteria](feature-specs/TICKETS.md) |
| Selected window and component design | [Single-window design](feature-specs/SINGLE-WINDOW-DESIGN.md) |
| Native SwiftUI architecture | [Single-window native architecture](feature-specs/SINGLE-WINDOW-NATIVE.md) |
| Scale and gallery behavior | [Grid and scale analysis](feature-specs/SINGLE-WINDOW-GRID-SCALE.md) |
| Generated artwork provenance | [Asset provenance](feature-specs/ASSET-PROVENANCE.md) |

Earlier two-window and large-gallery studies remain in the package as explicitly marked design history. Current single-window documents override them where they conflict.

## Run the interactive prototypes

From the repository root:

```bash
cd docs/agent-review/2026-09-recording-library/feature-specs
python3 -m http.server 8765
```

Then open:

- `http://127.0.0.1:8765/single-window.html?variant=color-disc-v1` — current single-window and four-variant study
- `http://127.0.0.1:8765/palette.html` — palette and semantic color tokens
- `http://127.0.0.1:8765/concepts.html` — earlier gallery explorations

The prototypes simulate data, audio, timing and filesystem operations. They do not read or modify recordings. Their Recorder imagery comes from existing native snapshot fixtures and exists to demonstrate that the Recorder surface remains unchanged.

## Package contents

- `reports/` — architecture, roadmap, backlog, security, testing and agent-development analysis.
- `feature-specs/` — product requirements, native architecture, query and scale contracts, tickets and acceptance criteria.
- `feature-specs/*.html`, `*.css`, `*.js` — self-contained browser studies.
- `feature-specs/recorder-baseline/` — native snapshot evidence used by the studies.
- `feature-specs/assets/` — transparent prototype artwork masters and UI-sized derivatives.
- `feature-specs/Inter.ttf`, `Archivo-Variable.ttf` — fonts required to reproduce the prototype rendering.

## Review boundaries

The source tree, Xcode project, signing settings, entitlements, updater configuration and release workflow are untouched. Reviewers should record final product choices in these documents before opening implementation pull requests. Native implementation must still satisfy the security, accessibility, real-window, filesystem and signed-build gates defined in the tickets.

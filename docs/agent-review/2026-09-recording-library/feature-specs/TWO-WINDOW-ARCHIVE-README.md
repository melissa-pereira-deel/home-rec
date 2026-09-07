> Archived exploration. Superseded by the single-window direction in [README.md](README.md).

# Home Rec — naming and recording library

**Selected: Concept A, Companion Library. The recorder and menu-bar popover stay exactly as they are.** All new navigation and name editing live in the Library, app/overflow menus or a separate naming panel. Use the reference’s rounded artwork, offset play control and restrained metadata to make recordings recognizable, while preserving Home Rec’s dark Glass language.

Prepared 5 September 2026 by a native Swift specialist, a UI/UX design specialist and a performance specialist, with a consolidated ticket and concept review. Baseline: Home Rec `main` at `2f9c42d`. All feature specifications are proposed; no native feature code, repository settings or production state changed.

## Start here

| Deliverable | Contents |
|---|---|
| [Visual palette](</Users/melissadebritto/Desktop/The Building Blocks Co./Home Rec/feature-specs/recording-library/palette.html>) | Interactive surface, artwork, text and control specimens with contrast modes. |
| [Shared palette and tokens](</Users/melissadebritto/Desktop/The Building Blocks Co./Home Rec/feature-specs/recording-library/COLOR-TOKENS.md>) | Source-aligned semantic aliases, exact standard/high-contrast values, measured flat-surface contrast, artwork palette and machine-readable JSON. |
| [Navigation and polish](</Users/melissadebritto/Desktop/The Building Blocks Co./Home Rec/feature-specs/recording-library/NAVIGATION-AND-POLISH.md>) | Recorder preservation contract; menu, shortcut, focus, window-state and naming-panel behavior. |
| [Interactive concepts](</Users/melissadebritto/Desktop/The Building Blocks Co./Home Rec/feature-specs/recording-library/concepts.html>) | Selected A, preserved native recorder baselines, navigation and shared-palette specimens. Interactions are simulated; native baseline renders preserve the current layout. |
| [12 implementation tickets](</Users/melissadebritto/Desktop/The Building Blocks Co./Home Rec/feature-specs/recording-library/TICKETS.md>) | Canonical scope, dependencies, owners, detailed acceptance criteria and required evidence. Ready to copy into your tracker. |
| [Design concepts and components](</Users/melissadebritto/Desktop/The Building Blocks Co./Home Rec/feature-specs/recording-library/DESIGN-CONCEPTS.md>) | Two distinct layouts; dimensions, token mapping, card/input/query contracts, state matrix and native accessibility/polish criteria. |
| [Native architecture and naming](</Users/melissadebritto/Desktop/The Building Blocks Co./Home Rec/feature-specs/recording-library/NATIVE-SPEC.md>) | Actual filename semantics, collisions, stable identity, session ownership, catalog, rename journals, legacy files and recovery. |
| [Scale and query decisions](</Users/melissadebritto/Desktop/The Building Blocks Co./Home Rec/feature-specs/recording-library/SCALE-AND-QUERY-SPEC.md>) | Lazy rendering versus pagination, store alternatives, precise query/cursor behavior, memory limits and benchmark plan. |

The local preview is also available at [Open design board](http://127.0.0.1:8765/concepts.html) while its local server is running. The HTML and bundled fonts remain usable together from this folder afterward. Browser interactions are simulated: they do not read, rename or play your recordings. The written specs are the native implementation contract, including minimum window sizes and failure handling beyond the prototype.

## Selected direction and archived alternative

| | A — Companion Library, selected | B — Studio Workspace, archived |
|---|---|---|
| Experience | Separate resizable archive beside the existing recorder | Recording rail and archive in one larger window |
| Default geometry | Recorder 450 × 450; Library 860 × 640 | Workspace 1040 × 700 |
| Benefit | Additive, lower disruption; recording stays a small utility | Strong side-by-side context for repeated record/review sessions |
| Cost | Some window switching | More layout/state integration and desktop space |
| When to choose | Recording and retrieval often happen separately | Evidence shows frequent switching between current and prior takes |

Concept A owns this release. The earlier B exploration remains documentation only; its persistent recorder rail is not an approved change. No sidebar is needed for one library destination. Cards are not albums: the app should not invent an artist/source label from the reference.

Window → Library (⌘L) and Library → Recorder (⇧⌘L) bring the corresponding existing window forward. Frames, library query/page/selection and current draft survive the transition. There is no auto-front on recording completion, no forced window tiling, and no new recorder-header control.

The component spec uses stable decorative gradients, not synthetic waveform-looking art. Saved-card color comes from immutable identity and survives rename. Play is neutral; red continues to mean recording or failure. Selection, focus and playback have distinct visual/accessibility states. Essential controls remain visible without hovering.

## What the MVP does

- **Name during recording:** the Library active-take area or File/overflow → Name Current Recording opens shared draft editing. The recorder gets no additional field, and the open audio file never moves. Stop remains available even if the draft is invalid.
- **Rename after recording:** use the card menu or File/overflow → Rename Last Recording. A successful rename changes the real filename; the format/extension stays fixed. Conflicts and storage failures preserve the original audio.
- **Browse:** a lazy grid in one Library window, with new recordings added after actual finalization and safe file materialization. Existing views do not jump when a take finishes.
- **Find:** filename search, a single format filter, and four date/name orders. No tagging, folder tree, date picker or list/grid toggle.
- **Preview:** one local play/pause stream at a time, blocked through capture and saving. Starting a take stops preview first to prevent feedback/re-recording.
- **Prior recordings:** proposed scope includes an explicit preview/confirmation for plausible Home Rec files in the selected save folder. It does not recursively import arbitrary audio or assume a filename prefix proves ownership.

The last two items are explicit recommendations inferred from the reference and the usefulness of a library, rather than finalized product decisions. If the preferred first release is new-recordings-only, HRL-009's legacy discovery portion can move later while missing-file handling remains in scope. If preview is deferred, remove Play from shipped cards.

## Why lazy rendering plus pages

Lazy view construction, bounded metadata queries and bounded audio work solve different problems. A lazy grid backed by an ever-growing array is not a memory-bounded archive.

Recommend **60-record Previous/Next pages, a LazyVGrid, and at most one prefetched adjacent page**. This gives a simple native implementation, stable keyboard focus and a bounded row cache. It costs a click after 60 recordings and deliberately does not offer one continuous scrollbar for the entire archive. Exact totals are optional; page-local count and authoritative More available/End of results are enough.

The alternative is a continuously scrolling, windowed collection with reusable cells. That can feel smoother for visual exploration, but requires more work to preserve scroll/focus during resize, renames, inserts and page eviction. Prototype it only if browsing evidence or measured grid performance justifies it. NSCollectionView is a candidate, not an automatic upgrade based on record count. Apple's APIs distinguish [lazy grid creation](https://developer.apple.com/documentation/swiftui/lazyvgrid) from [reusable collection items](https://developer.apple.com/documentation/appkit/nscollectionview).

SwiftData behind a repository is the initial store recommendation, gated by a short macOS 15 query/isolation spike. Use stable UUIDs, explicit bounded fetches and immutable display rows. Core Data is the fallback for a demonstrated framework limitation. Neither `fetchLimit` nor a normal B-tree proves fast arbitrary substring search; benchmark rare/no-match cases.

Test with 1k, 10k and 100k metadata rows. The last is a stretch workload, not an unmeasured support claim. Proposed warm-first-page p95 targets are 200/250/350 ms respectively, with at most 120 cached rows and a 50 MB steady incremental library memory budget. These are provisional acceptance targets; **no scale benchmarks have been run**. The detailed spec defines measurement setup, variance, capture coexistence and fallback decisions.

## Implementation order and discovered prerequisites

Start with two parallel tasks: safe session/file ownership and the catalog/query spike. Then implement durable identities, the draft-name field, actual filename commits, Library shell/cards, queries, legacy/missing-file handling and preview. Performance/craft evidence accompanies those changes and closes the release.

A concrete code finding affects the first ticket: current M4A/FLAC encoders remove a supplied destination, and WAV creation can truncate it. User-entered paths must never be passed directly to those paths. Reserve an exclusively owned working location and perform a non-overwriting filename commit after the encoder closes.

The catalog must also be subordinate to audio safety. A small pending-session manifest lets a completed take reach the normal save folder even if the library database is unavailable. Rename intent and final file identity need crash reconciliation because a filesystem move and a metadata save cannot be one atomic transaction.

For agent implementation, assign separate worktrees and module owners. One integrator controls session/view-model/Xcode-project changes; UI and data agents agree on immutable input/intent contracts before parallel edits. Development uses synthetic fixtures and unsigned builds. Existing signing and production-promotion boundaries remain intact.

## Review and evidence status

Three specialists authored the detailed specs and reviewed cross-document decisions. The selected-A board and palette were inspected in the browser. Active naming-panel transfer, accepted draft restoration, simulated Start/Stop, capture/preview exclusion, search preservation across Recorder/Library navigation and save, explicit Show in Library, and standard/Increase Contrast token switching were exercised. Earlier alternate-layout and saved-name validation checks informed the initial concepts. It is a design aid, not proof of native SwiftUI layout, accessibility, filesystem correctness or performance.

No native feature code or new tests were added. The existing offscreen `ReskinSnapshots` suite was run successfully and generated 25 current-view PNGs in `recorder-baseline/`; ready/recording and Increase Contrast variants are used in the board. These render the actual unchanged native layout on its deterministic flat snapshot backing, not live desktop glass. The renderer does not assert image differences, so this is reference evidence rather than a regression pass. The earlier baseline audit's unit run remains baseline evidence only. The new tickets explicitly require actual file assertions, process-interruption cases, native window/VoiceOver checks, scale traces and a verified signed release before the feature is considered complete.

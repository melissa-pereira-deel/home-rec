# Home Rec — one window, recording library and naming

**Current direction: one fixed 450 × 450 pt content window, with Recorder, Library and Naming subpages.** This replaces the earlier companion-window and detached naming-panel proposal. The Recorder’s existing visible layout, controls, colors and typography remain the baseline. Shared colors and the reference-led artwork treatment carry forward.

Prepared 5 September 2026 against `main` at `2f9c42d`, with native Swift, UI/UX design and performance specialists. These are specifications and interactive prototypes; no native feature code, user recordings, GitHub issues or production settings changed.

## Review the selected layout and artwork variants

[Open the interactive single-window study](http://127.0.0.1:8765/single-window.html). The [local HTML](single-window.html) and its adjacent CSS, JavaScript, fonts and reference images remain usable together after the local server closes.

| | Cover Gallery — earlier study | Contact Sheet — selected | Virgin CD | Color Disc — new variant |
|---|---|---|---|---|
| Columns | 2 | 3 | 3 | 3 |
| Artwork | 194 × 194 pt | 96 × 96 pt color cover | 96 × 96 pt transparent CD case | 80 pt disc in 96 pt color tile |
| Fully visible at standard type | 2 cards, plus a next-row cue | 6 cards | 6 cards | 6 cards |
| Filename | Two lines, Inter 13 | One line, Inter 13 | One line, Inter 13 | One line, Inter 13 |
| Metadata | Duration, format and compact date | Duration/format | Duration/format | Duration/format |
| Main tradeoff | More scrolling | Abstract identity | Repeated physical motif | More visual detail at small size |

**Contact Sheet is the selected layout.** Virgin CD and Color Disc keep its exact geometry, navigation and information hierarchy. Color Disc combines the UUID-selected muted palette with an isolated physical-media motif so files remain visually differentiated. The prototype switch exists for design review only; MVP should implement one approved artwork treatment rather than ship a user-facing density or theme setting.

Artwork deliverables: [isolated disc master](assets/virgin-disc-master-v1.png), [isolated disc UI asset](assets/virgin-disc-thumbnail-v1.png), [jewel-case master](assets/virgin-cd-master-v1.png) and [jewel-case UI asset](assets/virgin-cd-thumbnail-v1.png). The images are decorative; the filename and metadata remain the recording's accessible identity.

The gallery allocates 52 pt to its header, 52 pt to search/query controls, 306 pt to an internally scrolling grid, and 40 pt to its footer. At larger text sizes, the new pages reflow to one column and taller controls inside the same fixed window. Actual native scrollbar width, font metrics and chrome must be measured before treating nominal artwork sizes as fixed on every Mac.

## Navigation and naming

- **Recorder → Library:** View → Library (⌘L), also available through the existing status-item overflow. No permanent tab bar or new button is added to the Recorder face. This preserves its appearance at the cost of menu-based discovery.
- **Library → Recorder:** its visible Back/Recorder action or View → Recorder (⇧⌘L). This changes the page inside the same window.
- **Name while recording:** choose the compact Name action in Library or File/overflow → Name Current Recording…. The same window shows the naming page; the capture session continues independently. Stop remains reachable via Recorder even with invalid input or a pending rename.
- **Rename a saved file:** card actions/Return or Rename Last Recording… opens Naming with the target UUID fixed at invocation. Actual filename validation, non-overwriting commits and crash journals remain required.
- **Return:** preserve query, format, sort, current data page, valid selection and scroll anchor. Saving never forces a route change. Explicit Show in Library may clear conflicting search/filter values to reveal the saved identity.

The prototype includes active naming, saved-file naming, search, sort/filter, bounded pages, missing/empty/long-name fixtures, preview/capture exclusion and larger-text/contrast studies. Its audio, timing and filesystem operations are simulated. The macOS menu shown above the app frame is a menu simulation, not another application window or extra content inside the 450 pt budget.

## Specification map

| Deliverable | Authority |
|---|---|
| [Single-window design exploration](SINGLE-WINDOW-DESIGN.md) | Current layouts, component dimensions, navigation, naming and craft criteria. |
| [Single-window native architecture](SINGLE-WINDOW-NATIVE.md) | Current host/window identity, route ownership, lifecycle/presentation migration, focus/IME and ticket changes. |
| [Grid, paging and scale](SINGLE-WINDOW-GRID-SCALE.md) | Current compact-grid tradeoffs, scrolling cost, retained state, scrollbar and accessibility constraints. |
| [12 implementation tickets](TICKETS.md) | Canonical ticket scope and acceptance, revised for the single-window direction. |
| [Palette specification](COLOR-TOKENS.md), [token JSON](color-tokens.json), [visual palette](palette.html) | Inherited color/type/state values and muted artwork. Single-window documents override former detached-window geometry. |
| [Detailed query/storage scale contract](SCALE-AND-QUERY-SPEC.md) | Durable query semantics, bounded fetches, concurrency and provisional benchmark targets. |
| [Original native storage/naming specification](NATIVE-SPEC.md) | File identity, manifests, filename policy, non-overwriting commits and recovery remain valid; its two-window/panel presentation is superseded. |
| [Archived earlier exploration](TWO-WINDOW-ARCHIVE-README.md) | Historical companion-window and studio-workspace alternatives, not current implementation direction. |

## Architecture and testing implications

One stable app-owned host fixes content to 450 × 450 and owns the current route. One recording session, catalog and accepted-name controller live outside route-mounted views. Do not retain an invisible Recorder behind Library: it can leave keyboard commands and accessibility elements active.

The native inspection found that Recorder currently reports window presence from its appearance/disappearance hooks and attaches alerts/onboarding to itself. Those nonvisual responsibilities must move to the stable host. Otherwise a page change can resemble closing the window, trigger a floating notice, or suppress a recording error. The Recorder’s pixels and behavior remain unchanged; its lifecycle plumbing may change to make subpages correct.

Keep the prior audio-safety work: exclusive working-file ownership, pending-session manifests independent of catalog availability, protected extensions, durable rename intent, stable UUIDs and non-overwriting moves. Subpage navigation does not weaken any of those contracts.

Keep 60-record keyset data pages with at most 120 retained display rows. Scroll within the current page; Previous/Next fetch another data page. This is independent of 2 versus 6 visible cards. Cover Gallery makes a 60-record page long, so full-catalog search stays prominent; a 24-record tuning experiment is documented without prematurely changing the query contract. Native scale benchmarks have not been run for these features.

## Evidence and limits

Browser checks confirmed 450 × 450 frames on Recorder, Library and Naming; 306 pt standard grid viewport; Cover Gallery’s 194 pt artwork/262 pt cards with two fully visible; and Contact Sheet’s 96 pt artwork/150 pt cards with six fully visible. Virgin CD and Color Disc reuse the Contact Sheet geometry and true-alpha 512 px assets without changing card text, focus, preview or menu behavior. The Color Disc specimen renders an 80 pt isolated disc over the existing UUID-selected color tile, with complete edges and clear separation from the play control. Larger text uses one 406 pt column, 26 px filename text and internal scrolling with no horizontal overflow; naming navigation and Done remain inside the fixed frame. Data-page restoration, recording-name draft persistence, filter application and capture/preview exclusion were exercised in the simulation. Invalid names retained the last accepted draft and left Recorder/Stop accessible; completed rename stayed on Naming with result feedback. Empty and missing-file states retained the fixed frame, and unavailable playback was disabled. No browser console errors or warnings appeared in the inspected run.

Recorder images come from the existing offscreen `ReskinSnapshots` suite, which previously generated 25 actual-view references. They preserve the existing native layout on a deterministic flat backing, not the live desktop-sampling material. No new native implementation tests or scale benchmarks were run for this exploration. The revised tickets require native frame/chrome, IME, VoiceOver, lifecycle/error delivery, sustained capture, actual file outcomes and signed-release evidence before implementation is complete.

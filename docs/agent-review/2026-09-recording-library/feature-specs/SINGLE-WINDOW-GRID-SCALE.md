# Fixed-window library: grid density, scrolling and scale

Proposed specification, 5 September 2026. Latest direction: one fixed **450 × 450 pt window** with recorder, library and naming subpages. The recorder face remains exactly as shipped. This document supersedes earlier separate/resizable-library recommendations only for the subjects below; it changes no production code or other specification files. Timings remain proposed verification targets, not benchmark results.

## Recommendation

Use **C1, a two-column cover gallery**, as the primary concept. Its larger covers and two-line filename reservation favor recognition, naming and the supplied visual reference. Offer **C2, a compact contact sheet**, as the deliberate alternate concept for evaluation: three columns with 96 pt artwork inside approximately 123 pt cells, one-line filenames and tighter spacing. C2 shows more recordings by reducing both artwork and text space; it is not merely C1 with another column.

Keep the same metadata repository and **60-record bidirectional keyset pages** for both concepts. Use a vertical `ScrollView` and `LazyVGrid` inside that bounded data page. Grid columns determine presentation; fetch size determines data work. Neither requires a database or pagination architecture change when the user chooses the other concept. A persistent user-facing density switch is optional product scope, not necessary just to compare two design prototypes.

Performance is not a persuasive reason to prefer two or three columns here. Both put only a few simple cards onscreen, use decorative procedural covers, and retain the same bounded metadata. Choose density through task testing, then verify that the implemented view avoids expensive state invalidation. A compact window does not justify an unbounded catalog query.

## Exact standard-size geometry

These dimensions follow the current design-agent proposal. They are **layout targets at the default text size**, not fixed accessibility heights.

| Region | Height |
|---|---:|
| Navigation/chrome band | 52 pt |
| Search/filter/sort band | 52 pt |
| Scrollable library viewport | 306 pt |
| Navigation/page footer | 40 pt |
| Total outer content | **450 pt** |

With 22 pt side insets, horizontal content width is `450 − 44 = 406 pt`. Two columns with an 18 pt gap give `(406 − 18) / 2 = 194 pt`. Three columns with two 18 pt gaps give `(406 − 36) / 3 = 123⅓ pt`.

| Property | C1: Cover gallery | C2: Contact sheet |
|---|---|---|
| Columns at standard size | 2 | 3 |
| Cell width, absent reserved scrollbar gutter | 194 pt | 123⅓ pt |
| Artwork | 194 pt square | 96 pt square centered in cell |
| Filename reservation | 32 pt, two lines | 18 pt, one line |
| Remaining content rhythm | 18 pt art-to-name, 4 pt name-to-meta, 14 pt metadata | 8 pt art-to-name, 28 pt metadata/action band |
| Total tile/row height | `194 + 18 + 32 + 4 + 14 = 262 pt` | `96 + 8 + 18 + 28 = 150 pt` |
| Row gap | 18 pt | 6 pt |
| Complete rows in 306 pt viewport | 1 | 2, exactly `150 + 6 + 150 = 306 pt` |
| Complete records initially visible | 2 | 6 |
| User benefit | Better title recognition and visual calm | Faster scanning among many recent takes |
| User cost | More scrolling to inspect older records | More truncated names; smaller decorative identity |

C1 has 44 pt after its first complete row, so after the 18 pt row gap a 26 pt sliver of the next covers signals more content. C2's two rows fit exactly with no spare vertical space; a hidden overlay scrollbar and no visible next-row sliver can make scrolling less discoverable. Preserve a scroll indicator and make overflow discoverable on first scroll/focus traversal. Do not overlay a helper label on filenames or consume another permanent band solely to explain scrolling.

These widths assume overlay scrollbars or a scroll view whose gutter does not consume the measured content width. Test macOS **Show scroll bars: Always**. Use actual available width to size grid tracks: if a gutter is reserved, shrink the tracks and C1 art accordingly rather than clipping or widening the 450 pt window. C2 keeps 96 pt artwork only while each track can contain it plus required action geometry. Do not hard-code a 194 pt view into a narrower available track. Pixel snapping at display scale should prevent cumulative fractional rounding from creating horizontal overflow.

C2's 123⅓ pt title area is the primary usability risk. Repeated prefixes such as “Customer interview…” or timestamp-generated names can make six visible cards look identical. Preserve the true extension as separate metadata. A native tooltip/full-name accessibility label and a keyboard-accessible details/name subpage expose the complete stem without changing the file or truncating its actual data. Tooltips alone are insufficient for keyboard and VoiceOver users. C1 must expose the full name too when it exceeds two lines.

## Scroll page versus data page

A **visible screenful** is the portion of a grid inside the 306 pt viewport. A **data page** is up to 60 matching recordings. Scrolling reveals the rest of the current data page; Next/Previous moves between data pages, not between rows or screenfuls. The footer must not use language that implies every file is visible simultaneously. Suggested accessible action names are “Next recordings” and “Previous recordings,” with a description that the action loads the next or previous set of up to 60.

With 60 records and the standard geometry, C1 has 30 rows and approximately `30 × 262 + 29 × 18 = 8,382 pt` of content. C2 has 20 rows and `20 × 150 + 19 × 6 = 3,114 pt`. Those are roughly 27.4 and 10.2 viewport lengths respectively. C1 makes deliberate searching/sorting more valuable; C2 rewards browsing recent material without typing. Do not reduce search discoverability to gain one extra visible row.

Sixty remains an initial batch choice, not a claim that 60 is the ideal navigation interval for a small window. Keeping it avoids conflating the density decision with a repository redesign. If task tests show users repeatedly reach the bottom and find the page break disruptive, test 24-record pages using the same cursor contract: that is a tuning experiment with more frequent navigation, not a new implementation of pagination. Do not silently fetch the whole archive to simulate continuous scrolling.

`PageDown`/`PageUp` scroll the current grid viewport. They do not invoke the footer's database pagination. Tab reaches visible controls according to native focus order; arrow navigation follows the grid's row/column arrangement; moving focus to an offscreen item scrolls it into view. At the final row, do not silently fetch a new data page on an arrow key. The explicit footer action provides a predictable boundary.

## Bounded work and persistence of position

Retain at most the current 60-record snapshot and **one adjacent 60-record prefetch**. A fetch may request 61 to discover the next boundary. Keep selected/playing record identity separate from the page snapshots. Card view identity is recording UUID; no per-card observer subscribes to the recorder's live waveform. Procedural covers need no image file, waveform extraction or audio decoding.

Start speculative prefetch only after the page is interactive and the user approaches its last two grid rows or focuses the Next action. At most one foreground fetch and one speculative fetch are scheduled; coalesce repeated triggers. Suspend prefetch during capture. Foreground search/paging may continue through the measured repository boundary. Replacing a page frees the old distant page; scroll traversal must not retain all prior cards or an ever-growing page-history array.

On recorder → library → naming → library navigation, preserve query, sort, filter, current data-page cursor/revision, selected UUID, focused UUID, top visible UUID and its local vertical offset. Prefer a UUID anchor plus offset over a raw absolute scroll position. A route change may keep the bounded current page cached while the shared capture session stays alive; it must not create a second recorder or player.

The baseline restoration contract is:

1. Returning from naming with the same query and unchanged ordering restores the prior anchor and focused item.
2. A successful rename preserves recording identity/artwork. If name order changes, requery around the renamed UUID; if it no longer matches search, announce that outcome and restore the nearest surviving boundary.
3. A switch between C1/C2 changes visual positions but not the data page. Restore the top visible UUID and focused UUID in the new geometry; allow a new local offset rather than insisting that a card has the same absolute Y coordinate across different row heights.
4. Increasing text size follows the same anchor rule. No page reset merely because the grid drops a column.
5. Intentional search/sort/filter changes cancel prefetch and advance query generation, then reset to the first result page while leaving focus in the initiating control.
6. External rename/inserts/removals invalidate ordering cursors as described in the query specification. Do not use stale cursors when leaving or returning to a subpage. Refresh around a valid anchor or show a quiet refresh action; never let an old async response replace newer results.

“Scroll exactly to pixel N after any mutation” is not the guarantee. The guarantee is preservation of the user's logical place, selection and keyboard access within a revision-consistent bounded result.

## Capture and naming within the vertical budget

The standard 306 pt viewport can accommodate a compact **40 pt active-capture summary** by reducing the scroll viewport to 266 pt. That leaves only 4 pt beyond one C1 row; borders, padding and banners must be accounted for rather than appended casually. C2 then shows one complete row plus part of another. The active summary should communicate that capture continues and offer an obvious return to the recorder/stop route; no live waveform or duplicate large transport is needed on Library.

Capture summary is optional presentation, but preserving the ongoing session is mandatory. If navigation chrome already communicates recording state and provides an accessible route back, a separate strip may be unnecessary. Prefer one concise place for this state. Never treat navigating away from the recorder, committing a name, loading a page or changing density as a request to stop capture.

A persistent name editor stacked below a capture strip is a poor fit: another 44–60 pt band would reduce the C1 viewport below a whole tile and commonly hide its caption. **Use the dedicated naming subpage**, maintaining the same fixed outer window. A name entered while capturing updates the session draft; it does not rename the file while the writer owns it. Navigation back restores the grid anchor. The naming page can show a small cover/context label, but the input, extension, commit/cancel controls and validation must take precedence over a large decorative cover.

Error, empty-result and loading states replace the relevant content area. Avoid stacking several persistent status rails above the grid. An inline error for a card remains associated with that item or its naming/detail page. With constrained space, crop or reduce decorative artwork before truncating an error explanation or hiding a required action.

## Fixed outer size with accessible text

The 52/52/306/40 standard geometry must **not** become a set of hard frame heights at larger text sizes. The only invariant is the 450 × 450 outer content boundary. Existing theme type roles scale; never shrink fonts back to keep two or three columns.

At approximately **2× text**, use one grid column. Give the filename and metadata their intrinsic multiline height and expand hit areas as needed. The cover should stay decorative and capped rather than growing to 406 pt wide merely because the grid now has one column; target a maximum 144 pt cover in the accessible presentation, allowing a smaller cover when necessary. This is a Library accessibility layout choice, not a change to the frozen recorder.

Navigation and query controls may wrap or become a compact disclosure for sort/format, while search remains explicitly reachable. Header/query/footer heights grow with text and may reduce the available grid viewport. If their combined natural height would leave less than a practical 120 pt content viewport, move the query controls and pagination into the page's single vertical scrolling container, retaining only a compact accessible Back/navigation band. Do not layer nested competing vertical scroll views or force growing text into a 52 pt rail. Selection/focus is scrolled into view after any disclosure or layout change.

This compact accessibility layout can show less than one whole card at a time; scrolling is acceptable, clipped or unreachable text is not. Labels may wrap to several lines. Full filename, filter state, current page actions and capture status must remain reachable by keyboard and VoiceOver. Do not claim that the default-size “six cards visible” promise applies at 2× text.

For verification, inspect a real 450 pt host at default, 1.4× and 2× role scale, with standard/Increase Contrast, Reduce Motion, and always-visible scrollbars. Use long names, localization expansion, unknown metadata, unavailable media, recording active and naming validation errors. The specification does not assume macOS exposes exactly the same per-app text-size controls as iOS; tests can inject the supported SwiftUI environment sizes and verify any app-level size preference if one is added.

## Performance verification and decision gates

Use the existing 1k/10k/100k catalog fixtures and query semantics from [SCALE-AND-QUERY-SPEC.md](SCALE-AND-QUERY-SPEC.md). That document's resizable/separate-window assumptions no longer apply; its bounded fetch, cursor correctness, cancellation and capture coexistence requirements still do. Native rendering remains unmeasured in this design phase.

For each C1/C2 layout, test first open, search replacement, deep page retrieval, 60-record scroll traversal, subpage restoration, rename across a sort boundary and 2× text. Run on the declared minimum-supported reference hardware/OS, Release build, with idle and active capture. Capture Instruments traces and report raw counts/timings rather than claiming that LazyVGrid guarantees smoothness. Apple's [LazyVGrid documentation](https://developer.apple.com/documentation/swiftui/lazyvgrid) describes view construction on demand; it does not bound the repository or guarantee a reuse policy.

Provisional focused gates:

- First interactive metadata page p95 ≤ 250 ms at 10k rows, ≤ 350 ms at 100k, measured independently of app launch and filesystem checks.
- Next/Previous query p95 ≤ 100 ms without search; no increasing deep-offset cost from an offset-based implementation disguised as a cursor.
- No gallery-attributable main-thread stall above 50 ms; investigate any failure before choosing a different grid framework.
- At 60 Hz, prescribed active scroll trace has p95 frame interval ≤ 16.7 ms and fewer than 1% frames above 33.3 ms, with system/idle intervals reported separately.
- Current plus one adjacent data-page cache stays bounded across at least 200 page changes; memory settles instead of growing with the number of routes or pages visited.
- Ten rapid recorder/library/naming round trips do not start new recording sessions, duplicate observers, reset accepted name drafts or publish stale async page results.
- Thirty minutes of capture plus search/paging/rename-draft activity produces no additional discontinuities, dropped writes or writer backlog versus the deterministic capture baseline. Gallery state receives no per-sample database work.

Before adding an AppKit collection bridge, profile simple card view invalidation, accidental blur, filesystem work and retained models. With only 60 data records per page and a tiny viewport, those causes are more likely to matter than a categorical SwiftUI-versus-AppKit choice. `NSCollectionView` remains a measured alternative if the prototype misses its gate after those issues are corrected, or if a later product decision requires continuous archive virtualization. A smaller window alone is not evidence for a framework migration.

## Acceptance checks for the final single-window tickets

1. Window remains 450 × 450 at all subpages; no recorder-face restyling or extra window is required for library or naming.
2. C1 and C2 use the exact standard geometry above; C2 is documented as 96 pt artwork contact sheets with truncated-name costs. Actual scrollbar width cannot cause horizontal overflow.
3. Scroll controls browse a data page; explicit Next/Previous actions load bounded keyset pages. Column count does not change IDs, matching semantics or cursor order.
4. Query, selection and logical scroll/focus position survive navigation, density changes and accessible reflow; valid exceptions after rename/filter changes are announced.
5. Active-capture UI fits within an explicit height budget. Naming is its own subpage, and capture continues until an explicit stop action.
6. At 2× text the Library uses one column with intrinsic text height, reachable controls and scrollable content; no fixed rail clips text to preserve default density.
7. Both layouts pass the same query/cancellation/capture correctness tests and publish measured performance evidence before scale claims are made.

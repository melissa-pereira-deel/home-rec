> **Presentation superseded:** the current request uses one fixed 450 × 450 content window with subpages. Read [SINGLE-WINDOW-DESIGN.md](SINGLE-WINDOW-DESIGN.md) and [SINGLE-WINDOW-NATIVE.md](SINGLE-WINDOW-NATIVE.md). Earlier separate-window, naming-panel and large-gallery geometry below is historical; storage, file-safety and applicable visual-token contracts remain in force.

# Recording library — selected Companion Library design

Status: Concept A selected by the user; recorder and menu-bar popover appearance frozen. Revised implementation specifications, 5 September 2026. Concept B remains archived design history only. These are acceptance targets, not claims of shipped behavior or measured usability. Ticket IDs are assigned in the parent ticket pack; the DQA labels below are reusable design acceptance suites.

The problem is to make a recording easy to recognize, name, and retrieve while preserving Home Rec's quiet, compact recording experience.

## Evidence and recommendation

The existing recorder is fixed at 450 × 450 pt (`home-rec/HomeRec/HomeRec/RecorderView.swift:193`), with one prominent recording action, a live trace, and contextual Reveal in Finder. Source code is authoritative where `docs/design-system.md` has drifted: current recorder/status typography and colors remain unchanged even where they differ from ideal token roles; current popover, recovery, onboarding, and settings roots use `GlassWindowGround`. The ~47 Hz waveform publication boundary still requires observation isolation. `docs/design-system-vendoring.md` excludes the upstream gallery/player state machinery: app-owned state remains authoritative.

The attached visual reference contributes rounded square artwork, a play control overlapping its lower-right edge, a clear title, muted metadata, and an ellipsis. It does not establish a requirement for albums, artist fields, waveform decoding, import, or cloud storage. A recording's filename and date replace the reference's title/artist hierarchy; date provenance must remain truthful.

**Selected: Concept A, Companion Library.** The user requires the existing recorder to remain the same. Preserve its complete composition and appearance, not just its 450 × 450 pt frame: no new fields, buttons, links, notices, reflow, material changes, or hierarchy changes in `RecorderView` or `MenuBarPopoverView`. Accept one additional native window and secondary-menu discoverability to protect that constraint. Concept B is archived and outside implementation scope.

Applied lenses: **Legibility Design** separates glance recognition (title and artwork), comparison (date and duration), and verification (full filename, format, Reveal in Finder). Artwork carries identity, never evidence about sound. **Coherence Design** keeps recording as the product's center: a library helps users finish and find their recordings; a sidebar of future destinations or a full editing studio would dilute it. The **macos-design** skill informed native window chrome, keyboard operation, and sparse browsing controls. Existing dark-only appearance, Glass metrics, no-import scope, and confirmed filesystem feedback supersede its generic light-mode, drag-in, and optimistic-success examples.

## Concept A — Companion Library (selected)

**Experience.** Preserve the existing 450 × 450 pt recorder exactly. Open Library through the existing menu-bar overflow or Window → Library (Command-L); do not add a recorder-header button. The Library toolbar's neutral Recorder action and Window → Recorder (Shift-Command-L) return to the actual existing recorder window. Each route brings forward/reopens the target window without hiding, morphing, resizing, or moving the other. Closing Library neither stops recording nor discards accepted session-name revisions. [NAVIGATION-AND-POLISH.md](NAVIGATION-AND-POLISH.md) defines source-by-source navigation, focus, and naming-panel behavior.

**Library geometry, in points:**

| Element | Specification |
|---|---|
| Window | Default 860 × 640; minimum 640 × 480; freely resizable above minimum; remember frame within available display bounds |
| Chrome | Native titlebar/traffic lights; approximately 52 pt titlebar reserved for window dragging; no interactive content beneath traffic lights |
| Root | Reuse actual `GlassWindowGround` treatment for Library chrome/root; opaque existing ground/card scroll plane where needed for stable content contrast; no blur per card; [COLOR-TOKENS.md](COLOR-TOKENS.md) is authoritative |
| Horizontal inset | `xxl`, 22 pt on each side |
| Heading row | Library, `.title`; optional known page status in `.meta`; neutral Recorder action in toolbar; 36 pt minimum height; no eager total-count query |
| Query row | Search 220 pt preferred, 180 pt minimum; Sort and Format menus 30 pt tall; 12 pt between controls; 18 pt below row |
| Grid | 18 pt column gap, 28 pt row gap; 168–220 pt artwork width; square artwork; top-aligned cells |
| Footer | 36 pt minimum, native Previous/Next buttons, loaded page count and authoritative more/end status; reserved position below grid scrolling area; ordinal ranges only when known and contiguous |

Columns equal the largest whole number that fits 168 pt cells and 18 pt gaps. Distribute available width equally up to 220 pt per cell; center the resulting grid when its maximum width leaves spare space. At default width, 816 pt content gives four 190.5 pt cells. At minimum width, 596 pt content gives three approximately 186.7 pt cells. At larger text settings, increase the minimum cell width to 220 pt and allow fewer columns; do not shrink text to preserve column count. The top query row wraps as a unit onto two rows when required; the window never gains horizontal scrolling.

**During a take.** The Library heading gains an active-take strip with Recording, elapsed time, and a labeled Recording name field with protected extension and draft feedback. A neutral Recorder toolbar action restores the existing recording window so Stop remains straightforward. A separate native naming panel is available through File → Name Current Recording… and the existing overflow; it requires no alteration to either recording face. These surfaces edit one session-owned draft and do not display a second independently owned transport. Existing recordings remain browsable and renameable; all preview playback is disabled until capture setup, recording, saving, and teardown have ended. The active take is not mixed into the paged catalog as if it were already saved.

**After a take.** Publish a saved recording only after successful finalization. A Library-owned notice or already-open naming panel may report “Saved [filename]” with Show in Library; never add this surface to the recorder or menu-bar popover and never open/front another window automatically. File/overflow → Rename Last Recording… accesses the latest completed file; Library card actions access their own stable identities. Ordinary save preserves the user's page/query/focus. Only explicit Show in Library switches to newest-first, clears conflicting search/format filters as needed, loads the relevant page, and focuses the saved card. Visible control values explain that deliberate transition. Recovery state remains truthful.

## Concept B — Recording Workspace (archived; do not implement)

The following preserves the alternative explored before the user's selection. It is not a second MVP interface and cannot justify changes to the selected recorder. All instructions in this subsection describe the archived concept only.

**Experience.** A larger primary window places capture and browsing side by side. The left recording rail remains visible while the gallery scrolls. A neutral Compact Recorder command restores the current focused recording experience. This is a different working model, not a different palette.

| Element | Specification |
|---|---|
| Window | Default 1040 × 700 pt; minimum 820 × 560 pt; remember size and compact/workspace preference |
| Chrome/root | Historical native titlebar/material study; selected A's current source-derived root contract takes precedence |
| Layout | Outer inset 22 pt; fixed 300 pt recording rail; 28 pt major gap; remaining width is gallery |
| Recording rail | Brand, take-name field, timer, live trace, recording action, and confirmed latest-file state; 18 pt inner padding; never scroll Stop out of reach |
| Gallery | Same cards, query semantics, selection model, and pagination as A; default available width 668 pt gives three ~210.7 pt columns; minimum 448 pt gives two 215 pt columns |
| Small gallery header | Search occupies one row; Sort and Format occupy the next when necessary; never hide active query state behind an unlabeled icon |

The rail is a new composition of existing recording behavior, not the 450 pt view scaled down. At increased text sizes its secondary information can scroll in an inner area, while the naming field and recording controls remain reachable. Do not automatically switch between compact and workspace on resize, take completion, or app launch: surprise mode changes are more expensive than a deliberate toggle.

The persistent rail makes naming and previous-take context adjacent, but consumes substantial space and requires more decisions around permission notices, recovery, and compact/workspace continuity. It also increases the chance of coupling rapid waveform updates to the gallery unless observation boundaries are carefully separated.

## Decision comparison

| Criterion | A: Companion Library | B: Recording Workspace |
|---|---|---|
| Preserve current small-tool identity | Strong; existing window remains intact | Moderate; compact mode must be maintained |
| Browse while recording | Two windows, independently arranged | Immediate side-by-side context |
| Gallery capacity at default size | Four columns | Three columns with larger cards |
| Naming discoverability | Library active strip plus File/overflow naming panel; recording faces unchanged | Persistent field and library together; conflicts with selected frozen-recorder constraint |
| Native window/focus complexity | More window coordination | More mode continuity and constrained layout |
| Change surface and regression risk | Lower; additive library scene | Higher; recomposition of recording face and notices |
| Best hypothesis to test | Recording is occasional; retrieval happens afterward | Users record/review repeatedly in a session |

A is selected for the MVP. B is archived, not awaiting implementation or further approval. Reusing the same catalog leaves future presentation changes possible, but they would require a new product decision explicitly superseding the frozen-recorder constraint.

## Shared component specifications

Components render immutable presentation inputs and report user intents. They do not scan folders, rename files, decode audio, own recording lifecycle, or mirror it in a new design-system transport model. App-specific adapters use names such as `RecordingCard` and `TakeNameField`, without the reserved `Glass` prefix. Do not edit `DesignSystem/Vendor/` to implement these compositions.

### RecordingCard and RecordingArtwork

**Contract.** Inputs: stable recording identity, display basename, complete filename, formatted date with provenance and duration, format, availability, selection, keyboard focus, rename progress/error, playback state, and preview eligibility. Intents: select, request rename, request play/pause, reveal in Finder, show native context menu. Input formatting and eligibility come from app-owned models.

**Geometry.** Artwork is 168–220 pt square with radius 22 pt, an approved Library media exception numerically reusing `panel` without redefining the global token. Ordinary card/state plates use radius 12 pt. There is no additional padded tile shell or permanent resting border; a selected-state boundary appears only when selected. The 12 pt spacing alias applies to actual component gaps/internal content, not a second container around art and captions. A neutral 32 pt circular play control (`controlHeightSmall`, approved light fill/dark ink from the color spec) overlaps the artwork's bottom edge by 6 pt, with its right edge 6 pt inside the artwork. Reserve 18 pt below artwork before the text block. Text reserves two `.bodyEmphasized` lines at the actual font's metrics. Ellipsis has a 28 × 28 pt hit area aligned with the title block's upper-right; reserve 36 pt of title width. Metadata follows after 4 pt: duration · date in `.meta`, at least 14 pt high at standard size. Geometry expands with text size instead of cropping text.

**Typography for new Library/naming surfaces.** Card filename: Inter 13 medium (`bodyEmphasized`). Library heading: Inter 14 medium (`title`). Input and search: Inter 13 (`body`). Explanatory labels: Inter 12 (`caption`) or Inter 11 (`captionSmall`) for short hints. Durations/dates/counts: SF Mono 10 (`meta`). Compact elapsed recording time: SF Mono 14 (`timerCompact`). In these new surfaces Archivo is for brand wordmarks (`appTitle`/`wordmark`); Library uses Inter. This does not authorize correcting the existing recorder's Archivo status/timer or `Color.red` choices. Preserve user capitalization and Unicode in filenames.

**Color and artwork.** [COLOR-TOKENS.md](COLOR-TOKENS.md) and [color-tokens.json](color-tokens.json) are the single authority for refined colors, material boundaries, and approved decorative artwork variants. Reuse existing semantic text/surface tokens; do not redefine them locally or introduce another palette. Use a stable hash of immutable recording ID to choose an approved artwork variant; never derive it from filename, file path, duration, volume, or content. Renaming/restarting/reordering never changes artwork. No waveform-looking bars or fabricated audio analysis. Decorative art is hidden from VoiceOver. Existing recording surfaces and their actual typography/colors remain frozen.

**States:**

| State | Visual and interaction contract |
|---|---|
| Rest | Artwork, readable title, metadata, visible play and ellipsis; essential actions do not require hover |
| Hover | White 6% overlay on opaque `surfaceCard` state plate; `.hover` 120 ms ease-out; metadata promotes to `textSecondary`; no zoom, floating card, or animated gradient |
| Pressed | White 8% overlay on opaque state plate; `.press` 100 ms; metadata remains `textSecondary` |
| Selected | White 12% overlay on opaque state plate plus 1 pt neutral `textSecondary` selected boundary; metadata `textSecondary`; Selected accessibility trait, optional checkmark; selected is not playing |
| Keyboard focus | 2 pt neutral ring with 2 pt dark gap/offset around the focusable card or current child control, over a dark plate rather than directly over artwork; app-owned focus geometry, not a vendored hairline change; ring not clipped; distinct from selection fill; no recording-red focus decoration |
| Playing | Play changes to Pause; explicit “Playing” in `.caption` replaces secondary status region; elapsed/total can be shown in a compact shared preview strip, with no seek control; other cards stop before this one plays |
| Capture active | Preview button disabled with accessible explanation “Preview unavailable while recording”; do not gray out filename, metadata, Rename, or Reveal |
| Saving | No playable saved card before finalization; take status says Saving…; if a pending presentation exists outside the catalog it is clearly labeled, stable, and nonplayable |
| Renaming | Existing title remains the committed value until success; standalone native naming panel shows progress and retains draft; repeat submit disabled while request pending |
| Rename failure | Existing title/path remain authoritative; panel stays open with draft and actionable inline error; no success toast or temporary optimistic title |
| Missing | Neutral unavailable artwork, “File unavailable” text and missing-file symbol; disable play; retain known name/date; offer Retry/Locate only if supported by canonical storage spec, never a dead action |
| Duration unknown | Display an em dash with accessibility “Duration unavailable”; do not show 0:00 or start decoding the entire file to fill a card |

Resolve exactly one card fill with precedence **selected > pressed > hover > rest**. Never accumulate overlays or apply them to artwork, controls, or the entire view tree. Resting metadata can use `textTertiary`; hover/pressed/selected must promote it to `textSecondary` on the changed background. The 1 pt selected boundary and 2 pt external focus ring are distinct. Play has its own approved neutral light fill/ink symbol and black 6%/8% hover/pressed treatment, never the card's white overlays.

Source app and artist labels are omitted: no such reliable attribution is established. Full filename including extension and full date with provenance are available in accessible description and a native tooltip, and Reveal in Finder is the escape hatch to the physical file. Newly captured takes can say Recorded. For explicitly adopted legacy Home Rec files whose capture date is unknown, show the source file creation date with “File created” provenance, never assert that it is the recording time. If even that is unknown, display “Date unavailable”. The compact card may show an unlabeled date, but its tooltip and VoiceOver description expose the provenance.

### ActiveTakeStrip and RecordingNamePanel

**During capture.** Put the labeled Recording name field only in the Library's active-take strip and separate native Current Take naming panel. The existing recorder and menu-bar popover gain nothing and retain their exact geometry. The strip has 14 pt inset, 12 pt gaps, 30 pt minimum field height, and a reserved two-line 36 pt feedback region; it expands with text size. It shows session status and elapsed time without a second waveform or Stop control. The panel is approximately 400 pt wide with 28 pt content inset, natural content height, and the same field/feedback component. It is a separate normal-level native utility panel, not a sheet attached to the recorder. It can close without closing any recording window.

A bounded draft accepts edits while the encoder writes to its safe working path. A separate noneditable extension suffix makes the recorded format explicit. Helper copy: “Applied when this recording is saved.” Empty draft clears the custom name to the generated default and does not block Stop. Accepted revisions persist for that session through window close/reopen; transient invalid text and IME composition are not presented as committed. Opening the panel transfers the active editor there; the Library strip shows its accepted value and an Edit in Naming Panel action while that panel owns editing, so two carets cannot diverge. Closing the panel restores Library editability without shifting Library focus automatically. Never reuse a prior session's draft for a new take.

The app validates synchronously where possible, but capture and Stop cannot depend on a valid name. Invalid drafts get clear inline feedback and remain editable. Stop commits the latest valid editor text; if current text is invalid, preserve the prior valid name or generated default and explain the fallback. Name conflicts follow the canonical unique-name allocation policy. Finalization must not hang behind a naming dialog. The architecture spec owns Unicode, reserved characters, byte limits, collision allocation, atomicity, and recovery behavior; UI copy must reflect the actual selected policy.

**After capture.** File/overflow → Rename Last Recording… and Library ellipsis/context menu/Return all open the same reusable standalone native `NSPanel`, bound to an explicitly resolved completed recording UUID and rename mode. It is modeless so Recorder stays accessible; no Library-attached sheet or second naming panel exists. No Rename button or saved confirmation is added to the recorder/popover. Width 400 pt preferred with 28 pt padding, 12 pt gaps, full-width Recording name field, protected extension, inline error region, Cancel and Rename. Initially select basename only. Reinvoking the same target focuses the existing panel; a different target cannot silently replace an unsubmitted or pending edit. Finish/cancel the existing target first, then reuse that panel. Empty post-recording names are invalid. Active-draft mode uses Done; completed mode uses Cancel/Rename. An active writing file cannot use post-save rename.

Return submits only inside the rename field/presentation; Escape cancels an unsubmitted draft. While a filesystem operation is pending, show Renaming… and prevent duplicate submission; retain the presentation until completion. Do not dismiss it into ambiguous background success. Success updates every visible surface associated with that recording ID, updates the filename used by Finder, preserves artwork, and restores the invoking card or native command context if that app window is still active. It never steals focus back from another application. If name sort moves the item outside the current page, announce the successful new name and preserve a deliberate Show in Library route rather than losing focus silently.

### LibraryQueryBar and PageControls

Search is filename-only, case- and diacritic-insensitive according to the canonical query spec; label “Search recordings”. It remains a real native search field, not a command palette. Search intersects with the selected format. Clear has an accessible name. Sort choices: Newest first, Oldest first, Name A–Z, Name Z–A. Format: All formats, WAV, M4A, FLAC, sourced from supported recording formats. MP3 is declared but unavailable in current `AudioFormat.available`; do not expose it as an MVP filter. No tags, date-range picker, starred filter, duration slider, source facets, or list/grid toggle in MVP.

Changing search, sort, or format resets to page one and clears obsolete card selection. Preserve focus in the control the user is operating. Queries apply to the full indexed library, not merely loaded cards. Empty-library hides irrelevant queries; zero results keeps active controls visible and offers Clear search/filters. Show “No recordings match” separately from “No recordings yet”. A selected but presently empty format remains selectable so results do not reshuffle the menu under the user's pointer.

Use quiet explicit **Previous / Next pages of 60 recordings**, combined with lazy grid rendering within the page. This separates bounded data loading from lazy view creation, provides stable keyboard travel and a visible end, and avoids an ever-growing in-memory history. Default footer examples are “60 recordings · More available” and “23 recordings · End of results”. Count only the loaded page; do not perform eager exact-total work to decorate the interface. Expose Next from authoritative has-next state. Ordinal ranges such as “61–120” are permitted only when known and contiguous; invalidate them after anchor refresh or membership changes rather than retaining false positions. At a page boundary restore scroll to top, keep focus on the activated page control, and announce loaded page status once; no separate grid keyboard paging command is defined in MVP. When both directions are authoritatively unavailable, page buttons are absent; status remains.

An infinite scrolling alternative removes a click during casual browsing, but grows the focus/navigation surface, complicates position restoration and changing-result races, and requires a bounded windowing model beyond a plain lazy stack. Revisit after measured browsing evidence; do not ship an unbounded array as “lazy loading”. The scale specification owns ordering/cursor consistency and response targets. A page load error keeps the current visible page and query context, with Retry; it must not resemble an empty library.

## Native interaction, accessibility, and polish

- Preserve existing Command-R recording and Command-O Reveal behavior in the recorder. Add native Window menu commands Library (Command-L) and Recorder (Shift-Command-L), routed to existing window identities. Command-F searches only when Library is key and not blocked by a naming presentation. No global event monitor or app-wide keystroke interception; first-responder editing/IME semantics and native modal rules take precedence. Stale selection in another window never handles an action.
- Arrow keys move single selection spatially through the grid; Home/End select the first/last item on the loaded page; Return renames; Space previews/pauses only when grid selection owns focus and playback is eligible. Inside text fields, Space types a space and Return follows field semantics. Do not hijack system shortcuts.
- Tab reaches toolbar controls, the grid's selection entry point, selected-card actions, and page controls without visiting every decoration on every card. The grid must remain operable with Full Keyboard Access and VoiceOver, not just custom key handlers.
- VoiceOver exposes filename, duration, date with provenance, format, availability, selection, and play/pause state. Give distinct labels such as “Play Client interview” and “More actions for Client interview”. Announce final rename success/failure, page changes, and playback becoming unavailable once; do not announce every elapsed second or waveform sample.
- Native context menu includes Rename and Reveal in Finder, plus Play/Pause when applicable. No Delete, import, cloud action, or unsupported Locate placeholder is added simply to fill the menu.
- Do not invent a page exit confirmation during normal browsing. An unsubmitted post-recording rename can cancel with Escape; capture remains safe and independent from it. Starting recording first stops and drains local preview through the app-owned coordinator; no simultaneous feedback-producing preview.
- Increase Contrast uses existing high-contrast theme at every surface root. Check text on actual rendered backgrounds: normal text ≥4.5:1, meaningful control boundaries/focus indicators ≥3:1; decorative gradients carry no text or state by themselves. Avoid reusing the upstream red pill's known standard-mode contrast exception for any new library control.
- Reduce Transparency produces opaque, readable surfaces. Reduce Motion removes translation/scale; retain short opacity transitions from Glass motion tokens. Card appearance must not stagger hundreds of animations. Prefer no animation during page replacement; status text can use `.quick` 150 ms. No shimmering skeletons, rotating decorative art, or live traces on saved cards.
- At 2× text scale, metadata wraps, title region grows, column count falls, query row stacks, and footer may wrap. Stop, Rename/Cancel, query clear, and Next remain reachable without horizontal scrolling. Provide representative native previews with bundled fonts registered; browser concepts cannot prove this behavior.

## Design acceptance suites for implementation tickets

| ID | Concrete acceptance criteria | Evidence required |
|---|---|---|
| DQA-01 Concept A shell | Recorder and menu-bar popover match baseline snapshots with zero unmasked pixel differences under deterministic fixtures; no inserted controls/text/reflow/material changes; recorder remains 450 × 450; Library opens/reuses a distinct window at 640 × 480 and 860 × 640 without overlap/scroll; closing Library leaves capture running; reopening restores query/page/focus | Before/after native snapshot comparisons with identical theme/desktop/fonts/OS and fixed clock/waveform; static-region diff plus source review; window-navigation interaction recording |
| DQA-02 Card craft | Approved token-spec artwork remains stable after rename, sorting, relaunch and paging; no fake waveform; play overlap never touches filename; long Unicode filename truncates after two lines while tooltip and VoiceOver preserve full filename | Fixtures for short/long/emoji/combining-mark names; screenshots at 1×/2× text |
| DQA-03 Name during take | User names through Library strip or File/overflow naming panel while capture advances; neither recorder face changes; switching editors preserves accepted revisions without two divergent inputs; existing Stop stays reachable through Recorder route; blank/invalid/collision never block finalization; no inherited draft on next take | Valid/empty/invalid/collision/IME fixtures, panel close/reopen and externally triggered Stop; frozen-recorder snapshots and filesystem assertions |
| DQA-04 Post-save rename | Library card Return/context menu and File/overflow Rename Last Recording resolve correct UUID and shared editor contract; no new recorder confirmation or Rename control; protected extension; pending blocks repeats; failure retains original and draft; success preserves identity and restores origin focus without fronting a background app | Deterministic success/delay/failure and name-sort-page-move fixtures, app switch while pending, last-recording change during open panel |
| DQA-05 Find and page | Search × format works across whole library; each sort visibly reflects selected option; no-results retains controls; page one has no Previous action; final page no Next; page failure retains existing cards; query change cannot show late stale results | 0, 1, 60, 61, 120 and 121 item fixtures plus delayed/out-of-order query fixture |
| DQA-06 Playback truth | Idle card starts exactly one local preview; Pause reflects actual state; unavailable file cannot play; all preview entry points disabled during starting/recording/stopping/teardown; starting a take ends preview before capture begins | Coordinator test evidence and native keyboard/menu/click smoke test |
| DQA-07 Accessibility | Entire name → find → preview → rename → reveal task completes with keyboard and VoiceOver; no icon-only unlabeled actions; focus always visible; typing shortcuts do not steal text; success/error/page announcements occur once; no timer chatter | Manual VoiceOver/FKA checklist; contrast measurements with sample captures |
| DQA-08 Theme/motion | Dark appearance, Increase Contrast, Reduce Motion, Reduce Transparency, active/inactive windows and 2× text all readable; new UI honors Glass typography roles; vendor drift check passes | Native state gallery/screenshots and drift-check output |
| DQA-09 Honest degraded states | Unknown duration says unavailable; missing file says unavailable rather than empty; save/rename failures never claim success; page retry retains context; anchor refresh never retains false ordinal ranges; legacy file creation date is not labeled Recorded; decorative art persists without audio decoding | Missing URL, unreadable URL, unknown metadata, legacy provenance, anchor refresh and retry fixtures |

The parent ticket pack should attach these criteria to delivery tickets rather than create one broad “polish” ticket after implementation. Native screenshot comparison and manual VoiceOver checks are release evidence; a browser concept board is only a review aid.

## Product decisions and handoff

The library lists Home Rec recordings, not arbitrary media import. Explicit preview-and-confirm legacy adoption follows native/scale specs. Local play/pause remains recommended scope; seek, editing, mixing, and waveform generation remain deferred. Concept A is selected, B archived, and current recording surfaces are frozen. Filename normalization/collision policy, migration, and recovery ownership remain architecture contracts. The palette specification is the authority for refined shared colors; do not treat historical alternative art values here as permission to introduce another theme or change recorder tokens.

→ Handoff:

- **Product Manager** — preserve selected A, the frozen recording surfaces, format-only filtering and 60-item paging; map navigation/naming-panel acceptance into delivery tickets.
- **Software Architect** — supply one authoritative recording/preview coordinator and stable catalog identities; ensure naming commit, missing-file reconciliation, and bounded query results satisfy the UI contracts.
- **Product UI/UX Designer** — produce native state specimens using these component dimensions and DQA suites; check actual font registration, focus, contrast, window resizing, and assistive settings before release.

Constraints to preserve across all handoffs: exact existing recorder/popover appearance; existing windows reused without morphing or automatic repositioning; naming outside recording faces; no auto-front on completion; recording safety before naming convenience; filesystem success before success feedback; one dark Glass language; red reserved for recording/error; stable decorative identity; no imported state machine; keyboard/VoiceOver parity; bounded browsing; no general import, tags, sidebar, cloud, editing, or fabricated waveform data.

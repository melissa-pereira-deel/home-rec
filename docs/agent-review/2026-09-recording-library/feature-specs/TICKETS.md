# Home Rec — recording names and library tickets

Current direction: one fixed 450 × 450 content window with subpage navigation · revised 5 September 2026 · source baseline `2f9c42d`.

**User constraint: one window at the current recorder size; Recorder's visible layout remains exactly the same.** Preserve Recorder and menu-bar popover composition, controls, dimensions, typography and materials. Recorder, Library and Name are routes inside one fixed **450 × 450 point content host**, with no separate Library window or naming panel. New navigation uses app/overflow menus and in-content controls on the new subpages; none is added to Recorder. Nonvisual lifecycle/presentation extraction from `RecorderView` is permitted where required to keep capture, alerts and physical-window tracking correct after page unmounting. This supersedes prior two-window, detached-panel and inline-recorder-field proposals.

These are implementation-ready ticket drafts, not published GitHub issues. IDs `HRL-001`–`HRL-012` are local planning identifiers. The pack is the authoritative scope and sequencing summary; the linked specialist specifications supply detailed contracts. No native feature code or new native tests have been implemented by this specification exercise.

## Release contract

Users can name a take while recording, rename a saved take from the library or File/overflow menu, browse recordings in a visual grid, find them by filename and format, and sort by date or name. **The name is the real file basename, not an app-only alias.** A take in progress accepts a draft; filesystem rename waits for encoder finalization. File format and extension stay fixed.

The selected compact layout is **C2, Contact Sheet**: three columns inside the existing-size host. **C1, Cover Gallery** remains an earlier comparison. **C3, Virgin CD** replaces the abstract color cover with a transparent physical-media asset. **C4, Color Disc** composites an isolated disc over C2's UUID-selected color tile. C3 and C4 keep C2's geometry. HRL-007 records the final artwork choice separately from implementing the shared host/data behavior. The prior large Companion Library and Recording Workspace layouts are superseded history, not implementation alternatives for this release.

Recommended assumptions, pending product refinement: new recordings register automatically; existing plausible Home Rec recordings in the selected save folder are adopted only through an explicit preview/confirmation. Minimal in-app play/pause is included because the reference card makes that promise; it is unavailable while any recording session is starting, recording, saving or tearing down. No seek, playlists, tags, arbitrary import, folder tree, deletion, cloud sync or waveform thumbnails. Changing the save folder affects future files, not old library entries.

## Shared decisions

| Area | Contract |
|---|---|
| Identity | Immutable recording UUID; filename/location can change without replacing card identity or artwork. |
| Naming | Session draft during capture; actual non-overwriting rename after finalization; user capitalization and Unicode preserved. Blank draft uses generated default; blank post-save rename is invalid. |
| Collisions | Final save allocates a suffix and reports actual name. Explicit rename shows a conflict and an offered available name for user submission. Never overwrite. |
| Recovery | Persist intent before moves; reconcile process interruption; never equate a database save with an atomic filesystem/database transaction. |
| Metadata | Local SwiftData repository, subject to HRL-002 feasibility evidence; immutable row snapshots; audio remains outside the store. |
| Query | Filename-stem literal substring, case/diacritic folded, 200 ms debounce. All/WAV/M4A/FLAC. Newest/oldest/name ascending/name descending. Search × format applies across the catalog. |
| Order | Persisted normalized lexical name order, not Finder natural order; `Take 10` precedes `Take 2`. Stable UUID tie-break. Date sorting uses actual capture time or provenance-labeled legacy creation date; unknowns last. |
| Browsing | LazyVGrid within bounded 60-item keyset pages; quiet Previous/Next; current and at most one adjacent page retained. No whole-library query or eager exact count. |
| Visual language | Shared existing Glass theme; exact recorder frozen; inherited and app-local library roles defined in COLOR-TOKENS.md and color-tokens.json; Inter for UI, SF Mono for data, Archivo for brand only; neutral play/focus; red reserved for recording/error. Stable decorative gradients, no fabricated waveform. |
| Navigation | View → Library (⌘L), View → Recorder (⇧⌘L), existing overflow entries and new-subpage Back controls select routes in the one host. No Recorder toolbar/header additions, detached editors or route-driven window resize/move. |
| Scope safety | No new network requests or permissions. Browse/query work stays away from audio queues. Leaving a page or closing the main window never stops a take. |

**Current presentation authority:** [single-window native contract](SINGLE-WINDOW-NATIVE.md), [single-window design](SINGLE-WINDOW-DESIGN.md), [compact grid and scale](SINGLE-WINDOW-GRID-SCALE.md), and [colors and tokens](COLOR-TOKENS.md). These override two-window, detached-NSPanel, large-window geometry and simultaneous-editor-transfer instructions in earlier native/design/navigation documents. Preserve those documents' unaffected filename, storage, recovery, privacy and query contracts. Geometry in the current single-window design overrides older color-document geometry where applicable; semantic colors remain shared.

Specialist detail: [native spec](</Users/melissadebritto/Desktop/The Building Blocks Co./Home Rec/feature-specs/recording-library/NATIVE-SPEC.md>), [design/component spec](</Users/melissadebritto/Desktop/The Building Blocks Co./Home Rec/feature-specs/recording-library/DESIGN-CONCEPTS.md>), [scale/query spec](</Users/melissadebritto/Desktop/The Building Blocks Co./Home Rec/feature-specs/recording-library/SCALE-AND-QUERY-SPEC.md>).

## Ticket sequence

| ID | Title | Priority | Depends on | Owner |
|---|---|---|---|---|
| HRL-001 | Make recording ownership and output creation safe | P0 prerequisite | — | Native audio engineer |
| HRL-002 | Prove the catalog and query implementation | P0 decision spike | — | Native data/performance engineer |
| HRL-003 | Persist recording identities and recovery intents | P1 | 001, 002 | Native data engineer |
| HRL-004 | Edit a session’s recording-name draft | P1 | 001, 003 | SwiftUI engineer |
| HRL-005 | Commit filenames and rename saved takes | P1 | 001, 003, 004 | Native filesystem engineer |
| HRL-006 | Add one fixed host with Recorder/Library/Name routes | P1 | 001, 003 | SwiftUI/AppKit engineer |
| HRL-007 | Compare compact concepts and implement selected cards | P1 | 006 | UI/UX design engineer |
| HRL-008 | Implement search, sort, format filter and pages | P1 | 002, 003, 006, 007 | Native data + SwiftUI engineer |
| HRL-009 | Adopt legacy files and reconcile unavailable files | P1 assumed scope | 003, 005, 008 | Native filesystem engineer |
| HRL-010 | Add safe single-recording preview | P1 assumed scope | 001, 003, 007 | AVFoundation engineer |
| HRL-011 | Verify bounded browsing and capture coexistence | P1 release gate | 004–010 | Performance + QA engineer |
| HRL-012 | Complete native craft and release acceptance | P1 release gate | 001–011 | UI/UX + QA + release owner |

P0 means this release’s dependency, not a newly demonstrated security emergency. Tests and accessibility criteria belong in each feature PR; the final gate gathers evidence rather than postponing quality work.

## HRL-001 — Make recording ownership and output creation safe

**Outcome.** Adding subpages and file actions cannot replace an active writer, overwrite an existing take or let an update interrupt teardown.

**Implementation scope.** One session owner starts at exclusive output reservation. Writer ownership ends after capture/encoder teardown, before filename mutation; a separate termination gate remains held through the manifest-journaled initial move into the normal save folder. Quit/update can proceed after that verified materialization even if catalog registration is pending, so a database outage cannot hold termination forever. Reuse existing capture/encoder protocols. Serialize duplicate finish requests, reject stale session callbacks, roll back failed starts and propagate the first fatal write error. Use an exclusively created staging directory on the selected destination volume for URL-based encoders; do not pass editable filenames into current remove/truncate paths. Graceful Quit, updater and recovery consult these shared ownership phases.

**Acceptance criteria.**

1. Given an existing sentinel at a candidate path, starting WAV/M4A/FLAC leaves its bytes unchanged. Existence-check-then-write alone does not satisfy this test.
2. Given failure at create/setup/start/stop/finalize, all acquired resources are released once and any audio-bearing file remains available at its real path.
3. Given suspended teardown and a retry/update/recovery request, none can mutate or replace the owned output; an error may still be displayed immediately.
4. Given concurrent Stop commands from the main host and existing menu-bar controls, one result is published. A late callback from a previous UUID cannot stop the next take.
5. Given an encoder that rejects buffer N, one visible error appears and a common finish path preserves the partial take; waveform activity alone cannot publish success.
6. Given ordinary Quit during suspended finalization or initial materialization, termination waits. Once audio reaches the normal save folder with durable intent/location evidence, catalog-only failure does not keep Quit/update blocked indefinitely. Unrecoverable storage failures require a truthful retained-file result, not an endless invisible wait.

**Evidence.** Deterministic failure barriers, sentinel byte comparisons, late-callback and duplicate-command tests, real encoder smoke tests. Map to native N01; covers design DQA-06/09 prerequisites.

## HRL-002 — Prove the catalog and query implementation

**Outcome.** Choose a store and concurrency model with measured evidence before committing the production schema.

**Implementation scope.** Prototype an actor-isolated SwiftData repository on macOS 15-compatible APIs with disk-backed 1k/10k/100k fixtures. Compare Core Data only if a specific gate fails. Prove compound keyset predicates in both directions, normalized name search, immutable snapshots and explicit save behavior. Separate audio storage from metadata. Record index behavior, not merely declarations.

**Acceptance criteria.**

1. All four sorts, both page directions and every format/search combination return the same ordered IDs as the fixture oracle; page boundaries include repeated dates/names.
2. Fetch/materialization executes outside MainActor and audio queues under the repository’s actual Swift language/isolation settings.
3. A request returns at most 60 rows with 61-row lookahead; no initial full catalog load is needed.
4. Worst-case no-match substring search and mixed-direction date keys are measured. The report explicitly states that a normal B-tree does not accelerate arbitrary substring matching.
5. A finalization metadata write arriving during repeated searches is not indefinitely starved. If read/write isolation must change, document and test that contract first.
6. Deliver a brief go/no-go decision with actual timings, OS/toolchain, limitations and fallback reason; do not label targets as results.

**Evidence.** Reproducible benchmark fixture, query oracle, Instruments trace and decision record. Maps to Scale A. Can run alongside HRL-001 without editing session files.

## HRL-003 — Persist recording identities and recovery intents

**Outcome.** Recordings remain identifiable through app relaunch, rename, save-folder changes and recoverable catalog failures.

**Implementation scope.** Versioned local catalog in Application Support; `Recording` UUID and file references, known metadata/provenance, derived sort/search keys and pending file operations. A small independent per-session manifest records active output and materialization intent. It is the pending-location authority; any catalog session projection is rebuildable. No CloudKit or whole-catalog JSON array.

**Acceptance criteria.**

1. Given a finalized take and relaunch, exactly one UUID points to its actual file; duplicate completion events remain idempotent.
2. Given catalog failure with a working manifest and destination, recording can finish under a generated filename in the normal save folder, with Finder reveal and “Library unavailable” feedback. A database-only outage does not hide the result in staging.
3. Given independent manifest creation fails before capture, Start fails clearly before resources are acquired. A later journal failure preserves the existing pointer/audio and does not trigger an unjournaled move.
4. Given crash at each materialization phase, relaunch reconciles matching manifest/catalog operation IDs once; ambiguous paths are preserved for resolution.
5. Given a changed save preference, old rows/manifests still resolve their original actual destinations.
6. Given migration/open failure, the old store is retained. No silent reset presents an empty library as success.

**Evidence.** Disk-backed relaunch, failure-injection and migration fixtures; schema/normalization versions; no model instances crossing actor boundaries. Maps to native N02 and independent-manifest contract.

## HRL-004 — Edit a session’s recording-name draft

**Outcome.** Users can name the moment while recording without interrupting capture or moving an open file.

**Implementation scope.** Add the labeled `Recording name` field and protected extension to the Name subpage in active-draft mode. File/overflow → Name Current Recording… and Library's Name action select that route in the existing 450 × 450 host; no inline recorder field, extra header button, detached panel or automatic confirmation appears. App-owned editor/session state survives page replacement; accepted revision remains separate from transient text/IME composition. Stop freezes the valid committed draft or previous accepted/default value. Build against the HRL-006 route contract; use a host fake until integration lands.

**Acceptance criteria.**

1. While typing a valid Unicode name, audio frames continue and the encoder URL/handle does not change.
2. Recorder's existing Stop remains at its unchanged position. Name Back/View → Recorder stays available with invalid/composing text so the page never traps access to Stop; the existing popover Stop also works while Name is visible. Finalization never opens a naming dialog or route automatically.
3. Blank accepted draft clears the custom name and chooses the generated default. Done accepts valid committed text and returns to the captured origin; invalid text keeps feedback visible without disabling Back. Escape respects native editor/IME semantics before any route action; a new session does not inherit the old draft.
4. Stop from the existing popover during Name editing freezes valid committed shared text without prematurely accepting IME marked text. In-progress composition uses the prior accepted revision; a late callback cannot target another session. Back never forces `unmarkText` just to navigate.
5. Waveform updates do not reset caret, selection or composition. Recorder ↔ Library ↔ Name and main-window close/reopen retain accepted session state without creating a second model; focus/composition handling follows the native contract rather than promising marked-text restoration across unmount.
6. Feedback says the name is applied after saving; it does not claim that the active file has already been renamed. Only accepted durable revisions are promised after interruption.

**Evidence.** UI tests with injected clock/capture, IME and combining-character fixtures, buffer continuity, Back/Stop from every Name state and VoiceOver walkthrough. Maps to native N03 safety plus current single-window editor contract; older panel presentation is superseded. Pre-record naming is an optional later reuse, not required by this ticket.

## HRL-005 — Commit filenames and rename saved takes

**Outcome.** The app’s displayed filename, Finder location and actual recording agree after a successful rename; failures preserve audio.

**Implementation scope.** One naming service handles initial draft materialization and saved-file rename, journaling intent before non-overwriting filesystem operations. Card Rename…, Return on eligible grid selection and File/overflow → Rename Last Recording… select the same Name subpage in completed-file mode. Capture target UUID/origin at invocation. Preserve committed title until success and retain operation/draft state outside page mounting. Back/View → Recorder remains available while I/O is pending; leaving the page neither cancels nor reverses a move. No detached panel or sheet. The full filename policy remains defined in the native spec.

**Acceptance criteria.**

1. A successful finalized draft changes the actual basename with its fixed extension. Card, latest-recording menu action and existing Finder reveal update by the same UUID; artwork stays unchanged.
2. A draft collision automatically allocates `Name (1).wav` etc. An explicit saved rename instead shows the conflict and offered name for user submission. No existing file bytes change.
3. Blank post-save names, path/control inputs and overlong names fail inline. UTF-8 limit is 200 bytes including extension/suffix after NFC normalization; never truncate a grapheme silently. Matching pasted extension is stripped once; another recognized audio extension cannot change format.
4. An actual destination race is handled by the non-overwriting operation, not an earlier existence check. Final-save suffix attempts are bounded to 100; exhaustion preserves the existing safe file.
5. Case-only rename, identical-name no-op, unavailable/read-only volume and failure after move/before metadata save follow the journal contract. The UI distinguishes “saved, library update pending” from lost audio.
6. Subprocess interruption at every journal/move/save boundary preserves files and either resolves the original UUID or presents explicit ambiguity; no guessed rollback deletes another file.
7. Renaming a playing item first stops/releases playback. Save failure never shows a success toast or optimistically replaces the committed title.
8. Back while rename is pending returns to its origin/Recorder without changing window size or losing the operation. Returning to Name shows the same UUID and current result; completion never steals focus or changes route. Cancel before submission discards the edit; Back never silently submits a completed-file rename or promises undo after mutation starts.

**Evidence.** Case-sensitive/insensitive volume matrix, Unicode/byte-boundary table, collision races, subprocess barriers and decoded WAV/FLAC/M4A before/after comparison. Maps to N04, DQA-04/09.

## HRL-006 — Add one fixed host with Recorder/Library/Name routes

**Outcome.** Users record, browse and name through subpages in the same compact window, with the existing Recorder visible layout preserved.

**Implementation scope.** One uniquely identified main Window scene, a stable 450 × 450 content route host and app-owned route/session/catalog/editor services. Preserve current `.windowResizability(.contentSize)`, `.hiddenTitleBar` and actual Glass ground outside route replacement. Add View → Library (⌘L), View → Recorder (⇧⌘L) and entries in existing app/status overflow; Library/Name have in-content Back, Recorder gains no navigation controls. Register/reopen/deminiaturize the one host by identity. Move physical-window reporting, menu initialization and app-level alert/onboarding ownership from Recorder page appearance to the stable host as needed, without visual recorder changes. Never retain an invisible mounted Recorder whose shortcuts or accessibility elements leak into another route.

**Acceptance criteria.**

1. Repeated Recorder → Library → Name → Back, shortcuts and menu-only reopen create one main NSWindow and no Library/naming panel. Page changes never move or resize its frame. Closing main window leaves capture running; explicit reopen restores requested route and valid retained context.
2. Every route/loading/error/text state has fixed 450 × 450 point content and unchanged native outer frame under the same OS/style. Recorder ready/recording/denied/error/saved visuals and popover match baseline exactly. New pages scroll internally at large text rather than enlarging the host or clipping essential actions.
3. Gallery does not subscribe to 47 Hz waveform publications; changing waveform samples does not recompute the result page.
4. A pending active take is a compact nonplayable status/Name action outside completed results, within the current design's header budget. The gallery never infers finalization from `lastRecordingURL` alone or adds a second Stop transport.
5. Empty catalog, catalog unavailable, no matches, refreshing and page failure are different states; retry retains valid existing content.
6. Command-F targets Library search only there. Any Library Command-R action is disabled under text/IME focus; Recorder's existing R/O semantics exist only when Recorder is selected. Return/Space/Escape reach editors first. Navigation coalesces and preserves query/page/anchor without focus theft on completion.
7. While the recorder SettingsPopover remains hidden during starting/recording/stopping, View menu and existing status/popover overflow still reach Library/Name and Recorder. No settings visibility change or new recorder toolbar is used as a shortcut.
8. Page disappearance never decrements physical-window count, creates spurious install guidance, loses a fatal error/long-recording warning or runs setup twice. Browsing never initiates capture permission probes. Session UUID, timers and encoder continue across route unmounting.

**Evidence.** One-window identity/frame assertions, route/close/reopen/minimize tests, physical-visibility/presentation tests, hidden-settings navigation, current recorder pixel/geometry baseline and invalidation trace. Current authority is SINGLE-WINDOW-NATIVE; earlier N06/DQA window geometry is superseded. Use fake repository/session inputs for parallel layout work.

## HRL-007 — Compare compact concepts and implement selected cards

**Outcome.** Choose and implement a compact gallery composition using native evidence, preserving recognition, readable names and the exact-size host.

**Implementation scope.** Implement the user-selected **C2 Contact Sheet** and build native artwork specimens for its muted UUID-selected covers, **C3 Virgin CD** and **C4 Color Disc**. C3 changes decorative imagery only. C4 renders one cached 80-point isolated-disc asset over C2's code-driven 96-point color tile, with deterministic UUID color and subtle static diffraction rotation. All use the same three 123⅓-point tracks, 150-point rows and 6-point gaps, fitting two rows exactly in the standard viewport. Retain **C1 Cover Gallery** as design history. Do not add a runtime density or artwork toggle. All variants use the same app-owned RecordingCard/preview semantics and query model. At standard text the 450-point vertical budget is header 52 + query 52 + scroll viewport 306 + footer 40. Use supplied true-alpha 512 px UI assets with contain fitting and cached decode; retain masters as design sources. These are content budgets, not a second native titlebar. Follow SINGLE-WINDOW-DESIGN and SINGLE-WINDOW-GRID-SCALE for typography, controls, radius, text clearance and accessibility adaptations; COLOR-TOKENS supplies semantic colors/contrast. Compose app-local adapters without editing vendor tokens or recorder exceptions.

**Acceptance criteria.**

1. The ID-selected decorative palette stays stable after rename, reorder, relaunch and paging. It requires no audio decode and implies no source/artist/waveform analysis.
2. Chosen concept's specified Inter roles preserve user text; full name/extension remains available through native tooltip, keyboard-accessible naming/details and accessibility. C1 reserves two title lines; C2's tighter label truncation does not conceal distinct recordings without a usable full-name route. Long Unicode names never overlap play/menu targets.
3. Rest, hover, selection, keyboard focus, playing, unavailable, unknown metadata and rename states match the component spec. Selection is distinct from playback and from keyboard focus.
4. Play and menu remain discoverable without hover. Missing files retain identity and truthful metadata; unknown duration is unavailable, not zero.
5. New normal text measures at least 4.5:1 against actual rendered backgrounds; meaningful controls/focus at least 3:1. On lifted hover/selected plates, metadata promotes from tertiary to secondary to retain contrast. Verify actual glass separately from flat swatches. Red is not reused as generic gallery decoration.
6. Keyboard/VoiceOver can select, inspect and request supported actions. Reduce Motion has no decorative movement; Reduce Transparency/Increase Contrast remain readable; 2× text does not hide essential controls.
7. C2 color, C3 jewel-case and C4 Color Disc specimens are reviewed against the same long-name, missing-file, active-capture and keyboard tasks. Record the chosen artwork and measured tradeoffs before production visual integration. Do not represent a browser mock as native acceptance or implement multiple presentations by default.
8. C2/C3 fit 150 + 6 + 150 only if real font/control clearance passes. If it does not, increase row height and report fewer visible cards rather than shrinking targets/text. Always-visible scrollbars use measured available track width without horizontal overflow. Large text may reduce columns and grow internal control regions, never the 450-point host.
9. The CD PNG retains real transparency and complete jewel-case edges at 1× and 2×. It is decorative and accessibility-hidden; it never replaces the recording's accessible name. Reuse one decoded/cached image across cards and verify that play, selection and focus remain distinct on its brightest reflections.
10. C4 keeps color stable by canonical UUID and composites a single cached disc asset rather than generating per-card bitmaps. The disc fits inside the tile at 1×/2× without clipped edges; Reduce Motion disables its 1-point hover lift; no continuous decorative animation or playback color mutation is introduced.

**Evidence.** Side-by-side native C2 color/C3 jewel-case/C4 Color Disc specimens with bundled fonts, standard/large-text/gutter arithmetic, final artwork decision, 1×/2× asset captures, contrast checks, keyboard/FKA/VoiceOver checks and vendor drift. Map to current SW design suites; older C1 and large-window DQA geometry are design history. Destructive actions, fabricated metadata and runtime concept switching are out of scope.

## HRL-008 — Implement search, sort, format filter and bounded pages

**Outcome.** Finding a recording is predictable across the whole indexed library and does not consume memory proportional to everything browsed.

**Implementation scope.** Four sort modes, one format filter, literal normalized stem search; 200 ms debounce with Return flush. Bidirectional keyset fetches, generation/revision checks, current plus one adjacent page cache and low-priority prefetch. Quiet Previous/Next footer; show page-local status without inventing total counts or stable page numbers.

**Acceptance criteria.**

1. Search intersects format across all catalog rows. Test `Café`/`CAFÉ`, composed forms, emoji, internal whitespace and literal punctuation; extension/path/source/content are excluded.
2. Full forward and reverse traversal at a fixed revision matches the globally sorted oracle exactly once per UUID, including 60-item-boundary ties. Unknown dates are last in both date directions.
3. No result batch exceeds 60; lookahead is 61 and resident page snapshots are at most 120 rows. No page-number stack retains past row arrays; no eager total count delays first display.
4. Rapid query changes cancel pending work and reject stale generation/revision results. Query errors keep current cards with Retry, not an empty state.
5. Search/sort/filter changes return to first page without stealing input focus. Clear search/filters resets query and format but preserves sort.
6. External order changes offer Refresh instead of reordering under the pointer; stale Next/Previous refreshes before continuing. Rename refreshes around the same UUID or announces that the new name no longer matches.
7. Pagination preserves focus on its control, resets current page scroll intentionally and announces once. Route departure/return and text-size adaptation preserve valid selection/anchor. Footer distinguishes the loaded set of up to 60 from the visible screenful; PageUp/PageDown scroll the viewport rather than fetch database pages.
8. Leaving Library cancels page-view/prefetch tasks and rejects stale publications without destroying app-owned query/session state. Return restores query, page/scroll anchor and focus or the nearest valid boundary. No name/save completion automatically changes the visible route.

**Evidence.** Seeded property/oracle tests; 0/1/59/60/61/120/121 fixtures; out-of-order/failing query fakes; anchor deletion/rename/new-completion tests; native keyboard navigation. Maps to Scale B/C and DQA-05.

## HRL-009 — Adopt existing recordings and handle moved/missing files

**Outcome.** Users can bring prior Home Rec recordings into the library without indexing unrelated audio or losing references when files move.

**Implementation scope.** Explicit Find existing recordings in the currently selected save folder; nonrecursive streamed candidate discovery, preview/confirm and idempotent registration. Recognize the existing `recording_yyyy-MM-dd_HH-mm-ss` convention with optional ` (n)` suffix plus supported parseable format as a candidate heuristic, never ownership proof. Resolve known file bookmarks on demand; retain unavailable rows and support Locate. Integrate pending-session recovery independent of custom filenames.

**Acceptance criteria.**

1. Discovery examines only immediate regular files in the approved folder, skipping hidden files, symlinks, packages and descendants. No files are added or mutated before explicit candidate confirmation.
2. Work batches contain at most 100 candidates; progress pauses at 10,000 entries or five seconds of active work for Continue. Re-enumeration deduplicates instead of assuming stable directory order.
3. New finalized recordings appear through lifecycle events without requiring a rescan. Opening Library never waits for legacy discovery.
4. Known file identity prevents repeat import; distinct copies remain distinct. Matching names/sizes alone never silently merge files.
5. External moves that resolve update URL/title under the same UUID. Missing/unmounted/replaced paths retain a clearly unavailable card; a different file at the old path is not accepted silently.
6. Actual capture time remains separate from legacy filesystem creation date. Display “File created” provenance or “Date unavailable”; never substitute modification/import time as recorded time.
7. Recording pauses optional scanning/enrichment; at most two metadata requests run concurrently. Recovery rechecks live ownership before mutation and finds pending custom-named sessions from manifests.
8. Locate opens a native file panel. Cancel leaves the row unchanged; selecting an unsupported file fails clearly. A different/ambiguous replacement requires deliberate relink confirmation. Successful relink preserves UUID, updates actual location and invalidates derived metadata/artwork-content caches if any; decorative identity remains stable.

**Evidence.** Mixed directory fixtures, cancel/resume, hardlink/copy/symlink, external replacement, detached volume and database outage tests. Maps to N05, Scale D and DQA-09. A general importer and additional watched folders remain deferred.

## HRL-010 — Add safe single-recording preview

**Outcome.** The reference’s Play affordance plays the selected saved file honestly and never feeds playback into a new capture.

**Implementation scope.** One streaming AVFoundation preview controller, play/pause/stop and compact elapsed/total status; one selected file at a time. No seek, waveform analysis, speed, playlists or mixer. App-owned transport reports actual state to cards. All launch/callback paths carry current request identity.

**Acceptance criteria.**

1. Play A then Play B stops/releases A before B begins; rapid Play A → B → Stop cannot be undone by a stale async completion.
2. Starting a recording stops preview before capture begins. All preview entry points remain unavailable through starting/recording/stopping/teardown with an accessible reason.
3. Missing/corrupt/unsupported media produces a local per-item error without changing recording readiness or file bytes.
4. Rename releases the player’s reference before mutation and does not auto-resume. Leaving Library for Recorder/Name or closing main window stops preview; returning never auto-resumes it. Route/window closure leaves capture unchanged.
5. Space only previews when the grid owns eligible selection. Space in a filename field inserts a space; Return/Escape belong to the editor while editing.
6. WAV/M4A/FLAC previews work on macOS 15 and current macOS; long recordings use bounded streaming buffers rather than loading full files into memory.

**Evidence.** Transport cancellation fakes, actual format playback matrix, keyboard checks and allocation trace. Maps to N06 and DQA-06. If this assumed scope is deferred, remove Play from the shipped cards rather than leave a nonfunctional promise.

## HRL-011 — Verify bounded browsing and capture coexistence

**Outcome.** The library remains responsive with growing metadata and does not degrade audio capture.

**Implementation scope.** Repeatable generated 1k/10k/100k catalogs, long-media fixtures, unavailable paths, format skew, tied sort keys, no-match/common substring queries and query mutations. Test normal and active-recording modes; archive benchmark traces with build/OS/hardware.

**Acceptance criteria.**

1. Publish actual fresh-process/warm first-page, query-to-visible, page navigation, memory and hitch measurements against the scale spec’s provisional budgets. Fresh process does not imply cold OS filesystem caches. Report 100k as a stretch experiment until validated, not an automatic support claim.
2. Repeated next/previous traversal reaches a steady memory plateau: at most 120 cached display rows, one selected record/player state, bounded metadata concurrency and no whole audio reads for artwork.
3. A 30-minute capture while typing names and browsing has zero app-attributable missing/duplicate frames in deterministic signal checks; hardware smoke evidence and limits are recorded separately.
4. No-match search cannot starve lifecycle journal/catalog writes. Recording suspends prefetch/enrichment without preventing foreground metadata browsing.
5. Long-file preview allocations remain bounded, canceling obsolete work closes resources, and counts/timings contain no recording names, paths or audio in exported performance logs.
6. Any failed target gets a measured fix, documented lower support envelope or explicit product tradeoff before release; no silent search-semantic change to make timings pass.

**Evidence.** Instruments Time Profiler/Allocations/hitches, seeded query oracle, decoded signal continuity, actual unsigned Release candidate and hardware matrix. Maps to Scale E. NSCollectionView or an alternate search backend is justified only by specific measured failures.

## HRL-012 — Complete native craft and release acceptance

**Outcome.** The feature ships with evidence for the actual user journey and packaged Mac app, not just compiling previews.

**Implementation scope.** Integrate current single-window design/native acceptance plus unaffected DQA behavior into the feature checklist; prove exact release artifact, signed product and update interlock. Verify mounting/lifecycle/presentation extraction, frame constancy, capture source/format regressions, permission guidance, menu-bar behavior and recovery. Update public instructions/roadmap with actual one-window navigation and limitations.

**Acceptance criteria.**

1. A user can record → name → stop → find → preview → rename → reveal entirely with keyboard and separately with VoiceOver. Focus/selection remains meaningful after paging and rename.
2. Native screenshots compare unchanged recorder/popover baselines and all three routes at fixed 450 × 450 content, including long names, degraded states, large text, Always scrollbars, Increase Contrast, Reduce Transparency and Reduce Motion. Outer host frame is unchanged across routes. Offscreen snapshots do not prove live desktop blur; compare actual routes against the same controlled desktop. Vendor drift passes; no unsupported state has a dead button.
3. Current functional and unsigned Release build gates pass. Required failure tests from 001–010 run; skipped hardware/signed-product checks are explicitly reported.
4. The exact signed DMG is verified for identity, entitlements, version/feed/key and supported architectures; it opens/reuses one main host and performs representative Recorder/Library/Name, playback and recovery journeys without creating Library/naming windows.
5. An update waits while capture or required session finalization/initial materialization owns resources; catalog/rename operations are crash-recoverable. Stage the actual local payload, not a production URL accidentally bypassing the rehearsal.
6. The release notes state included legacy scope, preview restriction during capture, formats, paging behavior and truthful tested scale. No broad “unlimited library” claim.
7. Repeated route mount/unmount and main-window close/reopen preserve one capture owner, timer/observer setup and durable draft. Fatal errors/long warnings remain visible on the active route; install guidance uses actual window visibility rather than Recorder-page appearance. No hidden Recorder shortcut/accessibility element acts under Library/Name.
8. Pending rename and invalid/IME Name states never block Back/View → Recorder or existing popover Stop. Asynchronous completions preserve route/focus. Nonvisual extraction diffs are reviewed separately from exact Recorder pixel/geometry evidence; no global toolbar or navigation inset is introduced there.

**Evidence.** Candidate manifest, test artifact links, signed-product report, native interaction recordings and checklist with pass/fail/not-run status. These are future implementation gates; this specification/prototype does not satisfy them.

## Delegation and integration contract

Run HRL-001 and HRL-002 in parallel. Once interfaces settle, native data, SwiftUI routes/cards and tests may work in separate worktrees with explicit module ownership. One integrator owns `HomeRecApp`, route host/coordinator, `RecordingController`, `RecorderViewModel`, necessary nonvisual Recorder presentation-hook extraction and the Xcode project; do not let multiple agents independently rewrite those files. Freeze the route contract before integrating HRL-004/005; HRL-007's C1/C2 decision does not block independent safety/store work. Child views receive state/intents and never own capture or lifecycle-critical tasks.

Every ticket handoff records baseline and tested commit, changed files, acceptance results, unresolved limits and required manual evidence. Use synthetic names/media and unsigned development builds. Keep signing/release credentials outside development agent execution. No publication or deployment is implied by this ticket-writing request.

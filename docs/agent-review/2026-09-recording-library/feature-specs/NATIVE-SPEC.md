> **Presentation superseded:** the current request uses one fixed 450 × 450 content window with subpages. Read [SINGLE-WINDOW-DESIGN.md](SINGLE-WINDOW-DESIGN.md) and [SINGLE-WINDOW-NATIVE.md](SINGLE-WINDOW-NATIVE.md). Earlier separate-window, naming-panel and large-gallery geometry below is historical; storage, file-safety and applicable visual-token contracts remain in force.

# Recording names and library: native implementation specification

Status: proposed implementation contract, 2026-09-05; revised after the user's selection of Concept A and requirement that the record view remain exactly the same. No app changes have been made. Source baseline: `home-rec` commit `2f9c42d`. This document owns native lifecycle, naming, catalog identity and filesystem behavior; sibling design and scale documents own visual components and query/page behavior. Ticket IDs here are local planning identifiers, not existing GitHub issues.

## Recommendation and scope

Implement Concept A: keep the existing recorder and menu-bar popover **exactly unchanged** and add one resizable Library window, sharing a single application recording session. Do not add fields, buttons, save-confirmation UI, banners or reflow to `RecorderView.swift` or `MenuBarPopoverView.swift`. Existing overflow menus/application menus and app-level window coordination may change. Name editing belongs in Library's active-take area or a separate native naming panel. Add a local SwiftData catalog behind an actor/repository boundary; keep audio as ordinary files in the existing save folder. A recording has a permanent UUID and a mutable location. Its visible title is its actual file basename, excluding the format extension, after a rename succeeds.

During recording, editing changes a draft associated with that session. The file stays at its original generated location until the encoder closes. On successful finalization, the app applies the draft with a non-overwriting move, then publishes the final catalog row. A library problem must never discard an audio file.

Assumptions: new app-created recordings are included automatically. Existing files in the currently selected folder are candidates for an explicit import preview; filename patterns alone do not prove Home Rec authorship. Additional folders, recursive indexing, tags, cloud sync, file deletion in the gallery, batch rename, format conversion and editing audio are outside this MVP. The current save-location picker still controls future recordings; it never moves historical files.

## Evidence from this app

References below are relative to `home-rec/`.

| Verified source | Implication |
| --- | --- |
| `HomeRec/HomeRec.xcodeproj/project.pbxproj:405`, `:422`, `:433`, `:436` | Unsandboxed macOS 15 target, default MainActor isolation, Swift 5 language mode. Keep deployment compatibility; no wholesale concurrency migration required by this feature. |
| `HomeRec/HomeRec/HomeRecApp.swift:17`, `:37`, `:59`, `:81` | One root recorder view model is shared with menu UI; recorder is a content-sized `WindowGroup`. Library needs separate sizing/presentation; singleton navigation requires scene identity rather than opening fresh group windows. |
| `HomeRec/HomeRec/RecorderView.swift:193`; `MenuBarPopoverView.swift:132` | Current recorder is 450 × 450 and both surfaces invoke the shared view model. Preserve both view files and all current layout/control appearances; naming must be added elsewhere. |
| `HomeRec/HomeRec/OverflowMenu.swift:432` | Existing Show Window finds the first window titled Home Rec and cannot recreate it after closure. Replace this app-level route with identity-based coordination; do not guess a window by title/order. |
| `HomeRec/HomeRec/RecordingController.swift:61`, `:75`, `:87`, `:154` | Generated timestamp URL, opened before awaited setup, then exposed late. No naming input or durable catalog. |
| `HomeRec/HomeRec/RecorderViewModel.swift:399`, `:473` | Only last recording URL is retained and Finder reveal reads it. Successful rename must update this projection by recording identity. |
| `HomeRec/HomeRec/RecoveryScanner.swift:18`, `:55` | Recovery uses URL identity and `recording_` prefix. Custom names must instead be discoverable from persisted session identity. |
| `HomeRec/HomeRec/RecoveryViewModel.swift:50`, `:63` | Repair/trash actions currently lack a fresh session-ownership check. A listed item must not imply permission to mutate it later. |
| `HomeRec/HomeRec/RecorderViewModel.swift:756`; `RecordingState.swift:162` | Error presentation can precede cleanup while error state permits update/retry. Close this race before introducing file actions from a second window. |
| `HomeRec/HomeRec/SaveLocationProviding.swift:35`, `:50` | Save destination is currently a path preference with Desktop fallback; catalog must record the actual captured destination, not the current preference. |
| `HomeRec/HomeRec/AudioFormat.swift:57` | Shipped formats are WAV, M4A and FLAC. MP3 is declared but not available; do not advertise it as a working new-recording filter choice. |
| `HomeRec/HomeRec/M4AEncoder.swift:77`, `FLACEncoder.swift:71`, `WAVWriter.swift:84` | Encoders currently remove or create files at supplied paths. Existing existence-check loop does not establish exclusive ownership. Do not send a requested user filename into these creation paths. |

The earlier [architecture review](../../home-rec-review-architecture.md) supplies lifecycle failure cases and prerequisite rationale. Its findings are static analysis, not completed fixes.

## Ownership and concurrency

Application scope owns `RecordingSessionCoordinator`, `RecordingLibraryRepository` and, if preview ships, one `LibraryPlaybackController`. Names are proposed roles rather than a requirement to create a framework or many packages. Reuse existing `RecordingControlling`, file-writing and capture protocols.

- Session coordinator owns immutable session ID, selected source/format, resolved output directory, actual output URL, and accepted draft revision. Its observable presentation runs on MainActor. Audio samples remain with existing encoder/capture workers; no catalog work runs per sample.
- Catalog actor serializes metadata and pending-operation changes. Views receive immutable `Sendable` snapshots, never actor-owned SwiftData models. Verify actual executor behavior in Instruments; writing `actor` or using `async` alone is not proof that I/O runs away from the main thread. Apple describes [ModelActor](https://developer.apple.com/documentation/swiftdata/modelactor) as providing mutually exclusive model access.
- One file-operation service serializes mutations per recording. A short lease prevents rename, repair, preview-open and locate/relink from racing one another. No lock is held across unrelated recordings or a whole gallery query. Actor methods that suspend must recheck operation identity after resumption.
- `ownsOutput` begins when a path is reserved/created and ends only when capture and encoder teardown have completed. `isRecording` is a presentation fact, not this ownership rule. Recovery, rename, update install and graceful quit consult the same owner. Errors may be visible while teardown is still running.
- Window closure never stops capture. Reopening Library retains its query and selection. Menu-bar controls, recorder and Library commands address the same session. A dedicated Library view model observes catalog events and low-frequency session summaries; it does not subscribe to the waveform stream. No second recorder view is embedded in Library and no recorder/library mode swap occurs.
- While starting/stopping, rename commits and playback of the owned file are unavailable. Library's active-take area shows the editable name draft and recording status outside paged completed results; it is never playable. Stop freezes the latest valid, non-composing draft revision from the shared editor state. A later keystroke cannot retarget the next session.

### Native windows and commands, with unchanged recorder surfaces

Use one MainActor `AppWindowCoordinator` for the named roles `recorder`, `library` and `recordingNamePanel`. Recommended scene composition in `HomeRecApp`: unique `Window` scenes with stable IDs `home-rec.recorder` and `home-rec.library`, preserving the recorder's exact existing content, sizing, style and environment. Replacing the scene's `WindowGroup` container is app composition work; it must not change the recorder's pixels or its `RecorderView` implementation. Apple documents [Window](https://developer.apple.com/documentation/swiftui/window) as a single unique window and [openWindow](https://developer.apple.com/documentation/swiftui/environmentvalues/openwindow) as bringing that scene forward, whereas opening an unparameterized WindowGroup creates another window.

Register each actual NSWindow under its stable role/identifier from a scene-level hosting/window bridge outside `RecorderView` and `MenuBarPopoverView`. Use a retained application command router/open-window action that remains callable when content windows are closed; scene creation remains owned by SwiftUI. For an existing window, activate Home Rec, deminiaturize when needed, then call `makeKeyAndOrderFront` on the registered window. For an absent/closed scene, invoke `openWindow(id:)` for its unique ID and complete focus when the new window registers. Coalesce simultaneous show requests; never use `NSApp.windows.first`, title comparison, frontmost/key/main-window guesses or an unrelated panel as the target. [NSWindow](https://developer.apple.com/documentation/appkit/nswindow) supplies the native ordering/focus APIs. Verify the closed-all-windows menu-only case on minimum macOS; do not capture the only usable routing closure in a view that disappears on close.

Commands are **Window → Library (Command-L)** and **Window → Recorder (Shift-Command-L)**. Library's neutral toolbar **Recorder** uses exactly the same coordinator route. Existing overflow menu items can expose these destinations; its existing button and the popover body remain unchanged. Returning to Recorder focuses the real window without replacing Library content, creating a recorder duplicate, resetting a query or altering capture. Closing/reopening either window retains app-owned session state and Library query state.

**File/overflow → Name Current Recording…** opens one separately owned, key-capable standard NSPanel for the active session; **Rename Last Recording…** opens that panel for the latest completed UUID. Resolve/capture the target UUID at invocation, not again when Submit happens, so a later take cannot be renamed accidentally. No automatic name panel opens on Stop. The single reusable panel is modeless in both active-draft and completed-file modes, does not attach a sheet over or resize the recorder, and does not take focus until explicitly invoked. Its SwiftUI editor shares the app-owned draft controller with Library's active-take editor; it owns neither capture nor a second independent draft. Focus/revision ownership prevents late updates from an inactive editor replacing newer input. Post-recording rename from the card menu uses this same standalone modeless NSPanel and naming service; neither window receives a naming sheet. Reopening the same UUID/mode focuses the existing panel. A command for another UUID/mode brings the existing editor forward to finish/cancel before reuse, without silent retargeting. While the panel owns active draft editing, Library shows its accepted-name summary and Edit in Naming Panel action; two simultaneous editors never own composition. User-visible rename/save errors belong to Library or the naming panel; an existing recorder error mechanism may report actual capture/storage failures without adding new recorder UI.

**Command-R**, if exposed as Library's record/stop action, is window-scoped and dispatches to the same session coordinator. It is disabled while search, filename editing or another text editor owns focus, and while IME marked text is active; no global event monitor intercepts it and no shortcut changes are added to the recorder/popover. Return/Space/Escape retain text-editor semantics. Record/Stop remains reachable through the unchanged Recorder window and existing capture commands. Before a Stop from any surface, sample the shared editor's latest valid non-composing text; active composition is never forcibly committed—retain the last valid draft and explain the result in Library/panel.

## Filename contract

The editor says **Recording name** and displays a separate, noneditable extension. During recording it lives in Library's active-take area and the explicitly opened separate naming panel. Post-recording editing opens from the gallery card menu or File/overflow **Rename Last Recording…**; there is no new recorder save-confirmation action or inline recorder field. Existing title stays visible until commit succeeds. Keyboard Return commits, Escape cancels the current edit; field editing consumes these keys before any recording/playback shortcut. Clicking Stop anywhere first accepts the latest valid, non-composing editor value from shared draft state, then freezes it. Invalid or still-composing text never prevents Stop: preserve the last valid draft (or generated name) and show the validation message in Library/panel's result area.

| Case | Required behavior |
| --- | --- |
| Empty/whitespace-only during recording | Clear custom draft and use the generated default. Never interrupt recording. |
| Empty/whitespace-only post-recording | Inline “Enter a name.” Save disabled; Escape restores existing name. |
| Surrounding whitespace | Trim on commit; preview the resulting name before filesystem mutation. Preserve internal whitespace. |
| Unicode | Preserve accents, non-Latin scripts, emoji and grapheme clusters. Canonicalize to NFC for the product's proposed filename; do not transliterate. Test composed/decomposed names against real case-sensitive and case-insensitive volumes. |
| Unsafe path input | Reject slash, colon, NUL, newline and control characters; reject `.`/`..`, leading dot and trailing dot. Do not interpret URLs, tilde, separators or traversal. This is a deliberate app naming policy, not a claim that every rejected character is invalid on every filesystem. |
| Extension | A matching trailing `.wav`/`.m4a`/`.flac` pasted into the field is stripped once, case-insensitively, and the fixed extension is shown separately. A different recognized audio extension is rejected with “The format stays WAV” (actual format substituted). Other internal periods are retained. No rename changes encoding or appends a double matching extension. |
| Length | Proposed product cap: 200 UTF-8 bytes for the full final filename, including extension and any suffix. This is a conservative app cap, not a universal volume limit. Measure bytes after normalization, never `String.count`; reject overlong values without silently truncating. Revalidate actual destination errors. |
| Existing destination | Never overwrite. For finalization of a draft, choose `Name (1).wav`, `Name (2).wav`, etc., using an actual non-overwriting move; show the actual saved filename. For an explicit post-recording rename, show the conflict inline and offer the next available name, requiring the user to commit that displayed choice. |
| Destination race | Filesystem refusal is authoritative. If another process claims the proposed filename, retry suffix generation for finalization, or redisplay conflict for post-recording rename. Do not rely on `fileExists` as the safety mechanism. Limit retries to 100; preserve original and offer rename on exhaustion. |
| Case-only change | Treat as a real rename on case-insensitive volumes. Use a journaled, unique same-directory intermediate when the filesystem/API cannot perform it directly; track the intermediate for crash reconciliation. Exact unchanged basename is a no-op. |
| Name too long once suffix added | Preserve the original filename, retain requested draft and show actionable error. Never shorten the user's text silently to make room. |
| Read-only/unmounted/missing destination | Leave file and current title intact; explain the actual failure and allow retry. A naming error never relabels valid recorded audio as lost. |

Pre-record editing can reuse the Library/panel editor later, but is not necessary to satisfy this release and must not introduce a field into the existing recorder. Name field accessibility values must distinguish draft from saved filename without announcing each keystroke.

### File creation and commit

Use a generated path for recording, never the editable name. Harden existing encoder creation to avoid deletion/truncation of files the session has not created. Choose an exclusively created session staging directory in the selected destination with one app-owned output URL; after finalization move the completed file into the parent destination. This accommodates AVFoundation encoders that accept URLs rather than preopened descriptors. Tradeoff: partial recordings live inside a staging directory, so recovery needs an independent location record. Keep staging on the destination volume and do not substitute a global temporary directory. Prototype exclusive directory creation before implementation; a UUID alone is collision-resistant naming, not exclusive creation.

Only remove a staging directory after it is empty and verified to belong to that session. Never clean directories by a filename prefix alone.

**Database-independent session manifest:** Before opening the encoder, atomically write one small versioned JSON file at Application Support/Home Rec/RecordingSessions/<session-UUID>.json. This is a recovery journal of pending sessions, not a second library catalog. It contains session/recording UUID, owned staging path, original/generated parent destination, format, start timestamp, accepted draft revision, actual output location/bookmark when available, and materialization phase. Update only at accepted draft/lifecycle/rename boundaries, not per sample. Read it through an injectable storage seam. The catalog's PendingSession is a query projection; the manifest is the location authority while a session awaits durable catalog registration. Retain the manifest until both the normal destination and catalog row are committed.

If only the catalog fails, capture continues with this independent manifest. On successful encoder finalization, save a manifest intent for a normal generated filename in the **parent save folder**, perform a non-overwriting move, then save its resulting location in the manifest and publish that real path to Library/panel's result state and existing Finder reveal projection. Each collision retry records the newly intended destination before moving. Defer the custom name, retain its draft, and show “Saved as <actual filename>. Library unavailable.” in Library/panel. A database failure alone must never leave a successfully saved recording hidden in staging or require a new recorder banner.

Startup enumerates the bounded pending-manifest directory independently of whether SwiftData opens and independently of the current selected save folder. Reconcile original/intended paths conservatively using the table below, offer format recovery for unfinalized output, and retry registration using the same UUID when the database becomes available. A crash between move and manifest update is covered by the previously saved destination intent; ambiguous identity preserves both files. Pending sessions spanning old save folders therefore remain discoverable without scanning users' disks. Clear the manifest only after catalog commit; duplicate registration is idempotent.

If both catalog-independent manifest creation and its directory are unavailable **before capture**, fail Start with a recoverable storage error before acquiring capture/encoder resources; do not promise recoverable hidden output without a durable pointer. If manifest persistence fails after capture has begun, preserve the existing manifest and audio, finish/release resources, and report the exact retained location with Reveal in Finder. Do not perform an unjournaled move. If the destination volume itself becomes unwritable/unavailable, a file may necessarily remain in staging; present an explicit incomplete-save state and recovery action rather than a successful-save message. This is separate from a database-only outage.

1. Stop capture and drain/finalize encoder via the idempotent session finish operation. Release the writer before touching its filename.
2. If finalization failed, preserve partial output and pending session; expose recovery state, with the draft retained. Do not publish a playable success or apply the draft until format validation/repair succeeds.
3. Resolve the final name in the same selected directory. Persist `PendingFileOperation` with recording ID, operation ID, old/new/intermediate locations, source bookmark and phase before any rename. For the initial move out of staging, also mirror this exact operation ID and intended locations into the independent session manifest before moving; this lets recovery reconcile the custom final name even while the catalog cannot open. If catalog intent cannot save, use the generated-name fallback above and update the manifest intent accordingly. Startup reconciles a matching operation once, never runs the manifest and catalog instructions as competing moves. Explicit save must succeed; auto-save is insufficient.
4. Obtain fresh file ownership/identity and destination checks; perform a non-overwriting move. [Apple's file-management guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/ManagingFIlesandDirectories/ManagingFIlesandDirectories.html) documents synchronous move/copy operations and existing-destination errors. Run slow file work off the UI executor and revalidate the result.
5. For initial materialization, update the independent manifest with the actual location. In one metadata save update actual location/bookmark, title/search key, file revision, completed state and pending-operation state. Notify catalog UI surfaces by recording ID only after this succeeds; Library/panel may report the verified actual file location while registration remains pending. Keep the recorder's existing reveal projection current without adding recorder confirmation UI.
6. Clear the completed operation after durable metadata commit. If the metadata save fails after the move, keep its earlier intent for reconciliation and report “Saved; library update pending.” Never attempt an unverified reverse move or delete either path to make the database appear consistent.

Filesystem mutation and catalog save are **not** one atomic transaction. Process interruption recovery is an MVP requirement; hardware power-loss durability requires separate filesystem testing and must not be promised by calling `save()` alone.

## Catalog contract

Use an explicitly local SwiftData container in Application Support, no CloudKit configuration. Keep schema version 1 and a migration plan from the first release. The scale specification owns the bounded fetch/index prototype; if that proves unsuitable, substitute Core Data behind the same seam before shipping. A JSON array/UserDefaults catalog requires whole-library loading/rewriting; raw SQLite adds avoidable SQL/migration work at this scale.

| Record | Minimum persisted values |
| --- | --- |
| `Recording` | App UUID; canonical UUID string for deterministic query tie-break; actual filename/title; normalized search/sort name; actual URL and bookmark data; recording start date when known; date provenance and imported date; finalized duration when known; format; file byte count when known; source category/display snapshot for new recordings; status; file revision; origin (`createdHere`, `userConfirmedLegacy`). |
| `PendingSession` | Catalog projection of the independent pending-session manifest, keyed by the same UUID. Output URL/staging directory; selected format/destination; start timestamp; accepted draft revision; resource stage; finalization outcome. Rebuildable from the manifest; no competing source of location truth. |
| `PendingFileOperation` | Operation UUID; recording UUID; original/intended/intermediate URLs; original bookmark; operation kind/phase; timestamps and retry/error state. Retained until reconciliation succeeds. |

Unknown legacy capture time/duration/source stay unknown. Keep actual `recordedAt` optional and separate from `inferredSortDate` plus provenance: a legacy file's filesystem creation date may supply the latter when available, but it is never labeled “Recorded” or written into actual capture time. Show “File created <date>” where that estimate is surfaced; imports with neither date sort as unknown under the scale contract. Filesystem modification time and import time never masquerade as capture time. Do not manufacture creator/artist data from the reference card's subtitle. The scale spec defines unknown ordering and derived query keys.

Ordinary bookmark data is a location aid, not a permission grant or permanent identity guarantee. Resolve without UI/mount side effects on a background path, refresh stale bookmark data after successful resolution, and expose unavailable/Locate when resolution fails. Apple explains why [bookmarks are preferred over persisted file-reference URLs](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/AccessingFilesandDirectories/AccessingFilesandDirectories.html). App Sandbox is currently disabled; enabling it later requires a separate security-scoped access migration, not an entitlement casually added with this feature.

During a scan, deduplicate using available volume/file resource identity, with standardized resolved URL fallback when identity is unavailable. Runtime resource IDs are not a promised portable persisted key. App UUID remains the durable UI identity. Do not deduplicate different copies by filename, size or audio hash. Symlinks are skipped during candidate import; no recursive directory/package traversal. Re-importing the same known file is idempotent; hard links on a volume collapse to one entry when identity is available, with one canonical location chosen.

### Startup/reconciliation outcomes

| Observation after interrupted operation | Action |
| --- | --- |
| Original still resolves to the recorded source; intended path absent | Resume verified non-overwriting move or offer retry. |
| Intended/intermediate resolves to the same source via bookmark/verified identity; original absent | Complete or resume metadata update under the original UUID. |
| Both locations exist, identity conflicts, or evidence is ambiguous | Preserve both. Mark reconciliation required, disable mutating commands and ask user to Locate/select the intended recording. Never infer identity from matching filename/size alone. |
| Neither is available | Keep unavailable entry and pending operation; permit Locate. Do not delete audio references or scan the entire disk. |
| Pending session found with unfinalized format | Route through existing format-specific recovery after confirming no active owner; do not rely on `recording_` prefix. |
| Catalog cannot open/migrate | Show library unavailable, retain store and backups for recovery; no silent destructive reset. Independent manifests support generated-name capture/materialization into the normal save folder and later catalog registration. |

When an external rename is successfully resolved, update title and URL under the same UUID and requery if name sorting is active. If a path now points at a different file, do not silently attach it to the old row; require Locate. A user-selected replacement may be linked after format validation and an explicit choice, and should invalidate derived metadata. Removing an unavailable entry, if added later, removes only catalog metadata.

## Playback boundary, if the reference Play control ships

The reference introduces a functional promise: implement real in-app preview or omit the Play button. A decorative button is not an MVP option. Default proposal is one current preview, play/pause, elapsed/duration and Escape/explicit Stop; no playlists, editing, waveform analysis or speed controls. Use a streaming URL-based AVFoundation player and test actual WAV/M4A/FLAC output on macOS 15; do not load multi-hour files into `Data` for playback.

Starting capture stops preview first. Preview is disabled while any session owns capture/output to avoid recording Home Rec's playback through system output or microphone. This is intentional, conservative MVP behavior. A second Play replaces the previous preview; canceled/stale async loads cannot start later. Renaming the playing file stops/releases preview before acquiring its mutation lease; successful rename does not auto-resume. Closing Library stops preview; closing recorder does not stop capture. Missing/corrupt/unsupported files produce a per-item error and preserve the file. This functionality must be explicitly retained or deferred in the consolidated release scope.

## Ready implementation tickets

### HRL-N01 — Establish session ownership and safe finish

**Priority:** P0 prerequisite. **Owner:** native recording engineer. **Dependencies:** none; reuse earlier lifecycle findings. **Scope:** `RecordingController`, `RecordingControlling`, `RecorderViewModel`, state/update/recovery integration and affected encoder creation paths.

**Acceptance:**

- Given a session with an open encoder in starting/recording/stopping/error-cleanup, when retry, recovery, rename or update install is requested, then actions cannot act on that owned file or replace its session resources.
- Given failure at file creation, capture setup/start/stop or encoder finalization, when finish executes, then every acquired resource is released exactly once and any audio-bearing file is preserved with its actual location.
- Given an old session's late callback after a newer session starts, when it arrives, then the new session's writer and state remain unchanged.
- Given two windows request Stop together, then one finish result is published; given normal Quit while recording, then graceful finish is awaited before termination using the same ownership contract.
- Given another file already occupies a prospective output path, then starting a recording never removes or truncates it. Verify all three encoders, including their current removal paths.

**Proof:** fake capture/encoder suspension barriers; failed-start rollback matrix; duplicate stop; exact byte comparison of pre-existing sentinel files; real format smoke tests. Include fatal write-error propagation from the architecture review so a gallery success is not based only on a moving waveform.

### HRL-N02 — Add local catalog and pending-operation persistence

**Priority:** P1 foundation. **Owner:** native data engineer. **Dependencies:** scale repository/query spike and N01 session contract. **Scope:** versioned schema, local container, repository seam and immutable snapshots.

**Acceptance:**

- Given a completed recording, when metadata is durably saved/reopened, then one row retains the same UUID, real location, provenance, format and known metadata.
- Given catalog open/save failure with manifest storage available, then the recorder remains usable, a successfully finalized file is moved to a normal generated filename in the parent save folder, Finder reveal opens that actual file, and Library displays retryable unavailable state without resetting the store.
- Given database failure plus termination before/after fallback move, when the app relaunches even with a different current save folder, then its independent manifest locates the recording or exposes an explicit ambiguous/unavailable state; restoring the catalog inserts the same UUID exactly once.
- Given manifest storage is also unavailable before capture, then Start fails before opening capture/encoder; given manifest failure after capture begins, then the app preserves existing audio/manifest and displays its retained location without an unjournaled move or misleading success.
- Given duplicate event delivery, then catalog write is idempotent under recording UUID; no uniqueness upsert may silently merge different files.
- Given an actor fetch, then no SwiftData model crosses into views and instrumented disk operations do not stall the main thread.
- Given schema upgrade failure, then original store remains recoverable and no silent empty-library replacement occurs.

**Proof:** disk-backed temporary-container relaunch tests (not only in-memory tests), injected save/open failures, duplicate completion events, migration fixtures and query contracts from the scale spec.

### HRL-N03 — Edit the recording name while capturing

**Priority:** P1 user feature. **Owner:** SwiftUI engineer with native reviewer. **Dependencies:** N01, N02, Library active-take/panel design spec. **Scope:** Library active-take editor, separate naming NSPanel, shared draft controller and existing application/overflow menu commands. `RecorderView.swift` and `MenuBarPopoverView.swift` are outside edit scope.

**Acceptance:**

- Given a recording in progress, when a valid name is committed, then only that session's draft changes; its encoder URL/handle, accepted audio count and selected format remain unchanged.
- Given the user types in Library or its separate naming panel and then clicks the unchanged recorder's Stop, when the editor is valid and not composing, then the latest text is frozen for this recording; if invalid/composing, recording still stops with the last valid/default name and an explanation in Library/panel.
- Given blank text during recording, then the generated default is used; given canceled editing, then the last accepted draft returns.
- Given the app closes an editor/window and reopens it during the same session, then its accepted draft is still visible across surfaces; waveform events do not reset cursor/selection.
- Given both Library and the naming panel exist, then one shared draft revision/focus owner prevents late inactive-editor text from overwriting newer text. Name Current Recording targets the active UUID and Rename Last Recording captures the completed UUID at invocation.
- Given before/after images of Recorder and the menu-bar popover in matching states, then layouts, control counts/positions, text, sizes and backgrounds are unchanged; no added naming field, Library button or save result appears there.
- Given interruption after a durably accepted draft, then recovery can restore that draft. Uncommitted text is not claimed to be crash durable.

**Proof:** name-policy table tests, focus/IME composition tests, recording buffer continuity under typing, session revision race tests, VoiceOver and keyboard-only manual pass.

### HRL-N04 — Commit final names and rename saved recordings safely

**Priority:** P1 user feature. **Owner:** native filesystem engineer. **Dependencies:** N01–N03; card and File/overflow naming-panel entry points may be mocked initially. No recorder save-result entry point is introduced.

**Acceptance:**

- Given a draft name and successful finalize, then the file appears with that actual basename and fixed extension; recorder reveal, catalog and selected card all resolve the same UUID/location.
- Given a completed file renamed from Library, then success updates the filesystem and UI together; failure preserves original title/file and editor input for retry.
- Given existing or racing destinations, then the collision behavior table is followed and sentinel bytes are unchanged.
- Given a crash after every journal/move/save boundary, then relaunch resolves the same recording or displays an explicit ambiguous/unavailable state; no duplicate rows, deleted originals or unrelated overwritten files occur.
- Given a same-name or case-only edit, then behavior follows the contract on case-sensitive and case-insensitive volumes.
- Given disk-full, read-only or disconnected volume failures, then audio is preserved and the UI distinguishes naming/catalog failure from recording failure.

**Proof:** table-driven Unicode/extension/UTF-8 boundary tests; temporary-directory collision races; subprocess kill/relaunch tests with deterministic phase barriers; partial-finalize fixture recovery; actual WAV/M4A/FLAC decode before/after rename. Do not claim power-loss recovery from unit tests.

### HRL-N05 — Import legacy candidates and reconcile moved/missing files

**Priority:** P1 for agreed legacy scope; can ship after new-recording gallery if explicitly scoped that way. **Owner:** native data engineer. **Dependencies:** N02/N04 and scale bounded scan contract.

**Acceptance:**

- Given the selected folder, when the user chooses Find existing recordings, then a cancelable, nonrecursive scan previews plausible supported regular files with the full legacy naming pattern and parseable format; adding them requires explicit selection/confirmation.
- Given a same-prefix unrelated file, malformed file, symlink or directory, then no automatic ownership claim, repair or deletion occurs. Parseability alone never proves origin.
- Given duplicate imports, then available file identity prevents duplicate rows; distinct copies remain distinct.
- Given a moved file whose bookmark resolves, then location/title updates under the same UUID; otherwise a retained unavailable card offers Locate, and an unrelated replacement at the same path is not silently accepted.
- Given save-location preference changes, then new output uses the new resolved directory and existing catalog rows remain accessible at their stored locations.
- Given an old/custom-name pending session, then recovery uses persisted identity and fresh ownership checks rather than a filename-prefix filter.

**Proof:** mixed-content directory fixture, idempotent repeated import, symlink/hard-link/copy cases, external move/delete/replace, stale bookmark, unmounted volume and canceled-scan tests. No entire-home-directory fixtures or user recordings required.

### HRL-N06 — Wire shared windows and safe single-item preview

**Priority:** P1 shared navigation; preview follows included release scope. **Owner:** SwiftUI/AppKit engineer. **Dependencies:** N01/N02, gallery/card design and query view model. **Scope:** app-level scene composition/window coordinator, Library, separate naming panel and existing menus; recorder/popover view files remain unchanged.

**Acceptance:**

- Given recorder/menu bar/Library are open, then they reference one recording session and one catalog. Window → Library/Command-L repeatedly focuses one actual Library window; Window → Recorder/Shift-Command-L and Library's Recorder toolbar action focus one actual recorder window.
- Given either target window is minimized, closed or absent while only the menu bar remains, then its route restores/recreates the correct uniquely identified scene and focuses it without title/frontmost guesses, duplicates or a content-mode swap. Simultaneous show requests coalesce.
- Given Library navigation, naming or Stop occurs, then both existing recorder and menu-popover visuals remain exactly unchanged; no new fields/buttons/result UI or altered view files are required. Returning to Recorder preserves Library query/selection and the same live session.
- Given active capture, then all preview actions explain unavailability; given preview is playing and Record is pressed, then preview stops before capture begins.
- Given rapid Play A → Play B → Stop with asynchronous loading, then no stale completion starts A or B after Stop.
- Given rename of current preview, then player releases the file before mutation and remains stopped afterwards.
- Given missing/corrupt output, then playback fails visibly without affecting recording readiness or touching file bytes.
- Given Return/Space/Escape while editing a filename, then editor semantics win and playback/capture is not accidentally toggled.
- Given Command-R while Library's grid/toolbar owns focus, then an eligible action routes to the shared session; given any text field or IME composition owns focus, then it cannot start/stop recording or force text composition to commit.

**Proof:** coordinator tests for repeated/minimized/closed/absent-window routing and menu-only reopening; same-session identity assertions; matched recorder/popover visual regression evidence and unchanged view-file checks; keyboard/IME/VoiceOver pass; playback transport mock with canceled/stale loads and real-format playback matrix. Test CPU/memory on a long recording without eager audio reads.

## Delivery boundaries

Ship N01 lifecycle safety before or alongside gallery mutation capabilities. Merge small PRs: ownership/creation safeguards; persistence + query proof; draft editor; rename journal; legacy/recovery integration; shared Library/playback. Separate acceptance fixtures from user content. Keep local filenames, folder paths, bookmarks and source app names out of public diagnostics/telemetry. No new network permissions, uploads, signing changes or release credentials are required for this feature.

This plan defines tests to implement; it does not claim those tests, performance measurements or migrations have already passed.

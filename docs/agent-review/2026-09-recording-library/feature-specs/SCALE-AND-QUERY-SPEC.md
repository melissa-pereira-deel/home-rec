# Recording library: query, loading, and scale specification

Status: proposed implementation specification, 5 September 2026. This is design and code research; no performance benchmarks or application changes were executed for this document. All budgets below are provisional targets to validate, not measured results. The parent ticket pack assigns canonical HRL ticket identifiers.

## Recommendation

Ship a local metadata catalog behind an actor-isolated repository, a SwiftUI `LazyVGrid`, and **60-record pages with quiet Previous / Next controls**. Prefetch at most one adjacent page after the current page is interactive. Generate decorative card artwork from the recording UUID; browsing requires no audio decode, waveform extraction, or cover-art lookup.

Choose SwiftData as the initial store candidate for this macOS 15+ application, with a short indexed-query and isolation spike before committing the schema. Use explicit bounded fetches and immutable `Sendable` row snapshots, rather than a view-level query returning the entire catalog. Preserve a repository boundary so a demonstrated SwiftData limitation can justify Core Data without changing UI contracts. Audio stays in its existing user-selected location; the local catalog stores metadata and references, never the audio bytes.

Pagination is a deliberate MVP tradeoff: fixed memory, simple keyboard navigation, predictable position restoration, and fewer correctness cases during file changes. It introduces a click after 60 cards and does not offer a continuous scrollbar for the entire archive. Lazy view construction, bounded metadata fetching, and bounded media work are three separate requirements; implementing one does not implement the others.

## What exists today

- `RecorderViewModel.swift` exposes `lastRecordingURL`, set during recording start. This is not a completed-recording catalog and must not be used as proof that a playable file has finalized.
- `RecordingController.swift` chooses the output URL and timestamp filename; the recording lifecycle is the reliable source for adding new catalog rows after finalization.
- `SaveLocationProviding.swift` persists a plain selected path and falls back to Desktop. The app is not sandboxed today. The gallery must index the actual output destination, including fallback destinations, rather than assuming all files remain in the current preference folder.
- `RecoveryScanner.swift` synchronously enumerates immediate entries in the selected save directory on the main actor, then checks filename prefixes and recovery headers. It is a recovery implementation, not a scalable library implementation. A `recording_` prefix or valid header does not establish ownership of an arbitrary legacy file.
- The Xcode project specifies macOS 15, Swift language mode 5, and default MainActor isolation. Explicit concurrency boundaries must be verified with the actual compiler settings; adding `async` alone does not move filesystem or database work off the main actor.

These observations come from the local `home-rec/HomeRec/HomeRec` sources and `HomeRec.xcodeproj/project.pbxproj`. The native architecture specification owns file identity, naming, durable pending-session records, and rename recovery.

## Alternatives and tradeoffs

| Decision | Strength | Cost / limit | Proposed use |
|---|---|---|---|
| In-memory array / JSON catalog | Small prototype; no persistence framework | Whole-catalog reads, rewrites and sorts; awkward durable updates and migrations | Test fake only |
| SwiftData repository | Apple framework already available on minimum OS; typed schema; index declarations | Predicate expressibility and store behavior require real macOS 15 validation; framework-managed SQL | Default, gated by spike |
| Core Data repository | Mature background contexts, fetch limits, migrations and fetch tooling | More explicit schema/context work; same care needed with collation and search | Fallback if concrete SwiftData gate fails |
| Direct SQLite | Explicit queries, explain plans, specialized search design | More schema/migration/binding and concurrency ownership; capability/build choices for optional search extensions | Reconsider for measured large-search needs |
| `Grid` with all records | Simplest layout | Constructs all children; wrong default for an archive | Tiny previews only |
| `LazyVGrid` with 60 records | Native SwiftUI craft, constrained layout workload | Does not promise reusable cells or full archive virtualization | MVP |
| `NSCollectionView` bridge | Reusable items, explicit layouts and prefetch hooks | SwiftUI/AppKit hosting, focus, accessibility and diff synchronization complexity | Only after measured need or required continuous browsing |
| Offset pages | Easy arbitrary page-number jumps | Deep offsets may discard many rows; inserts can shift boundaries | Reject for normal browse; allowed in isolated comparison benchmark |
| Bidirectional keyset pages | Bounded result materialization; deterministic next/previous boundaries | No cheap jump to arbitrary numbered page; cursor invalidation required | MVP |
| Accumulating “Load more” | Familiar progressive exploration | Data grows with traversal even with lazy cards | Reject as an unbounded implementation |
| Windowed continuous grid | Continuous browsing with bounded page cache | Correct bidirectional anchors, placeholders, variable columns, focus and mutation handling are additional product work | Later enhancement, not assumed free |

Apple documents lazy-grid creation on demand, `FetchDescriptor` limits, and reusable collection-view items; those APIs support the choices, but do not guarantee this application's target timings. SwiftData's 2024 index additions cover individual and compound keys. [LazyVGrid](https://developer.apple.com/documentation/swiftui/lazyvgrid), [FetchDescriptor limits and offsets](https://developer.apple.com/documentation/swiftdata/fetchdescriptor/fetchoffset), [NSCollectionView](https://developer.apple.com/documentation/appkit/nscollectionview), [SwiftData updates](https://developer.apple.com/documentation/updates/swiftdata).

## MVP query contract

`LibraryQuery` contains a normalized search string, `format = all | wav | m4a | flac`, and `sort = newest | oldest | nameAscending | nameDescending`. Default is All formats, Newest, empty search. Search text is session-only; remember sort and format locally. “Clear filters” clears search and restores All; it leaves the selected sort unchanged. This avoids resetting an unrelated ordering preference.

### Search

Search the **complete user-visible filename stem**, excluding the final format extension; do not search directory paths, source applications, transcripts, or file content. A stem that contains dots keeps those dots. Trim leading/trailing query whitespace; preserve interior whitespace. Match one literal substring, not tokens, regular expressions, wildcards, or fuzzy similarity. Empty query matches all rows. `%`, `_`, `*`, and quotes are ordinary characters; implementations using SQL must bind and escape appropriately rather than interpolate.

Define a versioned `nameKeyV1`: canonical Unicode composition, Foundation case-insensitive and diacritic-insensitive folding with an explicit `en_US_POSIX` locale, then canonical composition. Apply the same function to stored stems and search input. Persist both original stem and the folded key; never change the actual filename to accomplish search. Test composed/decomposed `Café`, `CAFÉ`, emoji, Turkish dotted/dotless I, and non-Latin examples against the same function. Do not promise language-specific transliteration. A future normalization change requires rebuilding derived keys and invalidating cursors.

Debounce ordinary typing by **200 ms**, with an injected clock in tests. Submit/Return flushes the debounce. Query changes cancel prefetch and advance the request generation immediately. Keep existing cards visible with a subtle busy state; publish the replacement page only if it belongs to the latest generation. Announce the updated page once, not on each keystroke.

### Sorting and unknown values

All sort keys are persisted scalar values usable by the store, not per-row filesystem calls or ad hoc Swift sorting after fetching a subset.

| UI sort | Ordered keys |
|---|---|
| Newest | `dateUnknown ASC`, `recordedAtSort DESC`, `idKey ASC` |
| Oldest | `dateUnknown ASC`, `recordedAtSort ASC`, `idKey ASC` |
| Name A–Z | `nameKeyV1 ASC`, `idKey ASC` |
| Name Z–A | `nameKeyV1 DESC`, `idKey ASC` |

`idKey` is the stable lowercase canonical UUID string, compared with the same persistent-store ordering in both sort descriptors and cursor predicates. Names use the store's deterministic ordering of the folded key. This is lexical ordering: “Take 10” comes before “Take 2” in A–Z. It does not claim Finder's locale-aware natural ordering. Natural sorting can be revisited through a versioned persisted sort key after localized UX research; sorting each fetched page with `localizedStandardCompare` would break global order and cursors.

For new recordings, `recordedAt` is the capture-start instant recorded by the app, unaffected by later rename or file modification. For explicitly imported legacy files, store a provenance label for filesystem creation date when available; if unavailable, retain an unknown date. Do not substitute import time and call it recording time. `dateUnknown` is 0/1; unknown rows use a fixed nonoptional `recordedAtSort` sentinel and appear last in both date directions, with UUID ordering within that group. The displayed date is “Date unavailable” for unknown rows; inferred legacy dates are identified in details.

Persist timestamps as absolute instants and display them in the user's current time zone. Time-zone changes must not alter sort order. There are no MVP date filters. If added later, use calendar-derived half-open local intervals `[startOfDay, startOfNextDay)` converted to instants, including DST days rather than assuming 24 hours.

Format is the validated file format known at finalization/import, with a canonical stored value. Missing or unreadable files retain their last known format and remain visible in All and that format's filter; availability is a badge, not a silent filter. Unknown formats, if present from migration or failed metadata checks, match All only and display “Unknown format.” Duration/size are optional cached metadata, shown as an em dash while unknown; neither is a sort or filter in MVP. Interrupted/unfinalized sessions belong in recovery UI until playable, as defined in the native specification.

### Index feasibility

Candidate compound indexes are `(dateUnknown, recordedAtSort, idKey)`, `(nameKeyV1, idKey)`, and, only if measured useful, their format-prefixed counterparts. Validate actual plans/store diagnostics and timings for both date directions, since mixed ascending/descending keys may require extra sorting; an index declaration is not proof of an optimal plan. Keep `id` unique, using app identity rather than URL as the primary key.

An ordinary B-tree **does not make arbitrary substring matching efficient**. `contains` on the normalized name may scan many catalog keys, especially for no-match queries; `fetchLimit = 61` bounds returned rows, not examined rows or elapsed time. Evaluate 100k-row worst-case search before claiming scale. If search misses its budget, compare a separate locally rebuildable n-gram index with verified substring results, a backend with suitable tested search support, and a deliberate product change to prefix search. Token full-text search is not a drop-in substitute for substring semantics. Do not silently change matching to pass a benchmark.

## Page protocol, consistency, and focus

Repository contract: `page(query, boundary?, direction, limit: 60, generation) -> {rows, previousCursor?, nextCursor?, revision}`. Return at most 60 immutable display rows; fetch 61 to discover another page. Cursors contain the query fingerprint, normalization/schema version, catalog ordering revision, and complete boundary tuple. They are process-local opaque values, never a URL or an authorization capability.

For Newest, the next-page predicate follows the actual lexicographic order: an unknown-group value after the boundary, or equal group with earlier date, or equal group/date with a greater UUID. Reverse the predicate and sort traversal for Previous, then reverse the small returned batch into display order. Generalize through explicit tested per-sort predicates; do not assume all tuple fields reverse together. Strict inequalities plus the UUID tie-break prevent repeating tied rows. First/last boundaries determine navigation, so no growing stack of all visited page rows is required.

Only one foreground fetch and one lower-priority prefetch may be in flight. Deduplicate identical query/boundary requests. Retain current 60 and at most one adjacent 60-card snapshot; a transient 61-row fetch is allowed. Bookmarks and large metadata must not be copied into display snapshots. One selected record and one player state may live outside the page cache. A page replacement does not duplicate UUIDs; assert uniqueness in debug builds and report a repository contract failure rather than silently masking a cursor bug.

Swift task cancellation is cooperative and may not interrupt a synchronous store fetch already underway. Always check generation, query fingerprint, and catalog revision again before publishing. Do not launch an unlimited detached task for every character. Short serialized queries are a capture-reliability requirement: priority cannot preempt a long synchronous database operation already on the actor. The store spike must include worst-case no-match search while lifecycle metadata writes arrive. If needed, separate read and write execution through the repository with tested merge/revision semantics.

Committed inserts, removals, name changes, dates, or format changes advance the ordering revision and invalidate affected cursors/prefetch. Playback position and availability-badge-only changes do not. Visible row values may update immediately by UUID, while an order-changing external update offers a quiet **“Library changed — Refresh”** action instead of reordering under a pointer or moving focus. Next/Previous on stale data first performs a refresh; it must not continue with an old cursor. A local Rename commits and then refreshes around the renamed UUID if it still matches, announcing when search criteria now exclude it. These are revision-consistent pages, not a claim of an archive-wide database snapshot held throughout a browsing session.

For refresh, save the top visible UUID and focused UUID. If the anchor still matches, use its current sort tuple to fetch a bounded page beginning at that anchor; a refreshed page need not preserve the earlier ordinal page number. If it disappeared or no longer matches, fetch at the former sort boundary and focus the nearest surviving card; if no later records exist, fetch a preceding bounded page. Return to first page on an intentional search/sort/filter change, preserve focus in its control, and announce results. Page navigation moves to the top of the new page and announces it; a keyboard user keeps focus on the pagination control until moving into the grid. Resizing preserves current UUID selection and anchor. Do not present a full-archive scrollbar or exact page count that the model does not provide.

## Filesystem and media workload

First page reads the catalog immediately. It never waits for a directory sweep, global availability check, duration probe, or rebuild. Track new recordings from lifecycle events, and verify file reachability when the user plays, renames, or reveals one. A visible-page availability refresh checks known URLs in a bounded worker queue, showing cached state first. Use at most **two** simultaneous file metadata requests; close all acquired file/security resources when an operation finishes.

Legacy discovery is an explicit action against a user-selected folder. Enumerate only immediate regular files, skipping hidden entries, symlink traversal, packages and subdirectories. Stream enumeration instead of building an entire directory array. Validate candidates outside the main actor and preview them for confirmation: recognizable filenames and headers alone do not prove app ownership. The native spec owns accepted-candidate deduplication and durable import.

Use scan batches of 100 candidates and persist an enumeration checkpoint/report between batches; do not retain every URL in memory. A resumable scan may re-enumerate the approved directory and deduplicate by identity rather than pretending directory enumeration order is stable. Stop automatic progress at **10,000 entries or 5 seconds of active scan work**, whichever comes first, with visible partial results and an explicit Continue. Limits are tunable provisional budgets, not an assertion that a folder can always be scanned within five seconds. Pause discovery/header enrichment during active recording; a completed record's catalog commit remains allowed.

MVP does not require a persistent folder watcher. On app activation, refresh only current page file states and pending operations, coalescing activations within 2 seconds. Manual Refresh reconciles known visible records first; a separate explicit rescan discovers legacy candidates. When future FSEvents support is introduced, watch only approved roots, coalesce bursts, and treat events as invalidations. Dropped events/root changes demand reconciliation of the watched scope; they never authorize expanding scope to the user's home directory. Since the catalog scope is nonrecursive, a conservative rescan means all allowed immediate entries and known referenced files in that root. Moved/unavailable volumes retain catalog rows; no automatic deletion. Apple's event guidance emphasizes that events can be coalesced or dropped and that a root may move. [FSEvents handling](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/UsingtheFSEventsFramework/UsingtheFSEventsFramework.html).

MVP artwork is a small deterministic gradient recipe derived from UUID and a versioned palette. It is decorative, not an audio fingerprint; rename keeps its identity. There is no thumbnail disk cache. If waveform artwork is added later, generate it asynchronously into a bounded summary after capture, cache by recording ID plus content revision, and cancel work outside the prefetch window. Never read an entire multi-hour file into `Data` or `[Float]`. The player must stream/decode the selected file with bounded buffers; choosing a new file cancels the old preparation. Benchmark real multi-hour media separately from synthetic catalog rows.

No gallery DB query, file enumeration, `stat`, logging of names, artwork computation, or sorting belongs on capture sample callbacks or the writer's serial queue. UI page publication belongs on MainActor; database/scan work must be demonstrably off it. Suspend prefetch and optional enrichment when recording is active. If necessary, foreground browsing remains available without speculative work. Local performance diagnostics record durations/counts/operation classes, not names, paths, or audio contents; there is no telemetry upload.

## Measurement and release gates

Create deterministic fixtures for **1,000, 10,000, and 100,000 metadata rows**. Include repeated dates, identical folded names, numeric suffixes, long Unicode names, format skew (95% WAV), sparse format matches, unknown dates/metadata, 10% unavailable paths, and no-match/very-common search terms. Provide repeatable mutation streams of inserts, rename-across-boundary, availability changes, and external deletion. These catalogs are synthetic metadata datasets, not evidence of real-file decode performance.

Use a declared reference Mac (proposed baseline: Apple Silicon M1 / 8 GB, 60 Hz, local SSD, minimum supported macOS 15) and a supported Intel Mac when available. Record exact OS/build, compiler, thermal/power state, Release configuration and fixture seed. Avoid network volume timings masquerading as SSD results. Warm runs and fresh-process runs are separate; “fresh process” does not mean a fully cold OS disk cache. Establish current recorder-only timing/error baselines before adding library work.

| Metric | Provisional target / criterion |
|---|---|
| First 60 cards, warm catalog, 1k/10k/100k | p95 ≤ 200 ms / 250 ms / 350 ms from open action to interactive cards |
| First 60, fresh process, already populated catalog | p95 ≤ 500 ms / 600 ms / 800 ms, reported separately from whole-app launch |
| Next/previous page query, no search | p95 ≤ 100 ms at all three sizes, including deep traversal |
| Search replacement after 200 ms debounce | p95 ≤ 150 ms at 1k/10k and ≤ 300 ms at 100k; disclose debounce separately |
| Card grid interaction at 60 Hz | p95 frame interval ≤ 16.7 ms; <1% frames above 33.3 ms in prescribed scrolling/resizing trace |
| Library-added main-thread stalls | No individual synchronous DB/scan/decode block; investigate any gallery-attributable stall > 50 ms |
| Library incremental resident memory | ≤ 50 MB steady state over recorder-only baseline, ≤ 80 MB transient, after traversing 200 pages |
| Memory trend | No monotonic growth > 5 MB between settled traversal loops 2 and 5 |
| Capture coexistence | Zero new dropped/failed writes or discontinuities vs deterministic fixture baseline; callback p99 increase ≤ 10% and no new deadline misses |
| Stop/finalization coexistence | Capture finalization p95 increase ≤ 50 ms versus baseline; UI distinguishes finalized audio from pending catalog save |
| Selected long-file playback | No whole-file allocation; player incremental memory ≤ 32 MB and stable when choosing 2-, 6-, and 12-hour fixtures |

Frame intervals include idle/system effects; collect a reproducible active trace and inspect Instruments hitches rather than accepting a percentile alone. For capture correctness, use a known continuous input fixture with sample-count/timestamp verification and writer-queue backlog instrumentation; then confirm real ScreenCaptureKit and microphone recording manually. Include a 30-minute simultaneous recording/query/resize run, minimum-OS run, and disconnected external-volume behavior. Measure file-availability work under slow I/O separately; a slow volume may exceed a request budget but must not hang the main actor or block capture.

At least 30 samples per query/open scenario, with raw results and p50/p95; run repeated scroll traces. Report sample count and variance. CI can enforce deterministic page/cursor invariants and memory cardinality on every PR; reserve noisy timing gates for a controlled runner or documented local release run. No threshold is a guarantee before the measurements exist.

**Decision gates:** If 60 simple procedural cards miss frame/memory budgets after profiling and fixing avoidable state invalidations, prototype `NSCollectionView` against the identical fixture before migrating. If searchable 100k rows miss latency/capture coexistence gates, do not label the catalog scalable to 100k; implement the measured query/index remedy or explicitly ship a documented tested range. Do not select a framework based only on record count. If user research shows frequent page navigation interrupts finding recordings, evaluate a bidirectional windowed grid with at most five 60-record pages and a reusable collection view; ship only after scroll-anchor, keyboard, VoiceOver and mutation tests pass. Exact counts or jump-to-date are separate measured query features.

## Ticket-ready work packages

### Scale A — Prove the catalog and actor query boundary

**Priority:** prerequisite for catalog/schema implementation. **Dependencies:** native identity/schema proposal; finalized minimum OS and compiler configuration.

Deliver an isolated SwiftData prototype, deterministic metadata generator, and short ADR comparing measured results with the alternatives above. Explicitly configure local storage; add no CloudKit capabilities. Return display DTOs from the repository, never actor-confined models to SwiftUI. Use explicit saves for durable operations; the native spec defines crash reconciliation.

**Acceptance criteria:**

1. All four ordered queries, both cursor directions, optional format and literal substring search run against 1k/10k/100k fixtures on macOS 15 APIs.
2. Trace proves fetch/materialization and scanning do not execute on MainActor or capture/writer queues under the project's default isolation setting.
3. Index definitions and observed query behavior are recorded, including no-match substring and mixed-direction date sorts; findings distinguish targets from measurements.
4. A concurrent finalization metadata write is not starved by repeated searches. If it is, document and validate read/write scheduling before feature implementation proceeds.
5. Repository fake supports deterministic failures, delayed out-of-order responses, revisions and cancellation; no production schema is committed merely because the prototype compiles.

**Tests/evidence:** controlled benchmark artifact, OS/compiler matrix, actor/isolation compile checks, bounded-row count assertions, no names/paths in timing logs.

### Scale B — Implement precise search, sort and bidirectional pages

**Priority:** MVP. **Dependencies:** Scale A; native persistent recording catalog; finalized card snapshot contract.

**Acceptance criteria:**

1. Query semantics exactly match this document, including literal punctuation, extension exclusion, folded Unicode matching, lexical name order and unknown dates last in both directions.
2. At an unchanged revision, traversing every page forward and backward produces the same globally sorted IDs once each, for every sort/filter combination; ties spanning a 60-record boundary do not skip or duplicate.
3. Fetch results are at most 60 rows; 61-row lookahead determines navigation; no full-catalog fetch, eager count or whole-directory read is required to show the first page.
4. Search uses an injected 200 ms debounce; superseded results/prefetch never publish. A query failure retains existing cards and provides retry without an incorrect empty-library state.
5. Current plus one adjacent cached page is the steady-state maximum. Generation/query/revision mismatch discards stale rows and cursors.

**Tests:** property-based seeded cursor traversal; normalization fixture table; 0/1/59/60/61/120/121 rows; unknown-date ties; wildcard characters; reverse paging; delayed stale responses; error/retry; shape/cardinality assertions.

### Scale C — Integrate page navigation and stable updates

**Priority:** MVP. **Dependencies:** Scale B; UX gallery/card and native rename implementation.

**Acceptance criteria:**

1. Previous/Next controls reflect boundaries, expose accessible labels, retain keyboard focus after activation, and show a nonblocking busy state when needed.
2. New recordings, external renames and removals invalidate ordering cursors; no stale continuation yields silent gaps or duplicate IDs. Refresh restores an existing anchor or the nearest surviving boundary.
3. Rename retains identity/artwork and refreshes around the renamed item when it matches; a rename that leaves the current search announces why the item disappeared.
4. Search/filter/sort changes reset to the first page while preserving focus in the initiating control; window resize does not lose selected UUID or player state.
5. Opening the gallery has zero audio reads for decorative artwork, zero complete-folder scans, and no dependency on checking every file's existence.

**Tests:** keyboard and VoiceOver walkthrough; UI tests for stale Next, rapid queries, anchor deletion, cross-boundary rename, resize, and finalization during a filtered page; card rendering trace.

### Scale D — Bound legacy discovery and availability refresh

**Priority:** MVP only if legacy import ships; current-page reachability checks are MVP regardless. **Dependencies:** native import/identity/recovery specifications; Scale B.

**Acceptance criteria:**

1. Only an explicitly selected folder's immediate regular files are discovery candidates; symlinks, hidden entries, packages and descendants are excluded; candidate recognition never silently proves ownership.
2. A 100k-entry fixture folder does not allocate its entire entry list; batches are 100, automatic progress pauses at the stated work/entry limits, and Continue safely deduplicates re-enumerated candidates.
3. Recording pauses optional scanning/enrichment; gallery first-page display continues from the catalog. At most two metadata requests are in flight.
4. Unavailable volumes retain catalog entries with honest cached/pending/unavailable state. No rescan deletes files or entries automatically.
5. App activation refreshes only known current-page references and pending operations, with burst coalescing; no watcher is required for MVP correctness.

**Tests:** injected enumerator/read failures; entry and time budgets with a fake clock; malicious/deceptive paths and symlink fixtures; cancel/resume/idempotency; volume disappearance; capture-priority scheduling.

### Scale E — Validate archive size and capture coexistence

**Priority:** release gate, not an optional post-launch task. **Dependencies:** Scale B/C; player implementation; native naming/finalization changes; D if included.

**Acceptance criteria:**

1. Publish raw and summarized results for the declared 1k/10k/100k workloads, long-file media fixtures, query mutations, and 30-minute capture coexistence run, with machine/build/OS details.
2. Every provisional threshold is met or changed through a documented product/engineering decision before making a support claim. Failed 100k search cannot be hidden by testing only empty search.
3. Recorded media remains continuous under the deterministic input check and real-device smoke test; existing recording tests remain green.
4. Repeated paging demonstrates bounded row cache and stable memory. Minimum OS and Intel coverage limitations are stated explicitly.
5. Performance logs contain operational metrics only, and reproducible scripts use generated fixtures rather than personal recordings.

**Tests/evidence:** Instruments Time Profiler/Allocations/hitch traces, signposts for query-to-visible and finalization, decoder memory trace, deterministic audio continuity assertions, regression results, and a reviewed release checklist entry.

## Additional implementation references

SwiftData's model actor serializes model access; that is a concurrency tool, not permission to move actor-bound models between contexts. The view environment's context is main-actor bound, so explicit repository isolation matters here. [ModelActor](https://developer.apple.com/documentation/swiftdata/modelactor), [ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext).

Core Data's fetch batching can still evaluate the entire request and retain all matching identities; it is not synonymous with a bounded page. [NSFetchRequest.fetchBatchSize](https://developer.apple.com/documentation/coredata/nsfetchrequest/fetchbatchsize).

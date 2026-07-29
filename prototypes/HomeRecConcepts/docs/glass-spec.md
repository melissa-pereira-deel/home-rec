# Home Rec — Glass Redesign Spec

**Status:** concept spec for product scoping · **Prototype:** `prototypes/HomeRecConcepts` (`swift run -c release`, press `4`)
**Scope basis:** everything the shipping app implements today (states, errors, guardrails, onboarding) plus one new surface (the library) and one policy decision (concurrency). Copy shown in screens is **verbatim from shipping** unless marked *proposed*.

Regenerate every screen: `HRC_SNAPSHOT=<dir> swift run -c release` (subset: `HRC_SNAPSHOT_FILTER=spec-05`).

---

## 1. The twelve screens

### 1.1 Idle, honest data
![idle honest](img/spec-01-idle-honest.png)
Idle face with **real filenames** (`recording_2026-07-…`, the shipping scheme) — the poetic names elsewhere in this spec are a naming *proposal* (see backlog: rename-on-save). Timer dwells on the last take's duration rather than snapping to 0:00.0. Settings icon = `slider.horizontal.3`, ≥28pt target.

### 1.2 Transport truthfulness
| starting | recording | stopping | saved |
|---|---|---|---|
| ![](img/spec-02a-starting.png) | ![](img/spec-02b-recording.png) | ![](img/spec-02c-stopping.png) | ![](img/spec-02d-saved.png) |

The pill's label/fill/enablement always tell the truth: `record` → disabled `arming…` (250ms) → `stop` → disabled `saving…` (450ms, waveform freezes dimmed — never a dead flat line) → **`record`, immediately re-armable** while the saved beat plays out. Shipping today shows a contradictory "Start recording" label during starting/stopping; the redesign eliminates every dead-or-lying frame of the primary control.

### 1.3 Recording follows you into the library
![recbar](img/spec-03-recbar-library.png)
The **RecordingBar**: pulsing dot, wall-clock timer, live trace, stop pill — pinned above the library whenever transport is active. Invariant for every current and future screen: **a capture is never invisible and never more than one click from stop.**

### 1.4 Playback while recording (policy C)
![monitoring](img/spec-04-monitoring.png)
Playback during a capture is **allowed** and labeled `monitoring · not recorded`, with a one-time dismissible explainer. See §3 for the policy decision and its engineering requirement.

### 1.5 Permission states
| notDetermined | denied | opening settings | translocated |
|---|---|---|---|
| ![](img/spec-05a-perm-nd.png) | ![](img/spec-05b-perm-denied.png) | ![](img/spec-05c-perm-opening.png) | ![](img/spec-05d-transloc.png) |

The pill carries the corrective action: `allow audio capture` (nd) / `grant permission` (denied) → simulated `openSystemSettings()`, with a **disabled `opening settings…`** state during the ~2s registration probe (shipping publishes `isOpeningSystemSettings` but no view reads it — this binds it, flagged as a behavior improvement). Grant lands → face flips live, exactly like shipping's `PermissionGrantWatcher`. Translocation is terminal: message verbatim, pill becomes `reveal in finder`.

### 1.6 Errors + recovery
| startFailed | diskFull refusal | saveLocation fallback (recording continues) | streamFailed |
|---|---|---|---|
| ![](img/spec-06a-err-startfailed.png) | ![](img/spec-06b-err-diskfull.png) | ![](img/spec-06c-err-savefallback.png) | ![](img/spec-06d-err-streamfailed.png) |

The notice row takes the shelf's slot (priority: error > long-recording > translocation); messages and recovery labels are **verbatim** `RecorderError` copy (`Try again` / `Open settings` / `Choose folder…`). Key mirrored behaviors: disk-full is a **refusal on press** (never a broken start); save-location fallback is **non-blocking — the recording continues** while the notice shows. Unlike shipping's window-only alerts, these rows render on the panel itself, so a menu-bar-only user finally sees them (see §5).

### 1.7 Long recording
![longrec](img/spec-07-longrec.png)
Timer at `1:12:03` proves the hour layout. The shipping "Still recording" alert becomes an amber notice row: same copy, same `Keep recording` / `Stop` choices, same once-per-recording latch. (Prototype threshold compressed to 20s for demoability; shipping is 30 min.)

### 1.8 Library at scale
![50 items](img/spec-08-library-50-scrolled.png)
50 takes, scrolled mid-list: durations to hours (`2:08:09`), deep version stacks (`v4`), spec lines truncate rather than wrap. Scroll stays smooth (LazyVStack; no hitches observed at full-speed scroll in release).

### 1.9 Empty vs filter-empty
| true empty | filter empty |
|---|---|
| ![](img/spec-09a-empty.png) | ![](img/spec-09b-filter-empty.png) |

Two different states, two different sentences: `nothing here yet. / record something.` vs `no m4a takes.` + a **show all** reset. Filtering away the selected/playing row auto-deselects and stops playback — no invisible player.

### 1.10 Player across durations
| 8s take (tenths) | 1:12:03, clamp left | 1:12:03, clamp right |
|---|---|---|
| ![](img/spec-10a-player-8s.png) | ![](img/spec-10b-player-hour-clamp-left.png) | ![](img/spec-10c-player-hour-clamp-right.png) |

Timecode format is pinned per recording (`0:07.4` / `2:34` / `1:12:03`) so the chip never changes width mid-scrub. The capsule clamps inside bounds; the **stem stays on the true playhead**. Scrubbing suspends the playback task (drag never fights the playhead) and resumes on release.

### 1.11 Row actions *(proposed — no shipping equivalent)*
| inline rename | delete confirm |
|---|---|
| ![](img/spec-11a-rename.png) | ![](img/spec-11b-delete-confirm.png) |

Context menu: Reveal in Finder / Rename / Delete / Copy path. Rename is an inline TextField (return commits, esc cancels); delete is an inline row morph (`delete "…"? · delete / keep`) — no system alert. Shipping has only reveal-in-Finder; rename/delete are new scope for product to weigh.

### 1.12 Onboarding, reskinned
| needs permission | ready |
|---|---|
| ![](img/spec-12a-onboarding-nd.png) | ![](img/spec-12b-onboarding-granted.png) |

See §4 — flow, logic, and strings are untouched.

---

## 2. Interaction table — transport × screen × action

Actions: **R** record · **S** stop · **P** play take · **F** change format · **Q** quit. ✓ permitted · ✕ refused (no-op) · ⏳ deferred/disabled · ⚠ guarded.

| Transport ↓ / Screen → | Recorder face | Library | Onboarding overlay |
|---|---|---|---|
| disarmed (nd/denied) | R→routes to permission ✕ · P n/a · F ✓ · Q ✓ | P ✓ · F ✓ · Q ✓ | primary = settings flow |
| translocated | R ✕ (reveal) · F ✓ · Q ✓ | P ✓ · Q ✓ | (shipping shows sheet regardless — see §5 note) |
| idle | R ✓ · P n/a · F ✓ · Q ✓ | R ✓ (⌘R) · P ✓ · F ✓ · Q ✓ | primary = Get started |
| starting | R ⏳ · S ⏳ · F ⏳ | S ⏳ (bar disabled "arming…") | — |
| recording | S ✓ · F ⏳ (locked, tooltip) · Q ⚠ (see §5 ⌘Q guard) | S ✓ (bar) · **P ✓ monitoring** · F ⏳ · Q ⚠ | — |
| stopping | ⏳ ("saving…") | bar "saving…" ⏳ | — |
| saved | **R ✓ immediately** · P ✓ | R ✓ · P ✓ | — |

Rules the table encodes:
1. Recording visible + stoppable from every screen (RecordingBar).
2. `.saved` is never a dead state.
3. Format locked only while transport ≠ idle-ish (shipping behavior, now disabled-with-reason instead of hidden).
4. Playback never blocked by recording (§3), never invisible (auto-deselect on filter), never fighting a scrub.

---

## 3. Concurrency policy C — playback during capture

**Decision: allow, and make the guarantee visible.**

- The shipping capture already excludes the app's own audio from the stream: `config.excludesCurrentProcessAudio = true` (`HomeRec/ScreenCaptureAudioManager.swift:93`). In-app playback is provably not in the file.
- That invariant is currently **invisible and untested**. Policy C is unshippable without: **(a)** a regression test asserting `excludesCurrentProcessAudio` on the built `SCStreamConfiguration`; **(b)** playback implemented in-process (AVAudioPlayer/AVAudioEngine — never a helper process, which would defeat the exclusion).
- UX surfaces: `monitoring · not recorded` chip whenever recording+playing; one-time dismissible explainer on first concurrent playback.
- Speaker-bleed caveat for the spec: the exclusion is at the *tap*, not the room — a user recording via a microphone-equipped setup could still acoustically re-capture speaker output. Home Rec records system audio only, so this doesn't apply today; revisit if mic capture (BL-130) ships.
- Rejected alternatives: (A) hard mutual exclusion — kills the browsing concept, punishes users for a solved problem; (B) allow silently — leaves a load-bearing invariant invisible and unexplained when users hear their old take while recording.

---

## 4. Onboarding mapping — cosmetic only

Contract: **zero copy changes, zero flow changes, zero logic changes.** The conditional CTA slot keys off `permissionStatus == .granted` exactly as `OnboardingView.swift` does; a grant landing mid-sheet flips it live via the existing `@Published` chain.

| Shipping element (OnboardingView.swift) | Glass treatment |
|---|---|
| `.sheet` 420×440 over RecorderView | glass card 420×440 over the face (prototype uses an in-window overlay for capture; **shipping keeps `.sheet`**) |
| 72pt `NSApp.applicationIconImage` | 72pt icon, same slot (prototype substitutes a placeholder glyph — real app keeps the app icon) |
| "Welcome to Home Rec" — Archivo 22 semibold | same string, same font, white |
| Blurb — Inter-Regular 13 secondary | same string, Inter 13, white 60% |
| 3 bullets (`lock.shield`/`eye.slash`/`list.bullet`) | same strings incl. curly-quoted navigation hint, same symbols, dimmed glass register |
| Slot A: green "You're ready to record" / "Open System Settings" button | same branch; settings button = neutral glass pill, **disabled "opening settings…" while `isOpeningSystemSettings`** (⚠ behavior improvement: shipping publishes this but no view binds it) |
| "Get started"/"Done", `.keyboardShortcut(.defaultAction)` | brand-red flat pill, same labels, same shortcut, same `completeOnboarding()` persistence |

Known shipping quirk preserved (not fixed here): a translocated first run still presents onboarding over the blocked window, and its "Open System Settings" routes to the install notice (does nothing visible). Flagged for product; fixing it is a flow change.

---

## 5. Engineering notes for the real implementation

- **Timer** — derive elapsed from `clock.now - startTime` (shipping already does; the prototype initially accumulated tick intervals and drifted — do not regress this). Fix `formattedDuration`'s missing hour rollover (`90:00` today → `1:30:00`).
- **State fan-out** — the prototype's single `ObservableObject` invalidates whole faces 30×/s while recording. Real implementation: migrate to `@Observable` (per-property tracking) or split hot values (`level`, `samples`, `progress`) out of the main model.
- **Window/popover asymmetries to retire** — today: alerts + onboarding + long-rec warning are window-only; the popover's inline error keys off `state == .error` so `saveLocationUnavailable` and permission-denied never show there, and its error never dismisses. The notice-row pattern (§1.6) is surface-agnostic — apply it to both.
- **Menu-bar icon states** *(SPEC-ONLY — not prototyped)* — today only idle/recording. Spec: idle `waveform` template; recording `record.circle.fill` red; **error** `exclamationmark.triangle` amber; **blocked/ungranted** dimmed template. A recording app must never look healthy in the menu bar while broken.
- **Popover** *(SPEC-ONLY — not prototyped)* — ~280pt Glass-register popover: RecordingBar-equivalent status row, record/stop pill, last-take row, error notice row (same component), and a "open library" link. Full parity of notices with the window is the requirement; layout is a follow-up design task.
- **⌘Q guard** *(SPEC-ONLY — not prototyped)* — quitting mid-recording today silently relies on crash-safety (and loses FLAC takes entirely). Spec: intercept termination while recording → "Stop and save / Keep recording / Discard" with `.terminateLater` while finalizing.
- **FLAC fragility** — an interrupted FLAC is unplayable (CHANGELOG-documented, user-invisible). Surface it: one-line caption in the format picker, and it strengthens the ⌘Q guard case.
- **Format lock** — keep capture-at-start semantics; present the lock as disabled-with-tooltip (prototype behavior), not hidden-then-flickering-back during `.stopping`.
- **`.recovering` state** — unreachable in shipping; either wire it or delete it before building UI for it.

---

## 6. Backlog for product scoping

| Pri | Item | Notes |
|---|---|---|
| **P0** | Record pill state machine (starting/stopping/saved truthfulness) | Fixes shipping's contradictory button; small, high-trust |
| **P0** | Notice rows for errors/warnings on both surfaces | Retires window-only alerts; verbatim copy exists |
| **P0** | Permission states on the primary control + opening-settings disable | Binds existing unread `isOpeningSystemSettings` |
| **P0** | Onboarding reskin | Cosmetic only, §4 contract |
| **P1** | Library (rows, player, filters, empty states) | The new surface; scaffold spec'd in §1.8–1.10 |
| **P1** | RecordingBar + policy C (chip, explainer, exclusion test) | §3 prerequisites |
| **P1** | Settings popover (format lock + save location) | Replaces the two shelf menus |
| **P1** | Menu-bar icon states + Glass popover | Spec-only today; design follow-up |
| **P1** | ⌘Q guard | Small; pairs with FLAC fragility note |
| **P2** | Row actions (rename/delete/copy path) + rename-on-save naming | New scope; delete needs undo decision |
| **P2** | Version stacks | Implies a versioning model that doesn't exist yet — needs product definition |
| **P2** | Hour rollover in `formattedDuration`, `@Observable` migration | Engineering hygiene |

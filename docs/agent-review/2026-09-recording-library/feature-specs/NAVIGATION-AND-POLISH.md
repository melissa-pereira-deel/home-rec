> **Presentation superseded:** the current request uses one fixed 450 × 450 content window with subpages. Read [SINGLE-WINDOW-DESIGN.md](SINGLE-WINDOW-DESIGN.md) and [SINGLE-WINDOW-NATIVE.md](SINGLE-WINDOW-NATIVE.md). Earlier separate-window, naming-panel and large-gallery geometry below is historical; storage, file-safety and applicable visual-token contracts remain in force.

# Companion Library — navigation and polish contract

Status: selected Concept A; revised after the user's instruction to keep the recorder unchanged. This document specifies future behavior and acceptance evidence. It is not evidence of implemented native navigation.

The Library should feel like another room in Home Rec: entering it preserves the recorder and returning brings the user to the same familiar window, in the same place, with the same recording state.

## Non-negotiable surface boundary

`RecorderView` and `MenuBarPopoverView` keep their exact current visual composition. No recording-name field, Library button, new saved-result notice, extra transport, changed padding, new footer, altered typography, color correction, or material replacement is added inside either view. Preserve the 450 × 450 recorder, existing header/status/waveform/action geometry, current dynamic state behavior, and current popover dimensions and appearance. Existing source wins over stale descriptive documentation.

New capabilities use already-present menu entry points, the new Library window, and separate native panels. Adding menu items inside the existing overflow is allowed; adding or moving the overflow control itself is not. The existing Show Window menu command remains functional and can keep its familiar label while resolving the same Recorder destination as the new native Window command.

One Library window and the actual existing Recorder window are coordinated by stable scene/window identity. Never identify Recorder as merely the first titled/visible window after Library exists. Never fake a Recorder destination with a duplicate screenshot/native clone, hide one window to imitate in-window navigation, resize the recorder to library dimensions, or reposition either window into a preset layout.

## Navigation matrix

| Source | Action | Destination and focus | Preservation |
|---|---|---|---|
| Recorder is key | Window → Library, Command-L | Existing Library becomes key/front; create only if absent; first open focuses query field, subsequent opens restore valid previous focus | Recorder stays open, unmoved and unchanged; session continues |
| Menu-bar popover overflow | Library | Dismiss transient menu/popover, activate Home Rec in response to this explicit action, show/reuse Library | No popover redesign; recorder is not opened incidentally |
| Status-item right/control-click | Library in same configured overflow | Same Library route as popover overflow | One menu action implementation and one target identity |
| Library | Toolbar Recorder; Window → Recorder, Shift-Command-L | Bring forward actual Recorder; reopen if closed or restore if minimized | Leave Library open with search, sort, format, page anchor, scroll and valid selection/focus recorded |
| File menu / overflow while recording | Name Current Recording… | Show/reuse separate native Current Take naming panel bound to current session UUID; focus name field | Do not open Library or modify a recording face merely to type a name |
| Library active-take strip | Edit Recording name | Edit same session-owned draft in place; no new window | Existing query/page is unchanged; preview stays unavailable |
| Library strip while naming panel owns editor | Edit in Naming Panel | Bring existing naming panel forward and restore caret/composition | Do not create a second independent editor |
| File menu / overflow after a completed recording exists | Rename Last Recording… | Separate native rename panel bound to latest completed UUID resolved when invoked | No new recorder saved-state control; existing prior file can be renamed even if another take is active, provided it is not owned by that take |
| Library card menu / Return on selected card | Rename… | Same reusable standalone native naming panel, fixed selected UUID and rename mode | Preserve underlying query/page/selection; keep Recorder accessible; stop that item's preview before mutation |
| Library or already-open naming panel with completed result | Show in Library | Explicitly show/reuse Library, resolve named UUID, set newest-first and clear conflicting filters/search only as required to reveal it | This deliberate reveal is the only save-related action allowed to change browsing context or front Library |
| Existing overflow Show Window | Show Window | Existing Recorder route | Keep familiar behavior and label; no first-window/title heuristic |
| Any existing window | Native close / Command-W | Close only the key window/presentation under normal native rules | Capture ownership is unaffected; closing Library stops its preview, not recording |

Menu state is evaluated when opened and again when action executes. Name Current Recording… is available only while its draft can be edited. Starting/finalizing states show an accurate disabled reason rather than opening an editor for a different session. Rename Last Recording… targets the last completed file, not a mutable global “current URL”. If no eligible completed file exists, disable the command. Once a panel is open, new takes or newly saved files do not silently retarget it.

The Library toolbar label is **Recorder**, paired with an appropriate neutral window symbol and native tooltip “Show Recorder (⇧⌘L)”. Window menu destinations are **Library** and **Recorder**. These are destination commands rather than a browser Back stack. Do not add a back chevron that suggests a navigation history the app does not maintain.

## Activation, windows and return behavior

Showing a destination is idempotent: reuse its window, deminiaturize if necessary, and make it key in response to explicit user intent. Normal native window behavior determines the appropriate Space/display; never manually teleport an existing window to the current pointer. Preserve independent user placement. When a display is disconnected, constrain a restored frame to an available visible display so the window is recoverable; this is the only automatic repositioning exception.

When Home Rec is inactive, menu-bar activation routes may activate it because the user explicitly selected a destination. Recording completion, catalog refresh, rename completion, scan progress, error retry, and metadata enrichment do not activate Home Rec or front a window. Already-visible surfaces may update in place. An inaccessible original window is not a reason to open an unrelated new one.

Closing Library preserves its query and anchor within the session and stops local preview. Reopening first resolves that anchor against current data. If it is stale, restore the nearest valid context using scale-spec rules and a quiet refreshed-state message; never show false ordinal page positions. Reopening does not auto-start preview. Closing Recorder retains existing app/menu-bar lifecycle behavior and does not implicitly close Library. Do not change Dock click or launch behavior as an incidental part of this feature.

There is no automatic navigation on successful save. A user searching older takes stays in that search. The completed take is registered and a refresh opportunity may appear in Library without reordering under the pointer. Show in Library is an explicit exception: its visible control changes and newly focused item explain the transition. If the named file is unavailable, show its unavailable record or a truthful resolution message; never substitute the nearest filename.

## Naming panels and session continuity

The active-take strip is Library-owned, above its query/grid. It uses 14 pt content inset, 12 pt gaps, a 30 pt minimum field, and a reserved 36 pt two-line feedback area. It contains status, a modest `.timerCompact` elapsed value and Recording name with protected extension. It has no waveform or second Stop control. The Library's Recorder route is always reachable, including during text editing.

The standalone Current Take panel is approximately 400 pt wide with 28 pt inner padding and natural height. It uses the same actual `GlassWindowGround` root treatment and approved token values as the Library chrome, following [COLOR-TOKENS.md](COLOR-TOKENS.md). Text/input backing remains readable under the approved material. No custom modal overlay appears over Recorder; no attached sheet changes its visible composition. The panel is a normal-level native utility panel with an accessible title, close behavior and Done action. It does not float over other applications.

The Library strip and panel share one session editor coordinator, accepted revision and capture-session ID. Only the focused editing surface owns transient text/composition. Opening the panel transfers the editor there, and the Library strip becomes a read-only accepted-name summary plus Edit in Naming Panel until the panel closes. This prevents two simultaneously editable copies from overwriting each other's composition while preserving a single session draft. There is exactly one reusable standalone native naming panel for all entry points and modes, never two concurrently editable panels. Reopening the same UUID/mode focuses it. A command for another UUID/mode does not silently replace an unsubmitted or pending edit: bring the existing panel forward so the user can finish/cancel it before reuse.

| Naming event | Required outcome |
|---|---|
| Valid text accepted | Publish accepted session revision; keep actual open file URL unchanged; helper says Applied when this recording is saved |
| Empty accepted draft | Clear custom name to generated default |
| Invalid text | Keep transient editor content/error visible; last accepted valid/default remains intact |
| Done during capture | Accept latest valid committed text and close; invalid text remains with explanation; never stop recording |
| Escape/native close during capture | End editing, retain last accepted valid revision, discard only unaccepted invalid text/composition; close panel without changing capture |
| Recorder Stop / existing shortcut while naming | Coordinator freezes latest valid committed text for that session; active IME composition is not forcibly committed and uses prior accepted revision; no naming dialog delays Stop |
| Capture begins finalizing | Strip/panel becomes read-only Saving…; outstanding revisions cannot mutate a different/new session |
| Finalization succeeds | An already-open panel shows actual saved filename, Rename… and Show in Library; no panel/window opens automatically; new action uses completed UUID |
| Finalization fails | Existing panel/Library shows truthful failure and preserved actual file location from native spec; never claims the draft was applied |
| Another take begins | Existing panel remains bound to original session/result; explicit Name Current Recording brings the existing editor forward for finish/cancel before the single panel can target the current session |
| App relaunch after interruption | Restore only durable accepted revisions and actual recovery state from manifest; do not invent lost transient edits or auto-front naming |

Post-save rename uses the same reusable standalone native `NSPanel` for Library card, File menu and overflow entry points, with a fixed recording UUID and editor mode. This modeless presentation keeps Recorder accessible throughout and introduces no Library/Recorder sheet. Completed-file mode has Cancel/Rename, protected extension, and basename selection; active-draft mode has Done. While committing, Renaming… and disabled repeat-submit remain visible; asynchronous completion cannot auto-front an inactive app. A pending rename stays bound to its original UUID even if another recording finishes and “last recording” changes. No second concurrently editable naming panel may open.

## Keyboard and focus contract

Use native menu commands and first-responder resolution, not a global keyboard monitor. Command-L and Shift-Command-L are application Window menu commands available when native modal rules permit. The naming panel is modeless, so it does not block the Recorder route; unrelated native alerts retain normal platform behavior. Do not force an IME composition to end merely to route a command. No shortcut is installed system-wide.

Existing Command-R and Command-O behavior in Recorder remains unchanged. New Library actions must not hijack these through a global handler. If Library offers a recording command, it is disabled while any name/search editor or IME owns editing focus and still routes to the one session owner; this does not change Recorder's existing command behavior. Command-F focuses Library search only when Library is key and the naming panel does not own input. Space, Return and Escape belong to focused text fields and composition before grid preview/rename handlers. No keystroke typed in a name can start playback.

Ordinary Library↔Recorder navigation restores the most recent valid first responder for each window. First-time Library open may focus search; subsequent opens do not repeatedly select-all or clear it. Grid selection is retained by UUID, not index. Return from a card rename restores that card/action if still present; if it no longer matches, announce the outcome and focus a stable query/result region with Show in Library available. Pagination buttons retain focus after activation and announce once; paging has no implicit grid shortcut in MVP. Do not repair focus by fronting a window after the user has switched apps.

VoiceOver names all three destinations distinctly: Recorder, Library, and Name Current Recording/Rename Recording. Announce completed save/rename or page context only on the active relevant surface, never every timer tick. Show in Library announces filename and context change once. Meaningful controls remain visible without hover. Native titlebar controls retain native roles, order, and shortcuts.

## Shared craft without redesigning Recorder

Use one authority, [COLOR-TOKENS.md](COLOR-TOKENS.md) and [color-tokens.json](color-tokens.json). New Library and naming surfaces reuse existing root material, semantic text/surface tokens, Inter UI roles, data roles and neutral controls. Approved card art adds modest recognition; it is decorative and stable by UUID. No new accent system, differently colored toolbar family, per-card blur, fake waveform, or independent recorder reskin is introduced.

Card names use `.bodyEmphasized` Inter 13 medium; Library heading uses `.title` Inter 14 medium. Approved artwork radius is 22 pt as a Library-only media exception; ordinary card/state plates use 12 pt and add no padded tile shell. Card-state fill is exactly one of rest, white 6% hover, white 8% pressed, or white 12% selected, with **selected > pressed > hover > rest** precedence. Selected has a separate 1 pt neutral boundary; keyboard focus has a 2 pt ring with 2 pt dark gap. Metadata promotes to `textSecondary` on any non-rest overlay. These card overlays never cover artwork or the independently styled 32 pt neutral play button.

The current Recorder's actual source values—including status/timer typography and red behavior—are preserved even where upstream docs recommend different roles. This is a compatibility boundary, not an invitation to repair old token drift in this feature. Increasing craft in Library means precise alignment, consistent semantic tokens, readable muted metadata, reliable focus, and well-placed feedback rather than retroactively changing the recording face.

At default 860 × 640 Library size use four approximately 190.5 pt artwork columns with 22 pt outer insets and 18 pt gaps. At minimum 640 × 480 use three approximately 186.7 pt columns at standard text size. Increased text enlarges cells and reduces columns. Active-take strip adds height above scroll content and never overlaps query controls. New panel and Library respect Increase Contrast, Reduce Transparency, Reduce Motion and 2× text independently of the frozen Recorder baseline. There are no movement/scale transitions between windows; native activation is enough.

## Acceptance and review evidence

| ID | Acceptance | Evidence |
|---|---|---|
| NAV-01 Frozen recording surfaces | Recorder/popover contain no added/removed/reflowed controls or changed typography/colors/materials; Recorder stays 450 × 450; baseline versus feature output has zero unmasked pixel changes in deterministic fixtures | Same OS/fonts/desktop/theme; injected clock/waveform/status fixtures for idle/recording/saved/permission/error; compare source-region geometry and full native render; source diff review |
| NAV-02 Exact window reuse | From every matrix entry, repeated commands address one Library and the actual Recorder; neither is hidden, morphed, resized, or repositioned by navigation | Window identity assertions and multi-window interaction recording, including minimized/closed/restored/display-disconnected states |
| NAV-03 Browse continuity | Search/sort/filter/page anchor/scroll/selection survive Recorder return; valid first responder restores; ordinary save does not reorder, clear filters, or front Library | Search older take, navigate twice, finish capture while app inactive; assert no activation/context change |
| NAV-04 Explicit reveal | Show in Library reveals exact UUID, visibly changes only required query context, and focuses/announces target once; unavailable result never substitutes another take | Conflicting filter, renamed target, missing target, stale anchor fixtures |
| NAV-05 Naming independence | During capture, strip/panel edits leave recording faces unchanged; one editor revision/IME owner; Done/close/reopen retains accepted draft; Stop snapshots valid text without forcing composition | Keyboard and IME fixture; panel↔Library transfer; externally triggered Stop and new-session race |
| NAV-06 Correct latest rename | File/overflow resolves last completed UUID at invocation; new completion does not retarget open panel; no extra recorder saved-confirmation UI | Two recording completions while first rename remains open; actual filesystem outcome comparison |
| NAV-07 No focus theft | No completion/refresh/retry activates app; Return/Space/Escape respect editor; Library search command cannot steal naming focus; modal rules block incompatible window changes | Switch to another app during rename/save; run keyboard/FKA/VoiceOver task; capture single announcements |
| NAV-08 One visual language | Library chrome/naming panel use approved current root treatment/tokens; scrolling card field has stable contrast; no per-card blur; render actual Recorder in reviews, never approximate it | Native material/color specimens, contrast measurements, token fixture comparison; offscreen snapshot limitations labeled |

“Zero diff” means controlled fixtures, not comparing two uncontrolled live captures with different elapsed time or desktop content. If a renderer cannot sample behind-window glass offscreen, identify that limitation and compare geometry/type/control pixels under the same fixed backing, then perform a real desktop capture to validate material parity. Never treat a flat-ground offscreen snapshot as proof of unchanged production glass.

The interactive browser board is a review aid for Library navigation and card states. It must label simulated IO/playback and any source snapshot's material limitation. It cannot substitute for native focus, multiwindow identity, IME, VoiceOver, pixel parity, or capture safety evidence.

→ Handoff:

- **Product Manager** — preserve selected A and the exact recording-surface boundary in all ticket acceptance; archive B rather than keeping two implementations active.
- **Software Architect** — own stable window routing, shared draft revision/focus coordinator, capture-safe Stop handoff, and completed-record UUID resolution.
- **Product UI/UX Designer** — verify actual source snapshots, matrix routes, navigation focus and single-token material treatment on native macOS.

Constraints across handoffs: unchanged Recorder/popover; Library and separate panels own new UI; existing menu entry points; no auto-front or window morphing; preserve browse context; one session/editor authority; truthful file outcomes; native focus/IME and assistive behavior.

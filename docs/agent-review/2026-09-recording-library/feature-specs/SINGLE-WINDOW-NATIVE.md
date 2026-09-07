# One fixed window: native route contract

Status: latest proposed implementation contract after the user's direction to use **one window at the current recorder size**, with Recorder, Library and Name subpages. This supersedes earlier two-window coordination, resizable Library and detached naming-panel presentation requirements. It does not replace filename, catalog, recovery, collision, privacy or query contracts. No native application code changed for this document.

## Source facts and size interpretation

| Verified source, relative to `home-rec/` | Required implication |
| --- | --- |
| `HomeRec/HomeRec/RecorderView.swift:193` | The view has a **450 × 450 point content frame**. Preserve this exact recorder composition; do not add header/navigation controls or name fields to it. |
| `HomeRec/HomeRec/HomeRecApp.swift:77`, `:84` | `.windowResizability(.contentSize)` and `.windowStyle(.hiddenTitleBar)` determine current native hosting. The requirement is the current window's physical appearance with this content sizing, not an invented 450-pixel outer `NSWindow.frame`. |
| `HomeRec/HomeRec/HomeRecApp.swift:17`, `:37`, `:59` | Recorder model lives at App scope; current scene is a WindowGroup, and menu controller initialization is attached to recorder appearance. Preserve the shared model and move app/menu initialization away from page mounting. |
| `HomeRec/HomeRec/DesignSystem/Adapters/GlassWindowGround.swift:36`, `:65`, `:90` | Current ground samples the desktop using AppKit, marks the window nonopaque and permits background dragging. Keep one existing root treatment outside page replacement; do not follow stale flat-background prose in the App file. |
| `HomeRec/HomeRec/RecorderView.swift:40`; `RecorderViewModel.swift:62` | The SettingsPopover control is hidden during starting/recording/stopping. It cannot be the only Library/name route during a take. |
| `HomeRec/HomeRec/MenuBarPopoverView.swift:25`; `OverflowMenu.swift:358` | Existing popover overflow and its app-action section remain available. Add navigation commands inside these existing menus without changing the visible popover face. |
| `HomeRec/HomeRec/RecorderView.swift:194`, `:207`, `:221`, `:230` | Alerts, long-recording warning, onboarding and appear/disappear hooks are attached to Recorder today. Unmounting it for Library would otherwise lose presentations and falsely report a window close. |
| `HomeRec/HomeRec/RecorderViewModel.swift:625`, `:635` | Visibility counting can trigger a floating install-location notice. Route changes must not decrement physical-window counts. |
| `HomeRec/HomeRec/RecorderView.swift:166`, `:181` | Command-R and Command-O are mounted recorder-button shortcuts. Keeping an invisible recorder alive would risk active invisible controls/shortcuts. |

Apple states that [contentSize](https://developer.apple.com/documentation/swiftui/windowresizability/contentsize) derives both window size bounds from content. Apply an explicit fixed frame to the stable route host, not only to Recorder; `defaultSize` alone is not a fixed-size guarantee. Keep the existing [hiddenTitleBar](https://developer.apple.com/documentation/swiftui/windowstyle/hiddentitlebar) scene style across all routes. Changing styles, toolbar bands or safe-area rules per route risks changing native frame/chrome even if each child says 450 × 450.

## Recommended structure

Use one uniquely identified SwiftUI `Window("Home Rec", id: "home-rec.main")` and one MainActor `MainRouteCoordinator`. Retain the existing App-owned recorder/session services, Library repository/query model and name-draft controller outside route branches. A singleton scene avoids the current WindowGroup's duplicate-window behavior; Apple's [Window](https://developer.apple.com/documentation/swiftui/window) represents a single unique window.

The host selects `recorder`, `library`, or `name(targetID, mode, returnDestination)`, then applies `.frame(width: 450, height: 450)` and the same `GlassWindowGround` background/contrast adaptation. There is no navigation bar, new AppKit toolbar, frame animation, tab bar, sidebar or shared top row inserted above Recorder. Library and Name draw their own in-content navigation rows within their 450-point budget, below the existing traffic-light exclusion region. A simple enum-based route switch is sufficient; an unconstrained NavigationStack is unnecessary and must not introduce automatic toolbar/titlebar changes.

Conditional mounting is acceptable because capture and durable state are not owned by the child view. Apple ties [StateObject](https://developer.apple.com/documentation/swiftui/stateobject) lifetime to its declaring container/identity; do not declare the recorder session, editor authority or catalog anew inside the route switch. Do not keep an opacity-zero Recorder under Library: it can preserve unintended shortcuts, accessibility elements, alerts and waveform invalidations.

Keep one registered NSWindow identity for the host. Explicit menu-bar navigation activates/reopens/deminiaturizes that same window and selects its requested route; if it already exists, page changes never recreate, move or resize it. Repeated requests coalesce. Do not identify the window by title/frontmost guesses. Closing the window ends presentation, not capture; the unchanged menu-bar popover remains usable. Reopen restores the current route/context unless the command explicitly requests Recorder or Library. Existing Show Window reopens the main host at its retained route; View → Recorder deliberately chooses Recorder.

### Necessary nonvisual migration

The requirement freezes **Recorder's visible layout and behavior**, not obsolete view-lifecycle ownership. Move window/menu setup, physical window-presence reporting and application-level presentations to the stable host/coordinator. Preserve identical Recorder content, control geometry, fonts/colors, source settings gating, existing action meanings and material. Limited removal/rewiring of nonvisual `.onAppear`, `.onDisappear`, `.alert` and `.sheet` hooks is necessary; it is not authorization to restyle or reflow the recorder.

Physical visibility and “the recorder currently displays install guidance” become separate facts. When Recorder is visible, retain its exact current inline install/permission guidance. When Library/Name is visible, do not spuriously spawn the legacy floating notice simply because Recorder unmounted. Show required errors once through the host; provide Show Recorder for existing detailed remediation. If the main window is actually closed, preserve existing menu-only notice behavior. Library browsing itself never launches capture permission probes. Existing native system panels/alerts are outside the new subpage count; this feature adds no new library/naming window or panel.

Host alerts retain the same appearance and actions when Recorder is selected, and remain deliverable on Library/Name. A fatal capture failure or long-recording warning must not be lost on navigation. Actual capture state/teardown still follows the prior native spec; page state never determines “safe to quit/update.”

## Entry, return and keyboard behavior

| Action | Same-window result |
| --- | --- |
| View → Library, Command-L; Library in the existing status/popover overflow | Select Library, restore its retained query/page/selection; first entry focuses search. No new control appears on Recorder. |
| View → Recorder, Shift-Command-L; existing overflow Recorder destination if exposed | Select exact Recorder route, restoring a valid recorder focus target. Works throughout capture/teardown and from Name. |
| Library's in-content Back/Recorder control | Return to Recorder, retaining query/page/anchor. This control exists only on Library. |
| File/overflow → Name Current Recording… | Select Name in active-draft mode bound to the current session UUID; capture continues. Disabled only when that session's draft is no longer editable. |
| Library active-take Name action | Select the same Name subpage; avoid squeezing a second inline name field and validation region into the small gallery. Return destination is Library. |
| Library card Rename… / Return on selected card; File/overflow → Rename Last Recording… | Select Name in completed-file mode with UUID resolved at invocation. A new take/completion cannot retarget the edit. |
| Name's in-content Back | Return to its captured origin; if origin is unavailable use Recorder. It does not submit a completed-file rename or stop capture. |
| Name Done while capturing | Accept valid committed draft and return to origin; invalid text remains with feedback. An independent Back/Recorder route remains available even while text is invalid. |
| Name Cancel while renaming a completed file | Discard unsubmitted rename edit and return to origin. No filesystem mutation. |
| Name Rename | Start the existing journaled operation. Show pending state and reject duplicate submits; do not block Back/Recorder while I/O completes. |
| Explicit Show in Library for a completed UUID | Select Library and deliberately reveal that identity using agreed query-reset rules. It is the only completion-related route change. |
| Command-W/native close | Close main window, preserve session and accepted drafts; stop Library preview. Closing is not Back or Stop. |

The main recorder has no overflow of its own: its SettingsPopover is distinct from the status item's always-present OverflowMenu. Do not make Settings persist mid-take, append navigation controls to its hidden shelf, or move the settings icon. During a take, users reach Library through the native application menu/shortcut or existing status-item overflow, and return through Library/Name's in-content controls or View → Recorder. This is the concrete discoverability tradeoff accepted to preserve Recorder's face.

Menu commands use normal first-responder/native modal validation, with no global keyboard hook. Existing Recorder Command-R/O semantics apply only when Recorder is mounted. Library may expose a shared recording command only when no text editor or IME owns input; Name does not install a recording shortcut over its field. Return/Space/Escape go to the focused editor first, then eligible grid actions. Do not add a universal Escape-to-Recorder binding that steals IME cancellation or clears search unexpectedly; visible Back and explicit View → Recorder provide unambiguous navigation.

Before leaving Name, preserve the editor's committed text/selection and accepted session revision separately from IME marked text. Let the native text input system finish/cancel composition under its normal responder behavior; never manually force `unmarkText` merely to navigate, and never persist marked text as an accepted filename. [NSTextInputClient](https://developer.apple.com/documentation/appkit/nstextinputclient) exposes composition state for text-input integration. If Stop is invoked from the existing popover while composition is active, use the last accepted valid draft. Native composition restoration across unmount is not promised. Unsubmitted completed-file text may be restored on return, but cannot rename a file until explicit Rename.

Route changes save focus as a semantic target (search, UUID/card, editor), not a stale NSView pointer. Restore only a still-valid target after mounting; asynchronous I/O does not steal focus or change route. On return to Library, preserve query/page/selection and use the scale spec's nearest-boundary behavior if a mutation invalidated its anchor. Stop preview when leaving Library; returning never auto-resumes it.

## Naming while recording and during pending I/O

One app-owned active-session draft and one bounded current completed-file edit context are enough; do not introduce a general document/tab manager. Name mode uses fixed UUID and an explicit return destination. Stop snapshots the latest valid committed revision or previous accepted/default value, regardless of current route. Finalization changes an already-visible active Name page to a read-only saving/result state; it never pushes another page or retargets a new session.

Crucial change from the old detached panel: **pending Rename must not trap users on the Name page**, because that would hide the only full Recorder surface while capture continues. Back/View → Recorder always works through rename I/O. Operation identity, journal, error/result and draft remain app-owned; returning to Name shows that operation's real state. Completion updates existing state but never returns to Library or Recorder automatically. Cancel before submission discards the edit; cancellation after the non-overwriting move begins is not promised to undo it. Pending UI must distinguish Back from cancellation.

If a command targets another completed recording while an unsubmitted/pending completed edit exists, preserve the existing bounded context and route to it with an explanation until it is finished/canceled; do not silently overwrite edits. Access to Recorder is never subject to that restriction. Active recording's accepted name remains independently retained by its session.

## Fixed-size layout constraints for the prototype

The native host must remain 450 × 450 points of content on every route, including empty/error/loading, IME, active take and increased text. New pages scroll **inside** that frame; error copy/long names cannot grow the NSWindow. Two compact artwork columns are feasible: 450 − 44 inset − 18 gap = 388 points, or 194 points each. The prior 860 × 640/four-column geometry and minimum 640 × 480 are obsolete. Query controls need wrapping/compact rows; active take status and pagination reduce visible grid height, so not every card must fit without vertical scrolling. Page fetch size 60 does not mean 60 visible cards.

Keep Name's Back/Recorder route and submission actions reachable in a fixed header/footer while explanatory/form content scrolls if necessary. On Library, keep Back reachable without scrolling through recordings. Respect traffic lights and existing drag behavior; a dense full-window scroll view must not consume every draggable noninteractive area. Increased text may reduce Library to one column; it may not resize the window or shrink essential text. These are feasibility constraints, not a competing new visual design spec.

## Acceptance contracts and targeted ticket replacements

| Contract | Required evidence |
| --- | --- |
| Single host identity | Repeated Recorder → Library → Name → Back and menu requests leave one main NSWindow; close/reopen and minimized states return that same scene role; no Library/naming panel appears. |
| Fixed size | Measure actual content layout and native outer frame before/after every route/state with the same OS/style; content stays 450 × 450 and outer frame is unchanged. Dragging/zoom cannot change route constraints. |
| Recorder parity | Deterministic idle/recording/saved/permission/error render is pixel/geometry equivalent to baseline; changed code is limited to nonvisual host plumbing where needed. Test actual glass under matched desktops separately from offscreen snapshots. |
| Capture independence | Start, navigate away, type/query, stop from popover and return; one session UUID, uninterrupted accepted audio and correct final file. Repeated page mounting does not restart timers/capture or install observers twice. |
| Hidden-settings entry | During starting/recording/stopping, Settings remains hidden as today, but app menu/status overflow Library and View → Recorder remain available without altering capture settings. |
| Presentation correctness | Navigating away does not increment/decrement physical visible-window count, trigger a spurious floating install notice, lose a long-recording warning or suppress a fatal write error. No capture permission prompt from browsing. |
| Accessible stop access | Name invalid/composing/pending states allow Back/View → Recorder; old Stop stays usable. Pending completed rename cannot trap navigation; its eventual completion preserves current route/focus. |
| Editor truth | Current/completed mode has fixed target UUID; IME text is not accepted prematurely; Back preserves accepted active draft but never commits a completed rename. New completion does not retarget an open editor. |
| Focus and state | Back restores valid search/card focus and query/page/anchor; Return/Space/Escape follow first responder. No hidden recorder keyboard/accessibility targets remain under Library. |
| Playback | Leaving Library stops preview; starting capture stops it first; returning does not auto-start playback. Name/capture routes cannot play an unfinished file. |

Update the canonical tickets as follows:

- **HRL-004 / native N03:** replace active inline field + detached panel with the Name subpage and a Library Name action. Keep all draft, validation, fixed-ID and capture-continuity acceptance.
- **HRL-005 / native N04:** replace standalone rename panel with Name completed mode; explicitly permit Back while a journaled operation runs. Never add recorder saved-state controls.
- **HRL-006 / native N06:** replace two unique windows and focus switching with one route host, fixed 450 content, stable state ownership, host-level presentation migration and menu-only reopening. Move destination commands to **View** to describe subpages; Window menu retains native window duties.
- **HRL-007 / design/navigation/color:** remove default/minimum large Library geometry and extra native titlebar assumptions. Keep agreed tokens/card states and fit two-column or accessible one-column content inside the fixed host.
- **HRL-008 / scale:** retain 60-record bounded query semantics. Preserve a query/page/anchor across page departure and cancel page-view tasks without destroying repository/session state. The original full-frame resizing scenarios become fixed-window text/layout and route-state tests.
- **HRL-010–012:** preview stops on leaving Library; test route teardown, hidden shortcut suppression, no focus theft and exact one-window dimensions. Existing signed-release and audio safety gates remain.

Retire two-window shortcuts described as opening separate destinations, NSPanel/sheet editor modes, simultaneous Library/panel editor-transfer behavior, four-column default screenshots and 640-point minimum-window tests. Do not delete existing file operation journals, session manifests, source gating, player exclusion during recording, or benchmark correctness tests as part of this navigation change.

Main risks are route-mounted alert/lifecycle side effects, accidentally sizing to the outer frame, hiding Stop behind a noncancelable editor, and trying to fit the old large Library layout unchanged. Each has a concrete acceptance contract above; none requires a recording-face redesign.

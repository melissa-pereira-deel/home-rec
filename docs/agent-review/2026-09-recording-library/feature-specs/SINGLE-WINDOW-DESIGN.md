# Home Rec — one fixed window, selected Contact Sheet and artwork studies

Status: Contact Sheet selected by the user; Virgin CD and Color Disc are physical-media artwork variants. This supersedes the separate Library window and detached naming panel proposals. Design exploration only; no native code changes.

One **450 × 450 pt content window** hosts Recorder, Library and Naming subpages. The existing Recorder page keeps its actual visual composition; navigation changes the page inside that window and never its frame. The design problem is to make browsing useful in 450 pt without making a filename or a recording control pay for decorative scale.

## What stays authoritative

The actual [ready Recorder snapshot](recorder-baseline/window-01-ready.png) shows the current brand/header, format and settings placement, centered status and red recording control. It is the visual baseline, not a prompt to redraw a similar-looking recorder. Preserve the source page's current typography, color, layout and state behavior; the snapshot's offscreen flat backing does not certify real behind-window glass. Native chrome and actual root rendering still require native review.

Reuse [COLOR-TOKENS.md](COLOR-TOKENS.md) and [color-tokens.json](color-tokens.json) for **visual values**: semantic text, backgrounds, approved muted artwork, 32 pt neutral preview control, focus and state treatment. Their older separate-window/panel wording is superseded by this document; their colors do not authorize new host windows. Reuse the current root material once outside rapid recording observations, with an opaque Library scrolling content plane where specified. No per-card blur and no second theme.

The existing 450 × 450 Recorder and menu-bar popover acquire no new field, link, Library button, mode switch or naming notice. Recorder entry to Library uses the already-available application/overflow menus and Command-L. The user has authorized subpage navigation; they have not authorized a redesign of the Recorder surface.

Applied lenses: **Legibility Design** makes cover recognition, readable names and truthful metadata fit at the same time; neither columns nor artwork earn priority over identifying a recording. **Coherence Design** keeps the existing recording face intact and makes all new work feel like subordinate pages of the same tool. **macos-design** informed native menu commands, first-responder behavior and minimal navigation. Geometry below is an explicit design calculation, not a measured usability result.

## Shared 450 × 450 frame budget

All dimensions are points at standard text size. The offscreen Recorder baseline excludes physical native chrome; browser measurements certify only the simulated 450 pt content layout. Native traffic-light position, hit areas and safe-area offsets remain a separate real-window QA gate and must not be inferred from that snapshot or web simulation.

| Region | Height | Vertical extent | Contents |
|---|---:|---|---|
| Library header | 52 | 0–52 | Recorder back destination, Library title, compact active-capture status and Name action; native safe-area composition remains QA |
| Query band | 52 | 52–104 | Prominent search and one Sort & filter popup;30 pt controls with 11 pt top/bottom allocation; actual gaps can distribute around existing token values |
| Grid scroll viewport | 306 | 104–410 | Vertically scrolling current data page; no horizontal scroll |
| Footer | 40 | 410–450 | Previous/Next and local page status |
| **Total** | **450** | | Outer frame never changes |

Horizontal budget is `450 − 22 − 22 = 406 pt`. Keep the outer insets at the inherited 22 pt token. Give search the majority of this width and use one clearly labeled **Sort & filter** popup beside it. A working allocation is 262 pt search +12 pt gap +132 pt popup =406 pt; let native localized intrinsic control width redistribute this split rather than clip its label. Inside the popup, two separately labeled native choices, **Sort** and **Format**, expose Newest first/Oldest first/Name A–Z/Name Z–A and All formats/WAV/M 4A/FLAC. Show current choices/checkmarks and a neutral active-filter indicator; accessibility exposes both selected values. This replaces three cramped inline controls without hiding search. Keep labels in Inter 12, not a newly invented tiny role.

The 406 pt grid arithmetic assumes overlay scrollbars. With Always Show Scroll Bars, use the **measured** viewport width after the native scrollbar gutter, not a hardcoded guess. If the gutter is `G`, Cover Gallery art becomes `(406 − G − 18) / 2` and Contact Sheet cells become `(406 − G − 36) / 3`; retain the Contact Sheet's 96 pt art when it still fits. For an illustrative 15 pt gutter, Cover art is 186.5 pt and Contact cells 118⅓ pt. Do not place the scrollbar over a menu/focus target or preserve nominal artwork width by causing horizontal scroll.

The Library header has a neutral Recorder back action, Library title in `.title`, and a compact active-capture status/Name action when applicable. Name during capture explicitly means Name Current Recording and announces that target; after capture, selected-card Rename and File/overflow Rename Last Recording retain explicit targets. Do not silently retarget one action by guessing. These are Library-page controls only. Native chrome-safe positions must be resolved in the actual 450 pt content host; the web header's positions are not physical traffic-light evidence.

Use the footer's left label for “60 shown · More” / “End of results”, never an eagerly computed total. Previous/Next remain on the right. A 160 pt label,12 pt gap,88 pt Previous,12 pt gap and 76 pt Next use 348 pt, leaving 58 pt for flexibility. Active capture's compact status and Name action remain in the Library header, not a new tall strip. No second waveform, inline name field or additional vertical recording region reduces the 306 pt standard viewport. Naming has its own subpage.

## Concept 1 — Cover Gallery (earlier study)

Two large covers preserve the supplied reference's quiet, tactile identity. Names have two readable lines; a recording feels like a distinct item. This is the stronger match for recognizing a small set of recent takes and then using filename search when the library grows.

**Width arithmetic:** `2 × 194 + 18 = 406`. Two 194 × 194 pt covers fit between 22 pt window insets. Artwork radius is the approved 22 pt media exception. Ordinary dark caption/state plates use 12 pt radius, without an extra padded tile shell.

**Standard card height:** `194 cover + 18 cover-to-name gap + 32 two-line name slot + 4 gap + 14 metadata = 262 pt`. The title uses `.bodyEmphasized` Inter 13 medium, with actual measured line metrics allowed to increase the slot instead of clipping glyphs. Duration and a compact date occupy the metadata line, with full date/provenance available in tooltip/VoiceOver. A 28 pt ellipsis hit area sits at the right of the name region; the title reserves 36 pt for it, leaving 158 pt of name width.

The 32 pt neutral play disc overlaps the cover bottom by 6 pt and is inset 6 pt from its right edge. Its bottom ends 6 pt below art, leaving 12 pt clear before the name starts. Opaque light fill and dark symbol remain readable on every approved art variant. No text or focus ring is drawn directly on the gradient.

**Visible content:** one complete row of two cards occupies 262 pt of the 306 pt viewport. An 18 pt row gap leaves 26 pt of the next row visible as a quiet scroll cue: `306 − 262 − 18 = 26`. Do not claim four full cards are visible. A top-row name, date and play action are fully visible together before scrolling.

**Tradeoff.** Low simultaneous item count; more scrolling for visual browsing. In exchange, filenames retain context, dates stay visible, targets are comfortable, and the reference survives at useful scale. The search/query band remains prominent and reduces the need to scroll through a large catalog manually.

## Concept 2 — Contact Sheet (selected layout)

Three smaller cells prioritize comparison and rapid scanning. The center-aligned cover floats above a compact full-width filename and a duration/action row. This is a deliberate density concept, not the large-card layout squeezed into three columns.

**Width arithmetic:** `3 × 123⅓ + 2 × 18 = 406`. Each cell is 123⅓ pt wide, while its artwork is **96 × 96 pt**, centered with 13⅔ pt gutters inside the cell. This keeps a 32 pt play disc manageable and leaves an opaque dark exterior for focus. The artwork remains square with the approved 22 pt radius. Cell/state plate radius remains 12 pt and adds no padded container.

**Standard row height:** `96 art + 8 gap + 18 single-line name + 28 metadata/action row = 150 pt`. Name remains Inter 13 medium and gets the entire 123⅓ pt width; the ellipsis moves to the final row alongside duration. The 32 pt play overlaps the cover bottom by 6 pt and sits 6 pt inside its right edge; the following 8 pt gap leaves only 2 pt before the title slot, so native visual QA must prove the disc cannot touch tall glyphs. If that clearance fails, increase it to 12 pt and accept reduced visible row capacity—never shrink text or the play target to rescue the quota.

**Visible content:** two 150 pt rows with a 6 pt dense vertical gap fit exactly: `150 + 6 + 150 = 306`, yielding six cards at standard text size. This is a tightly specified reference viewport; actual increased line metrics or a taller localization may reduce capacity. Small adjustments should cause scrolling, not clipping. A compact cover of the full cell width (123⅓ pt) would require ~177⅓ pt rows and would **not** show six complete cards in this viewport; that alternative must not be illustrated as if it does.

**Metadata tradeoff.** Duration stays visible. Date/provenance and full filename move to tooltip, VoiceOver description and the Naming page's contextual summary. Single-line names truncate more often. Add no tiny second line simply to recreate missing density. Selection does not disclose a hidden expanded title that moves neighboring cards.

**Tradeoff.** Six visible targets offer a useful contact-sheet impression, but artwork has less identity and filenames require more inspection. The aggressive 6 pt vertical rhythm and reduced metadata fit repeated short take names better than descriptive interview/meeting names. This is a hypothesis to evaluate in native specimens, not a reason to reduce accessibility standards.

## Concept 3 — Virgin CD artwork

This variant keeps the selected Contact Sheet unchanged: three 123⅓ pt tracks, centered 96 pt artwork, 150 pt rows, six visible cards, one-line names and the same metadata/actions. Only the decorative artwork changes. Each recording displays an original frontal clear jewel case containing a pristine silver CD-R with restrained cyan, violet and rainbow diffraction. There is no label, red tape, album text, artist mark or copied packaging detail.

Use [the 512 px transparent UI asset](assets/virgin-cd-thumbnail-v1.png) for the 96 pt card and retain [the 1254 px transparent master](assets/virgin-cd-master-v1.png) as the source artifact. Preserve aspect ratio with contain fitting; never crop the case. The case may cast a subtle neutral shadow on the existing dark surface, but it receives no colored square behind it. The play control remains the existing opaque neutral disc above the lower-right artwork edge.

The image is decorative and hidden from VoiceOver. Recording name, format, duration, availability and preview state continue to define the accessible card. Missing artwork uses the existing unavailable treatment without implying that the audio is missing. Native image decoding should occur off the main actor and reuse one cached decoded asset because the same illustration repeats across cards.

The physical object adds tactility and continuity with recording culture, while repeated identical cases provide less per-record visual differentiation than UUID-selected colors. Validate 96 pt edge definition, play-control separation, selection/focus contrast, Reduce Transparency and Increase Contrast in native specimens before choosing it for production.

## Concept 4 — Color Disc artwork

Color Disc combines Concept 2's per-record muted tile with an isolated silver disc. The selected Contact Sheet geometry remains identical: three 123⅓ pt tracks, 96 pt artwork tiles, 150 pt rows and six complete cards. Inside each tile, render the disc at 80 × 80 pt with 8 pt optical insets. Preserve the 22 pt tile radius, clip the tile background and highlight, and allow the disc shadow to remain soft and neutral.

Use [the 512 px isolated-disc asset](assets/virgin-disc-thumbnail-v1.png) for cards and retain [the 1254 px transparent master](assets/virgin-disc-master-v1.png) as the source artifact. The bitmap contains only the disc. Tile colors remain code-driven from the canonical recording UUID using the existing rose, iris, mist and sand pairs, so a rename, sort, relaunch or page change never changes a recording's color.

A restrained radial highlight gives the tile material depth. Rotate only the disc artwork by a deterministic value between approximately −5° and +5° per UUID; because the disc is circular, this changes the diffraction orientation without disturbing alignment. Hover may lift the disc by 1 pt over 150 ms and slightly brighten it. Press returns it to rest. Reduce Motion removes translation while retaining static UUID rotation. Avoid continuous rotation, shimmer, waveform animation or color changes during playback.

The disc and color are decorative and accessibility-hidden. The card's full accessible name, extension, duration, format, state and actions remain unchanged. Decode and cache one disc image, then composite it over lightweight native gradients; do not create a distinct bitmap for every palette value. This preserves differentiation with minimal memory and asset cost.

## Which to choose

| Decision | Cover Gallery | Contact Sheet |
|---|---|---|
| Standard visible cards | 2 complete + next-row cue | 6 complete only at specified metrics |
| Name | Two lines; ~158 pt usable width beside menu | One line; 123⅓ pt width |
| Metadata visible | Duration + compact date | Duration; date available on inspection |
| Reference fidelity | Strong; cover dominates gently | Moderate; compact centered cover |
| Scan speed hypothesis | Better recognition of distinctive takes | More candidates visible per glance |
| Risk at 450 pt | Extra scrolling | Truncated names and very tight vertical clearance |

**Decision: Contact Sheet.** The user selected the three-column composition and its six-card first view. Cover Gallery remains useful design history, not the implementation default. The open visual decision is whether Contact Sheet ships with muted color, Virgin CD or the hybrid Color Disc treatment. Keep this comparison as a prototype review control only; MVP ships one treatment, without a density or artwork-mode setting.

## Naming as a same-window subpage

Naming replaces Library or Recorder content inside the same fixed 450 × 450 frame. No detached `NSPanel`, new window, attached sheet, drawer overlay or resizing is involved. Navigation state stores the origin page and the exact session/recording UUID. The user returns to that origin, not to whichever recording happened to finish most recently.

**Frame arithmetic:** 52 pt header + 330 pt scrollable form body + 68 pt fixed action footer = 450. Form body has 28 pt side insets, giving `450 − 56 = 394 pt` usable width. A standard arrangement consumes 192 pt before flexible space: 28 top + 32 context + 18 section gap + 18 field label + 8 + 36 input + 8 + 44 feedback. Remaining `330 − 192 = 138 pt` provides calm spacing and room for contextual data; it is not a place to add optional controls. Footer uses 12 pt top + 36 pt actions + 20 pt bottom = 68.

The header contains Back and a precise title: Name Recording during capture or Rename Recording after save. The form shows Recording name, a protected extension, and a concise context line: active status/elapsed time or completed filename/duration/date provenance. Name field uses Inter 13. Two-line feedback space prevents validation from moving the action under the pointer.

During capture, input updates the one session-owned accepted draft, never the open file path. Done accepts the latest valid committed text and returns to the origin. Empty clears to the generated name. Invalid text cannot block Stop; Done keeps it visible with an error, while Back/Recorder navigation can leave using the previous accepted draft. Retain unaccepted editor text only in bounded in-memory state for that same session; it is not promised after restart. An IME composition is never forcibly committed by page navigation or Stop. Capture finishing changes the same Naming page to Saving… and then truthful Saved/failed state without a navigation jump.

After capture, Cancel/Back dismisses an unsubmitted rename and returns to origin without changing files. Rename commits the actual non-overwriting file operation; keep the page in Renaming… until outcome, with duplicate submission disabled. Success stays on Naming with truthful actual-filename feedback until the user invokes Back or an explicit destination; it never auto-returns. Failure retains the old committed name and editable draft. If the user explicitly navigates away during a pending operation, the operation and fixed UUID remain owned by the coordinator; completion updates state without stealing focus, returning to Naming or sending the user elsewhere.

File/overflow Name Current Recording…, Rename Last Recording…, Library header's active Name action and Library-selected rename all route to this one Naming subpage. There is one editor revision owner and no second concurrently editable instance. A newly started take or a newer saved recording never silently changes the target of an open editor. Commands and accessibility labels make the target and disabled reason knowable.

## Navigation, recording safety and focus

- View → Library/Command-L selects the Library **subpage in the existing window**. Existing overflow Library follows the same route. View → Recorder/Shift-Command-L and the Library Recorder back action select the unchanged Recorder page. These are View destinations, not Window commands; no second window is created.
- The main native window has the same identity/frame before and after every route. Preserve user placement, minimized state conventions and app activation behavior; explicit routing may restore/front the one window. Completion events never activate the app.
- Preserve Library search/sort/filter, keyset anchor, current-page scroll and selected UUID while on Recorder/Naming. Ordinary save never resets the query or auto-navigates. Explicit Show in Library can change conflicting filters and focus its exact target, with visible state values explaining the action.
- Recorder's existing recording command remains authoritative. On Library/Naming, an explicit Recorder route must always remain accessible so the original Stop action can be reached. Native recording commands route to the same session owner with appropriate input eligibility; no stale page-local recorder state or duplicate transport exists.
- When Library's grid owns focus, arrows move spatially, Return renames selection and Space previews when eligible. All preview entry points are disabled through capture starting/recording/saving/teardown. Text fields and IME own Space/Return/Escape before any grid handler. No global keyboard monitor steals editing input.
- Back from Naming restores the actual invoking control/selection where valid. If rename removes the record from a filtered result, announce that outcome and focus a stable results/query element; provide explicit Show in Library. Do not restore by array index.
- Previous/Next retains focus on its button, resets current-page scroll intentionally and announces loaded status once. Never silently advance the 60-item data page merely because scrolling reaches the bottom.

## States, type and accessibility

All concepts use the same approved token values, not competing palettes. Card names are `.bodyEmphasized` Inter 13 medium, page titles `.title` Inter 14 medium, controls `.controlCompact` Inter 12 semibold, and machine metadata `.meta` monospaced 10. The Virgin CD is decorative imagery rather than a semantic color token. Existing Recorder typography is exempt from any normalization and remains untouched.

Card-state plate precedence is selected > pressed > hover > rest: white 12%, 8%, 6% or no overlay on opaque `surfaceCard`, never stacked. Metadata promotes to `textSecondary` on non-rest fills. Selected has a 1 pt neutral boundary; focused target has a separate 2 pt neutral ring and 2 pt dark gap, never white directly on a pale cover. Play remains 32 pt opaque neutral light with ink glyph and independent black 6/8% hover/press. Artwork remains decorative, stable by canonical UUID assignment, and never a simulated waveform or status color.

Unavailable files keep names and identity, with readable “Unavailable” in the metadata area and no play. Unknown duration says unavailable rather than 0:00. Playing has real pause affordance plus accessible state, and a compact footer indication if needed; no whole-card pulse. Save/rename errors use actual error color plus words. Empty catalog hides irrelevant query controls inside their allotted region; no matches retains active queries and Clear search/filter. Query/page errors retain valid cards and Retry without pretending the library is empty.

**At increased text sizes, readability wins over the standard-count arithmetic.** Cover Gallery reduces to one centered column; at 2× text cap artwork at 144 pt to leave more room for intrinsic labels rather than inflating the cover to 406 pt. Contact Sheet reduces to two and then one column as text requires, with its title allowed to wrap; it does not force the six-card promise. Header/query/footer can become taller inside the same 450 pt frame and reduce the scroll viewport. If expanded fixed regions would leave less than 120 pt of usable content, retain only a compact Back/header region and move query/footer controls into the same page's vertical scroll view. All labels/actions remain reachable. Search and the Sort & filter popup may stack vertically; both choices and current values inside the popup remain readable. This is adaptive disclosure, not smaller fonts.

Reduce Motion removes translations/scale. Page replacement uses at most a 150 ms opacity transition, with native keyboard focus settled on the destination; no sideways carousel that suggests swiping is required. Reduce Transparency uses the approved new-page opaque fallback without changing Recorder's current renderer. Increase Contrast applies approved text/selection/focus states. Verify actual glass against light, dark and detailed desktops; flat-plane contrast calculations alone are insufficient.

VoiceOver exposes Library as a page heading and each recording's full name/extension, duration, format, date provenance, selection, availability and preview state even where Contact Sheet omits visual metadata. Decorative art stays hidden. Announce page changes and operation outcomes once, never elapsed seconds or every search keystroke. Full Keyboard Access reaches query controls, grid entry, selected-item actions and footer without tabbing into every decoration.

## Discoverability tradeoff — explicit, not silently fixed

With Recorder visually frozen, opening Library is discoverable through the existing overflow and native menus/shortcut rather than an on-face navigation button. This is weaker first-use discovery than a visible Library link; it is the accepted constraint of the current direction. Do not claim the unchanged snapshot already teaches that destination.

An **optional, unapproved** future change would add a neutral Library item to the Recorder's existing settings popover/menu content if a native usability review demonstrates repeated failure to find it; a direct Recorder-header Library button would be a more visible but clearly broader visual change. Neither is included or to be implemented silently. The current deliverable should illustrate working menu routes outside the unchanged Recorder snapshot and make their keyboard shortcuts visible in those menus.

## Acceptance targets and review fixtures

| ID | Required result |
|---|---|
| SW-01 One frame | Recorder→Library→Naming→Back→Recorder retains one native window identity and exact 450 × 450 content size/position; no detached naming/library window or attached sheet |
| SW-02 Recorder freeze | Controlled before/after snapshots for ready/recording/saved/permission/error have zero unmasked changes to Recorder and popover; no inserted navigation chrome inside Recorder |
| SW-03 Cover arithmetic | Standard 450 viewport renders two 194 pt covers, complete two-line names and metadata within first 262 pt row, 18 pt row gap, and no clipped play/menu/focus |
| SW-04 Contact arithmetic | Standard 450 viewport renders three 123⅓ pt cells per row, centered 96 pt covers and no text smaller than roles; if 150 pt row or 2 pt play/title clearance fails, increase height and honestly show fewer cards |
| SW-04A CD artwork | Contact Sheet geometry is identical with the CD asset; true alpha, complete case edges, neutral shadow and play/focus overlays remain crisp at 1×/2×; the decorative image is absent from the accessibility tree |
| SW-04B Color Disc | An 80 pt true-alpha disc sits within each 96 pt UUID-colored tile; deterministic color/rotation survives rename, reorder and relaunch; Reduce Motion removes translation; one cached image serves every card |
| SW-05 Naming continuity | Active valid/invalid/empty/IME draft, Stop while elsewhere, saved rename failure and new-take race preserve correct UUID/revision; no success before filesystem outcome |
| SW-06 Browse continuity | Query/anchor/scroll/selection survive page navigation; no auto-route or query reset on save; explicit reveal targets exact UUID |
| SW-07 Scale independence | 60-item keyset data pages stay bounded regardless of 2/3/1-column presentation; full-page scrolling and explicit Previous/Next work without eager total count |
| SW-08 Accessibility | 1×/2× text, VoiceOver, FKA, Increase Contrast, Reduce Transparency/Motion remain operable in fixed frame; no horizontal scroll or inaccessible action below an unscrollable area |

Review specimens should include “Test”, “Guitar take 02”, “Interview with Ana — funding discussion”, a long composed-Unicode filename, unknown duration, unavailable file, a playing take, and a current capture. Use these identical records across concepts. Inspect native text clearance and task completion, not just attractive empty or short-title grids. Browser concepts remain a review aid with simulated IO/playback and labeled source-snapshot material limitations.

→ Handoff:

- **Product Manager** — retain the selected Contact Sheet and record the final artwork choice among muted color, Virgin CD and Color Disc after native specimens; keep one fixed window and record the menu-only entry tradeoff.
- **Software Architect** — replace prior multiwindow routing with one page coordinator, preserve recording ownership outside page lifetime, and reuse bounded catalog queries/editor revisions.
- **Product UI/UX Designer** — validate the 450 pt arithmetic, card clearance, scroll/focus restoration and exact Recorder baseline using native specimens.

Constraints across handoffs: one 450 × 450 content window; frozen Recorder/popover face; naming as subpage; actual file naming; no auto-navigation on save; same token family; accessibility over card-count quotas; no new unapproved Recorder button.

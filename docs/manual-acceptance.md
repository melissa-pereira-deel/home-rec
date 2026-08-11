# Manual acceptance checklist

The automated suite is **blind to TCC, AppKit lifecycle, and window
choreography** by construction. It has passed while a shipped feature was broken
more than once. These checks are the part no test can do — run them before
tagging a release and record the result in the PR.

> **The boxes below stay empty.** This file is the template for *every* release,
> not a record of any one of them. A ticked box here would make the next release
> start out looking half-done, which is the same "it passed once, so it passes"
> failure this file exists to prevent. Results go in the **Run log** at the
> bottom, dated and tied to a version.

## Every release

```bash
scripts/check-docs.sh          # documented facts still true?
```

```bash
xcodebuild -project HomeRec/HomeRec.xcodeproj -scheme HomeRec \
  -configuration Debug SWIFT_VERSION=6 CODE_SIGNING_ALLOWED=NO build
```

The Swift 6 build is **not** optional polish: the app target infers `@MainActor`
on unannotated types, and that entire class of bug is invisible to a
warning-free Swift 5 build. Errors here are expected to cascade — fixing the top
layer reveals more underneath.

- [ ] `scripts/check-docs.sh` exits 0
- [ ] Swift 6 error count has not grown
- [ ] Full suite green; note the count in the PR
- [ ] `MARKETING_VERSION` verified against the **built product's**
      `CFBundleShortVersionString`, not the file
- [ ] `CHANGELOG.md` describes what the *user* experiences
- [ ] **README describes the app that is shipping** — this has silently failed
      before (M4A shipped in June and never reached the README or the site)
- [ ] **Site parity** — does homerec.app describe this build? Separate repo;
      it will not update incidentally

## Permissions and first run

- [ ] `tccutil reset ScreenCapture com.mdebritto.HomeRec`, then launch:
      **no dialog** on opening the menu, and **none on hovering `App ▶`**
      *(run `tccutil` yourself — it modifies a privacy setting)*
- [ ] First mic recording prompts, and the app is **not killed** — a missing
      usage string is a TCC *termination*, not a denial
- [ ] Declining the mic prompt shows "Open settings", never "Try again"
- [ ] Onboarding copy still describes what the app actually does

## Recording, per source

- [ ] **All System Audio** — record, play back
- [ ] **Per-app** — play audio in the selected app *and* another app
      simultaneously; the file contains **only** the selected one
- [ ] **Microphone** — record; correct pitch and speed
      *(a 44.1 kHz interface into a 48 kHz-declared file is the real test of the
      normalizer; broken, it plays ~8.8% fast)*
- [ ] Selected app quits mid-recording → partial file plays, banner shown
- [ ] Mic unplugged mid-recording → partial file plays, banner shown
- [ ] Mic unplugged while idle → menu shows "(not connected)", checked, disabled

## Crash durability — one force-quit per format

⚠️ **The highest-value check on this page.** `CHANGELOG.md` promises interrupted
recordings are repaired so they play, and **FLAC is the one format that needs
repair to be playable at all.** A durability claim nobody has tested against a
real force-quit is a claim, not a fact.

- [ ] **WAV** — force-quit mid-recording, file plays as found
- [ ] **M4A** — force-quit, file plays as found
- [ ] **FLAC** — force-quit, file does *not* play as found, **Recover
      Recordings repairs it**, repaired file opens
- [ ] Recovery never lists the recording currently in progress
- [ ] Recovery never touches a file that finished normally

## Auto-update (BL-034) — first shipped in 1.1.0

⚠️ **Nothing in the suite can reach this.** Building an `SPUUpdater` touches the
network, so the tests assert only the recording interlock rule. Whether an
update actually *installs* has to be watched.

> ⚠️ **"N-1 → N" was impossible for 1.1.0, and the checklist claimed otherwise.**
> Sparkle landed *in* 1.1.0 (`bcb2554`). v1.0.2 has zero Sparkle references — no
> **Check for Updates…**, no updater to run — so "install the previous version
> and update to this one" could never be performed for that release. It read as
> a pending check rather than an inapplicable one, which is worse: a box nobody
> could ever tick looks the same as a box nobody got to.
>
> Two consequences that outlive this release. Everyone on 1.0/1.0.1/1.0.2 is
> **permanently stranded** — no shipped build of theirs can be told a new one
> exists. And the appcast entry for 1.1.0 changes nothing for them; it exists so
> that people who install 1.1.0 are offered 1.1.1.
>
> **The first hop that can actually be tested is N → N+1**, from the first
> version that has an updater. Rehearse it against a staging feed before it is
> real — see below.

- [ ] `https://homerec.app/appcast.xml` responds 200, as XML, on a machine that
      has never loaded it (a stale CDN entry hides a broken deploy)
- [ ] The published appcast entry's `enclosure url` resolves 302 → 200 and its
      `length` matches the asset's real byte count
      *(a signature is verified against bytes; a wrong length fails late and
      confusingly)*
- [ ] The entry's `edSignature` verifies against the **published** asset, not a
      local copy of it. Re-sign the downloaded file: Ed25519 is deterministic,
      so the same bytes and key reproduce the same signature exactly, and
      anything else means the entry describes a different build. Cheap, and the
      failure it catches is a rebuilt DMG at an unchanged version.

**N → N+1, rehearsed against a staging feed.** Everything here runs locally,
offers nothing to any user, and is the only way to see the update path work
before it matters:

- [ ] Build a scratch **N+1** (version bumped, signed, notarized, `sign_update`d)
- [ ] Serve a staging appcast on `127.0.0.1` containing only that entry
- [ ] Build a scratch **N** whose `SUFeedURL` points at the staging feed, with an
      ATS exception for localhost, and install it to `/Applications`
- [ ] **Check for Updates…** finds N+1, verifies, downloads and installs it
- [ ] It relaunches as N+1, **at the same path**, still named `Home Rec.app` —
      a second differently-named copy in `/Applications` is the failure this
      catches
- [ ] Screen Recording and Microphone permissions **survived** the update
      (TCC keys on the designated requirement, so a signing change silently
      revokes the grant)
- [ ] Tamper check: change one character of the staging entry's `edSignature`
      — Sparkle must **refuse** it. A signature check nobody has seen reject
      anything is not known to work.

> ⚠️ **Installing the scratch N anywhere but `/Applications` silently voids two
> of those checks.** Putting it in `~/Desktop` protects the real install, which
> is tempting and was done once — but same-path relaunch is then unobservable,
> and TCC keys on signature **and path**, so a bundle elsewhere holds its own
> grant no matter what happens to the one in `/Applications`. The update will
> install and the run will look complete. Either accept that the real install
> gets updated, or record those two as not run.

> ⚠️ **The tamper check only means something if the signature is the *sole*
> defect.** Serve a genuine, correctly signed payload with a correct `length`
> and a `sparkle:version` that really is newer, then change one character
> *within* the base64 alphabet so it still decodes to 64 bytes. A garbled
> string is the easier test and the weaker one: it can fail at the parser and
> never reach the verifier. Confirm from the feed's access log that the **whole
> payload downloaded** before the refusal, and that the error names the
> signature rather than the network or the disk image — otherwise something
> else stopped it and the verifier is still unobserved.

**The interlock, which is the part that can lose someone's take:**

- [ ] While recording, **Check for Updates…** is greyed, and hovering explains why
- [ ] It is enabled again the moment recording stops
- [ ] Start a check, then start recording before it finishes — the update must
      **wait**, not relaunch, and must install after you stop

## Accessibility (~30 min, on the surface that changed)

- [ ] VoiceOver: cursor the Capture Source section — checkmark announced,
      submenu opens, "(not connected)" announces as dimmed
- [ ] Activate the popover's "•••" from the **keyboard** — the menu appears
      under the button, not wherever the pointer happens to be
      *(known open defect: the menu pops at the pointer location rather than
      under the button)*

## The reskin (v1.1.0) — every state, seen once

No UI test asserts anything visual, so a reskin regression cannot fail CI — and
the states below are exactly the ones the run log shows never get exercised.
The error states matter most: unreadable text does its worst damage to someone
whose recording just failed. First release with the new look only; trim
afterwards.

**Most of the state coverage is one command.** The snapshot harness renders
every state to PNG — no permissions to reset, no takes to kill, no window ever
opens:

```bash
TEST_RUNNER_HR_SNAPSHOT=/tmp/reskin xcodebuild test \
  -project HomeRec/HomeRec.xcodeproj -scheme HomeRec \
  -destination 'platform=macOS' -only-testing:HomeRecTests/ReskinSnapshots
```

25 images: the main window across ready / recording (quiet, loud, silent) /
permission-denied / undetermined / install-blocked / install-notice / error,
each in both palettes, plus the popover and sheets. Flip through them, attach
them to the PR. It asserts nothing and cannot fail — its whole job is to make
looking cheap.

Two things it deliberately does **not** prove, which stay below: that the glass
is legible over a real desktop (an offscreen window has nothing to blur), and
that `glassThemeAdaptingToContrast()` actually fires (the harness injects the
palette, because `colorSchemeContrast` is read-only and `NSAppearance` does not
drive it — measured).

- [ ] macOS set to **Light**, then **Dark** — every window and the popover stay
      dark and legible in both; the menu-bar icon still reads against both
      menu bars
- [ ] The main window's glass over a **white desktop, a black desktop, a busy
      photo, and a full-screen app** — controls legible on all four
      *(the window samples the desktop now; a light wallpaper is the stress
      case, and the popover gets the same four-background pass)*
- [ ] Idle · recording (loud material, near-silence, stopped) — the waveform
      visibly tracks level, silence stays a flat dotted line
- [ ] **Disabled record button** — reads as unavailable, not as an error
- [ ] Permission not granted · mic denied · install-from-DMG block (window
      **and** popover) · first-run onboarding · recording error (quit the
      captured app mid-take) · long-recording alert · recovery window with
      results **and** empty — text legible in every one
- [ ] **Increase Contrast** on — the high-contrast palette actually engages
      (the record pill's fill visibly darkens)
      *(known deviation, documented in docs/design-system.md: white-on-accent
      is ≈3.9:1 at standard contrast)*
- [ ] **Reduce Motion** on — hover/press scaling stops; nothing else breaks
- [ ] Open and close the settings popover ~20× while hovering its controls —
      the pointer returns to an arrow every time
      *(guards an NSCursor push/pop imbalance in the vendored hover tracker,
      which would leak a pointing-hand cursor system-wide)*
- [ ] Drag the window by its body — it moves (there is no title bar to grab)
- [ ] Sparkle **N-1 → N**, screenshot before and after — the only place the
      reskin is seen arriving the way users will

## Recording anything new?

Add a check here in the same commit. A check that lives only in someone's head
is the failure mode this file exists to prevent.

---

# Run log

Newest first. Record what was checked, what was *not*, and by what means — a run
that doesn't say what it skipped is indistinguishable from a complete one.

## v1.1.0 — update interlock, 2026-08-11 · `ff28b6b`

**All three interlock checks pass, and the one that matters had never actually
run before.** Gate 2 — the postponed relaunch — executed for the first time in
the project's history during this session. It has no unit test (BL-154), so
until now nothing had ever exercised it.

### Passed — by a person at the machine

| Check | Evidence |
|---|---|
| Greyed while recording | Confirmed three times: magnified screenshots of the row dimmed while its neighbours, including "Quit Home Rec" directly below, stayed bright; and independently by hand — "cannot check for update while recording, option appear as disabled" |
| Live again once stopped | A check was started from the menu while idle after several takes |
| **Postponed relaunch** | Both log lines, below |

```
19:59:44.288  Update ready but a recording is open; postponing relaunch
20:00:41.631  Recording stopped
20:00:41.631  Recording ended; releasing the postponed update relaunch
```

Clicking **Install and Relaunch** mid-take did nothing visible — which is the
correct behaviour and worth writing down, because it reads as a broken button.
There is no UI for a postponement. The app stayed alive on its original pid,
kept recording, and the bundle was still 1.0.9. On stopping, the release fired
in the **same millisecond** as the stop, and it relaunched as 1.1.0 build 10100.

**The take survived**: 58,878,764 bytes, 306.66s of valid stereo PCM, playable,
matching the 307s it was open. That is the guarantee the gate exists for.

**Same-path relaunch, incidentally verified.** The update replaced the bundle in
place — same path, same name, exactly one `Home Rec.app` and no second copy
alongside. Previously recorded as not run. ⚠️ This was at `~/Desktop`, so the
`/Applications` half of that check is still open.

### The first attempt passed by accident, and that is the lesson

The run before this one looked like a pass — download finished mid-take, no
relaunch, installed after stopping — but **neither gate-2 line was logged**.
Sparkle had stopped at "Ready to Install" waiting for a click, and the click
came after the recording ended. The app was protected by Sparkle's consent
prompt, not by the interlock. The delegate was consulted once, said "safe", and
did nothing.

**So the pass condition for this check is the two log lines, not the visible
behaviour.** Nothing on screen distinguishes a working interlock from Sparkle
politely waiting. Anyone re-running this must click **Install and Relaunch while
still recording**, and must check the log.

Note also that the obvious route is blocked: "Check for Updates…" is greyed
during a take (gate 1, working as designed), so the check must be *started while
idle* and the download must still be in flight when recording begins. This is
what the throttled feed is for — unthrottled, the payload arrives in 4ms and the
overlap cannot be created by hand.

### TCC survived the update

Recorded from the **updated** bundle immediately after the relaunch: no prompt,
no denial, `Capture started` 192ms after the take began, and a valid 15.84s
stereo PCM file. ScreenCaptureKit cannot start without the grant, so a started
capture *is* the proof — no need to interpret the absence of a prompt.

This is the check that would have been quietly expensive to get wrong. TCC
validates against the code requirement, and a shipped update replaces the whole
bundle; if the grant did not carry across, every user updating would silently
lose Screen Recording and discover it the next time they tried to record. It
carries because the replacement is signed by the same Developer ID team
(`S3J47F2UXA`) — which also means **a signing-identity change is the thing that
would break it**, not a version bump. Re-run this check on any release where the
signing identity changes.

⚠️ Verified at `~/Desktop`. The `/Applications` case is not separately tested,
though nothing in TCC's model makes the location the deciding factor here.

## v1.1.0 — auto-update path, 2026-08-10 · `cd56bf0`

**The update path is now proven in both directions: it installs a correctly
signed update, and it refuses a mismatched one.** The appcast, empty since it
was created, now announces v1.1.0. What remains of this block is the two checks
the rehearsal's one deliberate substitution put out of reach, plus the interlock.

### Passed — by a person at the machine

| Check | Notes |
|---|---|
| **N → N+1 install** | 1.1.0 → 1.1.1 against a `127.0.0.1` feed. Offered, release notes rendered, downloaded, installed |
| **Tamper check — Sparkle refused** | *"The update is improperly signed and could not be validated."* |

### Passed — mechanically

| Check | Evidence |
|---|---|
| Appcast reachable, as XML | `HTTP 200`, `application/xml; charset=utf-8`, `must-revalidate`; live file byte-identical to the commit |
| Enclosure resolves, length agrees | `200`, `content-length: 2666422` = entry `length` = asset size |
| Published signature matches published bytes | sha256 `2932b2dd…` matches the release sidecar, **and** re-signing the downloaded asset reproduced `8UQC1+hL…` exactly |

### Why the tamper result is worth trusting

A refusal only means something if the signature was the **sole** defect —
otherwise Sparkle may have stopped for an unrelated reason and the verifier is
still unobserved. So everything else was made genuine:

- The payload served was the **real published v1.1.0 DMG**, sha256-verified
  against the release sidecar. Correctly signed, notarized, stapled.
- `length` was correct, and `sparkle:version` (10100) exceeded the running
  app's (10009), so version comparison offered it normally.
- The flipped character stayed **inside the base64 alphabet** and still decoded
  to 64 bytes. A garbled string would have been the easier test and the weaker
  one: it could fail at the parser and never reach the verifier.

And the failure landed in the right place. The access log shows the app fetched
the feed, then downloaded the **full 2,666,422-byte payload**, and only then
refused — the verifier ran on real bytes rather than bailing out early. The
bundle on disk was still 1.0.9 / build 10009 afterwards, and the error names the
cause rather than blaming the network or the disk image.

### What this run did *not* establish

- **Both proofs used a local feed with a local enclosure.** The live appcast
  points at GitHub. Signature and URL are each verified independently, so the
  residual risk is narrow — the GitHub download path specifically — but no
  client has yet consumed the real feed with a real entry in it. The first user
  update closes this; nothing cheaper does.
- **The two `/Applications` checks above.** The rehearsal ran from `~/Desktop`
  to protect the shipping install, which is also precisely why it cannot speak
  to same-path relaunch or TCC survival.
- **The interlock is untouched** and remains the highest-risk item here, because
  it is the one that can cost someone a take.

### A local preference was changed and not changed back

`SUAutomaticallyUpdate` is now `0` for `com.mdebritto.HomeRec`, set so the
refusal would surface as a dialog instead of failing silently in a background
install. It was unset beforehand, so this is a choice rather than a
restoration, and preferences key on bundle ID — it applies to the real install
too. `defaults delete com.mdebritto.HomeRec SUAutomaticallyUpdate` reverts it.

## v1.1.0 — partial, 2026-08-07 · `53bb672`

**Both blocks the previous run called highest-risk are now verified against real
hardware, and doing so found a release blocker.** Crash durability is complete;
per-app isolation was done properly, with two apps playing. What remains is
permissions, accessibility, and the auto-update path.

### Passed — by a person at the machine

| Check | Notes |
|---|---|
| **WAV** force-quit mid-recording | plays as found |
| **M4A** force-quit | plays as found |
| **FLAC** force-quit → Recover Recordings → repaired file opens | the check the changelog's durability promise rests on, and the one never previously run |
| Recovery never lists the in-progress recording | |
| Recovery never touches a file that finished normally | |
| **Per-app** isolation | two apps playing simultaneously; the file contains only the selected one. With one app playing, a working filter and a broken one produce identical files, so this is the only form that counts |
| **All System Audio** | recorded and played back; a 294s take measured −8.4 dBFS peak, 99.2% non-zero |
| **Microphone**, Focusrite Scarlett 2i2 4th Gen | 10s take, left −14.1 dBFS, right silent, which is correct for one input under the `[0, 1]` channel map |

### Passed — mechanically

| Check | Evidence |
|---|---|
| `scripts/check-docs.sh` | exit 0 |
| Full suite green | 275 passed, 0 failed, 0 skipped |
| `MARKETING_VERSION` vs built product | both `1.1.0` |
| Build number derived, not stale | `CFBundleVersion = 10100` |
| `LSMinimumSystemVersion` | `15.0` |
| Appcast reachable | `HTTP 200`, `application/xml`, cache-busted |
| README describes the shipping app | FLAC ×7, M4A ×5, microphone ×10 |
| Site parity | features and the privacy page current; see the gap below |

### ⚠️ This run found a release blocker

Microphone capture reached the file as **digital silence** — full length,
correct duration, every sample zero. `AVAudioConverter` defaults `channelMap`
to `[-1, -1]` for a discrete channel layout and emits zeros while reporting
success. Fixed in `53bb672`.

**It was found by hand and could not have been found otherwise.** The previous
round's tests stopped at `makePCMBuffer`, one stage before the silence
happened, and every guard on the path returned success. Same lesson BL-150
taught the first time: a duration-based check calls a silent file a good take.

### Two corrections to the previous entry

**The Swift 6 count is understated.** The last entry records `1 —
DiskSpace.swift:21`. Across five builds of the same tree, four reported only
that; one also surfaced `PermissionGrantWatcher.swift:81` — *"cannot access
property 'activity' with a non-Sendable type from nonisolated deinit"*. So **at
least two** exist. This is the TD-008 nondeterminism, and it means "the count
has not grown" cannot be evaluated from a single build.

**Site parity is partial, and the important half is fine.** homerec.app
describes the features (flac ×4, m4a ×4, microphone ×7) and the privacy page
correctly documents the appcast request. The homepage never mentions automatic
updates, a headline feature of this release. A marketing gap, not a correctness
or privacy one.

### Not run — and why

| Block | Checks | Blocked on |
|---|---|---|
| Permissions and first run | 4 | `tccutil reset` modifies a privacy setting, and no TCC prompt can be answered without a person |
| Recording, per source | 3 of 6 | Source removed *mid-recording* (app quits, mic unplugged), and mic unplugged while idle |
| Auto-update | 7 of 8 | 3 interlock checks are runnable now; the rest need the release published |
| Accessibility | 2 | VoiceOver |

### Still unverified, in order of risk

1. **Microphone at 44.1 kHz.** The fix above proves the *channel* path. The
   sample-rate path is untouched by it, and a broken normalizer plays ~8.8%
   fast: wrong, but not obviously wrong on a voice take.
2. **The update interlock** — greyed while recording, re-enabled on stop, and
   an in-flight check that must wait rather than relaunch. This is the part
   that can cost someone a take, and it does not need the release published.
3. **N-1 → N update**, including that TCC grants survive and no second
   `Home Rec.app` appears in `/Applications`.
4. **Tamper check.** A signature verifier nobody has watched *reject*
   something is only known to accept.
5. **Permissions on a clean machine**, and VoiceOver.

## v1.1.0 — partial, 2026-08-02 · `f467048`

**7 of 32 checks verified. 25 outstanding, all requiring a human at the machine.**
Everything below was run mechanically; nothing in this run involved a person
looking at the app.

### Passed

| Check | Evidence |
|---|---|
| `scripts/check-docs.sh` | exit 0 |
| Swift 6 error count has not grown | **1** — `DiskSpace.swift:21`, `minimumBytesToRecord` referenced from a nonisolated context |
| Full suite green | **282 passed, 0 failed, 0 build warnings** |
| `MARKETING_VERSION` vs built product | product reports `CFBundleShortVersionString = 1.1.0`; file agrees |
| Build number derived, not stale | product reports `CFBundleVersion = 10100` |
| README describes the shipping app | FLAC ×7, M4A ×5, microphone ×10, automatic updates present |
| Site parity — landing | flac/m4a/microphone ×9 on homerec.app |
| Appcast reachable | `HTTP 200`, `application/xml; charset=utf-8` |
| `CHANGELOG.md` written as user experience | 11 entries, all phrased as what the user meets |

⚠️ **The Swift 6 count is a floor, not a total.** The build stops at the first
failing batch, so later files are never type-checked. The same tree reported one
error before an unrelated change and two after, with nothing touching either
file — see TD-008. Do not read a short list as "nearly clean".

### Not run — and why

| Block | Checks | Blocked on |
|---|---|---|
| Permissions and first run | 4 | `tccutil reset` modifies a privacy setting, and no TCC prompt can be answered without a person |
| Recording, per source | 6 | Real audio in real apps. The per-app check needs audio playing in **two** apps at once to prove the file contains only one |
| Crash durability | 5 | A real force-quit mid-recording |
| Auto-update | 7 of 8 | v1.1.0 must be published first — the N-1 → N test cannot precede the release it tests |
| Accessibility | 2 | VoiceOver |

### The ordering trap in the auto-update block

Five of those checks can only run **after** the release they validate is public.
Cut the release, verify immediately, and be prepared to pull it — there is no
arrangement in which the update path is proven before shipping.

### Highest risk still unverified, in order

1. **FLAC force-quit → Recover Recordings → plays.** Never exercised, and
   `CHANGELOG.md` makes the promise. FLAC is the one format that *needs* repair
   to open at all.
2. **Per-app isolation with two apps playing.** The headline feature, and its
   failure is silent — you get a file, it simply has the wrong audio in it.
3. **Mic at 44.1 kHz into a 48 kHz-declared file.** A broken normalizer plays
   ~8.8% fast: wrong, but not obviously wrong.
4. **N-1 → N update**, including that TCC grants survive and no second
   `Home Rec.app` appears in `/Applications`.
5. **Tamper check.** A signature verifier nobody has watched *reject* something
   is only known to accept.

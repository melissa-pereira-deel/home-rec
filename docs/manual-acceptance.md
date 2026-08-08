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
update actually *installs* is provable one way: install the previous version and
update to this one.

- [ ] `https://homerec.app/appcast.xml` responds 200, as XML, on a machine that
      has never loaded it (a stale CDN entry hides a broken deploy)
- [ ] **N-1 → N end to end.** Install the previous DMG into `/Applications`,
      launch it, **Check for Updates…**, let it install
- [ ] It relaunches as N, **at the same path**, still named `Home Rec.app` —
      a second differently-named copy in `/Applications` is the failure this
      catches
- [ ] Screen Recording and Microphone permissions **survived** the update
      (TCC keys on the designated requirement, so a signing change silently
      revokes the grant)
- [ ] Tamper check: point a scratch build at an appcast entry whose
      `edSignature` has one character changed — Sparkle must **refuse** it. A
      signature check nobody has seen reject anything is not known to work.

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

## Recording anything new?

Add a check here in the same commit. A check that lives only in someone's head
is the failure mode this file exists to prevent.

---

# Run log

Newest first. Record what was checked, what was *not*, and by what means — a run
that doesn't say what it skipped is indistinguishable from a complete one.

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

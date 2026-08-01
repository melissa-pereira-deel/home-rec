# Manual acceptance checklist

The automated suite is **blind to TCC, AppKit lifecycle, and window
choreography** by construction. It has passed while a shipped feature was broken
more than once. These checks are the part no test can do — run them before
tagging a release and record the result in the PR.

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

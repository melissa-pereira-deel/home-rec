# Building & Distributing Home Rec

> **Status:** run end-to-end for the v1.0 release (2026-06-04). Requires an Apple
> Developer account and the Keychain items described below.

Home Rec is distributed **outside the Mac App Store** (system audio capture
isn't permitted under the App Sandbox). That means: Developer ID signing →
notarization → stapling → a `.dmg`.

## 1. Required Release build settings (BL-030 / BL-031)

Verify in Xcode (Target → Build Settings, Release configuration):

| Setting | Value | Why |
|---|---|---|
| `DEBUG_INFORMATION_FORMAT` | `dwarf-with-dsym` | Symbolicated crash reports |
| Enable Hardened Runtime | `Yes` | Required for notarization |
| App Sandbox | **Off** | System audio capture needs it off (see CLAUDE.md) |
| Code Signing Identity (Release) | `Developer ID Application` | Required for distribution outside MAS |
| `ENABLE_BITCODE` | `No` | Deprecated; not used for macOS apps |

The signing **identity lives in your Keychain** — never in the repo.

## 2. One-time notarization setup (BL-032)

Store a notarytool profile in your Keychain (do this once). Leave `--password`
out and notarytool prompts for the app-specific password:

```bash
xcrun notarytool store-credentials "HomeRecNotary" \
  --apple-id "you@example.com" \
  --team-id "S3J47F2UXA"
```

See `notarization.md` for details, and for refreshing the profile when it stops
working.

## 3. Build the DMG (BL-033)

```bash
brew install create-dmg            # one time
TEAM_ID=YOUR_TEAM_ID AC_PROFILE=HomeRecNotary ./scripts/build-dmg.sh
```

The script (`scripts/build-dmg.sh`) runs: archive → export (Developer ID) →
verify signature → notarize app → staple → `create-dmg` → notarize DMG →
staple DMG → Gatekeeper assess. Output: `dist/HomeRec.dmg`.

## 4. Verify on a clean Mac

- Double-click the DMG: it should mount with no "unidentified developer" warning.
- Drag Home Rec to Applications and launch it: it should open without a Gatekeeper block.

```bash
codesign --verify --deep --strict HomeRec.app   # exit 0
spctl --assess --verbose HomeRec.app            # "accepted"
xcrun stapler validate HomeRec.app              # "validated"
```

## 5. Working on the permission prompt

### The Screen Recording prompt's text cannot be authored

**Do not try to customise it.** `NSScreenCaptureUsageDescription` is not read by
macOS. Tested 26.5.2, 2026-07-26: the key was delivered into the built bundle and
verified present with `PlistBuddy`, TCC was reset, and the dialog still showed the
stock *"…deseja gravar a tela e o áudio deste computador."* (BL-080, closed.)

Two traps sit in front of that conclusion, and both cost time before it was reached:

- `INFOPLIST_KEY_NSScreenCaptureUsageDescription` **does nothing**. Xcode's
  generated-plist path only maps an allow-list of `INFOPLIST_KEY_*` settings
  declared in `CoreBuildSystem.xcspec`; `NSScreenCaptureUsageDescription` is not in
  it. Anything not in the list is accepted as a user-defined build setting, echoed
  back by `-showBuildSettings`, and silently dropped. **Never verify a plist key
  with `-showBuildSettings`** — check the built product:

```bash
/usr/libexec/PlistBuddy -c "Print :SomeKey" "$(ls -d ~/Library/Developer/Xcode/DerivedData/HomeRec-*/Build/Products/Debug/HomeRec.app | head -1)/Contents/Info.plist"
```

- Keys that *are* in the allow-list work normally as `INFOPLIST_KEY_*` — including
  `NSMicrophoneUsageDescription`, which BL-130 will need. Only the screen-capture
  one is missing.

### Resetting the grant to see the prompt again

Still useful for BL-130's microphone prompt and for testing the first-run funnel.
The prompt fires once per grant decision, so a reset is the only way to see it twice.

```bash
tccutil reset ScreenCapture com.mdebritto.HomeRec
```

**Quit every copy of the app first, and make sure only one is running afterwards.**

```bash
osascript -e 'quit app id "com.mdebritto.HomeRec"'; sleep 1; pkill -x HomeRec
open ~/Library/Developer/Xcode/DerivedData/HomeRec-*/Build/Products/Debug/HomeRec.app
ps aux | grep "[H]omeRec/Contents/MacOS"     # confirm WHICH binary is running
```

Three things that will mislead you if you skip that:

- **One bundle ID, two signatures, one broken grant.** The installed
  `/Applications/Home Rec.app` is signed **Developer ID**; a DerivedData build is
  signed **Apple Development**. TCC keys a grant on bundle ID **plus designated
  requirement**, and those two DRs are mutually exclusive — so the toggle in System
  Settings can be on for one identity while the other is refused. Symptom: the
  toggle is on, the app insists permission is missing, and toggling or re-adding
  with "+" changes nothing. Observed twice (2026-06-04, 2026-07-26).
- **`open` on an already-running bundle ID activates the running instance** rather
  than launching the binary you pointed at. Home Rec is a menu-bar app, so it is
  probably still running even with no window. This is how you end up testing the
  wrong build without noticing.
- **The dialog's app name comes from the bundle *filename*.** Xcode builds
  `HomeRec.app`; `build-dmg.sh` renames to `Home Rec.app` at packaging. A dev-loop
  dialog saying "HomeRec" is correct and expected — and a *Settings row* saying
  "HomeRec" while `/Applications/Home Rec.app` is the app running is the tell-tale
  of the signature collision above. (BL-083 closed on this finding.)

**Return denies.** On macOS 26.5.2 the blue default button is *Deny*, on the right;
"Open System Settings" is the recessive one on the left.

`tccutil reset` clears a real privacy grant for this bundle ID — it is safe and
reversible (you re-grant it), but run it deliberately, not in a script.

## Notes / things to verify on first run

- **Toolchain:** the project targets a recent macOS SDK; build on a machine whose
  Xcode provides it.
- **CI:** `.github/workflows/ci.yml` runs the unit tests; release packaging is not
  automated yet (could be a tag-triggered job later — see BL-035).
- Secrets (signing identity, app-specific password, notary profile) stay in
  Keychain. `dist/` is git-ignored.

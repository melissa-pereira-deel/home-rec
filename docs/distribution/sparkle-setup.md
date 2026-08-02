# Sparkle auto-update setup

How Home Rec updates itself, and what a release has to do to keep that working.

Sparkle 2 is pinned in `HomeRec.xcodeproj` and resolved via Swift Package
Manager. `Package.resolved` is committed on purpose: it is the only record of
which version of the updater a given release shipped with, and the updater is
the one component that can replace the app on someone's disk.

---

## One-time setup

### 1. Generate the signing keypair

Sparkle verifies every download against an EdDSA public key baked into the app.
Run this **once**, on the Mac you release from:

```bash
"$(find ~/Library/Developer/Xcode/DerivedData -path '*/artifacts/sparkle/Sparkle/bin/generate_keys' -type f | head -1)"
```

It stores the **private** key in your login Keychain and prints the public half.

⚠️ **The private key is unrecoverable and unreplaceable in practice.** Every
copy of Home Rec already in the world trusts exactly one public key. Lose the
private half and you cannot sign an update those copies will accept — the entire
installed base is stranded, permanently, with no way to reach it except asking
people to re-download by hand. That is the failure Sparkle exists to prevent, so
losing the key would undo the whole point of shipping it.

### Backing it up — the exact procedure

The destination is a **password manager's secure-note field**. Not a file you
keep. `generate_keys -x` writes a plaintext seed to disk, and that file is a
liability from the moment it exists:

```bash
generate_keys -x /tmp/sparkle-seed.txt   # NOT ~/Desktop, NOT ~/Documents
# paste the contents into your password manager, then:
rm /tmp/sparkle-seed.txt
```

⚠️ **Never write it to `~/Desktop`, `~/Documents`, or any folder inside a sync
root.** With iCloud Desktop & Documents sync enabled — the macOS default — a
signing key written there is uploaded within seconds, and deleting it locally
leaves a copy in iCloud's *Recently Deleted* for about 30 days. This happened on
2026-08-02, which is why the instruction now names the path.

Only the Mac holding the private key can cut a release. To move it to another
machine, import from the password manager with `generate_keys -f`, using the same
write-to-`/tmp`-then-delete discipline.

The key must **never** enter this repo. `.gitignore` and `.githooks/pre-commit`
both cover it — the hook blocks a bare 44-character base64 seed on content, not
just on filename — but treat those as the last line, not the first.

### 2. Put the public key in the app

Paste the printed value into `HomeRec/Info.plist` as `SUPublicEDKey`, replacing
the placeholder. `InfoPlistTests` asserts the key reaches the built product.

> `HomeRec/Info.plist` sits one level **above** the source directory on purpose.
> `HomeRec/HomeRec/` is a file-system-synchronized group, so a plist placed
> inside it would also be copied to `Contents/Resources/` — the inert second
> plist BL-084 removed. Do not move it.

`SUFeedURL` is already set to `https://homerec.app/appcast.xml` and should not
change. Every shipped copy asks that exact URL what the newest version is,
including copies whose owners never visit the site again.

---

## Cutting a release

`scripts/build-dmg.sh` handles signing and produces the appcast entry. The
order below is not interchangeable.

1. **Build, notarize and package** as usual:
   ```bash
   TEAM_ID=S3J47F2UXA AC_PROFILE=HomeRecNotary ./scripts/build-dmg.sh
   ```
   Besides the DMG and its SHA-256 sidecar, this writes
   `dist/appcast-item-<version>.xml` — the `<item>` block for the feed, already
   signed with the key from your Keychain.

2. **Publish the GitHub release** for tag `v<version>`, attaching `HomeRec.dmg`.
   Do this **before** step 3: the appcast entry points at that release's asset,
   so publishing the feed first advertises a URL that 404s.

3. **Paste the item** into `<channel>` in `home-rec-site/public/appcast.xml`,
   newest first, and deploy. That repo is the live feed.

### Why the entry's URL is version-pinned

The website links to `releases/latest/download/HomeRec.dmg`, which deliberately
follows the newest release. An appcast entry must do the opposite: it points at
`releases/download/v<version>/HomeRec.dmg` and must keep pointing there forever,
because its signature was computed over that exact file. Pointed at `latest`,
every past entry would silently start resolving to a newer DMG, the signature
check would fail, and Sparkle would refuse the update with no obvious cause.

### Why Sparkle downloads the DMG

Sparkle replaces the installed bundle **at its path**, and the installed bundle
is `Home Rec.app`. The build product is `HomeRec.app`; `build-dmg.sh` renames it
during packaging. The DMG therefore contains the correctly-named bundle and is
already notarized and stapled. An archive made before that rename would install
a second, differently-named copy alongside the original.

---

## The recording interlock

This is the part a stock Sparkle integration does not give you, and the part
worth understanding before changing anything.

Installing an update quits and relaunches the app. Home Rec spends its time
holding an open audio file that is only valid once `finalize()` has run, so an
update landing mid-take destroys that take — a WAV keeps a header claiming
length it doesn't have, an M4A loses its `moov` atom, a FLAC is unplayable until
repaired.

`UpdaterController` closes that with two gates:

| Gate | Handles |
|---|---|
| `updater(_:mayPerform:)` | Refuses to **start** a check while a take is open. |
| `updater(_:shouldPostponeRelaunchForUpdate:untilInvokingBlock:)` | A check that began *before* recording started and finished during it. Sparkle waits until `MenuBarController` releases it when the state clears. |

The rule itself is `RecordingState.allowsUpdateInstall`, asserted by
`UpdateGateTests` — deliberately not inside the Sparkle glue, because building
an `SPUUpdater` reaches the network.

`.stopping` counts as unsafe. It reads like the safest moment and is the most
dangerous: that is when the file is being finalized.

---

## Testing an update end-to-end

The only meaningful test is a real one, and it cannot be faked locally:

1. Install version N-1 from its DMG into `/Applications`.
2. Publish version N through the steps above.
3. Launch N-1, choose **Check for Updates…**, and let it install.
4. Confirm it relaunches as N, **at the same path**, with `Home Rec.app`
   unchanged as the bundle name and TCC permissions still granted.

Step 4 is the one that catches the naming and signing mistakes; a check that
merely *finds* the update proves almost nothing.

# Cutting a release (BL-036)

> **Goal:** publish a notarized `HomeRec.dmg` to GitHub Releases so the
> `releases/latest/download/HomeRec.dmg` URL serves the newest version
> automatically and the website's download button never breaks across versions.

This guide covers the per-release flow. One-time setup lives in
[`build.md`](build.md) and [`notarization.md`](notarization.md).

## Prerequisites (one-time)

- Developer ID Application identity in the login Keychain. Verify with:
  ```bash
  security find-identity -v -p codesigning | grep "Developer ID Application"
  ```
- A stored notarytool profile in the Keychain. `scripts/build-dmg.sh` checks it
  first and stops before building if it cannot sign in. If that happens, see
  [When the notary service refuses the profile](notarization.md#when-the-notary-service-refuses-the-profile).
  To check before tagging rather than after, run the same call by hand:
  ```bash
  xcrun notarytool history --keychain-profile "HomeRecNotary"
  ```
- `create-dmg` installed: `brew install create-dmg`
- `gh` CLI authenticated against the repo: `gh auth status`

## Per-release flow

Run all of this from the repo root.

**The order is the point.** The DMG that ships must be the DMG a person tested,
and `scripts/check-docs.sh` (a CI job since BL-160) refuses a version that has
no run-log entry in `docs/manual-acceptance.md`. So the version is bumped on a
release branch first, the release candidate is built from that commit, the manual
pass runs on that DMG, and only then is the run log written, the branch merged
and the tag cut. Testing a build and then shipping a different one is how
v1.1.3's run log came to describe an artifact that reported itself as 1.1.2.

### 1. Cut a release branch and bump the version

```bash
git checkout main
git pull --ff-only
git status --short    # should be empty
VERSION=1.2.0         # SemVer: a minor bump when the release adds something
git checkout -b "release/$VERSION"
```

In this one commit:

- **`MARKETING_VERSION`** in all six build configurations (`check-docs.sh`
  counts them; a find-and-replace that misses one ships a mislabelled build).
- **`CURRENT_PROJECT_VERSION`**, which is what Sparkle compares. It must be
  higher than the last release's; the convention is `MMmmpp` (`1.2.0` →
  `10200`).
- **`CHANGELOG.md`:** rename `## [Unreleased]` to `## [$VERSION] - YYYY-MM-DD`
  and open a fresh empty `## [Unreleased]` above it. The build reads the
  release notes out of that heading by name, so skipping this ships an
  **empty** GitHub release and an empty Sparkle update sheet — with no error,
  because there is nothing malformed about a changelog whose newest section is
  still called Unreleased.
- **`README.md`:** the version badge and the footer.

Push the branch and open its PR. **CI's Docs check fails on this commit, on
purpose:** there is no run-log entry for `$VERSION` yet. That is the gate
working, not a fault to fix by writing an entry.

### 2. Build the release candidate

```bash
TEAM_ID=S3J47F2UXA AC_PROFILE=HomeRecNotary ./scripts/build-dmg.sh
git rev-parse --short HEAD    # the commit this candidate was built from
```

This checks the notary profile first, then runs archive → Developer ID sign →
notarize → staple → DMG → notarize → staple → verify, and writes:

- `dist/HomeRec.dmg` and `dist/HomeRec.dmg.sha256`
- `dist/appcast-item-$VERSION.xml`, the Sparkle entry for step 9

**Copy `dist/` aside now** (for example to `dist-rc-$VERSION/`). The script
overwrites it on every run, and this is the artifact that ships.

Apple's notary service typically returns Accepted in a few minutes. Outliers
of 60–90 minutes happen during queue spikes — that's normal, the script waits.

### 3. Read the notes the update dialog will show

An empty or developer-facing section is the last screen a user sees before
accepting the update:

```bash
awk -v v="$VERSION" '$0 ~ "^## \\["v"\\]" {f=1; next} /^## \[/ {f=0} f' \
  CHANGELOG.md | sed '/^---$/d'
```

That must print the section body, written for someone who records music, not
for someone who builds the app. The same text is in the appcast entry's
`<description>`.

### 4. Run the manual pass on that DMG, then record it

Work through [`docs/manual-acceptance.md`](../manual-acceptance.md) on the
candidate from step 2: **Every release**, **Signed product**, and **Auto-update**,
including the N → N+1 rehearsal against a staging feed.

Then add the run-log entry — `## v$VERSION — <what>, <date> · \`<commit from
step 2>\`` — in its own commit on the release branch. It touches only that file.
`scripts/check-docs.sh` now exits 0 and CI's Docs check goes green.

**Why the gate sits before the tag rather than after the build.** v1.1.1 shipped
on 2026-08-22 with no run-log entry at all — the release that fixed microphone
recording, and the checklist that would have covered everything the fix did not
touch was skipped. A tag is the point of no return for the appcast, so the gate
belongs before it. If the run log has no entry for this version, **go and do the
manual pass**; do not write an entry to make the check go green.

### 5. Merge, prove the code is what was tested, then tag

Merge the release PR. Then, on `main`:

```bash
git checkout main && git pull --ff-only
git diff --stat <commit from step 2> HEAD -- HomeRec scripts
```

That must print nothing: between the tested commit and `main`, only the run log
changed. If anything else did, the candidate is not this release — go back to
step 2.

```bash
git tag -a "v$VERSION" -m "Home Rec v$VERSION"
git push origin "v$VERSION"
```

### 6. Publish the GitHub Release with the tested DMG

Upload the files you set aside in step 2, not a rebuild:

```bash
gh release create "v$VERSION" \
  --title "Home Rec v$VERSION" \
  --notes-file <(awk -v v="$VERSION" '$0 ~ "^## \\["v"\\]" {f=1; next} /^## \[/ {f=0} f' CHANGELOG.md | sed '/^---$/d') \
  "dist-rc-$VERSION/HomeRec.dmg" \
  "dist-rc-$VERSION/HomeRec.dmg.sha256"
```

⚠️ The previous form here was `awk '/^## \[$VERSION\]/,/^## \[/' … | sed '$d'`,
and it **could never work for any version**. A range expression ends on the
first record matching the end pattern *including the record that started it*,
and `## [1.1.0] - 2026-08-07` matches both `/^## \[1.1.0\]/` and `/^## \[/`. So
the range was always exactly one line, `sed '$d'` deleted it, and the result was
always empty. Verified against 1.0.2 as well. A flag is used instead of a range
because it is the only form that survives a header matching both ends.

### 7. Verify the public URL

```bash
curl -sI -L https://github.com/melissa-pereira-deel/home-rec/releases/latest/download/HomeRec.dmg \
  | grep -E "^(HTTP|content-length|content-type)"
```

Expected: a 302 → 200 chain ending at the CDN-hosted asset, `content-type: application/x-apple-diskimage`, `content-length` matching the local file size.

### 8. Confirm the SHA-256 sidecar

A downloader can verify the artifact didn't change in transit:

```bash
curl -sL -o /tmp/HomeRec.dmg https://github.com/melissa-pereira-deel/home-rec/releases/latest/download/HomeRec.dmg
curl -sL -o /tmp/HomeRec.dmg.sha256 https://github.com/melissa-pereira-deel/home-rec/releases/latest/download/HomeRec.dmg.sha256
( cd /tmp && shasum -a 256 -c HomeRec.dmg.sha256 )
```

Expected: `HomeRec.dmg: OK`

### 9. Publish the appcast entry — after the release, never before

The entry's enclosure URL points at the release from step 6, so publishing it
first would offer every install an update that 404s.

In `home-rec-site`, on a branch, paste `dist-rc-$VERSION/appcast-item-$VERSION.xml`
into `<channel>` in `public/appcast.xml`, **newest first**. Open a PR: the
site's CI validates the feed (BL-176) and must pass. Merging deploys it. Then run the first boxes of the checklist's
**Auto-update** section against the live feed.

### 10. Record it

In the private backlog: set **Current shipped release**, and move every item
that shipped from *merged, unreleased* to *shipped in v$VERSION*.

## URL pattern for the website

The website links to:

```
https://github.com/melissa-pereira-deel/home-rec/releases/latest/download/HomeRec.dmg
```

This **auto-resolves to the newest release's `HomeRec.dmg` asset** — no website
update needed for future releases. The asset name `HomeRec.dmg` is intentionally
versionless for this reason; the version lives inside the bundle.

The release notes page is at:

```
https://github.com/melissa-pereira-deel/home-rec/releases/latest
```

## Rollback

If a release ships broken:

1. Edit the release on GitHub → mark as **Pre-release** (demotes it; the
   `latest` URL skips pre-releases automatically and falls back to the
   previous one).
2. If urgent, **delete the bad release tag** and ship a `v$NEXT.0.1` with
   the fix. Don't reuse the broken version number.

## Notes

- The build script is idempotent. Re-running overwrites `dist/`. To preserve a
  prior artifact, copy `dist/HomeRec.dmg` aside before re-running.
- `dist/` is git-ignored. Artifacts only exist locally and on GitHub Releases.
- Signing identity and notarytool credentials never leave the Keychain.

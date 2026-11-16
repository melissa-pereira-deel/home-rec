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
- Python 3 for staging and appcast enclosure verification

## Per-release flow

Run all of this from the repo root.

Build the candidate after bumping the version, run manual acceptance on the
preserved DMG, and commit the acceptance evidence before merging and tagging.
The release check compares the tagged tree with the tested source and the
published DMG with the digest recorded during acceptance.

### 1. Cut a release branch and bump the version

```bash
git checkout main
git pull --ff-only
git status --short    # should be empty
VERSION=1.2.0         # SemVer: a minor bump when the release adds something
git checkout -b "release/$VERSION"
```

In this one commit:

- **`MARKETING_VERSION`** in all six build configurations.
- **`CURRENT_PROJECT_VERSION`** in all six build configurations. Sparkle
  compares this number with the previous release's build number. Use a higher
  value following the existing convention (`1.2.0` → `10200`).
  `check-docs.sh` verifies that all six configurations agree on both values.
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

### 2. Build from a clean checkout and preserve the candidate

Use a fresh detached worktree at the version-bump commit. The candidate
directory lives outside the build worktree so a rebuild cannot overwrite it.
Keep the directory path and the full source commit for the acceptance pass.

```bash
SOURCE_COMMIT=$(git rev-parse HEAD)
RC_DIR=$(mktemp -d "${TMPDIR:-/tmp}/HomeRec-v$VERSION.XXXXXX")
BUILD_DIR="$RC_DIR/build"

(
  set -e
  git worktree add --detach "$BUILD_DIR" "$SOURCE_COMMIT"
  cd "$BUILD_DIR"
  status=$(git status --porcelain --ignored)
  test -z "$status" || exit 1
  TEAM_ID=S3J47F2UXA AC_PROFILE=HomeRecNotary ./scripts/build-dmg.sh
  cp dist/HomeRec.dmg dist/HomeRec.dmg.sha256 "dist/appcast-item-$VERSION.xml" "$RC_DIR/"
)

printf 'Tested source commit to record after acceptance: %s\n' "$SOURCE_COMMIT"
printf 'Candidate artifacts: %s\n' "$RC_DIR"
```

The build archives and signs the app, notarizes and staples the app and its
DMG, verifies the DMG, and produces the Sparkle entry. Continue once it succeeds.
Keep the three copied files together through publication. Copy them to durable
storage if the release will outlast the temporary directory.

### 3. Read the notes the update dialog will show

An empty or developer-facing section is the last screen a user sees before
accepting the update:

```bash
awk -v v="$VERSION" '$0 ~ "^## \\["v"\\]" {f=1; next} /^## \[/ {f=0} f' \
  "$BUILD_DIR/CHANGELOG.md" | sed '/^---$/d'
```

That must print the section body, written for someone who records music, not
for someone who builds the app. The same text is in the appcast entry's
`<description>`.

### 4. Run the manual pass on that DMG, then record it

Work through [the manual acceptance checklist](../manual-acceptance.md) on
`$RC_DIR/HomeRec.dmg`, using this DMG as **N+1** for the staging feed. The
staging script serves a copy of the saved item with the enclosure rewritten
to localhost. Point the staging N build at the staging feed.

```bash
scripts/staging-feed.sh "$RC_DIR/appcast-item-$VERSION.xml" "$RC_DIR/HomeRec.dmg"
```

After the pass, get the digest of the file you tested and verify its sidecar.

```bash
(
  set -eo pipefail
  cd "$RC_DIR"
  shasum -a 256 HomeRec.dmg | cmp - HomeRec.dmg.sha256
  shasum -a 256 HomeRec.dmg
)
```

Add the newest entry to the run log with the version, date and results. Record
the full `$SOURCE_COMMIT` and digest in the two fields documented in the run
log. Commit only `docs/manual-acceptance.md` and run this gate before merging.

```bash
scripts/check-docs.sh --candidate "$VERSION" "$RC_DIR/HomeRec.dmg"
```

### 5. Merge, verify the merged tree, then tag

On `main`, run the same candidate check before tagging. It compares all tracked
paths, including packaging assets and release notes, with the source recorded
in the run log. Only the acceptance log is excluded. If the check reports a
tree difference, build and test a new candidate from the updated source.

```bash
(
  set -e
  git checkout main
  git pull --ff-only
  scripts/check-docs.sh --candidate "$VERSION" "$RC_DIR/HomeRec.dmg"
  git tag -a "v$VERSION" -m "Home Rec v$VERSION"
  git push origin "refs/tags/v$VERSION"
  scripts/check-docs.sh --release "$VERSION" "$RC_DIR/HomeRec.dmg"
)
```

### 6. Publish the GitHub Release with the tested DMG

Run this from the clean checkout at the release commit. The gate requires the
local and published tags to resolve to the checked commit. GitHub's
`--verify-tag` also requires a published tag.

```bash
scripts/check-docs.sh --release "$VERSION" "$RC_DIR/HomeRec.dmg" &&
  ( set -o pipefail; cd "$RC_DIR" && shasum -a 256 HomeRec.dmg | cmp - HomeRec.dmg.sha256 ) &&
  gh release create "v$VERSION" --verify-tag \
    --title "Home Rec v$VERSION" \
    --notes-file <(awk -v v="$VERSION" 'index($0, "## [" v "]") == 1 {f=1; next} /^## \[/ {f=0} f' CHANGELOG.md | sed '/^---$/d') \
    "$RC_DIR/HomeRec.dmg" \
    "$RC_DIR/HomeRec.dmg.sha256"
```

### 7. Verify the appcast enclosure before deploying it

Download the public DMG from the version-pinned enclosure URL in the saved
appcast item. Check those bytes against the digest in the committed acceptance
log. The sidecar must contain the canonical checksum line for `HomeRec.dmg`.

```bash
(
  set -eo pipefail
  BASE_URL="https://github.com/melissa-pereira-deel/home-rec/releases/download/v$VERSION"
  ENCLOSURE_URL=$(python3 - "$RC_DIR/appcast-item-$VERSION.xml" "$BASE_URL/HomeRec.dmg" <<'PYTHON'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

item_path, expected_url = sys.argv[1:]
fragment = Path(item_path).read_text(encoding="utf-8")
root = ET.fromstring(
    '<feed xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
    + fragment + "</feed>"
)
enclosures = root.findall("./item/enclosure")
if len(root) != 1 or len(enclosures) != 1:
    sys.exit("Expected one appcast item with exactly one enclosure.")

url = enclosures[0].get("url")
if url != expected_url:
    sys.exit(f"Expected version-pinned enclosure {expected_url}. Found {url!r}.")
print(url)
PYTHON
  )
  PUBLIC_DIR=$(mktemp -d "${TMPDIR:-/tmp}/HomeRec-public.XXXXXX")
  trap 'rm -r "$PUBLIC_DIR"' EXIT
  curl -fLsS "$ENCLOSURE_URL" -o "$PUBLIC_DIR/HomeRec.dmg"
  scripts/check-docs.sh --release "$VERSION" "$PUBLIC_DIR/HomeRec.dmg"
  curl -fLsS "$BASE_URL/HomeRec.dmg.sha256" -o "$PUBLIC_DIR/HomeRec.dmg.sha256"
  ( cd "$PUBLIC_DIR" && shasum -a 256 HomeRec.dmg | cmp - HomeRec.dmg.sha256 )
)
```

### 8. Verify the website download

```bash
curl -fLsSI https://github.com/melissa-pereira-deel/home-rec/releases/latest/download/HomeRec.dmg \
  | grep -Ei "^(HTTP|content-length|content-type)"
```

Expect a redirect to the new release's `HomeRec.dmg` and a successful CDN
response with the candidate's file size.

### 9. Publish the appcast entry — after the release, never before

After the published DMG passes step 7, paste the original
`$RC_DIR/appcast-item-$VERSION.xml` into `<channel>` in `public/appcast.xml`
in `home-rec-site`, **newest first**. Open a PR and wait for the site's feed
validation (BL-176). Merge to deploy the feed, then run the live-feed checks in
the checklist's **Auto-update** section.

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

1. Remove the affected version's item from `public/appcast.xml` in
   `home-rec-site` and deploy the feed change. Fetch the live appcast with a
   cache-busting query string and confirm the withdrawn item is gone.
2. Mark the GitHub release as **Pre-release** so the website's `latest`
   download falls back to the previous release. The appcast's version-pinned
   enclosure is independent of that alias.
3. Ship the fix as a new release with a higher build number so Sparkle can
   update installations that received the withdrawn release.

## Notes

- The build script is idempotent. Re-running overwrites `dist/`. To preserve a
  prior artifact, copy `dist/HomeRec.dmg` aside before re-running.
- `dist/` is git-ignored. Artifacts only exist locally and on GitHub Releases.
- Signing identity and notarytool credentials never leave the Keychain.

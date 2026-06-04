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
- A stored notarytool profile in the Keychain. Verify with:
  ```bash
  xcrun notarytool history --keychain-profile "HomeRecNotary"
  ```
- `create-dmg` installed: `brew install create-dmg`
- `gh` CLI authenticated against the repo: `gh auth status`

## Per-release flow

Run all of this from the repo root.

### 1. Decide the version

Bump `MARKETING_VERSION` in `HomeRec/HomeRec.xcodeproj` (Xcode → target →
General → Version) if this release contains code changes. The build script
reads it and tags the release with it. Use [SemVer](https://semver.org).

### 2. Confirm `main` is clean and up to date

```bash
git checkout main
git pull --ff-only
git status --short    # should be empty
```

### 3. Tag the release

```bash
VERSION=$(awk -F' = ' '/MARKETING_VERSION/ {gsub(/[;\" ]/, "", $2); print $2; exit}' \
            HomeRec/HomeRec.xcodeproj/project.pbxproj)
git tag -a "v$VERSION" -m "Home Rec v$VERSION"
git push origin "v$VERSION"
```

### 4. Build the notarized DMG

```bash
TEAM_ID=S3J47F2UXA AC_PROFILE=HomeRecNotary ./scripts/build-dmg.sh
```

This runs archive → Developer ID sign → notarize → staple → DMG → notarize → staple → verify, and emits two artifacts:

- `dist/HomeRec.dmg`
- `dist/HomeRec.dmg.sha256`

Apple's notary service typically returns Accepted in a few minutes. Outliers
of 60–90 minutes happen during queue spikes — that's normal, the script
waits.

### 5. Publish the GitHub Release

```bash
gh release create "v$VERSION" \
  --title "Home Rec v$VERSION" \
  --notes-file <(awk '/^## \['"$VERSION"'\]/,/^## \[/' CHANGELOG.md | sed '$d') \
  dist/HomeRec.dmg \
  dist/HomeRec.dmg.sha256
```

If the CHANGELOG section isn't ready (release notes draft), pass `--notes "…"` inline instead.

### 6. Verify the public URL

```bash
curl -sI -L https://github.com/melissa-pereira-deel/home-rec/releases/latest/download/HomeRec.dmg \
  | grep -E "^(HTTP|content-length|content-type)"
```

Expected: a 302 → 200 chain ending at the CDN-hosted asset, `content-type: application/x-apple-diskimage`, `content-length` matching the local file size.

### 7. Confirm the SHA-256 sidecar

A downloader can verify the artifact didn't change in transit:

```bash
curl -sL -o /tmp/HomeRec.dmg https://github.com/melissa-pereira-deel/home-rec/releases/latest/download/HomeRec.dmg
curl -sL -o /tmp/HomeRec.dmg.sha256 https://github.com/melissa-pereira-deel/home-rec/releases/latest/download/HomeRec.dmg.sha256
( cd /tmp && shasum -a 256 -c HomeRec.dmg.sha256 )
```

Expected: `HomeRec.dmg: OK`

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

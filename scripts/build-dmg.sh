#!/usr/bin/env bash
#
# build-dmg.sh — Archive, Developer ID sign, notarize, staple, and package
# Home Rec as a distributable .dmg. (BL-030–033)
#
# Run end-to-end for the v1.0 release (2026-06-04). Requires an Apple Developer
# account, a Developer ID Application identity in your Keychain, and a stored
# notarytool profile. No secrets are embedded; everything sensitive comes from
# your environment/Keychain.
#
# Prerequisites:
#   - Xcode + command line tools
#   - create-dmg:  brew install create-dmg
#   - A Developer ID Application identity in Keychain
#   - A stored notarytool profile, created once with:
#       xcrun notarytool store-credentials "HomeRecNotary" \
#         --apple-id "you@example.com" --team-id "TEAMID" --password "<app-specific-pw>"
#
# Required environment variables:
#   TEAM_ID      Apple Developer Team ID (e.g. ABCDE12345)
#   AC_PROFILE   notarytool keychain profile name (e.g. HomeRecNotary)
#
# Usage:
#   TEAM_ID=ABCDE12345 AC_PROFILE=HomeRecNotary ./scripts/build-dmg.sh

set -euo pipefail

PROJECT="HomeRec/HomeRec.xcodeproj"
SCHEME="HomeRec"
BUILT_APP_NAME="HomeRec"   # what xcodebuild produces (PRODUCT_NAME / TARGET_NAME)
APP_NAME="Home Rec"        # user-facing bundle name (drives the Finder/Dock label)
CONFIG="Release"
VOL_ICON="$(pwd)/Assets/AppIcon.icns"
VERSION="$(awk -F' = ' '/MARKETING_VERSION/ {gsub(/[;\" ]/, "", $2); print $2; exit}' \
             "$PROJECT/project.pbxproj")"
: "${VERSION:=0.0.0}"
DIST_DIR="$(pwd)/dist"
ARCHIVE="$DIST_DIR/$BUILT_APP_NAME.xcarchive"
EXPORT_DIR="$DIST_DIR/export"
APP="$EXPORT_DIR/$APP_NAME.app"   # after the rename below
# DMG filename is versionless (`HomeRec.dmg`) so the GitHub "releases/latest/download"
# URL pattern stays stable across releases. The version is visible inside the bundle
# (Info.plist CFBundleShortVersionString) and in the GitHub release page itself.
DMG="$DIST_DIR/HomeRec.dmg"

: "${TEAM_ID:?Set TEAM_ID to your Apple Developer Team ID}"
: "${AC_PROFILE:?Set AC_PROFILE to your stored notarytool profile name}"

# Ensure the non-iCloud staging directory (defined later) is cleaned up on exit.
NON_ICLOUD_STAGING=""
cleanup() {
  if [[ -n "$NON_ICLOUD_STAGING" && -d "$NON_ICLOUD_STAGING" ]]; then
    rm -rf "$NON_ICLOUD_STAGING"
  fi
}
trap cleanup EXIT

command -v create-dmg >/dev/null 2>&1 || {
  echo "error: create-dmg not found. Install with: brew install create-dmg" >&2
  exit 1
}

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "==> Archiving ($CONFIG)…"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime"

echo "==> Exporting (Developer ID)…"
cat > "$DIST_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>manual</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$DIST_DIR/ExportOptions.plist"

# The build product is "HomeRec.app" (PRODUCT_NAME), but the user-facing bundle
# should be "Home Rec.app" so Finder/Dock show "Home Rec". Renaming a bundle is
# signature-safe (the signature covers contents, not the enclosing filename).
mv "$EXPORT_DIR/$BUILT_APP_NAME.app" "$APP"

# Strip iCloud-attached extended attributes (com.apple.FinderInfo, quarantine, etc.)
# that codesign refuses to accept. Safe: Mach-O code signatures live inside the
# binary (LC_CODE_SIGNATURE), not in xattrs, so clearing xattrs preserves signing.
#
# Robust fix: copy the .app to a non-iCloud staging directory in /tmp before
# verify+notarize+DMG. iCloud Drive aggressively re-attaches FinderInfo to files
# inside its sync root within milliseconds of any modification, racing with our
# strip step. Working from /tmp eliminates the race entirely. The final DMG is
# moved back to dist/ at the end.
NON_ICLOUD_STAGING="${TMPDIR:-/tmp}/HomeRec-build-$$"
rm -rf "$NON_ICLOUD_STAGING"
mkdir -p "$NON_ICLOUD_STAGING"
echo "==> Moving .app out of iCloud to $NON_ICLOUD_STAGING …"
mv "$APP" "$NON_ICLOUD_STAGING/"
APP="$NON_ICLOUD_STAGING/$APP_NAME.app"
xattr -cr "$APP"

echo "==> Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Notarizing the app…"
ditto -c -k --keepParent "$APP" "$DIST_DIR/$APP_NAME.zip"
xcrun notarytool submit "$DIST_DIR/$APP_NAME.zip" --keychain-profile "$AC_PROFILE" --wait
xcrun stapler staple "$APP"

echo "==> Building DMG…"
DMG_VOLICON_ARGS=()
if [[ -f "$VOL_ICON" ]]; then
  DMG_VOLICON_ARGS=(--volicon "$VOL_ICON")
fi
create-dmg \
  --volname "Home Rec" \
  "${DMG_VOLICON_ARGS[@]}" \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 175 190 \
  --app-drop-link 425 190 \
  "$DMG" \
  "$APP"

echo "==> Notarizing + stapling the DMG…"
xcrun notarytool submit "$DMG" --keychain-profile "$AC_PROFILE" --wait
xcrun stapler staple "$DMG"

echo "==> Validating Gatekeeper acceptance…"
# The DMG ticket: a stapled notarization ticket is the canonical Gatekeeper signal.
xcrun stapler validate "$DMG"
# The real-world Gatekeeper check is on the .app inside the mounted DMG. We mount,
# probe with `spctl --assess --type execute`, and detach. `spctl --type install` on
# the DMG file would look for a codesign signature on the container itself, which
# we deliberately don't add — the staple is sufficient.
MOUNT_DIR="/Volumes/Home Rec"
hdiutil attach "$DMG" -nobrowse -readonly >/dev/null
spctl --assess --type execute --verbose=2 "$MOUNT_DIR/$APP_NAME.app"
hdiutil detach "$MOUNT_DIR" >/dev/null

echo "==> Emitting SHA-256 sidecar…"
( cd "$DIST_DIR" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256" )

# ---------------------------------------------------------------------------
# Sparkle appcast entry (BL-034)
#
# Sparkle downloads this same notarized, stapled DMG — it contains
# "Home Rec.app", which is the name the bundle carries once installed. Feeding
# it an archive built before the rename above would install a *second*,
# differently-named copy alongside the original, because Sparkle replaces the
# bundle at its installed path rather than by identifier.
# ---------------------------------------------------------------------------
echo "==> Signing the DMG for Sparkle…"

# `sign_update` ships inside the resolved Sparkle package. Set SPARKLE_BIN to
# override; otherwise take the copy Xcode has already checked out.
if [[ -z "${SPARKLE_BIN:-}" ]]; then
  SPARKLE_BIN="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
    -path "*/artifacts/sparkle/Sparkle/bin/sign_update" -type f 2>/dev/null | head -1)"
fi
[[ -x "${SPARKLE_BIN:-}" ]] || {
  echo "error: sign_update not found. Build once so SPM resolves Sparkle," >&2
  echo "       or set SPARKLE_BIN=/path/to/sign_update." >&2
  exit 1
}

# --- The keypair-identity check ---------------------------------------------
# The unit suite proves SUPublicEDKey is a well-formed Ed25519 key, but it runs
# in CI where there is no Keychain, so it cannot prove the key is *ours*. This
# can, and this is the only place that can.
#
# The failure it prevents is silent and permanent: sign the appcast with private
# key A while the app ships public key B, and every copy of this release rejects
# every update forever, with the build, the signing and the launch all reporting
# success. Cheaper to fail here than to strand a release.
#
# `-p` only looks up and prints; unlike a bare `generate_keys` it never creates
# a key, so running it in a build script has no side effects.
GENERATE_KEYS="${SPARKLE_BIN%/sign_update}/generate_keys"
if [[ -x "$GENERATE_KEYS" ]]; then
  echo "==> Verifying the shipped public key matches the signing key…"
  KEYCHAIN_PUBKEY="$("$GENERATE_KEYS" -p 2>/dev/null | tr -d '[:space:]')"
  BUNDLE_PUBKEY="$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$APP/Contents/Info.plist" 2>/dev/null | tr -d '[:space:]')"
  if [[ -z "$KEYCHAIN_PUBKEY" ]]; then
    echo "error: no Sparkle private key in the login Keychain. Run generate_keys" >&2
    echo "       on this Mac, or import it with generate_keys -f." >&2
    exit 1
  fi
  if [[ "$KEYCHAIN_PUBKEY" != "$BUNDLE_PUBKEY" ]]; then
    echo "error: SUPublicEDKey in the built app does NOT match the private key" >&2
    echo "       that would sign this release. Shipping this would make every" >&2
    echo "       update fail verification, permanently, for everyone who" >&2
    echo "       installs it. Paste this into HomeRec/Info.plist:" >&2
    echo "         $KEYCHAIN_PUBKEY" >&2
    echo "       (bundle currently has: ${BUNDLE_PUBKEY:-<missing>})" >&2
    exit 1
  fi
else
  echo "warning: generate_keys not found — skipping the keypair-identity check." >&2
  echo "         Confirm by hand that SUPublicEDKey matches your signing key." >&2
fi

# Reads the EdDSA private key from the login Keychain, where generate_keys put
# it. It is never written to disk and never enters this repo.
SIG_ATTRS="$("$SPARKLE_BIN" "$DMG")"

# ⚠️ Version-pinned URL, deliberately NOT the `releases/latest/download/...`
# form the website uses. An appcast entry is permanent and must keep pointing at
# the exact file its signature was computed over. Pointed at "latest", every
# past entry would silently start resolving to a newer DMG, the signature check
# would fail, and Sparkle would refuse the update with no obvious cause.
ENCLOSURE_URL="https://github.com/melissa-pereira-deel/home-rec/releases/download/v$VERSION/$(basename "$DMG")"
APPCAST_ITEM="$DIST_DIR/appcast-item-$VERSION.xml"

cat > "$APPCAST_ITEM" <<ITEM
    <item>
      <title>$VERSION</title>
      <pubDate>$(date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$(defaults read "$APP/Contents/Info" CFBundleVersion)</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$(defaults read "$APP/Contents/Info" LSMinimumSystemVersion)</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/melissa-pereira-deel/home-rec/releases/tag/v$VERSION</sparkle:releaseNotesLink>
      <enclosure url="$ENCLOSURE_URL" $SIG_ATTRS type="application/octet-stream" />
    </item>
ITEM

echo "==> Done: $DMG (v$VERSION)"
echo "         $(awk '{print $1}' "$DMG.sha256")  sha256"
echo
echo "    Sparkle appcast entry written to:"
echo "      $APPCAST_ITEM"
echo
echo "    Order matters: publish the GitHub release for tag v$VERSION FIRST —"
echo "    the entry's URL points at it — then paste the item into <channel> in"
echo "    home-rec-site/public/appcast.xml, newest first, and deploy."

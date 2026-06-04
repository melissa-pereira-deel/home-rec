#!/usr/bin/env bash
#
# build-dmg.sh — Archive, Developer ID sign, notarize, staple, and package
# Home Rec as a distributable .dmg. (BL-030–033)
#
# ⚠️ UNTESTED SCAFFOLD: this orchestrates the standard direct-distribution flow
# but has not been run. It requires an Apple Developer account, a Developer ID
# Application identity in your Keychain, and a stored notarytool profile. No
# secrets are embedded; everything sensitive comes from your environment/Keychain.
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
echo "==> Stripping iCloud xattrs…"
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

echo "==> Done: $DMG (v$VERSION)"
echo "         $(awk '{print $1}' "$DMG.sha256")  sha256"

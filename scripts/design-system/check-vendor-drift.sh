#!/usr/bin/env bash
#
# Verify that nothing under DesignSystem/Vendor/ has been edited.
#
# The vendored design-system files are byte-identical copies of GlassKit from the
# ui-explorations repo. That property is the entire reason the vendoring is
# maintainable: it means a future re-sync is a clean diff rather than an
# archaeology exercise. Editing a vendored file breaks it silently — nothing
# fails, nothing warns, and the cost only lands months later on the day someone
# tries to pull upstream changes and finds every file conflicts.
#
# So the check has to be mechanical. A git blob SHA is the content hash of a
# file, independent of its path — which matters here because the vendored paths
# deliberately differ from upstream's. Re-hashing each vendored file and
# comparing against the SHA recorded at sync time answers "did we drift?" without
# needing the network, the upstream remote, or even the upstream objects.
#
# Local changes belong in DesignSystem/Adapters/, which this script ignores.
# If a vendored file genuinely must change, see docs/design-system-vendoring.md —
# the patch procedure exists, but it is deliberately the last resort.
#
# Exits non-zero on drift. Run in CI and before a release.

set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

PROVENANCE="HomeRec/HomeRec/DesignSystem/DesignSystemProvenance.swift"
VENDOR_DIR="HomeRec/HomeRec/DesignSystem/Vendor"

fail=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=1; }
note() { printf '  \033[33m•\033[0m %s\n' "$1"; }

[ -f "$PROVENANCE" ] || { echo "Missing $PROVENANCE"; exit 1; }
[ -d "$VENDOR_DIR" ] || { echo "Missing $VENDOR_DIR"; exit 1; }

commit=$(sed -nE 's/.*static let commit = "([0-9a-f]+)".*/\1/p' "$PROVENANCE")
echo "Checking vendored design-system files against ${commit:0:12}…"
echo

# Recorded manifest: "<relative path> <blob sha>" per line. Scoped to the `blobs`
# block, because `patchedBlobs` below it has identical line shape and would
# otherwise be read as a seventeenth vendored file.
manifest=$(sed -n '/static let blobs/,/^    \]/p' "$PROVENANCE" \
    | sed -nE 's/^[[:space:]]*"([^"]+)": "([0-9a-f]{40})",?[[:space:]]*$/\1 \2/p')
[ -n "$manifest" ] || { echo "Could not parse the blob map from $PROVENANCE"; exit 1; }

# Files carrying a recorded patch, and the hash they should have after it.
patched=$(sed -n '/patchedBlobs/,/^    \]/p' "$PROVENANCE" \
    | sed -nE 's/^[[:space:]]*"([^"]+)": "([0-9a-f]{40})",?[[:space:]]*$/\1 \2/p')

patched_hash_for() {
    [ -n "$patched" ] || return 1
    while read -r p h; do
        [ "$p" = "$1" ] && { echo "$h"; return 0; }
    done <<< "$patched"
    return 1
}

# --- every recorded file still matches its recorded content -----------------
while read -r path sha; do
    [ -n "$path" ] || continue
    file="$VENDOR_DIR/$path"
    if [ ! -f "$file" ]; then
        bad "$path — recorded but missing"
        continue
    fi
    actual=$(git hash-object "$file")

    # A patched file is expected to differ from upstream — but only in exactly
    # the way the recorded patch says. Anything else is still drift.
    if expected=$(patched_hash_for "$path"); then
        if [ "$actual" = "$expected" ]; then
            note "$path — patched (see scripts/design-system/patches/)"
        else
            bad "$path — EDITED beyond its recorded patch (expected ${expected:0:12}, found ${actual:0:12})"
        fi
        continue
    fi

    if [ "$actual" = "$sha" ]; then
        ok "$path"
    else
        bad "$path — EDITED (expected ${sha:0:12}, found ${actual:0:12})"
    fi
done <<< "$manifest"

# --- and no unrecorded file has been added ----------------------------------
# An untracked addition is drift too: it will not survive a re-sync, and nobody
# will know where it came from.
while read -r file; do
    path=${file#"$VENDOR_DIR/"}
    if ! grep -q "\"$path\"" "$PROVENANCE"; then
        bad "$path — present in Vendor/ but not recorded in the provenance map"
    fi
done < <(find "$VENDOR_DIR" -name '*.swift' | sort)

echo
if [ "$fail" -eq 0 ]; then
    patch_count=$(printf '%s' "$patched" | grep -c . || true)
    if [ "${patch_count:-0}" -gt 0 ]; then
        echo "No unrecorded drift. $patch_count file(s) carry a recorded patch —"
        echo "each one is a file that no longer diffs cleanly against upstream."
    else
        echo "Vendored files are byte-identical to upstream. Re-sync stays cheap."
    fi
else
    echo "Vendored files have drifted from upstream."
    echo "Move the change into DesignSystem/Adapters/, or follow the patch"
    echo "procedure in docs/design-system-vendoring.md and re-run sync.sh."
fi
exit "$fail"

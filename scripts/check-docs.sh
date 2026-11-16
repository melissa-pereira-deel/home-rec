#!/usr/bin/env bash
#
# Verify that what the docs claim is still true.
#
# Every stale entry in the old CLAUDE.md tech-debt table was detectable by a
# grep — the table described a deleted file as a live hazard for months. Writing
# things down more carefully does not fix that; *checking* them does.
#
# Run before a release (it is a step in docs/manual-acceptance.md), or from a
# SessionStart hook. Exits non-zero when reality and the docs disagree.
#
# Two of its inputs are not part of this public repository: CLAUDE.md and
# private/tech-debt.md are both gitignored. Every check that reads one of them
# is skipped, with a printed note, when the file is absent, so CI can run the
# public checks on a clean checkout (BL-160).
#
# Be clear about what that CI run is worth. On a clean checkout the script can
# only check what is public: the code invariants that need no doc to compare
# against (sandbox off, the .screen handler, the version settings, the
# nonisolated encoders), the rot guards against README.md, and the release
# evidence in README.md and docs/manual-acceptance.md. Everything it verifies
# against CLAUDE.md or private/tech-debt.md is verified only where those files
# exist — on the maintainer's machine. A green CI run says nothing about them.

set -uo pipefail

mode=docs
if [ "$#" -eq 3 ] && [[ "$1" = --candidate || "$1" = --release ]]; then
  mode="${1#--}"
  requested_version="$2"
  dmg="$3"
elif [ "$#" -ne 0 ]; then
  echo "Usage: $0 [{--candidate|--release} VERSION DMG]" >&2
  exit 2
fi

# Resolve relative artifact paths against the caller's working directory.
if [ "$mode" != docs ]; then
  case "$dmg" in
    /*) ;;
    *) dmg="$PWD/$dmg" ;;
  esac
fi
cd "$(dirname "$0")/.." || exit 1

fail=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=1; }
note() { printf '  \033[33m•\033[0m %s\n' "$1"; }

echo "Checking documented facts against the codebase…"
echo

# --- CLAUDE.md constraints that are mechanically checkable -------------------
echo "CLAUDE.md constraints:"

grep -q 'ENABLE_APP_SANDBOX = NO' HomeRec/HomeRec.xcodeproj/project.pbxproj \
  && ok "App Sandbox is disabled (constraint 1)" \
  || bad "App Sandbox is NOT disabled — audio capture will silently break (constraint 1)"

grep -q 'type: .screen' HomeRec/HomeRec/ScreenCaptureAudioManager.swift \
  && ok "Dummy .screen output handler present (constraint 2)" \
  || bad "The .screen output handler is gone — startCapture() will throw (constraint 2)"

target=$(grep -m1 'MACOSX_DEPLOYMENT_TARGET' HomeRec/HomeRec.xcodeproj/project.pbxproj | tr -dc '0-9.')
if [ ! -f CLAUDE.md ]; then
  note "CLAUDE.md not present — skipping the deployment-target match (constraint 4)"
elif grep -q "Minimum deployment: macOS ${target%.}" CLAUDE.md \
   || grep -q "macOS ${target%.}" CLAUDE.md; then
  ok "Deployment target ${target%.} matches CLAUDE.md (constraint 4)"
else
  bad "project.pbxproj says ${target%.} but CLAUDE.md disagrees (constraint 4)"
fi

# The build script reads the first marketing version. Detect a missed bump in
# any of the project or target configurations before that value can mask it.
project_setting() {
  awk -v key="$1" '
    $1 == key {
      count++
      if ($2 != "=" || NF != 3 || !sub(/;$/, "", $3)) invalid = 1
      if ($3 ~ /^"[^"]*"$/) gsub(/"/, "", $3)
      if (count > 1 && "setting:" value != "setting:" $3) invalid = 1
      value = $3
    }
    END {
      if (count != 6 || invalid) exit 1
      print value
    }
  ' HomeRec/HomeRec.xcodeproj/project.pbxproj
}

if VERSION=$(project_setting MARKETING_VERSION) && [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){2}$ ]]; then
  ok "All six MARKETING_VERSION settings agree on $VERSION"
else
  bad "Expected six identical MARKETING_VERSION settings in major.minor.patch form"
  VERSION=
fi
if BUILD_VERSION=$(project_setting CURRENT_PROJECT_VERSION) && [[ "$BUILD_VERSION" =~ ^[0-9]+$ ]]; then
  ok "All six CURRENT_PROJECT_VERSION settings agree on $BUILD_VERSION"
else
  bad "Expected six identical numeric CURRENT_PROJECT_VERSION settings"
fi

# The audio hot path must stay off the main actor. This is the class of bug that
# was reintroduced into the very file written to fix it.
unannotated=0
for f in WAVWriter M4AEncoder FLACEncoder AudioFormatNormalizer; do
  path="HomeRec/HomeRec/$f.swift"
  [ -f "$path" ] || continue
  grep -qE "^nonisolated (final )?class $f" "$path" || { bad "$f is not declared nonisolated (constraint 3)"; unannotated=1; }
done
[ "$unannotated" -eq 0 ] && ok "Audio-path encoders are all nonisolated (constraint 3)"

echo

# --- private/tech-debt.md (skipped if absent) --------------------------------
if [ ! -f private/tech-debt.md ]; then
  echo "private/tech-debt.md: not present — skipping tech-debt checks"
  echo
else
echo "private/tech-debt.md:"

n=$(grep -c 'static var' HomeRec/HomeRec/OverflowMenu.swift)
[ "$n" -gt 0 ] \
  && note "TD-010 still open: $n mutable statics in OverflowMenu" \
  || bad "TD-010 appears FIXED — remove it from private/tech-debt.md"

fi

echo

# --- things the docs must NOT claim any more ---------------------------------
echo "Rot guards:"

# Every doc that names source files, not just CLAUDE.md. The README carried
# `DebugLogger.swift` in its project tree for months while this guard reported
# "no references to deleted DebugLogger.swift" — it was only ever looking at one
# file. A guard that checks a subset of the places a claim can rot is worse than
# none, because it reports success — so a doc that is absent is named as
# skipped, never silently passed over.
GHOST_DOCS="README.md"
if [ -f CLAUDE.md ]; then
  GHOST_DOCS="CLAUDE.md $GHOST_DOCS"
else
  note "CLAUDE.md not present — ghost-file checks cover README.md only"
fi

for ghost in DebugLogger.swift WaveformView.swift ShelfMenu.swift; do
  if [ -f "HomeRec/HomeRec/$ghost" ]; then
    note "$ghost exists"
    continue
  fi
  found=""
  for doc in $GHOST_DOCS; do
    grep -q "$ghost" "$doc" 2>/dev/null && found="$found $doc"
  done
  if [ -n "$found" ]; then
    bad "$ghost does not exist, but is still referenced in:$found"
  else
    ok "No references to deleted $ghost"
  fi
done

n=$(grep -rc 'NSLog' HomeRec/HomeRec/ --include='*.swift' 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
[ "$n" -eq 0 ] \
  && ok "No NSLog calls (the old TD-004 is genuinely gone)" \
  || note "$n NSLog call(s) — migrate to Log.*"

if [ ! -f CLAUDE.md ]; then
  note "CLAUDE.md not present — skipping its line-count check"
else
  lines=$(wc -l < CLAUDE.md)
  [ "$lines" -le 200 ] \
    && ok "CLAUDE.md is $lines lines (target: under 200)" \
    || bad "CLAUDE.md is $lines lines — over the 200-line target, which reduces instruction adherence"
fi

echo

# --- release evidence (BL-179) -----------------------------------------------
# v1.1.1 shipped on 2026-08-22 with no manual-acceptance entry: the run log
# stopped at v1.1.0. That is the release which fixed microphone recording, and
# this project's own standing lesson is that the automated suite has passed
# while a shipped feature was broken three separate times — the manual pass is
# the only gate that has ever caught those. An unenforced checklist is a
# checklist that gets skipped exactly when the release is urgent.
echo "Release evidence:"

# Read only the newest version entry. A matching field in an older entry
# cannot fill a gap in the current one.
runlog=$(awk '
  /^## v[0-9]/ {
    if (entry) exit
    entry = 1
  }
  entry { print }
' docs/manual-acceptance.md)
runlog_version=$(printf '%s\n' "$runlog" | awk 'NR == 1 { print substr($2, 2) }')
source_commit=
accepted_digest=

runlog_field() {
  awk -v label="- $1:" '
    index($0, label) == 1 {
      count++
      value = substr($0, length(label) + 1)
    }
    END {
      if (count == 1 && value ~ /^ `[0-9a-f]+`$/) {
        print substr(value, 3, length(value) - 3)
      }
    }
  ' <<< "$runlog"
}

if [ -n "$VERSION" ]; then
  if [ "$runlog_version" != "$VERSION" ]; then
    bad "MARKETING_VERSION is $VERSION but the newest run-log entry is v${runlog_version:-<missing>}"
  elif [ "$VERSION" = 1.1.3 ] && [ "$mode" = docs ]; then
    ok "Manual-acceptance run log covers historical v$VERSION"
  else
    source_commit=$(runlog_field "Tested source commit")
    accepted_digest=$(runlog_field "Tested DMG SHA-256")
    if [[ "$source_commit" =~ ^[0-9a-f]{40}$ && "$source_commit" =~ [1-9a-f] ]]; then
      ok "Manual-acceptance run log records a full source commit for v$VERSION"
    else
      bad "The v$VERSION run log needs one full Tested source commit"
    fi
    if [[ "$accepted_digest" =~ ^[0-9a-f]{64}$ && "$accepted_digest" =~ [1-9a-f] ]]; then
      ok "Manual-acceptance run log records a DMG SHA-256 for v$VERSION"
    else
      bad "The v$VERSION run log needs one full Tested DMG SHA-256"
    fi
  fi

  if grep -Fq "badge/Version-$VERSION-" README.md; then
    ok "README version badge matches v$VERSION"
  else
    bad "README version badge does not say $VERSION"
  fi
  grep -Fq "**Version:** $VERSION " README.md \
    && ok "README footer matches v$VERSION" \
    || bad "README footer does not say $VERSION"
fi

if [ "$mode" != docs ] && [ "$fail" -eq 0 ]; then
  if [ "$requested_version" != "$VERSION" ]; then
    bad "Requested release v$requested_version differs from project version v$VERSION"
  fi
  if ! status=$(git status --porcelain) || [ -n "$status" ]; then
    bad "Release verification requires a clean checkout"
  fi
  if [ "$(git cat-file -t "$source_commit" 2>/dev/null)" != commit ]; then
    bad "Tested source commit $source_commit is unavailable in this checkout"
  elif git diff --quiet "$source_commit" HEAD -- . ':(exclude)docs/manual-acceptance.md'; then
    ok "HEAD matches the tested tree outside docs/manual-acceptance.md"
  else
    bad "HEAD differs from the tested tree outside docs/manual-acceptance.md"
    git diff --name-status "$source_commit" HEAD -- . ':(exclude)docs/manual-acceptance.md'
  fi
  if digest=$(shasum -a 256 < "$dmg") && [ "${digest%% *}" = "$accepted_digest" ]; then
    ok "DMG SHA-256 matches the manual-acceptance run log"
  else
    bad "DMG SHA-256 does not match the manual-acceptance run log"
  fi

  if [ "$mode" = release ]; then
    tag="refs/tags/v$VERSION"
    head=$(git rev-parse HEAD)
    if [ "$(git rev-parse --verify "${tag}^{commit}" 2>/dev/null)" != "$head" ]; then
      bad "Local tag v$VERSION must point to HEAD"
    elif remote_refs=$(git ls-remote --exit-code origin "$tag" "${tag}^{}"); then
      # Annotated tags include a peeled ref. Lightweight tags directly name a commit.
      remote_commit=$(printf '%s\n' "$remote_refs" | awk -v tag="$tag" '
        $2 == tag { direct = $1 }
        $2 == tag "^{}" { peeled = $1 }
        END { print (peeled ? peeled : direct) }
      ')
      if [ "$remote_commit" = "$head" ]; then
        ok "Published tag v$VERSION points to the verified commit"
      else
        bad "Published tag v$VERSION points to $remote_commit instead of $head"
      fi
    else
      bad "Could not verify published tag v$VERSION on origin"
    fi
  fi
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "All documented facts still hold."
else
  echo "Docs and reality disagree. Fix the code or fix the docs — do not ignore this."
fi
exit "$fail"

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
# The tech-debt checks read private/tech-debt.md, which is not part of this
# public repository. They are skipped when it is absent, so a contributor
# cloning the repo gets the CLAUDE.md and rot-guard checks and no spurious
# failures.

set -uo pipefail
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
if grep -q "Minimum deployment: macOS ${target%.}" CLAUDE.md 2>/dev/null \
   || grep -q "macOS ${target%.}" CLAUDE.md; then
  ok "Deployment target ${target%.} matches CLAUDE.md (constraint 4)"
else
  bad "project.pbxproj says ${target%.} but CLAUDE.md disagrees (constraint 4)"
fi

count=$(grep -c 'MARKETING_VERSION' HomeRec/HomeRec.xcodeproj/project.pbxproj)
[ "$count" -eq 6 ] \
  && ok "MARKETING_VERSION appears in 6 configs, as documented" \
  || bad "MARKETING_VERSION appears $count times, docs say 6 — find/replace will miss some"

# The audio hot path must stay off the main actor. This is the class of bug that
# was reintroduced into the very file written to fix it.
unannotated=0
for f in WAVWriter M4AEncoder FLACEncoder AudioFormatNormalizer; do
  path="HomeRec/HomeRec/$f.swift"
  [ -f "$path" ] || continue
  grep -qE "^nonisolated (final )?class $f" "$path" || { bad "$f is not declared nonisolated (constraint 12)"; unannotated=1; }
done
[ "$unannotated" -eq 0 ] && ok "Audio-path encoders are all nonisolated (constraint 12)"

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

if grep -rql MonitorController HomeRec/HomeRec/ --include='*.swift' \
   | grep -qv 'MonitorController.swift'; then
  bad "TD-011 appears FIXED (MonitorController is now referenced) — update private/tech-debt.md"
else
  note "TD-011 still open: MonitorController ships but is referenced nowhere"
fi

n=$(grep -rl ScreenCaptureAudioManager HomeRec/HomeRecTests/ 2>/dev/null | wc -l | tr -d ' ')
[ "$n" -eq 0 ] \
  && note "TD-013 still open: no test touches the real ScreenCaptureAudioManager" \
  || bad "TD-013 appears FIXED ($n test file(s) reference it) — update private/tech-debt.md"
fi

echo

# --- things the docs must NOT claim any more ---------------------------------
echo "Rot guards:"

for ghost in DebugLogger.swift; do
  if [ -f "HomeRec/HomeRec/$ghost" ]; then
    note "$ghost exists"
  elif grep -q "$ghost" CLAUDE.md 2>/dev/null; then
    bad "CLAUDE.md still references $ghost, which does not exist"
  else
    ok "No references to deleted $ghost"
  fi
done

n=$(grep -rc 'NSLog' HomeRec/HomeRec/ --include='*.swift' 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
[ "$n" -eq 0 ] \
  && ok "No NSLog calls (the old TD-004 is genuinely gone)" \
  || note "$n NSLog call(s) — migrate to Log.*"

lines=$(wc -l < CLAUDE.md)
[ "$lines" -le 200 ] \
  && ok "CLAUDE.md is $lines lines (target: under 200)" \
  || bad "CLAUDE.md is $lines lines — over the 200-line target, which reduces instruction adherence"

echo
if [ "$fail" -eq 0 ]; then
  echo "All documented facts still hold."
else
  echo "Docs and reality disagree. Fix the code or fix the docs — do not ignore this."
fi
exit "$fail"

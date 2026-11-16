#!/usr/bin/env bash
#
# Report what a Thread Sanitizer test run actually found, from its .xcresult.
#
#   scripts/tsan-report.sh TestResults.xcresult
#
# Why this exists: TSan writes its reports to the test host's stderr, which
# xcodebuild stores inside the result bundle and never prints to the console.
# For months the CI job was read from the console, so it showed no races while
# every run contained one — and a report halted the host, after which every
# unfinished Swift Testing test was marked "crashed" in 0.000 seconds. A job
# that cannot show what it found, or that it stopped early, is worse than none.
#
# Prints, and in GitHub Actions also annotates and writes to the step summary:
#   - how many tests ran, passed and failed;
#   - how many were marked crashed — the host died, so they never ran;
#   - every TSan report, de-duplicated by its SUMMARY line.
#
# Exit status: 0 clean · 1 TSan reported something · 2 the run is not
# trustworthy (host crashed, no tests ran, or the bundle is unreadable).
# The CI step stays advisory; the status is for the log and for local use.

set -uo pipefail

bundle=${1:-}
if [ -z "$bundle" ] || [ ! -d "$bundle" ]; then
  echo "usage: $0 path/to/TestResults.xcresult" >&2
  exit 2
fi

in_ci=${GITHUB_ACTIONS:-false}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

summary_json=$(xcrun xcresulttool get test-results summary --path "$bundle" 2>/dev/null) || {
  echo "Could not read the result bundle: $bundle" >&2
  [ "$in_ci" = true ] && echo "::error title=TSan run unreadable::xcresulttool could not read $bundle"
  exit 2
}

# passed failed skipped crashed — "crashed" is the host-abort signature: tests
# that never ran because the process hosting them died.
read -r passed failed skipped crashed < <(printf '%s' "$summary_json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
crashed = sum(1 for f in d.get("testFailures", []) if "crashed with signal" in f.get("failureText", ""))
print(d.get("passedTests", 0), d.get("failedTests", 0), d.get("skippedTests", 0), crashed)
')
ran=$((passed + failed))

xcrun xcresulttool export diagnostics --path "$bundle" --output-path "$work/diag" >/dev/null 2>&1
# Reports are colourised when TSAN_OPTIONS is set, so strip ANSI before matching.
find "$work/diag" -name StandardOutputAndStandardError.txt -exec cat {} + 2>/dev/null \
  | sed $'s/\x1b\\[[0-9;]*m//g' > "$work/stderr.txt"
reports=$(grep -c 'WARNING: ThreadSanitizer' "$work/stderr.txt")
grep -E '^SUMMARY: ThreadSanitizer' "$work/stderr.txt" \
  | sed 's/^SUMMARY: ThreadSanitizer: //' | sort | uniq -c | sort -rn > "$work/distinct.txt"
distinct=$(wc -l < "$work/distinct.txt" | tr -d ' ')

echo "Thread Sanitizer run: $bundle"
echo "  tests ran:        $ran ($passed passed, $failed failed, $skipped skipped)"
echo "  host crashed:     $crashed test(s) marked crashed — never ran"
echo "  TSan reports:     $reports ($distinct distinct)"
if [ "$distinct" -gt 0 ]; then
  echo
  sed 's/^/    /' "$work/distinct.txt"
  echo
  echo "  Full reports (stack traces): StandardOutputAndStandardError.txt in the"
  echo "  bundle — xcrun xcresulttool export diagnostics --path <bundle> --output-path <dir>"
fi

status=0
[ "$reports" -gt 0 ] && status=1
if [ "$crashed" -gt 0 ] || [ "$ran" -eq 0 ]; then
  status=2
fi

if [ "$in_ci" = true ]; then
  if [ "$ran" -eq 0 ]; then
    echo "::error title=TSan ran no tests::The result bundle holds no test results. Nothing was checked for races."
  fi
  if [ "$crashed" -gt 0 ]; then
    echo "::error title=TSan host crashed::$crashed tests were marked crashed and never ran, so they were not checked for races. See the bundle's StandardOutputAndStandardError.txt for why the host died."
  fi
  while read -r count line; do
    [ -n "$line" ] && echo "::warning title=ThreadSanitizer (${count}x)::$line"
  done < "$work/distinct.txt"

  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo "### Thread Sanitizer"
      echo
      echo "| Tests ran | Marked crashed (never ran) | TSan reports | Distinct |"
      echo "|---|---|---|---|"
      echo "| $ran | $crashed | $reports | $distinct |"
      if [ "$distinct" -gt 0 ]; then
        echo
        echo '```'
        cat "$work/distinct.txt"
        echo '```'
      fi
    } >> "$GITHUB_STEP_SUMMARY"
  fi
fi

exit "$status"

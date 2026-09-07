#!/usr/bin/env bash
#
# Serve a Sparkle appcast on localhost, so the update path can be rehearsed
# before it is real for anyone.
#
# Why this exists: the only way to know an update *installs* is to watch one
# install. Doing that against the live feed means the first rehearsal is also
# the performance — every user checking for updates in that window gets whatever
# you were testing. This serves the same appcast to one machine instead.
#
# It also makes the tamper check cheap. A signature verifier nobody has watched
# reject something is only known to accept, and flipping a character in a local
# feed is a two-second edit.
#
#   ./scripts/staging-feed.sh <path-to-appcast-item.xml> <path-to.dmg> [port] [kbps]
#
# `build-dmg.sh` writes the item to dist/appcast-item-<version>.xml. Pass that
# and the DMG it describes — the enclosure URL has to resolve to a real file, or
# the rehearsal only proves the feed parses.
#
# ⏱️ **The payload is throttled by default, and that is what makes the interlock
# check possible.** That check needs an overlap: the download still running when
# recording starts, so Sparkle reaches its relaunch point mid-take and has to
# postpone. Over loopback a 2.6 MB image transfers in milliseconds, so the
# window to hit record by hand is effectively zero — the check cannot be
# performed, and the run reports "could not reproduce" for something that was
# never given a chance to happen. At the default rate the same image takes about
# half a minute, which is easy to hit deliberately.
#
# Pass `0` as the fourth argument to serve at full speed.
#
# Then build the *older* version with its feed pointed here — Sparkle requires
# HTTPS for a feed unless the app allows the exception, so the scratch build
# needs both, in HomeRec/Info.plist:
#
#     <key>SUFeedURL</key>
#     <string>http://127.0.0.1:8765/appcast.xml</string>
#     <key>NSAppTransportSecurity</key>
#     <dict>
#       <key>NSAllowsLocalNetworking</key><true/>
#     </dict>
#
# ⚠️ Never commit a build with those two keys. `SUFeedURL` is a permanent
# contract with every copy of the app ever shipped; a scratch value that escapes
# into a release points those copies at a machine that is not on.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

ITEM="${1:?usage: staging-feed.sh <appcast-item.xml> <update.dmg> [port] [kbps]}"
DMG="${2:?usage: staging-feed.sh <appcast-item.xml> <update.dmg> [port] [kbps]}"
PORT="${3:-8765}"
KBPS="${4:-80}"

[ -f "$ITEM" ] || { echo "error: no such item file: $ITEM" >&2; exit 1; }
[ -f "$DMG" ]  || { echo "error: no such DMG: $DMG" >&2; exit 1; }

STAGING_DIR="$(mktemp -d)"
FEED="$STAGING_DIR/appcast.xml"
cp "$DMG" "$STAGING_DIR/$(basename "$DMG")"

# The entry's `length` is what Sparkle checks the download against, and a
# mismatch fails after the download rather than before it. Catch it here.
ITEM_LEN="$(sed -nE 's/.*length="([0-9]+)".*/\1/p' "$ITEM" | head -1)"
REAL_LEN="$(stat -f%z "$DMG")"
if [ -n "$ITEM_LEN" ] && [ "$ITEM_LEN" != "$REAL_LEN" ]; then
  echo "error: the entry says length=$ITEM_LEN but the DMG is $REAL_LEN bytes." >&2
  echo "       The item was built for a different file — re-sign it." >&2
  exit 1
fi

# ⚠️ The enclosure URL has to be rewritten, and for a long time it was not.
#
# `build-dmg.sh` writes the item with a **GitHub** enclosure URL — deliberately,
# because a published appcast entry is permanent and must point at the exact file
# its signature was computed over. This script used to `cat` that item verbatim,
# so the feed it served told Sparkle to download from github.com. The local DMG
# was copied into the staging directory and never fetched.
#
# That silently disabled the whole point of this script. The throttling documented
# at the top is what makes the update-interlock check possible — the download has
# to still be running when recording starts — and over the internet, unthrottled,
# that window is whatever the network gives you rather than the ~30s this script
# promises. Worse, the length cross-check above still passed, because it is the
# same file at the same size, so nothing looked wrong.
#
# Rewrite **only** the enclosure URL. The signature covers the DMG bytes, not the
# feed, so the entry stays valid and the tamper rehearsal still means something.
# (BL-177. The historical results in docs/manual-acceptance.md stand — that run
# used a hand-edited local enclosure, which is what this now does automatically.)
ITEM_LOCAL="$STAGING_DIR/item.xml"
DMG_NAME="$(basename "$DMG")"
python3 - "$ITEM" "$ITEM_LOCAL" "http://127.0.0.1:$PORT/$DMG_NAME" <<'REWRITE' || exit 1
import re, sys

src, dst, local_url = sys.argv[1], sys.argv[2], sys.argv[3]
xml = open(src, encoding="utf-8").read()

# Mask CDATA and comments before looking for the enclosure. The release notes are
# arbitrary HTML generated from the CHANGELOG, so a note that happens to contain
# something shaped like "<enclosure ...>" would otherwise be counted as one — and
# this script would refuse a perfectly good item. Found by a fixture that put
# exactly that in the notes.
masked = list(xml)
for pat in (re.compile(r"<!\[CDATA\[.*?\]\]>", re.S), re.compile(r"<!--.*?-->", re.S)):
    for m in pat.finditer(xml):
        masked[m.start():m.end()] = " " * (m.end() - m.start())
masked = "".join(masked)

matches = list(re.finditer(r"<enclosure\b[^>]*>", masked))
if len(matches) != 1:
    sys.stderr.write(
        "error: expected exactly 1 <enclosure> in %s, found %d.\n"
        "       Refusing to guess which one the rehearsal should serve.\n"
        % (src, len(matches))
    )
    sys.exit(1)

start, end = matches[0].span()
tag = xml[start:end]
if not re.search(r'\surl="[^"]*"', tag):
    sys.stderr.write("error: <enclosure> in %s has no url attribute.\n" % src)
    sys.exit(1)

# Escape for XML attribute context. The URL is ours and contains no & or <, but
# building a URL into markup without escaping is how the next one breaks.
safe = (local_url.replace("&", "&amp;").replace("<", "&lt;")
                 .replace(">", "&gt;").replace('"', "&quot;"))
new_tag = re.sub(r'(\surl=")[^"]*(")', lambda m: m.group(1) + safe + m.group(2), tag, count=1)
open(dst, "w", encoding="utf-8").write(xml[:start] + new_tag + xml[end:])
REWRITE

# The channel wrapper is the live feed's, minus the commentary — the point is to
# serve something structurally identical to production, so a failure here means
# the entry is wrong rather than the scaffolding.
{
  echo '<?xml version="1.0" encoding="utf-8"?>'
  echo '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
  echo '  <channel>'
  echo '    <title>Home Rec (staging)</title>'
  echo "    <link>http://127.0.0.1:$PORT/appcast.xml</link>"
  echo '    <description>Local rehearsal feed. Not served to anyone.</description>'
  echo '    <language>en</language>'
  cat "$ITEM_LOCAL"
  echo '  </channel>'
  echo '</rss>'
} > "$FEED"

echo "Staging feed assembled from $(basename "$ITEM"):"
echo
sed -n 's/^ *//p' "$FEED" | grep -E "sparkle:(short)?[Vv]ersion|enclosure url|length=" | sed 's/^/  /'
echo
echo "Serving http://127.0.0.1:$PORT/appcast.xml"
echo "Point a scratch build's SUFeedURL there. Ctrl-C to stop."
echo
echo "To rehearse the tamper check, edit this file and change one character of"
echo "sparkle:edSignature — Sparkle must refuse the update:"
echo "  $FEED"
echo

# Bound to 127.0.0.1 on purpose: loopback only. A feed bound to 0.0.0.0 is
# reachable by anything on the network, which is the opposite of the point.
#
# This replaced `python3 -m http.server`, which cannot throttle. Two properties
# of the stock server are load-bearing and are preserved deliberately:
#
#   * The feed is re-read from disk on **every** request. The tamper rehearsal
#     above tells you to edit the file while this is running; caching it in
#     memory at startup would make that edit do nothing, and the check would
#     "pass" while testing the unmodified feed.
#   * Requests are logged, so the access log can answer whether the payload was
#     actually downloaded before a refusal — the difference between the
#     signature being rejected and something else stopping the update first.
exec python3 - "$FEED" "$STAGING_DIR/$(basename "$DMG")" "$PORT" "$KBPS" <<'PY'
import http.server
import os
import socketserver
import sys
import time

FEED, DMG, PORT, KBPS = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
DMG_NAME = os.path.basename(DMG)


class Handler(http.server.BaseHTTPRequestHandler):

    def log_message(self, fmt, *args):
        sys.stderr.write("  %s  %s\n" % (self.log_date_time_string(), fmt % args))
        sys.stderr.flush()

    def do_GET(self):
        self.serve(body=True)

    # `python3 -m http.server` answered HEAD, and dropping it would be a silent
    # regression: a client that probes before downloading would get a 501 where
    # the stock server gave it headers, and the failure would look like a
    # problem with the update rather than with this scaffolding.
    def do_HEAD(self):
        self.serve(body=False)

    def serve(self, body):
        if self.path.endswith("appcast.xml"):
            # Re-read per request. See the note above: the tamper rehearsal
            # depends on an edit taking effect without a restart.
            with open(FEED, "rb") as f:
                payload = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "application/xml")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            if body:
                self.wfile.write(payload)
        elif self.path.endswith(DMG_NAME):
            if body:
                self.send_payload()
            else:
                self.send_response(200)
                self.send_header("Content-Type", "application/octet-stream")
                self.send_header("Content-Length", str(os.path.getsize(DMG)))
                self.end_headers()
        else:
            self.send_error(404)

    def send_payload(self):
        size = os.path.getsize(DMG)
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(size))
        self.end_headers()

        # A tenth of a second's worth per iteration: coarse enough to stay cheap,
        # fine enough that the rate is steady rather than bursty.
        chunk = (KBPS * 1024 // 10) if KBPS > 0 else 1024 * 1024
        sent = 0
        started = time.monotonic()
        with open(DMG, "rb") as f:
            while True:
                data = f.read(chunk)
                if not data:
                    break
                try:
                    self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError):
                    # Sparkle cancelled, or the app quit. Not an error: say how
                    # far it got, because a partial download explains a failure
                    # that otherwise looks like a bad signature.
                    sys.stderr.write("  client hung up after %d of %d bytes\n" % (sent, size))
                    sys.stderr.flush()
                    return
                sent += len(data)
                if KBPS > 0:
                    time.sleep(0.1)
        sys.stderr.write(
            "  payload complete: %d bytes in %.1fs\n" % (sent, time.monotonic() - started)
        )
        sys.stderr.flush()


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    # Threaded so a slow payload does not block the feed: Sparkle re-reads the
    # appcast while a download is in flight, and a single-threaded server would
    # deadlock for the whole throttled transfer.
    daemon_threads = True


if KBPS > 0:
    eta = os.path.getsize(DMG) / (KBPS * 1024)
    print("Payload throttled to %d KB/s — about %.0fs for the whole file." % (KBPS, eta))
    print("That window is the point: start recording while it downloads.")
else:
    print("Payload unthrottled — the interlock check cannot be performed at this rate.")
print()
sys.stdout.flush()

Server(("127.0.0.1", PORT), Handler).serve_forever()
PY

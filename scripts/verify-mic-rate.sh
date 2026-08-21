#!/usr/bin/env bash
#
# Verify a microphone take was captured at the correct sample rate.
#
# The check this exists for: a 44.1 kHz interface whose audio is *mislabeled*
# as 48 kHz passes every guard in the app (WAVWriter:118, M4AEncoder:116,
# FLACEncoder's format equality all compare the label, not the content) and
# lands as a file that plays ~8.8% fast. Correct duration, real audio, no
# error — the failure this project keeps being bitten by.
#
# Ears cannot settle 8.8% reliably; a reference tone can. Play a known tone
# into the mic, record it, then run this on the take.
#
# Usage:
#   scripts/verify-mic-rate.sh --tone [out.wav]        # write the reference tone
#   scripts/verify-mic-rate.sh <recording> [wall_clock_seconds]
#   REF_HZ=1000 scripts/verify-mic-rate.sh take.wav 60
#
# Exits non-zero on any FAIL, so it can gate a manual-acceptance step.

set -euo pipefail

REF_HZ="${REF_HZ:-1000}"

# Reference tone. Generated rather than committed: it is 7 MB of sine wave that
# any machine can rebuild in a second, and REF_HZ must be able to change it.
if [[ "${1:-}" == "--tone" ]]; then
    out="${2:-homerec-${REF_HZ}hz-reference.wav}"
    ffmpeg -v error -f lavfi -i "sine=frequency=${REF_HZ}:duration=75:sample_rate=48000" \
           -af "volume=0.3" -c:a pcm_s16le -y "$out"
    echo "Reference tone: $out  (${REF_HZ} Hz, 75 s)"
    echo "Play it into the mic with:  afplay \"$out\""
    exit 0
fi

FILE="${1:-}"
WALL="${2:-}"

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
    echo "usage: $0 <recording> [wall_clock_seconds]   (REF_HZ=$REF_HZ)" >&2
    exit 2
fi
for tool in ffprobe ffmpeg python3; do
    command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 2; }
done

echo "File:      $FILE"
probe=$(ffprobe -v error -select_streams a:0 \
        -show_entries stream=sample_rate,channels -show_entries format=duration \
        -of default=nw=1:nk=1 "$FILE")
declared_rate=$(echo "$probe" | sed -n 1p)
channels=$(echo "$probe" | sed -n 2p)
duration=$(echo "$probe" | sed -n 3p)
echo "Declared:  ${declared_rate} Hz, ${channels} ch, ${duration} s"
echo "Reference: ${REF_HZ} Hz"
echo

# Decode to mono 8 kHz float32. Both the correct tone and the 8.8%-fast one sit
# far below the 4 kHz Nyquist, and ffmpeg's resampler is anti-aliased, so this
# is lossless for the measurement while keeping a pure-Python FFT-free scan fast.
ffmpeg -v error -i "$FILE" -ac 1 -ar 8000 -f f32le - 2>/dev/null | python3 -c '
import sys, math
from array import array

REF   = float(sys.argv[1])
WALL  = sys.argv[2]
DUR   = float(sys.argv[3]) if sys.argv[3] not in ("", "N/A") else 0.0
SR    = 8000

buf = array("f")
data = sys.stdin.buffer.read()
buf.frombytes(data[: len(data) - (len(data) % 4)])
n = len(buf)
if n == 0:
    print("FAIL  no decodable audio")
    sys.exit(1)

# Level over the whole take, so a partly-silent file cannot hide behind a good window.
peak = max(max(buf), -min(buf))
rms  = math.sqrt(sum(x * x for x in buf) / n)
db   = lambda v: (20 * math.log10(v)) if v > 1e-12 else -999.0
print(f"Peak:      {db(peak):7.1f} dBFS")
print(f"RMS:       {db(rms):7.1f} dBFS")

# Measure pitch on a window from the middle: start/stop transients and any
# fade at the edges would bias the estimate.
skip = min(int(2.0 * SR), n // 4)
win  = buf[skip : skip + min(int(6.0 * SR), n - 2 * skip)] or buf
N    = len(win)

def power(freq):
    # Goertzel: one bin, no FFT, no numpy.
    coeff = 2.0 * math.cos(2.0 * math.pi * freq / SR)
    s1 = s2 = 0.0
    for x in win:
        s1, s2 = x + coeff * s1 - s2, s1
    return s1 * s1 + s2 * s2 - coeff * s1 * s2

lo, hi = REF * 0.55, REF * 1.60
coarse = max((f for f in [lo + i * 5.0 for i in range(int((hi - lo) / 5.0) + 1)]), key=power)
fine   = max((coarse - 5.0 + i * 0.25 for i in range(41)), key=power)
ratio  = fine / REF
print(f"Dominant:  {fine:7.1f} Hz   ({ratio:.4f}x reference)")

if DUR and WALL:
    wall = float(WALL)
    print(f"Duration:  {DUR:7.1f} s vs {wall:.1f} s wall clock ({DUR / wall:.4f}x)")
print()

fails = []
if db(peak) < -60.0:
    fails.append(f"SILENT — peak {db(peak):.1f} dBFS. The BL-150 class: full length, no audio.")

FAST = 48000.0 / 44100.0  # 1.0884 — 44.1 kHz content labeled 48 kHz
if abs(ratio - FAST) < 0.02:
    fails.append(f"PITCH — {fine:.1f} Hz is {ratio:.4f}x reference, matching 48000/44100. "
                 "44.1 kHz audio is being labeled 48 kHz and written unresampled.")
elif abs(ratio - 1.0 / FAST) < 0.02:
    fails.append(f"PITCH — {fine:.1f} Hz is {ratio:.4f}x reference (slow by 44100/48000).")
elif abs(ratio - 1.0) > 0.01:
    fails.append(f"PITCH — {fine:.1f} Hz is {ratio:.4f}x reference; expected 1.0000x "
                 "(within 1%). Not the classic rate swap, but not clean either.")

if DUR and WALL:
    d = DUR / float(WALL)
    if abs(d - 1.0) > 0.02:
        fails.append(f"DURATION — file is {d:.4f}x the wall clock; a correct take is 1.00x "
                     "regardless of interface rate.")

if fails:
    for f in fails:
        print("FAIL  " + f)
    sys.exit(1)

print(f"PASS  {fine:.1f} Hz ({ratio:.4f}x), peak {db(peak):.1f} dBFS"
      + (f", duration {DUR / float(WALL):.4f}x wall clock" if (DUR and WALL) else ""))
' "$REF_HZ" "$WALL" "$duration"

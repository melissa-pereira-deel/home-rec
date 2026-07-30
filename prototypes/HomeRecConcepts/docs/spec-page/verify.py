"""Decode a PNG with zlib alone and report (a) which concept chip is
highlighted in the stage chrome and (b) whether any phosphor-green LCD
pixels are present. Both are proxies for "this screen rendered the wrong
concept", which is exactly the failure we shipped last time."""
import sys, zlib, struct

def decode(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos, idat, pal = 8, b'', None
    while pos < len(data):
        ln, typ = struct.unpack('>I4s', data[pos:pos+8])
        body = data[pos+8:pos+8+ln]
        if typ == b'IHDR':
            w, h, depth, color, _, _, interlace = struct.unpack('>IIBBBBB', body)
            assert depth == 8 and interlace == 0, (depth, interlace)
        elif typ == b'IDAT':
            idat += body
        pos += 12 + ln
    channels = {0:1, 2:3, 4:2, 6:4}[color]
    raw = zlib.decompress(idat)
    stride = w * channels
    out, prev = [], bytearray(stride)
    p = 0
    for _ in range(h):
        f = raw[p]; line = bytearray(raw[p+1:p+1+stride]); p += 1 + stride
        for i in range(stride):
            a = line[i-channels] if i >= channels else 0
            b = prev[i]
            c = prev[i-channels] if i >= channels else 0
            if f == 1: line[i] = (line[i] + a) & 255
            elif f == 2: line[i] = (line[i] + b) & 255
            elif f == 3: line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b-c), abs(a-c), abs(a+b-2*c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out.append(bytes(line)); prev = line
    return w, h, channels, out

def px(rows, ch, x, y):
    r = rows[y]
    return r[x*ch], r[x*ch+1], r[x*ch+2]

# Chip x-centres (2x pixels) of the five concept labels in the top chrome,
# measured from the captures; the active chip is white, inactive is grey.
CHIPS = {"1 PO": 110, "2 DT": 300, "3 BR": 468, "4 GS": 598, "5 GL": 748}

for path in sys.argv[1:]:
    w, h, ch, rows = decode(path)
    band = range(84, 96)          # the label's cap-height band
    best, bestval = None, -1
    for name, cx in CHIPS.items():
        peak = 0
        for y in band:
            for x in range(cx - 55, cx + 55):
                if 0 <= x < w:
                    r, g, b = px(rows, ch, x, y)
                    peak = max(peak, min(r, g, b))
        if peak > bestval:
            best, bestval = name, peak
    green = 0
    for y in range(600, min(h, 780), 3):
        for x in range(500, min(w, 1000), 3):
            r, g, b = px(rows, ch, x, y)
            if g > 130 and g > r + 40 and g > b + 40:
                green += 1
    print(f"{path.split('/')[-1]:42s} active={best} lcd_green_px={green}")

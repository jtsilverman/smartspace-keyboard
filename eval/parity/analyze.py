"""Compare stock vs SmartSpace key caps on one device crop pair.

Letter caps are white in both keyboards, so they are matched row by row and
reported as point deltas. Function keys (shift, delete, 123, emoji, return)
are white in stock iOS 26; their fill colour is sampled from the SAME stock
rect in both images, so a colour gap shows up as a delta.
"""
import json, sys
import numpy as np
from PIL import Image

stock_p, smart_p, scale, label = sys.argv[1:5]
scale = float(scale)

def rows_of_caps(path):
    a = np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)
    white = (a > 245).all(axis=2)
    on_rows = white.any(axis=1)
    bands, start = [], None
    for y, on in enumerate(on_rows):
        if on and start is None:
            start = y
        elif not on and start is not None:
            if y - start > 10 * scale / 3:
                bands.append((start, y))
            start = None
    if start is not None:
        bands.append((start, len(on_rows)))
    rows = []
    for top, bottom in bands:
        cols = white[top:bottom].any(axis=0)
        runs, s = [], None
        for x, on in enumerate(cols):
            if on and s is None:
                s = x
            elif not on and s is not None:
                if x - s > 8 * scale / 3:
                    runs.append((s, x))
                s = None
        if s is not None:
            runs.append((s, len(cols)))
        row = []
        for left, right in runs:
            sub = white[top:bottom, left:right]
            ys = np.where(sub.any(axis=1))[0]
            row.append({"x": left / scale, "w": (right - left) / scale,
                        "y": (top + ys[0]) / scale, "h": (ys[-1] - ys[0] + 1) / scale,
                        "px": (left, top + ys[0], right, top + ys[-1] + 1)})
        rows.append(row)
    return rows, a

def fill_colour(img, rect):
    """Median over the cap: the glyph is a minority of the pixels, so the
    median lands on the fill instead of averaging fill and glyph together."""
    x0, y0, x1, y1 = rect
    mx, my = int((x1 - x0) * 0.12), int((y1 - y0) * 0.12)
    patch = img[y0 + my:y1 - my, x0 + mx:x1 - mx]
    return [int(round(float(np.median(patch[:, :, c])))) for c in range(3)]

srows, simg = rows_of_caps(stock_p)
mrows, mimg = rows_of_caps(smart_p)
out = {"device": label}

if len(srows) < 4 or len(mrows) < 4:
    out["error"] = f"row detection failed: stock {len(srows)} rows, smartspace {len(mrows)} rows"
    print(json.dumps(out)); sys.exit(0)

# Once both keyboards paint function caps white, every row holds the same
# number of caps and pairs by index. While SmartSpace still greys them, its
# third row is missing stock's shift and delete, so that row pairs inward.
def pair_row(a_row, b_row):
    if len(a_row) == len(b_row):
        return list(zip(a_row, b_row))
    if len(a_row) == len(b_row) + 2:
        return list(zip(a_row[1:-1], b_row))
    return []

pairs = pair_row(srows[0], mrows[0]) + pair_row(srows[1], mrows[1]) \
        + pair_row(srows[2], mrows[2])
if not pairs:
    out["error"] = (f"cap counts do not line up: stock {[len(r) for r in srows]}, "
                    f"smartspace {[len(r) for r in mrows]}")
    print(json.dumps(out)); sys.exit(0)
dx = [abs(p["x"] - q["x"]) for p, q in pairs]
dy = [abs(p["y"] - q["y"]) for p, q in pairs]
dw = [abs(p["w"] - q["w"]) for p, q in pairs]
dh = [abs(p["h"] - q["h"]) for p, q in pairs]
out["letter_caps"] = len(pairs)
out["max_dx_pt"] = round(max(dx), 2)
out["max_dy_pt"] = round(max(dy), 2)
out["max_dw_pt"] = round(max(dw), 2)
out["max_dh_pt"] = round(max(dh), 2)

# Space bar: the widest cap in the bottom row of each keyboard.
s_space = max(srows[3], key=lambda c: c["w"])
m_space = max(mrows[3], key=lambda c: c["w"])
out["space_dx_pt"] = round(abs(s_space["x"] - m_space["x"]), 2)
out["space_dw_pt"] = round(abs(s_space["w"] - m_space["w"]), 2)

# Function keys, sampled from the stock rect in both images.
fn = {}
if len(srows[2]) >= 2:
    fn["shift"] = srows[2][0]["px"]
    fn["delete"] = srows[2][-1]["px"]
bottom = sorted(srows[3], key=lambda c: c["x"])
if len(bottom) >= 4:
    fn["layer"] = bottom[0]["px"]
    fn["emoji"] = bottom[1]["px"]
    fn["return"] = bottom[-1]["px"]
out["function_fill"] = {
    name: {"stock": fill_colour(simg, rect), "smartspace": fill_colour(mimg, rect)}
    for name, rect in fn.items()
}
out["function_keys_white_in_stock"] = list(fn)
print(json.dumps(out))

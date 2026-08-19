"""Find the top of the keyboard assembly and the bar band in a full shot.

The practice field sits on a white app background; the keyboard assembly is
grey. Scanning up from the bottom, the first row whose median goes white is
the top edge of the assembly, so the bar band is that edge down to the first
key row.
"""
import json, sys
import numpy as np
from PIL import Image

path, screen_w, screen_h, key_top, label, side = sys.argv[1:7]
screen_w, screen_h, key_top = float(screen_w), float(screen_h), float(key_top)
a = np.asarray(Image.open(path).convert("RGB"), dtype=np.int16)
scale = a.shape[1] / screen_w
med = np.median(a, axis=1)                      # one median colour per row
# The app background is white; the keyboard assembly ground is grey. The
# assembly starts at the first row that holds grey and keeps holding it.
grey = ((med > 210) & (med < 245)).all(axis=1)
run = 0
top_px = None
for y in range(a.shape[0]):
    run = run + 1 if grey[y] else 0
    if run >= 6:
        top_px = y - 5
        break
if top_px is None:
    print(json.dumps({"device": label, "side": side, "error": "no grey assembly row found"}))
    sys.exit(0)
bottom = a.shape[0] - 1
top_pt = top_px / scale
print(json.dumps({
    "device": label, "side": side,
    "assembly_top_pt": round(top_pt, 1),
    "bar_height_pt": round(key_top - top_pt, 1),
    "assembly_bottom_pt": round((bottom + 1) / scale, 1),
    "bar_fill": [int(x) for x in med[int((top_pt + 4) * scale)]],
}))

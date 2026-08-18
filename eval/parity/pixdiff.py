"""Pixel-diff the stock keyboard against SmartSpace on one device.

Both shots are cropped by the SAME rect, taken from the STOCK key area, so a
vertical offset in SmartSpace shows up as difference instead of hiding.
"""
import json, sys
from PIL import Image, ImageChops
import numpy as np

stock_p, smart_p, q_top_pt, screen_w_pt, screen_h_pt, out_prefix, label = sys.argv[1:8]
q_top_pt, screen_w_pt, screen_h_pt = float(q_top_pt), float(screen_w_pt), float(screen_h_pt)

stock = Image.open(stock_p).convert("RGB")
smart = Image.open(smart_p).convert("RGB")
if stock.size != smart.size:
    print(json.dumps({"device": label, "error": f"size mismatch {stock.size} vs {smart.size}"}))
    sys.exit(0)

scale = stock.width / screen_w_pt
box = (0, int(round(q_top_pt * scale)), stock.width, int(round(screen_h_pt * scale)))
a = np.asarray(stock.crop(box), dtype=np.int16)
b = np.asarray(smart.crop(box), dtype=np.int16)

d = np.abs(a - b).max(axis=2)
total = d.size
differing = int((d > 8).sum())
report = {
    "device": label,
    "crop_px": [box[0], box[1], box[2], box[3]],
    "scale": round(scale, 2),
    "pct_pixels_differing": round(100.0 * differing / total, 2),
    "mean_abs_diff": round(float(d.mean()), 2),
    "max_abs_diff": int(d.max()),
}

# Row profile: the point-row bands where the two keyboards disagree most.
rows = (d > 8).mean(axis=1)
band = max(1, int(round(scale)))          # one point per band
bands = [(i / scale + q_top_pt, float(rows[i:i + band].mean()))
         for i in range(0, len(rows), band)]
worst = sorted(bands, key=lambda t: -t[1])[:6]
report["worst_point_rows"] = [[round(y, 1), round(100 * v, 1)] for y, v in worst]

overlay = Image.fromarray(np.dstack([
    np.where(d > 8, 255, a[:, :, 0]).astype(np.uint8),
    np.where(d > 8, 0, a[:, :, 1]).astype(np.uint8),
    np.where(d > 8, 0, a[:, :, 2]).astype(np.uint8),
]))
overlay.save(f"{out_prefix}-diff.png")
stock.crop(box).save(f"{out_prefix}-stock.png")
smart.crop(box).save(f"{out_prefix}-smart.png")
print(json.dumps(report))

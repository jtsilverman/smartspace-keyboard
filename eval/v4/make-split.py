#!/usr/bin/env python3
"""Deterministic stratified dev/test split for eval v4.

50/50 within each (file, subcategory) stratum, ordered by crc32(id) so the
split is reproducible across machines (Python hash() is seed-randomized).
Typos and scenarios stay unsplit (whole-set benchmarks, v3 typo precedent).

Run from repo root after QC assembly:  python3 eval/v4/make-split.py
Writes eval/v4/split-map.tsv. FROZEN once committed.
"""
import csv
import zlib
from collections import defaultdict
from pathlib import Path

V4 = Path(__file__).resolve().parent
SPLIT_FILES = ["cap.tsv", "symbols.tsv", "protect.tsv", "completions.tsv"]

strata = defaultdict(list)
for name in SPLIT_FILES:
    with open(V4 / name, newline="") as f:
        reader = csv.reader(f, delimiter="\t", quoting=csv.QUOTE_NONE, quotechar=None)
        for row in reader:
            if row and row[0].strip():
                strata[(name, row[1])].append(row[0])

pairs = []
for (name, sub), ids in sorted(strata.items()):
    ordered = sorted(ids, key=lambda i: zlib.crc32(i.encode()))
    cut = (len(ordered) + 1) // 2
    pairs += [(i, "dev") for i in ordered[:cut]]
    pairs += [(i, "test") for i in ordered[cut:]]

with open(V4 / "split-map.tsv", "w", newline="") as f:
    w = csv.writer(f, delimiter="\t")
    for row_id, halfname in sorted(pairs):
        w.writerow([row_id, halfname])

dev = sum(1 for _, h in pairs if h == "dev")
print(f"split-map.tsv: {dev} dev / {len(pairs) - dev} test across {len(strata)} strata")

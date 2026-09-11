#!/usr/bin/env python3
"""Regenerate wordrank.bin: the engine's word list, which is both its spelling
vocabulary and its frequency order.

The list is the Android Open Source Project's LatinIME English dictionary
(`engine/tools/vendor/en_wordlist.combined.gz`, Apache-2.0, 165,544 words).
Each entry carries its own casing and a 0-255 frequency, so one file answers
both questions the engine asks: "is this a word" and "how common is it".
`wordlist.py` assembles the list; this script packs it.

The list this replaced was Norvig's `count_1w.txt` top 20k, scraped from web
text, which held `teh` at rank 19395 and `definately` at 19107. A vocabulary
that contains `teh` can never correct `teh`.

The output is a binary file the engine maps read-only (`WordRank.swift`), so
the list costs the keyboard extension no heap: held as Swift dictionaries it
measured about 50MB of a 70MB footprint against a 55MB ceiling (2026-09-11).

Layout, little-endian, offsets from the start of the file:

    header   4s magic "SSWR", u32 version, u32 count, u32 maxLen,
             u32 recordsOff, u32 alphaOff, u32 lengthStartsOff,
             u32 lengthListOff, u32 stringsOff
    records  count x 19 bytes: u32 lowerOff, u32 casedOff, u32 rank,
             u32 letterMask, u8 lowerBytes, u8 casedBytes,
             u8 flags (bit 0: the lowercase form is not ASCII)
    alpha    count x u32 record indices, sorted by the lowercase bytes
    lengthStarts (maxLen + 2) x u32: for each character count, where its
             run starts in lengthList; the last entry is the list's end
    lengthList count x (u32 record index, u32 letterMask), grouped by
             character count, rank order inside a group. The mask rides
             beside the index so the candidate scan reads one run
             sequentially and touches a record only when the mask admits it
    strings  the lowercase and cased bytes of every record, no separators

Run from the repo root:

    python3 engine/tools/gen-wordrank.py
"""
import struct
from pathlib import Path

from wordlist import build, records

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "engine" / "Sources" / "TypingEngine" / "Resources" / "wordrank.bin"

MAGIC = b"SSWR"
VERSION = 2
RECORD = struct.Struct("<IIIIBBB")
HEADER = struct.Struct("<4sIIIIIIII")


def letter_mask(lower: str) -> int:
    mask = 0
    for char in lower:
        if "a" <= char <= "z":
            mask |= 1 << (ord(char) - ord("a"))
    return mask


def main():
    recs = records()
    strings = bytearray()
    record_bytes = bytearray()
    masks = []
    for lower, cased, rank in recs:
        lower_bytes, cased_bytes = lower.encode(), cased.encode()
        lower_off = len(strings)
        strings += lower_bytes
        cased_off = len(strings)
        strings += cased_bytes
        flags = 0 if lower_bytes.isascii() else 1
        masks.append(letter_mask(lower))
        record_bytes += RECORD.pack(lower_off, cased_off, rank, masks[-1],
                                    len(lower_bytes), len(cased_bytes), flags)
    alpha = sorted(range(len(recs)), key=lambda i: recs[i][0].encode())
    max_len = max(len(lower) for lower, _, _ in recs)
    by_length = [[] for _ in range(max_len + 1)]
    for i, (lower, _, _) in enumerate(recs):
        by_length[len(lower)].append(i)
    length_starts, length_list = [], []
    for run in by_length:
        length_starts.append(len(length_list))
        for i in run:
            length_list += [i, masks[i]]
    length_starts.append(len(length_list))
    # Starts count entries, and an entry is two u32s.
    length_starts = [start // 2 for start in length_starts]

    records_off = HEADER.size
    alpha_off = records_off + len(record_bytes)
    length_starts_off = alpha_off + 4 * len(alpha)
    length_list_off = length_starts_off + 4 * len(length_starts)
    strings_off = length_list_off + 4 * len(length_list)
    header = HEADER.pack(MAGIC, VERSION, len(recs), max_len, records_off, alpha_off,
                         length_starts_off, length_list_off, strings_off)
    TARGET.parent.mkdir(exist_ok=True)
    TARGET.write_bytes(header + bytes(record_bytes)
                       + struct.pack(f"<{len(alpha)}I", *alpha)
                       + struct.pack(f"<{len(length_starts)}I", *length_starts)
                       + struct.pack(f"<{len(length_list)}I", *length_list)
                       + bytes(strings))
    print(f"wordrank.bin: {len(recs)} records from {len(build())} words, "
          f"{TARGET.stat().st_size} bytes")


if __name__ == "__main__":
    main()

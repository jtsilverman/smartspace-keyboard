"""The engine's word list as the generators see it: the AOSP LatinIME entries
in frequency order, then the shipped TextingLexicon. Both gen-wordrank.py and
gen-wordpairs.py read `records()`, because wordpairs.bin refers to words by
their position in wordrank.bin and the two files must agree on that order.
"""
import gzip
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LEXICON = ROOT / "engine" / "Sources" / "TypingEngine" / "TextingLexicon.swift"
SOURCE = ROOT / "engine" / "tools" / "vendor" / "en_wordlist.combined.gz"
NAMES = ROOT / "engine" / "tools" / "vendor" / "us-first-names.txt"

ENTRY = re.compile(r"^ word=([^,]+),f=(\d+)")


def aosp_words() -> list:
    """(word, frequency) in the list's own casing, most frequent first."""
    if not SOURCE.exists():
        sys.exit(f"{SOURCE} is missing; see engine/tools/vendor/NOTICE")
    entries = []
    with gzip.open(SOURCE, "rt", encoding="utf-8") as handle:
        for line in handle:
            match = ENTRY.match(line)
            if match:
                entries.append((match.group(1), int(match.group(2))))
    if not entries:
        sys.exit(f"{SOURCE} held no word entries")
    # Frequency first, then alphabetical, so the order is total and a
    # regeneration reproduces the file byte for byte.
    entries.sort(key=lambda pair: (-pair[1], pair[0]))
    return entries


def texting_words() -> list:
    return sorted(set(re.findall(r'"([a-z0-9]+)"', LEXICON.read_text())))


def first_names() -> list:
    """US first names, most popular first, in their own casing."""
    return [line.strip() for line in NAMES.read_text().splitlines()
            if line.strip() and not line.startswith("#")]


def build() -> list:
    """Every word in rank order, duplicates of a lowercase form included."""
    words = [word for word, _ in aosp_words()]
    seen = {w.lower() for w in words}
    # The texting lexicon is modern slang the 2014 list never had. It lands
    # last: these words are never corrected away, and rank only breaks ties.
    words += [w for w in texting_words() if w not in seen]
    seen |= {w.lower() for w in words}
    # First names the 2014 list does not carry (Nathen, Jesica, Danial): a
    # name the engine reads as a typo is the most expensive miscorrection
    # there is, and stock leaves these spellings alone. They land after the
    # lexicon, so a name never outranks a common word at a distance tie.
    return words + [n for n in first_names() if n.lower() not in seen]


def records() -> list:
    """(lower, cased, rank), one per distinct lowercase form, rank order.
    `rank` is the position in the full list, duplicates included, so the rank
    cutoffs the engine holds keep their meaning."""
    seen = set()
    out = []
    for position, word in enumerate(build()):
        lower = word.lower()
        if lower in seen:
            continue
        seen.add(lower)
        out.append((lower, word, position + 1))
    return out

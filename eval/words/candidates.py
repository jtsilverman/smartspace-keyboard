#!/usr/bin/env python3
"""The words the dictionary does not know yet, in the order stock gets asked
about them (specs/autocorrect-loop.md, unit 1).

    python3 eval/words/candidates.py --aggregate <dir of SSA yobYYYY.txt>
        writes engine/tools/vendor/ssa-names.tsv (name, since 1980, all time)
    python3 eval/words/candidates.py [--floor 200] [--size 150]
        prints the next batch, as oracle rows, of candidates stock has not
        answered (eval/oracle/stock-*.tsv, slice `words`)
    python3 eval/words/candidates.py --accepted
        rewrites engine/tools/vendor/accepted-words.tsv: every candidate stock
        left as typed, in probe order

Brands first, by Wikidata sitelinks: there are under two thousand and a
mangled brand is the miscorrection Jake named. Then first names by births
since 1980, so a name a child has today outranks one only a grandparent
had. A word the list already knows is never a candidate, and a name under
the floor never reaches the recorder. Each row types the word lowercase
inside a carrier, because alone at the start of the field autocap would
capitalize it and stock protects a capitalized unknown as a name.
"""
import argparse
import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "engine" / "tools"))
VENDOR = ROOT / "engine" / "tools" / "vendor"
SSA = VENDOR / "ssa-names.tsv"
BRANDS = VENDOR / "wikidata-brands.tsv"
ACCEPTED = VENDOR / "accepted-words.tsv"
ORACLE = ROOT / "eval" / "oracle"
RECENT_FROM = 1980
CARRIER = "i said {} today"


def aggregate_ssa(directory: Path) -> dict:
    """name -> (births since 1980, births all time), both sexes summed."""
    out = {}
    for path in sorted(directory.glob("yob*.txt")):
        year = int(path.stem[3:])
        for line in path.read_text().splitlines():
            name, _sex, count = line.split(",")
            recent, total = out.get(name, (0, 0))
            n = int(count)
            out[name] = (recent + (n if year >= RECENT_FROM else 0), total + n)
    return out


def write_ssa(rows: dict, path: Path = SSA):
    with open(path, "w", newline="") as f:
        f.write("# US first names from the Social Security Administration's yobYYYY files,\n"
                "# 1880-2024, both sexes summed: births since 1980 and all time. Public\n"
                "# domain (17 U.S.C. 105, CC0 on data.gov). See NOTICE.\n")
        f.write("name\tsince1980\ttotal\n")
        for name, (recent, total) in sorted(rows.items(), key=lambda kv: (-kv[1][0], kv[0])):
            f.write(f"{name}\t{recent}\t{total}\n")


def read_ssa(path: Path = SSA) -> dict:
    out = {}
    for line in path.read_text().splitlines():
        if line.startswith("#") or line.startswith("name\t"):
            continue
        name, recent, total = line.split("\t")
        out[name] = (int(recent), int(total))
    return out


def read_brands(path: Path = BRANDS) -> list:
    out = []
    for line in path.read_text().splitlines():
        if line.startswith("#") or line.startswith("label\t"):
            continue
        label, links = line.split("\t")
        out.append((label, int(links)))
    return out


def build(names: dict, brands: list, known: set, floor: int) -> list:
    """Every candidate in probe order: {word, source, weight}."""
    rows = []
    for label, links in sorted(brands, key=lambda t: (-t[1], t[0])):
        if label.lower() not in known:
            rows.append({"word": label, "source": "brand", "weight": links})
    for name, (recent, _total) in sorted(names.items(), key=lambda kv: (-kv[1][0], kv[0])):
        if recent >= floor and name.lower() not in known and re.fullmatch(r"[A-Za-z]+", name):
            rows.append({"word": name, "source": "name", "weight": recent})
    return rows


def next_batch(rows: list, recorded: set, size: int) -> list:
    """The first `size` candidates stock has not answered yet."""
    return [r for r in rows if r["word"].lower() not in recorded][:size]


def oracle_rows(rows: list) -> list:
    return [{"id": f"word-{r['word'].lower()}", "slice": "words",
             "typed": CARRIER.format(r["word"].lower()), "offsets": "-",
             "note": f"{r['source']}|{r['word']}|{r['weight']}"}
            for r in rows]


def stock_rows() -> list:
    """Every `words` row stock has answered, from every recording."""
    rows = []
    for path in sorted(ORACLE.glob("stock-*.tsv")):
        with open(path, newline="") as f:
            rows += [row for row in csv.DictReader(f, delimiter="\t") if row["slice"] == "words"]
    return rows


def recorded_words() -> set:
    """Lowercase words stock has answered."""
    return {row["typed"].split()[2] for row in stock_rows()}


def accepted(rows: list, stock: list) -> list:
    """The candidates stock left as typed, with the vendor's casing. Case is
    stock's autocap and name capitalization, not a verdict on the letters."""
    left_alone = {row["typed"].split()[2] for row in stock
                  if row["slice"] == "words"
                  and row["produced"].strip().lower() == row["typed"].strip().lower()}
    return [r for r in rows if r["word"].lower() in left_alone]


def write_accepted(rows: list, path: Path = ACCEPTED):
    with open(path, "w", newline="") as f:
        f.write("# Words the stock keyboard left as typed inside the carrier, written by\n"
                "# eval/words/candidates.py --accepted from eval/oracle/stock-*.tsv. The\n"
                "# engine's word list appends these after the first names (wordlist.py).\n")
        f.write("word\tsource\tweight\n")
        for r in rows:
            f.write(f"{r['word']}\t{r['source']}\t{r['weight']}\n")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--aggregate", type=Path, help="directory of SSA yobYYYY.txt files")
    ap.add_argument("--floor", type=int, default=200, help="births since 1980 a name needs")
    ap.add_argument("--size", type=int, default=150)
    ap.add_argument("--accepted", action="store_true",
                    help="rewrite engine/tools/vendor/accepted-words.tsv from the recordings")
    args = ap.parse_args()
    if args.aggregate:
        rows = aggregate_ssa(args.aggregate)
        write_ssa(rows)
        print(f"ssa: {len(rows)} names", file=sys.stderr)
        return 0
    import wordlist
    known = {lower for lower, _, _ in wordlist.records(accepted=False)}
    rows = build(read_ssa(), read_brands(), known, args.floor)
    if args.accepted:
        kept = accepted(rows, stock_rows())
        write_accepted(kept)
        print(f"accepted: {len(kept)} of {len(recorded_words())} answered", file=sys.stderr)
        return 0
    batch = next_batch(rows, recorded_words(), args.size)
    print(f"candidates: {len(rows)} ({sum(r['source'] == 'brand' for r in rows)} brands), "
          f"batch of {len(batch)}", file=sys.stderr)
    writer = csv.writer(sys.stdout, delimiter="\t", quoting=csv.QUOTE_NONE, quotechar=None,
                        lineterminator="\n")
    writer.writerow(["id", "slice", "typed", "offsets", "note"])
    writer.writerows([[r["id"], r["slice"], r["typed"], r["offsets"], r["note"]]
                      for r in oracle_rows(batch)])
    return 0


if __name__ == "__main__":
    sys.exit(main())

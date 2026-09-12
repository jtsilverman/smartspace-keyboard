#!/usr/bin/env python3
"""Score the engine once: run `swift test` and read every number the loop keeps
or reverts on (specs/autocorrect-loop.md, check 2).

    python3 eval/loop/score.py [--repo PATH]

Prints one JSON object: the oracle agreement per slice and per half, every
dev-half miss, the typo benches, the protection and completion sets, the
suite count, the failed test names, and whether the package built at all.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

FRACTION = re.compile(r"(\d+)/(\d+)")


def parse(text: str) -> dict:
    """The numbers in one `swift test` transcript."""
    out = {
        "build_ok": False,
        "oracle": {},
        "misses": [],
        "typo": {}, "typo4": {},
        "protect": {}, "completions": {},
        "failed": [],
        "tests_total": 0,
        "suite_ok": False,
    }
    for line in text.splitlines():
        line = line.rstrip()
        if line.startswith("ORACLE-AGREE "):
            key, rest = line[len("ORACLE-AGREE "):].split(":", 1)
            a, n = map(int, FRACTION.search(rest).groups())
            out["oracle"][key.strip()] = [a, n]
        elif line.startswith("ORACLE-MISS "):
            out["misses"].append(line[len("ORACLE-MISS "):])
        elif line.startswith("TYPO-BENCH ") or line.startswith("TYPO4-BENCH "):
            slot = "typo" if line.startswith("TYPO-") else "typo4"
            a, n = map(int, FRACTION.search(line).groups())
            mis = int(re.search(r"miscorrected (\d+)", line).group(1))
            out[slot] = {"corrected": a, "n": n, "miscorrected": mis}
        elif line.startswith("[PROTECT ") or line.startswith("[COMPLETIONS "):
            name = line[1:line.index("]")]
            slot = "protect" if name.startswith("PROTECT") else "completions"
            half = name.split()[1].lower()
            a, n = map(int, FRACTION.search(line[line.index("]"):]).groups())
            out[slot][half] = [a, n]
        elif (m := re.match(r"✘ Test (\w+)\(\) failed after", line)):
            out["failed"].append(m.group(1))
        elif "Test run with" in line:
            m = re.search(r"Test run with (\d+) tests? in \d+ suites? (passed|failed)", line)
            if m:
                out["tests_total"] = int(m.group(1))
                out["suite_ok"] = m.group(2) == "passed"
    out["build_ok"] = bool(out["oracle"])
    return out


def score(repo: Path) -> dict:
    run = subprocess.run(["swift", "test"], cwd=repo / "engine",
                         capture_output=True, text=True)
    return parse(run.stdout + run.stderr)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    args = ap.parse_args()
    result = score(args.repo)
    json.dump(result, sys.stdout, indent=1)
    print()
    return 0 if result["build_ok"] else 1


if __name__ == "__main__":
    sys.exit(main())

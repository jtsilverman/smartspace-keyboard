#!/usr/bin/env python3
"""Record what the stock keyboard produces for one oracle slice.

Runs `StockOracleTests` against the real stock keyboard in a simulator, parses
the printed rows, and merges them into `eval/oracle/stock-<date>.tsv`. Rerunning
a slice resumes: ids already in the file are passed to the suite as ORACLE_SKIP
and never retyped. A run killed mid-slice still holds its rows in the log, so
`--merge-only` recovers them without retyping.

    python3 eval/oracle/record.py <udid> sloppy|nospace|context|names|drift

Every run resets the learned keyboard state first
(eval/v4/reset-keyboard-state.sh). Stock's engine adapts to what it has typed,
so a slice recorded from an adapted lexicon is not the same measurement as one
recorded from a cleared lexicon. A resume therefore starts from the same
cleared state row 1 started from.

Drift mode writes eval/oracle/drift-<date>.tsv and diffs it against the frozen
recording, which is check 1's stability gate.
"""
import argparse
import csv
import datetime
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ORACLE = ROOT / "eval" / "oracle"
CORPUS = ORACLE / "corpus"
DERIVED = Path.home() / ".smartspace-oracle" / "DD"
SLICES = ["sloppy", "nospace", "context", "names", "drift"]
FIELDS = ["id", "slice", "typed", "offsets", "produced", "device", "ios", "recorded"]


def corpus_rows():
    rows = {}
    for name in SLICES[:4]:
        with open(CORPUS / f"{name}.tsv", newline="") as f:
            for row in csv.DictReader(f, delimiter="\t"):
                rows[row["id"]] = row
    return rows


def device_info(udid: str):
    data = json.loads(subprocess.run(
        ["xcrun", "simctl", "list", "devices", "-j"],
        capture_output=True, text=True, check=True).stdout)
    for runtime, devices in data["devices"].items():
        for device in devices:
            if device["udid"] == udid:
                ios = runtime.split("iOS-")[-1].replace("-", ".")
                return device["name"], ios
    sys.exit(f"udid {udid} is not a known simulator")


def read_existing(path: Path):
    if not path.exists():
        return {}
    with open(path, newline="") as f:
        return {row["id"]: row for row in csv.DictReader(f, delimiter="\t")}


def write_rows(path: Path, rows: dict):
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, FIELDS, delimiter="\t", quoting=csv.QUOTE_NONE,
                                quotechar=None, lineterminator="\n")
        writer.writeheader()
        for key in sorted(rows):
            writer.writerow(rows[key])


def run_slice(udid: str, slice_name: str, skip: set, log: Path):
    method = "testRecordDrift" if slice_name == "drift" else \
        f"testRecord{slice_name.capitalize()}"
    env = dict(os.environ, TEST_RUNNER_ORACLE_SKIP=",".join(sorted(skip)))
    command = [
        "xcodebuild", "test-without-building", "-scheme", "SmartSpace",
        "-project", str(ROOT / "app" / "SmartSpace.xcodeproj"),
        "-only-testing:SmartSpaceUITests/StockOracleTests/" + method,
        "-destination", f"platform=iOS Simulator,id={udid}",
        "-derivedDataPath", str(DERIVED),
    ]
    with open(log, "w") as out:
        subprocess.run(command, stdout=out, stderr=subprocess.STDOUT, env=env)
    return log.read_text()


# Xcode prefixes every runner line; the tag anchors the parse to our own output.
LINE = re.compile(r"ORACLE(?:-DRIFT)?\t([a-z]+)\t([\w-]+)\t(.*)$")


def parse(output: str, tag: str):
    seen = {}
    for line in output.splitlines():
        index = line.find(tag + "\t")
        if index < 0:
            continue
        match = LINE.match(line[index:])
        if match:
            seen[match.group(2)] = (match.group(1), match.group(3))
    return seen


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("udid")
    parser.add_argument("slice", choices=SLICES)
    parser.add_argument("--merge-only", action="store_true",
                        help="merge an existing run's log without retyping it")
    parser.add_argument("--no-reset", action="store_true",
                        help="keep the learned keyboard state; the drift slice "
                             "runs this way first, because a reset would wipe "
                             "the adaptation it is looking for")
    args = parser.parse_args()

    device, ios = device_info(args.udid)
    today = datetime.date.today().isoformat()
    corpus = corpus_rows()
    drift = args.slice == "drift"
    # The drift file names the protocol that produced it. "warm" keeps the
    # learned keyboard state, which is the adaptation question; "reset" starts
    # from a cleared dynamic lexicon, which asks whether the answers reproduce
    # at all. The two runs are different measurements and never share a file.
    protocol = "warm" if args.no_reset else "reset"
    out = ORACLE / (f"drift-{today}-{protocol}.tsv" if drift
                    else f"stock-{today}.tsv")
    rows = read_existing(out)

    if not args.merge_only:
        if not args.no_reset:
            # Called through bash: the checked-in script is not mode +x.
            subprocess.run(["bash", str(ROOT / "eval" / "v4" / "reset-keyboard-state.sh"),
                            args.udid], check=True)
        subprocess.run(["xcrun", "simctl", "boot", args.udid], capture_output=True)
        subprocess.run(["xcrun", "simctl", "bootstatus", args.udid], capture_output=True)
        app = DERIVED / "Build/Products/Debug-iphonesimulator/SmartSpace.app"
        subprocess.run(["xcrun", "simctl", "install", args.udid, str(app)], check=True)

    if drift:
        wanted = {rid for rid in corpus if rid in drift_ids()}
    else:
        wanted = {rid for rid, row in corpus.items() if row["slice"] == args.slice}
    skip = {rid for rid in rows if rid in wanted}
    print(f"{args.slice}: {len(wanted)} rows, {len(skip)} already recorded")

    log = ORACLE / f"record-{args.slice}-{today}.log"
    tag = "ORACLE-DRIFT" if drift else "ORACLE"
    # A killed run leaves its rows in the log. Merging from the log alone
    # keeps those rows: one 17-minute slice was killed mid-run on 2026-08-19.
    output = log.read_text() if args.merge_only else run_slice(args.udid, args.slice, skip, log)
    produced = parse(output, tag)
    if not produced:
        sys.exit(f"no rows recorded; read {log}")

    for rid, (slice_name, text) in produced.items():
        source = corpus[rid]
        rows[rid] = dict(id=rid, slice=slice_name, typed=source["typed"],
                         offsets=source["offsets"], produced=text,
                         device=device, ios=ios, recorded=today)
    write_rows(out, rows)
    held = len(wanted & set(rows))
    print(f"{len(produced)} rows recorded, {held}/{len(wanted)} of {args.slice} "
          f"held in {out.name}")

    if drift:
        compare(rows)


def drift_ids():
    swift = (ROOT / "app" / "SmartSpaceUITests" / "OracleCorpus.swift").read_text()
    line = [l for l in swift.splitlines() if l.startswith("let oracleDriftIDs")][0]
    return set(re.findall(r'"([\w-]+)"', line))


def compare(fresh: dict):
    frozen_files = sorted(ORACLE.glob("stock-*.tsv"))
    if not frozen_files:
        sys.exit("no frozen recording to compare against")
    frozen = read_existing(frozen_files[0])
    same, moved = 0, []
    for rid, row in sorted(fresh.items()):
        before = frozen.get(rid)
        if before is None:
            continue
        if before["produced"] == row["produced"]:
            same += 1
        else:
            moved.append((rid, before["produced"], row["produced"]))
    for rid, before, after in moved:
        print(f"DRIFT {rid}: {before!r} -> {after!r}")
    total = same + len(moved)
    print(f"DRIFT-RESULT {same}/{total} rows reproduced "
          f"against {frozen_files[0].name}")
    if moved:
        sys.exit("stock's answers moved: the oracle is not ground truth (check 1)")


if __name__ == "__main__":
    main()

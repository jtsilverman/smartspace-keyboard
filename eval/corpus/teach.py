#!/usr/bin/env python3
"""The teacher: a local model writes casual English messages for the context
model's training text (specs/autocorrect-loop.md, unit 4).

    ssh -f -N -L 11435:localhost:11434 studio          # once, the Studio's ollama
    python3 eval/corpus/teach.py --url http://localhost:11435 --model qwen2.5:7b \
        --count 200000 --seed 1

Each prompt seeds a topic, a persona, and three words from the engine's own
list, so the text covers the vocabulary the student must rank. Replies are
split one message per line, cleaned (numbering, quotes, URLs and non-ASCII
lines go), kept only when 90% of their tokens are in the word list, and
deduplicated across every file already written. Output lands in
eval/corpus/teacher/<model>-seed<seed>.txt, one message per line, with the
model and seed in the header. No throughput target: it runs until --count.
"""
import argparse
import datetime
import json
import random
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "engine" / "tools"))
OUT = ROOT / "eval" / "corpus" / "teacher"

TOPICS = [
    "dinner plans", "running late", "the weekend", "a work meeting", "picking up the kids",
    "a delayed flight", "the game last night", "a doctor's appointment", "groceries",
    "a birthday party", "the weather", "a road trip", "a new job", "moving apartments",
    "a broken phone", "a concert", "the gym", "a first date", "a family visit",
    "a package that never arrived", "a lost wallet", "a dog that got out", "homework",
    "a car repair", "a coffee run", "the wifi being down", "a movie night", "a haircut",
    "splitting the bill", "a wedding", "a sick day", "a job interview", "a hike",
    "a flat tire", "a late train", "a neighbor", "a group chat", "a roommate", "a landlord",
    "a recipe", "a sale", "a parking ticket", "a missed call", "a hangover", "a beach day",
]
PERSONAS = [
    "a 30 year old sends a close friend", "a college student sends a roommate",
    "a parent sends their teenager", "a teenager sends a friend", "two coworkers send each other",
    "a husband sends his wife", "a woman sends her sister", "a guy sends his brother",
    "someone sends their partner", "a nurse sends a colleague", "a coach sends the team",
]
URL = re.compile(r"https?://|www\.")


def prompt(rng: random.Random, words: list) -> str:
    topic = rng.choice(TOPICS)
    persona = rng.choice(PERSONAS)
    a, b, c = rng.sample(words, 3)
    return (f"Write 12 short casual text messages {persona} about {topic}. "
            f"Use the words {a}, {b} and {c} somewhere across them. "
            "Real texting style: lowercase is fine, contractions, short. "
            "One message per line. No numbering, no quotes, no names of real companies, "
            "no emoji, plain ASCII only.")


def clean(raw: str) -> list:
    out = []
    for line in raw.splitlines():
        line = re.sub(r"^\s*(\d+[.)]|[-*•])\s*", "", line).strip().strip('"“”').strip()
        if not line or not line.isascii() or URL.search(line):
            continue
        out.append(line)
    return out


def in_vocab(lines: list, vocab: set, ratio: float = 0.9) -> list:
    out = []
    for line in lines:
        tokens = re.findall(r"[a-z']+", line.lower())
        if tokens and sum(t in vocab for t in tokens) / len(tokens) >= ratio:
            out.append(line)
    return out


def key(line: str) -> str:
    return re.sub(r"[^a-z0-9]", "", line.lower())


def dedupe(lines: list, seen: set) -> list:
    out = []
    for line in lines:
        k = key(line)
        if k and k not in seen:
            seen.add(k)
            out.append(line)
    return out


def ask(url: str, model: str, text: str, temperature: float = 0.9) -> str:
    body = json.dumps({"model": model, "stream": False,
                       "messages": [{"role": "user", "content": text}],
                       "options": {"temperature": temperature, "num_predict": 400}}).encode()
    req = urllib.request.Request(url.rstrip("/") + "/api/chat", data=body,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as resp:
        return json.load(resp)["message"]["content"]


def existing_keys() -> set:
    seen = set()
    for path in OUT.glob("*.txt"):
        for line in path.read_text().splitlines():
            if not line.startswith("#"):
                seen.add(key(line))
    return seen


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--url", default="http://localhost:11435")
    ap.add_argument("--model", default="qwen2.5:7b")
    ap.add_argument("--count", type=int, default=1000)
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args()
    import wordlist
    records = wordlist.records()
    vocab = {lower for lower, _, _ in records}
    # Words to seed prompts with: common, lowercase, three letters or more.
    words = [lower for lower, cased, _ in records[:8000] if cased.islower() and len(lower) >= 3]
    OUT.mkdir(parents=True, exist_ok=True)
    seen = existing_keys()
    path = OUT / f"{args.model.replace(':', '-').replace('/', '-')}-seed{args.seed}.txt"
    new_file = not path.exists()
    rng = random.Random(args.seed)
    written = 0
    with open(path, "a") as f:
        if new_file:
            f.write(f"# teacher={args.model} seed={args.seed} started={datetime.date.today()} "
                    f"prompts=eval/corpus/teach.py\n")
        while written < args.count:
            lines = dedupe(in_vocab(clean(ask(args.url, args.model, prompt(rng, words))), vocab), seen)
            for line in lines:
                f.write(line + "\n")
            f.flush()
            written += len(lines)
            print(f"{path.name}: +{len(lines)} = {written}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())

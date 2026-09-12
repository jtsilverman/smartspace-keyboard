#!/usr/bin/env python3
"""Extract the English NUS SMS corpus into one message per line
(specs/autocorrect-loop.md, unit 4).

    python3 eval/corpus/nus.py <smsCorpus_en_2015.03.09_all.xml>

Keeps a message when it has three or more tokens and 95% or more of them are
in the engine's word list, which drops the Singlish-heavy rows ("liao", "wat",
"oso") while keeping the texting register. Writes eval/corpus/nus-sms-en.txt.
The XML itself is not vendored (44MB); the release is at
https://github.com/kite1988/nus-sms-corpus. Used with the authors' permission
(Jake asked them, 2026-09-12); cite Chen and Kan 2013.
"""
import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "engine" / "tools"))
OUT = ROOT / "eval" / "corpus" / "nus-sms-en.txt"
HEADER = ("# NUS SMS Corpus, English, 2015-03-09 release: messages with 3+ tokens where "
          "95%+ of tokens are in the engine word list (Singlish-heavy rows dropped). Used "
          "with the authors' permission (Jake, 2026-09-12); cite Chen and Kan 2013. See "
          "engine/tools/vendor/NOTICE.\n")


def in_vocab(text: str, vocab: set):
    tokens = re.findall(r"[a-z']+", text.lower())
    if not tokens:
        return 0.0, 0
    return sum(t in vocab for t in tokens) / len(tokens), len(tokens)


def messages(xml: str) -> list:
    return [html.unescape(t).replace("\n", " ").strip()
            for t in re.findall(r"<text>(.*?)</text>", xml, re.S)]


def keep(texts: list, vocab: set, ratio: float = 0.95, min_tokens: int = 3) -> list:
    out = []
    for t in texts:
        r, n = in_vocab(t, vocab)
        if r >= ratio and n >= min_tokens:
            out.append(t)
    return out


def main() -> int:
    import wordlist
    vocab = {lower for lower, _, _ in wordlist.records()}
    texts = messages(Path(sys.argv[1]).read_text(encoding="utf-8"))
    kept = keep(texts, vocab)
    OUT.write_text(HEADER + "".join(t + "\n" for t in kept))
    print(f"nus: {len(kept)} of {len(texts)} messages kept", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())

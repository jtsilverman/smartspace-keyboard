#!/usr/bin/env python3
"""Train the student: a small next-word model in the Gboard shape, exported as
a weights file the engine maps (specs/autocorrect-loop.md, unit 5).

    ~/.smartspace-ml/bin/python engine/tools/model/train.py [--epochs 4] [--hidden 384]

Reads every line of eval/corpus/nus-sms-en.txt and eval/corpus/teacher/*.txt,
encodes words as their position in the engine's own list (the first 10,000
records of wordlist.py, which is WordRank record order, so the Swift reader
needs no vocabulary file), trains an embedding (96) -> LSTM (hidden) ->
projection (96) -> tied-embedding softmax on next-word cross-entropy, and
writes engine/Sources/TypingEngine/Resources/contextmodel.bin.

File layout, little-endian:
    "SSCM"  u32 version  u32 vocab (words + 3 specials)  u32 embed  u32 hidden
    u32 arrays, then per array: u8 nameLen, name, u32 ndim, u32 dims..., float16 data
Ids: 0 pad, 1 start, 2 unknown, then word i at i + 3. Gates in Wx/Wh/bias
are i, f, g, o (mlx.nn.LSTM).
"""
import argparse
import re
import struct
import sys
import time
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "engine" / "tools"))
OUT = ROOT / "engine" / "Sources" / "TypingEngine" / "Resources" / "contextmodel.bin"
CORPUS = [ROOT / "eval" / "corpus" / "nus-sms-en.txt"] + sorted((ROOT / "eval" / "corpus" / "teacher").glob("*.txt"))
PAD, START, UNK = 0, 1, 2
SPECIALS = 3
VOCAB_WORDS = 10_000
TOKEN = re.compile(r"[a-z']+")


def encode(sentence: str, vocab: list, index: dict = None) -> list:
    index = index if index is not None else {w: i for i, w in enumerate(vocab)}
    return [START] + [index.get(t, UNK - SPECIALS) + SPECIALS for t in TOKEN.findall(sentence.lower())]


def batch(sequences: list, length: int):
    """Padded inputs and next-word targets; PAD targets are masked in the loss."""
    x = np.full((len(sequences), length), PAD, dtype=np.int32)
    y = np.full((len(sequences), length), PAD, dtype=np.int32)
    for r, seq in enumerate(sequences):
        seq = seq[:length + 1]
        x[r, :len(seq[:length])] = seq[:length]
        y[r, :len(seq) - 1] = seq[1:]
    return x, y


def export(weights: dict, vocab_size: int, hidden: int, embed: int, path: Path):
    out = bytearray(b"SSCM" + struct.pack("<IIII", 1, vocab_size, embed, hidden))
    out += struct.pack("<I", len(weights))
    for name, array in weights.items():
        array = np.ascontiguousarray(np.asarray(array, dtype=np.float16))
        out += struct.pack("<B", len(name)) + name.encode()
        out += struct.pack("<I", array.ndim) + struct.pack(f"<{array.ndim}I", *array.shape)
        out += array.tobytes()
    path.write_bytes(bytes(out))


def read_export(data: bytes) -> dict:
    assert data[:4] == b"SSCM"
    _version, _vocab, _embed, _hidden, count = struct.unpack_from("<IIIII", data, 4)
    offset, out = 24, {}
    for _ in range(count):
        n = data[offset]; offset += 1
        name = data[offset:offset + n].decode(); offset += n
        ndim = struct.unpack_from("<I", data, offset)[0]; offset += 4
        shape = struct.unpack_from(f"<{ndim}I", data, offset); offset += 4 * ndim
        size = int(np.prod(shape)) * 2
        out[name] = np.frombuffer(data[offset:offset + size], dtype=np.float16).reshape(shape).astype(np.float32)
        offset += size
    return out


def vocabulary() -> list:
    import wordlist
    return [lower for lower, _, _ in wordlist.records()[:VOCAB_WORDS]]


def sentences() -> list:
    lines = []
    for path in CORPUS:
        if path.exists():
            lines += [l for l in path.read_text().splitlines() if l and not l.startswith("#")]
    return lines


def main() -> int:
    import mlx.core as mx
    import mlx.nn as nn
    import mlx.optimizers as optim

    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--epochs", type=int, default=4)
    ap.add_argument("--hidden", type=int, default=384)
    ap.add_argument("--embed", type=int, default=96)
    ap.add_argument("--length", type=int, default=24)
    ap.add_argument("--batch", type=int, default=64)
    ap.add_argument("--lr", type=float, default=2e-3)
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args()

    vocab = vocabulary()
    index = {w: i for i, w in enumerate(vocab)}
    lines = sentences()
    rng = np.random.default_rng(args.seed)
    rng.shuffle(lines)
    seqs = [encode(l, vocab, index) for l in lines]
    seqs = [s for s in seqs if len(s) >= 3]
    held = max(1, len(seqs) // 20)
    dev, train_seqs = seqs[:held], seqs[held:]
    V = VOCAB_WORDS + SPECIALS
    print(f"sentences {len(seqs)} (train {len(train_seqs)}, dev {held}), vocab {V}", file=sys.stderr)

    class Student(nn.Module):
        def __init__(self):
            super().__init__()
            self.embed = nn.Embedding(V, args.embed)
            self.lstm = nn.LSTM(args.embed, args.hidden)
            self.proj = nn.Linear(args.hidden, args.embed)

        def __call__(self, x):
            h, _ = self.lstm(self.embed(x))
            return self.embed.as_linear(self.proj(h))

    model = Student()
    mx.random.seed(args.seed)

    def loss_fn(model, x, y):
        logits = model(x)
        losses = nn.losses.cross_entropy(logits, y, reduction="none")
        mask = (y != PAD).astype(losses.dtype)
        return (losses * mask).sum() / mask.sum()

    optimizer = optim.Adam(learning_rate=args.lr)
    step = nn.value_and_grad(model, loss_fn)

    def perplexity(seqs_):
        total, count = 0.0, 0
        for i in range(0, len(seqs_), args.batch):
            x, y = batch(seqs_[i:i + args.batch], args.length)
            x, y = mx.array(x), mx.array(y)
            n = int((y != PAD).sum())
            total += float(loss_fn(model, x, y)) * n
            count += n
        return float(np.exp(total / max(count, 1)))

    for epoch in range(1, args.epochs + 1):
        started = time.time()
        order = rng.permutation(len(train_seqs))
        total = 0.0
        for i in range(0, len(order), args.batch):
            chunk = [train_seqs[j] for j in order[i:i + args.batch]]
            x, y = batch(chunk, args.length)
            loss, grads = step(model, mx.array(x), mx.array(y))
            optimizer.update(model, grads)
            mx.eval(model.parameters(), optimizer.state)
            total += float(loss)
        steps = (len(order) + args.batch - 1) // args.batch
        print(f"epoch {epoch}: train loss {total / steps:.3f}, dev perplexity "
              f"{perplexity(dev):.1f}, {time.time() - started:.0f}s", file=sys.stderr)

    params = model.parameters()
    weights = {
        "embed": np.array(params["embed"]["weight"]),
        "lstm.Wx": np.array(params["lstm"]["Wx"]),
        "lstm.Wh": np.array(params["lstm"]["Wh"]),
        "lstm.bias": np.array(params["lstm"]["bias"]),
        "proj.weight": np.array(params["proj"]["weight"]),
        "proj.bias": np.array(params["proj"]["bias"]),
    }
    export(weights, V, args.hidden, args.embed, OUT)
    size = sum(w.size for w in weights.values())
    print(f"wrote {OUT.name}: {size} parameters, {OUT.stat().st_size // 1024} KB", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())

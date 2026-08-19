#!/usr/bin/env python3
"""Author the stock-oracle corpus, then compile it to Swift.

The oracle corpus is the keystroke half of `specs/autocorrect-parity.md` unit 0.
It carries no expected output: stock's own answers are recorded by
`StockOracleTests` and land in `eval/oracle/stock-<date>.tsv`.

Unlike eval/v4, the TSVs here are generated rather than hand-edited, because the
sloppy slice needs per-character tap offsets. Generation is deterministic (fixed
seed, no clock), so a regeneration reproduces the committed TSVs byte for byte;
that is what freezes them. Run from the repo root:

    python3 eval/oracle/gen-corpus.py

Writes (eval/oracle/corpus/):
    sloppy.tsv    150 rows   thumb off-centre, offsets in points from key centre
    nospace.tsv   100 rows   one missing space or one stray space
    context.tsv   100 rows   50 pairs, same typed token in two sentences
    names.tsv      50 rows   contact and brand names, clean and with one slip
    drift.tsv      30 rows   ids held back from the four slices, re-recorded later

Row shape (all five files):
    id  slice  typed  offsets  note

`typed` is lowercase a-z and spaces only, so the harness never leaves the letters
plane. `offsets` is one `dx,dy` point pair per character, or `-` for centre taps.
The harness taps one committing space after the last character and records what
the field then holds.

Also writes app/SmartSpaceUITests/OracleCorpus.swift.
"""
import csv
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "eval" / "oracle" / "corpus"
SWIFT = ROOT / "app" / "SmartSpaceUITests" / "OracleCorpus.swift"

# One seed for every random draw in this file. Never read the clock.
SEED = 20260819

# Stock's letter cell at the 402pt device class: 39.47pt wide, 54pt tall
# (StockLayoutMetrics). A thumb that strays more than 26pt sideways or 16pt
# vertically is no longer sloppy typing, it is a different key on purpose, so
# the draws clamp there. Space keeps centre taps: the slice tests letters.
CELL_W, CELL_H = 39.47, 54.0
DX_SIGMA, DX_CLAMP = 8.0, 26.0
DY_SIGMA, DY_CLAMP = 7.0, 16.0
# A real thumb carries a standing bias, not fresh noise per key, so each row
# draws its own bias and every character inherits it.
BIAS_SIGMA_X, BIAS_SIGMA_Y = 4.0, 3.0

# --------------------------------------------------------------------------
# Slice 1: sloppy. Everyday texting phrases, typed with the thumb off-centre.
# --------------------------------------------------------------------------

SLOPPY_PHRASES = [
    "hey are you around", "on my way", "be there in ten", "sounds good to me",
    "i just left the house", "call me when you can", "did you eat yet",
    "running a little late", "see you tomorrow", "thanks so much",
    "what time works for you", "i can pick you up", "let me know",
    "im almost there", "sorry i missed you", "that works for me",
    "are we still on", "text me when you land", "i will be home soon",
    "do you need anything", "the meeting got moved", "not sure yet",
    "give me five minutes", "just got out of work", "traffic is terrible",
    "we should grab dinner", "did you find it", "im heading out now",
    "talk to you later", "have a good night", "i had a good time",
    "can you send it again", "the door is unlocked", "im in the parking lot",
    "where do you want to eat", "i forgot my charger", "check your email",
    "the game starts at eight", "we are almost done", "let me check",
    "i got your message", "sorry for the delay", "im on the train",
    "the flight was delayed", "can we push it back", "i am so tired",
    "that is really funny", "how was your day", "the weather is awful",
    "i need more coffee", "we ran out of milk", "the store closes soon",
    "did you lock the door", "i left it on the counter", "call me back",
    "im walking the dog", "the kids are asleep", "i will bring dessert",
    "save me a seat", "the line is so long", "we got a table",
    "i am outside now", "the movie was great", "i cannot find my keys",
    "meet me at the corner", "the address is wrong", "send me the link",
    "i will look into it", "that is a good idea", "we can figure it out",
    "the package arrived", "i signed for it", "the wifi is down",
    "my phone is dying", "i lost my headphones", "the battery died",
    "can you hear me", "you are breaking up", "i will call you back",
    "the connection is bad", "let me step outside", "i am in a meeting",
    "give me one second", "i am reading it now", "that makes sense",
    "i completely agree", "we should talk about it", "i am free after five",
    "the earlier the better", "i will be there early", "do not wait for me",
    "start without me", "i am pulling up now", "found a spot",
    "the garage is full", "i parked around back", "coming up the stairs",
    "buzz me in", "i am at the front door", "which apartment",
    "third floor on the left", "i brought snacks", "who else is coming",
    "just the four of us", "bring a jacket", "it is cold out there",
    "the rain stopped", "the roads are icy", "drive safe",
    "text me when you get home", "i made it back", "that was a long drive",
    "i slept the whole way", "we landed early", "baggage claim is packed",
    "my bag never showed up", "the hotel is nice", "the room is tiny",
    "breakfast is included", "check out is at eleven", "i booked the flight",
    "the ticket was cheap", "i have a middle seat", "the layover is short",
    "i am boarding now", "see you at the gate",
    "my phone is on airplane mode", "i will be offline",
    "message me on the app", "i will read it later", "sorry i fell asleep",
    "just woke up", "give me a minute to get ready",
    "i am jumping in the shower", "leaving in five", "i am running behind",
    "start the food without me", "order me the usual", "no onions please",
    "the food is here", "it got cold", "i will heat it up",
    "there are leftovers", "help yourself", "i am still hungry",
    "that was delicious", "we should go back", "next time i am buying",
    "you got the last one", "let me pay this time",
]
assert len(SLOPPY_PHRASES) == 150, len(SLOPPY_PHRASES)

# --------------------------------------------------------------------------
# Slice 2: nospace. Fifty phrases with one space missing, fifty with one
# stray space inside a word. Typed clean: the slice tests the split and the
# join, not the thumb.
# --------------------------------------------------------------------------

MISSING_SPACE = [
    "im onmy way", "see youtomorrow", "thankyou so much", "i willbe there soon",
    "call melater", "whattime is it", "iam almost there", "letme know",
    "sounds goodto me", "are youcoming", "i gotyour message", "we shouldgo",
    "the mealwas great", "can youhear me", "i willcall you back",
    "howwas your day", "i needmore coffee", "the storecloses soon",
    "did youlock the door", "meet meat the corner", "sendme the link",
    "that isa good idea", "the packagearrived", "my phoneis dying",
    "give meone second", "i amin a meeting", "maybenext week",
    "any timeworks", "i willbe there early", "do notwait for me",
    "i parkedaround back", "buzz mein", "which apartmentis it",
    "who elseis coming", "bring ajacket", "the rainstopped", "drivesafe",
    "i madeit back", "we landedearly", "the hotelis nice",
    "breakfastis included", "i bookedthe flight", "the ticketwas cheap",
    "i amboarding now", "see youat the gate", "sorry ifell asleep",
    "just wokeup", "almostready", "leavingin five", "order methe usual",
]
STRAY_SPACE = [
    "see you tomo rrow", "than ks so much", "i will be there toni ght",
    "call me la ter", "what ti me is it", "i am al most there",
    "let me kn ow", "sounds go od to me", "are you com ing",
    "i got your mess age", "we should g o", "the meal was gre at",
    "can you he ar me", "i will call you ba ck", "how was your d ay",
    "i need more cof fee", "the store clo ses soon", "did you lock the do or",
    "meet me at the cor ner", "send me the li nk", "that is a good id ea",
    "the pack age arrived", "my ph one is dying", "give me one sec ond",
    "i am in a meet ing", "may be next week", "any time wor ks",
    "i will be there ear ly", "do not wa it for me", "i parked around ba ck",
    "buzz me i n", "which apart ment is it", "who else is com ing",
    "bring a jack et", "the ra in stopped", "dri ve safe", "i made it ba ck",
    "we lan ded early", "the ho tel is nice", "break fast is included",
    "i booked the fli ght", "the tick et was cheap", "i am board ing now",
    "see you at the ga te", "sorry i fell asle ep", "just woke u p",
    "almost rea dy", "leav ing in five", "order me the usu al",
    "the food is he re",
]
assert len(MISSING_SPACE) == 50 and len(STRAY_SPACE) == 50

# --------------------------------------------------------------------------
# Slice 3: context. Fifty pairs. The same mistyped token sits in two
# sentences that pull it to two different words. A correction engine that
# never reads the sentence cannot pass both halves of a pair.
# --------------------------------------------------------------------------

CONTEXT_PAIRS = [
    ("fro", "thanks fro the ride", "i just got back fro work"),
    ("si", "that si really great", "si happy for you guys"),
    ("ot", "i want ot go home", "a lot ot people showed up"),
    ("wat", "wat time is dinner", "wat for me outside"),
    ("hom", "i am driving hom now", "hom many are coming"),
    ("ther", "i will be ther soon", "ther car is outside"),
    ("bak", "call me bak later", "can you bak a cake"),
    ("wer", "we wer already gone", "wer are you right now"),
    ("thn", "thn i went home", "thn you so much"),
    ("nw", "i am leaving nw", "she got a nw phone"),
    ("hav", "do you hav a minute", "i hav to leave early"),
    ("sen", "i sen it yesterday", "have you sen my keys"),
    ("mad", "she was so mad", "i mad you a sandwich"),
    ("liv", "i liv on the third floor", "he is still liv at home"),
    ("bin", "throw it in the bin", "i have bin waiting an hour"),
    ("ar", "how ar you doing", "we ar almost there"),
    ("cant", "i cant find my keys", "the cant was too high"),
    ("wont", "he wont answer me", "she has a wont of leaving early"),
    ("fell", "i fell asleep on the couch", "the fell of the room was off"),
    ("hte", "hte door is unlocked", "give it to hte other guy"),
    ("teh", "teh meeting got moved", "i left it on teh counter"),
    ("adn", "you adn me both", "adn then he left"),
    ("nad", "salt nad pepper", "nad i told him no"),
    ("ans", "coffee ans a bagel", "ans then we left"),
    ("dont", "dont forget the milk", "i dont think so"),
    ("im", "im on my way", "tell im i said hi"),
    ("ill", "i think im getting ill", "ill call you tonight"),
    ("id", "i lost my id card", "id rather stay home"),
    ("wel", "wel be there at six", "the wel ran dry"),
    ("shes", "shes already left", "the shes are in the closet"),
    ("thier", "thier car broke down", "i went over thier last night"),
    ("recieve", "did you recieve my email", "the recieve was very warm"),
    ("definately", "i definately left it there", "that was definately him"),
    ("seperate", "we took seperate cars", "keep them seperate please"),
    ("occured", "it occured to me later", "the delay occured again"),
    ("becuase", "becuase i said so", "i left becuase of the rain"),
    ("recomend", "i recomend the fish", "would you recomend it"),
    ("tommorow", "see you tommorow morning", "tommorow works better"),
    ("alot", "i miss you alot", "alot of people came"),
    ("prolly", "prolly around eight", "i will prolly be late"),
    ("gonna", "i am gonna be late", "it is gonna rain"),
    ("finaly", "we finaly got a table", "finaly some good news"),
    ("wich", "wich one do you want", "the wich hazel is empty"),
    ("no", "i have no idea", "did you no about this"),
    ("of", "a cup of coffee", "i want to get of the train"),
    ("to", "i am going to work", "the food was to cold"),
    ("your", "is that your car", "your going to love this"),
    ("its", "its going to rain", "the dog hurt its paw"),
    ("were", "we were already there", "were you at the game"),
    ("then", "then we went home", "bigger then the last one"),
]
assert len(CONTEXT_PAIRS) == 50

# --------------------------------------------------------------------------
# Slice 4: names. Twenty-five carriers typed clean, twenty-five with one
# slip. Every carrier starts with a lowercase word so the name is never the
# field's first word, where autocap would capitalize anything.
# --------------------------------------------------------------------------

NAMES_CLEAN = [
    "tell jake i said hi", "i saw sarah at the store", "michael is running late",
    "ask jessica about it", "david never texted back", "emily got the job",
    "call daniel tonight", "rachel is bringing dessert", "matthew forgot his keys",
    "olivia is on her way", "i sent it to andrew", "sophia picked the place",
    "ryan is parking the car", "hannah left already", "nathan is still working",
    "i work at google now", "she bought a new iphone", "we watched it on netflix",
    "order it from amazon", "the starbucks on main street",
    "i uninstalled instagram", "he posted it on youtube", "we booked it on airbnb",
    "my flight is on delta", "i paid with venmo",
]
NAMES_SLIP = [
    ("tell jaje i said hi", "jake"), ("i saw sarha at the store", "sarah"),
    ("michal is running late", "michael"), ("ask jesica about it", "jessica"),
    ("davod never texted back", "david"), ("emliy got the job", "emily"),
    ("call danial tonight", "daniel"), ("rachal is bringing dessert", "rachel"),
    ("mathew forgot his keys", "matthew"), ("olivai is on her way", "olivia"),
    ("i sent it to andrwe", "andrew"), ("sophie picked the place", "sophia"),
    ("rryan is parking the car", "ryan"), ("hanah left already", "hannah"),
    ("nathen is still working", "nathan"), ("i work at googel now", "google"),
    ("she bought a new ipone", "iphone"), ("we watched it on netlix", "netflix"),
    ("order it from amazn", "amazon"), ("the starbcks on main street", "starbucks"),
    ("i uninstalled instgram", "instagram"), ("he posted it on youtub", "youtube"),
    ("we booked it on airbnd", "airbnb"), ("my flight is on detla", "delta"),
    ("i paid with vemno", "venmo"),
]
assert len(NAMES_CLEAN) == 25 and len(NAMES_SLIP) == 25


def offsets_for(phrase: str, rng: random.Random) -> str:
    """One `dx,dy` pair per character, in points from the key's centre."""
    bias_x = rng.gauss(0, BIAS_SIGMA_X)
    bias_y = rng.gauss(0, BIAS_SIGMA_Y)
    pairs = []
    for ch in phrase:
        if ch == " ":
            pairs.append("0.0,0.0")
            continue
        dx = max(-DX_CLAMP, min(DX_CLAMP, bias_x + rng.gauss(0, DX_SIGMA)))
        dy = max(-DY_CLAMP, min(DY_CLAMP, bias_y + rng.gauss(0, DY_SIGMA)))
        pairs.append(f"{dx:.2f},{dy:.2f}")
    return ";".join(pairs)


def build_rows():
    rng = random.Random(SEED)
    slices = {}

    sloppy = []
    for i, phrase in enumerate(SLOPPY_PHRASES, 1):
        sloppy.append([f"slop-{i:03d}", "sloppy", phrase, offsets_for(phrase, rng),
                       "thumb off-centre, offsets from key centre"])
    slices["sloppy"] = sloppy

    nospace = []
    for i, phrase in enumerate(MISSING_SPACE, 1):
        nospace.append([f"nosp-{i:03d}", "nospace", phrase, "-", "one space missing"])
    for i, phrase in enumerate(STRAY_SPACE, 51):
        nospace.append([f"nosp-{i:03d}", "nospace", phrase, "-", "one stray space inside a word"])
    slices["nospace"] = nospace

    context = []
    for i, (token, first, second) in enumerate(CONTEXT_PAIRS, 1):
        context.append([f"ctx-{i:03d}a", "context", first, "-", f"token {token}, sentence a"])
        context.append([f"ctx-{i:03d}b", "context", second, "-", f"token {token}, sentence b"])
    slices["context"] = context

    names = []
    for i, phrase in enumerate(NAMES_CLEAN, 1):
        names.append([f"name-{i:03d}", "names", phrase, "-", "typed clean, must survive"])
    for i, (phrase, target) in enumerate(NAMES_SLIP, 26):
        names.append([f"name-{i:03d}", "names", phrase, "-", f"one slip, target {target}"])
    slices["names"] = names

    for name, rows in slices.items():
        expected = {"sloppy": 150, "nospace": 100, "context": 100, "names": 50}[name]
        assert len(rows) == expected, f"{name}: {len(rows)} rows, expected {expected}"

    # The drift slice is a stratified sample of the 400, held back and
    # re-recorded a day later. It is a subset, not a 401st row: check 1 of
    # specs/autocorrect-parity.md pins the corpus at 400 rows.
    drift_rng = random.Random(SEED + 1)
    quota = {"sloppy": 11, "nospace": 8, "context": 7, "names": 4}
    drift = []
    for name, count in quota.items():
        drift.extend(sorted(drift_rng.sample(slices[name], count), key=lambda r: r[0]))
    assert len(drift) == 30
    slices["drift"] = drift
    return slices


def write_tsv(path: Path, rows):
    with open(path, "w", newline="") as f:
        writer = csv.writer(f, delimiter="\t", quoting=csv.QUOTE_NONE,
                            quotechar=None, lineterminator="\n")
        writer.writerow(["id", "slice", "typed", "offsets", "note"])
        writer.writerows(rows)


def swift_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_swift(slices):
    lines = [
        "// GENERATED from eval/oracle/corpus/*.tsv by eval/oracle/gen-corpus.py",
        "// -- do not hand-edit. Stock-oracle corpus (specs/autocorrect-parity.md",
        "// unit 0). FROZEN: the rows carry keystrokes only; stock's own answers",
        "// are recorded into eval/oracle/stock-<date>.tsv by StockOracleTests.",
        "",
        "import CoreGraphics",
        "",
        "struct OracleRow {",
        "    let id: String",
        "    let slice: String",
        "    /// Lowercase a-z and spaces only, so the harness never leaves the",
        "    /// letters plane. The harness taps one committing space after the",
        "    /// last character.",
        "    let typed: String",
        "    /// One offset per character of `typed`, in points from the key's",
        "    /// centre. Empty means every tap lands dead centre.",
        "    let offsets: [CGVector]",
        "}",
        "",
    ]
    for name in ("sloppy", "nospace", "context", "names"):
        rows = slices[name]
        lines.append(f"let oracle{name.capitalize()}: [OracleRow] = [")
        for rid, slice_name, typed, offsets, _note in rows:
            if offsets == "-":
                vectors = "[]"
            else:
                pairs = [p.split(",") for p in offsets.split(";")]
                vectors = "[" + ", ".join(
                    f"CGVector(dx: {dx}, dy: {dy})" for dx, dy in pairs) + "]"
            lines.append(
                f"    OracleRow(id: {swift_str(rid)}, slice: {swift_str(slice_name)}, "
                f"typed: {swift_str(typed)}, offsets: {vectors}),")
        lines.append("]")
        lines.append("")
    drift_ids = ", ".join(swift_str(r[0]) for r in slices["drift"])
    lines.append("/// Held back from the 400 and re-recorded a day later. If stock's")
    lines.append("/// answers move, the oracle is not ground truth (check 1).")
    lines.append(f"let oracleDriftIDs: Set<String> = [{drift_ids}]")
    lines.append("")
    lines.append("let oracleSlices: [String: [OracleRow]] = [")
    for name in ("sloppy", "nospace", "context", "names"):
        lines.append(f"    \"{name}\": oracle{name.capitalize()},")
    lines.append("]")
    lines.append("")
    SWIFT.write_text("\n".join(lines))


def main():
    slices = build_rows()
    OUT.mkdir(parents=True, exist_ok=True)
    for name, rows in slices.items():
        write_tsv(OUT / f"{name}.tsv", rows)
    write_swift(slices)
    total = sum(len(slices[n]) for n in ("sloppy", "nospace", "context", "names"))
    print(f"corpus: {total} rows across four slices, {len(slices['drift'])} held back for drift")


if __name__ == "__main__":
    main()

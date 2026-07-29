# v4 Eval QC Report (blind pass)

QC performed blind to the implementation (no engine/ or app/ files read). Judged against standard high-quality iOS-style keyboard behavior plus each row's stated note. Policy: no gold rewrites were needed; every questionable row was cut and logged. Mechanical fixes: none.

Structural checks (all files): exact column counts, unique ids, no CR/stray newlines inside fields, expected/tolerance enums valid, scenario script tokens limited to {SP} {DSP} {BS} {RET}. Result: zero structural defects in the inputs. Cross-file check: no string appears as both a protect word and a typo target.

---

## cap.tsv — in 206, kept 92, cut 114

### Wrong or contested gold (8 cuts)
- cap-021, cap-039, cap-052, cap-081: gold `cap` immediately after a terminator with NO trailing space. iOS-style autocap requires terminator + space (otherwise "example.Com" / "report.Pdf"-class bugs, contradicting cap-148..154 which this same file gets right). Wrong gold.
- cap-103: `She said, "` -> cap. iOS-style autocap does not shift after an opening quote mid-sentence (no terminator present). Contested convention vs keyboard behavior; ambiguous, cut.
- cap-002, cap-003, cap-004: byte-identical input+gold to cap-001 (context EMPTY, expected cap). Exact duplicates.

### Near-duplicates cut (same rule, trivially different surface; kept representative named)
- after-period — cut cap-008, 009, 010, 013, 014, 015, 016, 018, 019, 024, 025, 026, 027, 028: all "sentence. " -> cap; kept variants cover baseline (007), one-word (011), casual acronym (012), prose (017), apostrophe word (020), multi-space (022), single letter (023).
- after-question — cut cap-030, 033, 034, 035, 036, 037: dup of 029 (baseline), 031 (casual), 032 (one-word); kept 038 (??), 040 (?!).
- after-exclaim — cut cap-042, 044, 045, 046, 047, 050, 051: dup of 041 (baseline), 043 (one-word); kept 048 (!!), 049 (stretched word).
- after-abbrev — cut cap-058 (e.g. dup of 057), cap-060 (i.e. dup of 059), cap-065 (Sr. dup of Jr. 064), cap-070 (a.m. dup of p.m. 069).
- after-ellipsis — cut cap-074, 075, 076, 079, 080 (dup of 073 baseline), cap-078 (Unicode dup of 077), cap-081 listed above (no-space, wrong gold).
- after-newline — cut cap-084, 085, 087, 091, 092, 094, 095, 096: all "text\n" -> cap, dup of 083; kept 086 (terminator+newline), 088 (colon override), 089 (multi-line), 090 (blank line), 093 (after digit).
- after-quote — cut cap-099 (dup of 097), cap-105, 106, 107 (mid-sentence scare-quote nocap, dup of 104); kept 097/098/100/101/102 (terminator-inside-quote variants), 108 (quoted identifier).
- after-emoji — cut cap-110, 112, 114, 115 (terminator+emoji cap, dup of 109/111/113), cap-117, 118, 119 (no-terminator nocap, dup of 116); kept 120 (inline emoji).
- after-comma-no — cut cap-122, 123, 125, 126, 127, 128, 129, 131: dup of 121 (baseline), 124 (introductory), 130 (list), 132 (texting acronym).
- mid-sentence-no — cut cap-134, 135, 136, 137, 138, 158, 163 (plain mid-sentence-after-space, dup of 133), cap-162, 164 (texting register, dup of 161), cap-140 (mid-word dup of 139), cap-149 (number-dot dup of 148), cap-151 (URL dup of 150), cap-153, 154 (dot-inside-token dup of 150/152), cap-160 (word-in-progress dup of 159).
- standalone-i — cut cap-167, 168, 169, 170, 171, 172, 173: identical i->I rule, dup of 165 (bare), 166 (after word); kept 174 (idk untouched, final i corrects).
- after-number — cut cap-176, 180, 181, 182: dup of 175 (period), 177 (?), 178 (!), 179 (currency).
- after-parenthetical — cut cap-184, 186 (cap dup of 183), cap-188, 189, 190 (nocap dup of 187); kept 185 (full sentence inside parens).
- after-colon — cut cap-192, 193, 194, 195, 198 (label-colon dup of 191), cap-197 (ratio-colon dup of time-colon 196).
- greeting-line — cut cap-200, 202, 203, 206 (salutation+newline dup of 199), cap-205 (bare word+newline, duplicates after-newline cap-083).

### Contested gold KEPT (flagged)
- cap-053, 054, 055, 056, 066 (titles Mr./Dr./Mrs./Ms./Prof. -> nocap): stock iOS capitalizes here; the file consistently targets abbreviation-aware suppression. Kept as deliberate design; note the next word after a title is almost always a proper noun anyway.
- standalone-i subcategory (165, 166, 174): measures autocorrect (i -> I on commit), not shift state. Notes disambiguate; kept, but the harness must score it as a correction, not keyboard shift.
- cap-077 (Unicode ellipsis terminates): plausible high-quality behavior, unverified against stock; kept.

### Subcategory counts after cuts
empty-field 1, sentence-start 2, after-period 7, after-question 5, after-exclaim 4, after-abbrev 16, after-ellipsis 3, after-newline 6, after-quote 7, after-emoji 5, after-comma-no 4, mid-sentence-no 17, standalone-i 3, after-number 4, after-parenthetical 3, after-colon 2, greeting-line 3.

---

## symbols.tsv — in 259, kept 179, cut 80

### Wrong / contradictory / contested gold (4 cuts)
- sym-091, sym-092 (all-caps DONT/CANT left alone): contradicts scenario e2e-028, whose gold requires THATS -> THAT'S with caps preserved (stock iOS corrects all-caps typos preserving case). Cross-file conflict resolved by cutting the weaker (leave-alone) rows.
- sym-088 ("as is his wont" stays): note itself marks it contested and admits stock fixes it; also conflicts with typos row wont -> won't. Cut.
- sym-090 ("thieves spoke in cant" stays): note marks contested; sense is vanishingly rare, conflicts with typos cant -> can't. Cut.

### Near-duplicates cut
- contraction-fix — sym-003 (third dont context adds nothing over 001/002), sym-018 (wasnt, context "that" vs kept "it").
- contraction-ambiguous-no — sym-061 (well noun, dup of 060), sym-065, 066 (ill adjective, dup of 064), sym-068, 069, 070 (id noun, dup of 067), sym-072, 073 (hell, dup of 071), sym-075, 076, 077 (shell, dup of 074), sym-079 (wed verb, dup of 078), sym-082, 083 (its possessive, dup of 081), sym-085 (were, dup of 084), sym-087 (shed verb, dup of noun 086).
- quote-open — sym-099 (string-start open, dup of 098), sym-101 (open after space, dup of 100), sym-112 (open+close pair, dup of 110), sym-115 (open after space, dup of 100).
- quote-close — sym-125, 130, 131 (close after word char + continue, dup of 120/124), sym-128, 134 (bare close after letter, dup of 118).
- quote-after-punct — sym-141, 142 (open after "? "/"! ", dup of 140), sym-143 (open after colon+space, duplicates quote-open sym-105), sym-147, 148, 149 (mark+close+continue, dup of 136/137/138).
- quote-nested — sym-152 (full nested pair, dup of 151), sym-155 (apostrophe-in-quote, dup of 154), sym-157 (nested open after space, dup of 150).
- apostrophe-word-internal — sym-161, 162 (can't/won't curl, dup of don't 160), sym-165 (we're, dup class of 163/164), sym-168 (ma'am, dup of y'all 167), sym-172 (D'Angelo, dup of O'Brien 171), sym-175 (int'l, dup of gov't 174), sym-177, 178 ('d contractions, dup of how'd 176), sym-179 (y'know, dup of y'all 167), sym-181, 182, 183 (trailing elision, dup of goin' 180).
- apostrophe-decade — sym-185, 186 ('80s/'00s, dup of '90s 184), sym-189 ('69, dup of '09 188). Elided-word rows ('til/'em/'cause/'twas/'bout/'round) all kept: distinct lexicon entries.
- prime-measurement — sym-197, 198 (heights, dup of 196), sym-203 (inches, dup of 202), sym-206, 207 (feet-before-word, dup of 201).
- emdash — sym-209, 210, 215 (unspaced -- conversion, dup of 208), sym-223 (compound hyphen untouched, dup of 218).
- ellipsis — sym-225, 228, 230 (trailing ... conversion, dup of 224), sym-229 (mid-phrase, dup of 226).
- possessive-s — sym-239, 247 (simple possessive, dup of 236/237), sym-241 (s's, dup of James's 238), sym-244 (plural possessive, dup of kids' 243), sym-246 (brand, dup of McDonald's 245), sym-248 (pronoun possessive, dup of everyone's 240).
- plural-not-possessive-no — sym-253, 256 (initialism plural, dup of CDs 252), sym-255, 257, 258 (plain plural, dup of 250), sym-259 (decade plural, dup of 251).

### Contested gold KEPT (flagged)
- sym-004, 006, 043 (cant/wont/lets fixed): notes acknowledge ambiguity; matches stock iOS. Kept.
- sym-064, 067, 071, 074, 078, 081, 084, 086 (context-gated no-fix for ill/id/hell/shell/wed/its/were/shed): beyond stock iOS (which fixes some of these context-free, e.g. ill -> I'll); kept as the high-quality context-aware target. Note tension with context-free typos rows ill/cant/wont/lets (see typos section).
- sym-089 (Professor Cant): capitalization is a strong protect signal; kept.
- sym-093 (IM me later): stock might fix IM -> I'M; kept as high-quality target.
- sym-113, 114 (straight quotes preserved in JSON/shell), sym-216, 217 (CLI flags keep --): explicitly better-than-stock targets; kept.
- sym-121, 122 (interrupted speech --" closes the quote): hard-by-design, consistent with the file's quote-stack logic (sym-104 opens after dash only with no pending open). Kept.
- sym-222 (--- markdown divider left alone): note marks contested; harmless target, kept.
- sym-129 (close quote after digit when an open quote is pending): consistent with prime rows (no pending quote there). Kept.

### Subcategory counts after cuts
contraction-fix 57, contraction-ambiguous-no 18, quote-open 14, quote-close 15, quote-after-punct 8, quote-nested 7, apostrophe-word-internal 12, apostrophe-decade 9, prime-measurement 7, emdash 12, ellipsis 8, possessive-s 8, plural-not-possessive-no 4.

(Contraction-fix intentionally left dense: each row is a distinct lemma, i.e. a distinct dictionary entry, not a surface duplicate.)

---

## protect.tsv — in 206, kept 196, cut 10

### Near-duplicates cut (mechanical #/@ protection, token identity not load-bearing)
- A111, A113, A116, A117 (lowercase short hashtags, dup of #tbt A110; kept A112 compound, A114 caps, A115 camelcase).
- A119, A120, A121, A124, A125 (plain handles, dup of @jaydenw A118; kept A122 trailing underscore, A123 intentional misspelling inside handle).
- A130 (hahahaha, dup of hahahah A129 — same base, same pattern, one char longer).

Slang, names, brands, shortforms, stylization, interjections, loanwords, number-mix all kept in full: each row is a distinct dictionary token, which is exactly what the protect eval exercises.

### Notes
- A019 "chopped" and A016 "sigma" are ordinary dictionary words; they trivially pass any engine and carry little signal, but the gold is correct. Kept.
- A180 "hell" (must not become he'll) is consistent with symbols sym-071 and absent from typos. No conflict.

### Subcategory counts after cuts
slang 35, acronym-caps 15, name 25, brand 20, url 8, email 6, hashtag 4, handle 3, stylization 17, shortform 25, number-mix 10, profanity-mild 6, non-english-loanword 10, interjection 12.

---

## typos.tsv — in 123, kept 114, cut 9

(No id column; rows identified by typed token. All typed tokens unique — verified.)

### Wrong / ambiguous gold (6 cuts)
- form -> from, fro -> for, quiet -> quite, sue -> use, tow -> two, sing -> sign: all six typed forms are common valid English words and the file has NO context column. A high-quality keyboard must not rewrite a bare valid word context-free (stock iOS does not); gold is only right with disambiguating context the file cannot express. Ambiguous without tolerance, cut.
- Kept real-word rows cant/wont/ill/lets: stock iOS special-cases these context-free, so the gold is defensible. Flagged: they sit in deliberate tension with symbols context-gated rows (sym-064 "i feel ill", sym-089); the context column there disambiguates, so both can stand.

### Near-duplicates cut (3)
- hte -> the (transposition): dup of teh -> the, same class same target.
- becasue -> because (casual): dup of becuase (transposition), same recovery.
- tommorrow -> tomorrow (casual): dup of tommorow, same class same target.

### Category-label nits (kept, gold correct)
- runing/stoping/finaly sit in doubled-letter but are missing-letter errors (the true word has the double). Correction targets are right; category label is cosmetic only.

### Subcategory counts after cuts
fat-finger 26, transposition 19, doubled-letter 12, missing-letter 15, extra-letter 13, phonetic 15, casual 10, real-word 4.

---

## completions.tsv — in 100, kept 93, cut 7

### Wrong / under-specified gold (3 cuts)
- cmp-092 ("was" -> NONE): "wasn't" is a high-frequency completion of "was" in texting; NONE gold would penalize a correct suggestion. Cut.
- cmp-082 ("ha" list omits "haha"): in texting register "haha" is arguably the top ha- completion; closed acceptable list would false-fail a good engine. Cut.
- cmp-084 ("br" list omits "brb"): same defect; "brb" is a top texting br- completion missing from the list. Cut.

### Near-duplicates cut (4)
- cmp-097, cmp-099, cmp-100 (random consonant runs, dup of zxq cmp-094).
- cmp-098 (keyboard-row mash, dup of dfgh cmp-096).

### Flagged, kept
- Remaining short-prefix rows (cmp-080, 081, 083, 085-089): closed lists over open-ended prefixes are inherently risky, but each list contains the overwhelming top-frequency candidates (the/what/more/still/come/please/from...), so a sound top-k engine intersects. Kept.
- cmp-033/034 (prob/def completions) vs protect A164/A165 (prob/def must not be autocorrected): no conflict — suggesting a completion in the bar is not auto-replacing the typed token.

### Subcategory counts after cuts
common-word 20, long-word 12, texting 15, day-month 12, greeting 8, after-context 12, short-prefix 8, no-completion-expected 6.

---

## scenarios.tsv — in 43, kept 40, cut 3

All scripts mentally simulated under stock-iOS behavior + the double-space punctuation feature. Verified per row: {BS} counts (e2e-024: 1 for "5"; e2e-025: 5 for "pizza"; e2e-026: 2 for "pm" — all correct), autocap after {RET} and after terminal marks, curly apostrophes in expected text, URL/email dots not treated as terminators, expected text reachable from the script. No miscounts found; no mechanical fixes needed.

### Cuts
- e2e-042 ("happy birthday dude{DSP}..." expected "!" under EXACT tolerance): the punctuation guess is genuinely two-way ("Happy birthday dude." is normal texting), and every comparable row (e2e-001, 003, 043) carries punct-top2 with an ALT. Exact tolerance here is inconsistent and would false-fail a reasonable engine. Ambiguous without a tolerance, cut.
- e2e-002 ("yep see you then{DSP}"): same behavior and tolerance as e2e-001 (declarative + {DSP}, punct-top2), trivially different surface. Near-duplicate.
- e2e-033 (todo list): same behavior as e2e-032 ({RET} autocap list, exact), trivially different surface. Near-duplicate.

### Flagged, kept
- e2e-040, e2e-041 ({DSP} guessing comma after greeting/list fragments): a product-feature claim beyond stock double-space-period; punct-top2 ALT covers the stock period+autocap variant, so both behaviors pass. Kept.
- e2e-021 (jake -> Jake under exact tolerance): assumes name-lexicon capitalization, which stock iOS does perform; kept.
- e2e-028 (THATS -> THAT'S preserving all-caps): kept as ground truth for the caps-correction direction; conflicting symbols rows sym-091/092 were cut (see symbols section).
- e2e-004/006/007 all interrogative+"?" but retained: are-/wh-/do-questions exercise different classifier inputs, not trivial surface variants.

### Tolerance mix after cuts
exact 12, punct-top2 12, loose-ws 16.

---

## Totals

| file | in | kept | cut |
|---|---|---|---|
| cap.tsv | 206 | 92 | 114 |
| symbols.tsv | 259 | 179 | 80 |
| protect.tsv | 206 | 196 | 10 |
| typos.tsv | 123 | 114 | 9 |
| completions.tsv | 100 | 93 | 7 |
| scenarios.tsv | 43 | 40 | 3 |
| total | 937 | 714 | 223 |

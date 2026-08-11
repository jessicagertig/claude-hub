# Criteria v5 Evaluation

## Changes from v4
1. Restructured heading detection with "FIRST, classify each section heading" instruction
2. Added explicit "Need-to-Have's:" and "Nice-to-Have's:" examples in heading lists
3. Added more neutral heading examples ("Your Responsibilities", "Who are you?", "Deine Aufgaben", "Dein Profil")
4. Added "IMPORTANT: ability to is ALWAYS tier_2" instruction with example
5. Added concrete text example: `If source_text is "You have excellent...", then text is "You have excellent..."`
6. Added explicit compound decomposition reminder with example

## Summary Stats

| JD | Criteria | T1 | T2 | T3 | Binary | Decomposed |
|---|---|---|---|---|---|---|
| Elixir | 7 | 0 | 5 | 2 | 0 | 2 |
| Glide | 17 | 8 | 9 | 0 | 0 | 0 |
| Housekeeper | 15 | 2 | 13 | 0 | 2 | 1 |
| Levellr | 12 | 2 | 10 | 0 | 0 | 5 |
| Sales Manager (DE) | 10 | 2 | 8 | 0 | 1 | 0 |
| Video Production | 42 | 11 | 31 | 0 | 3 | 6 |

## Major wins

### Glide heading detection FIXED
"Need-to-Have's:" items now tier_1 (8 tier_1 total including 2 "Excellent" items + 6 from heading). "Nice-to-Have's:" items now tier_2 (correct per decisions doc). This is the correct distribution.

### Levellr compound decomposition partially restored
12 criteria with 5 decomposed (was 10 criteria in v4). "5+ years... including frontend and backend" now correctly produces 3 criteria. Still down from v1's full 15-17, but the key compound is decomposed.

### Housekeeper decomposed count dropped to 1
15 criteria, only 1 marked as decomposed (text != source_text). Most non-compound items now preserve text == source_text. Significant improvement.

### Video Production signal words consistently recognized
All 4 "Proficiency" items: tier_1. "Highly organized": tier_1. "Excellent": tier_1. "deep understanding": tier_1. "Strong": tier_1. Consistent.

## Remaining issues (diminishing returns territory)

### Issue 1: Elixir "Solid" regressed
"Solid understanding of modern web applications" is tier_2 again (was tier_1 in v3 and v4). The signal word "solid" is present but the AI is not catching it this run. This is nondeterministic model behavior -- "solid" was recognized in v3/v4 but not v5.

### Issue 2: Levellr "proven" still not recognized
"You have a proven ability to learn fast..." is tier_2. "proven" IS a tier_1 signal word. The AI is not catching it. This has been a persistent miss.

### Issue 3: "Ability to lift more than 50lbs" still tier_1
The AI literally says "signal: 'Ability to' is a tier_2 signal, but since this is a physical requirement it still qualifies as tier_1." The model KNOWS ability to is tier_2 but overrides it. The tier is arguably wrong but the binary: true is correct and more important.

### Issue 4: Housekeeper has some questionable criteria
"No resume required." extracted as a criterion -- this is meta/process information, not a candidate requirement. "You execute it." is a sentence fragment extracted as its own criterion. "You don't need someone standing over your shoulder" is also debatable.

### Issue 5: Housekeeper stopped decomposing the checklist compound
v1-v4 decomposed "follow checklists, deep clean, change linens, make beds, restock, flag maintenance" into individual items. v5 left it as one criterion. This is a regression for housekeeper but the criteria count (15) is reasonable.

### Issue 6: Glide Nice-to-Have's tier_2 reasoning shows "default -- no signal word"
The tier IS correct (tier_2) but the reasoning should cite the heading. Minor -- the tier assignment is correct.

## Assessment
v5 is the best version so far. The tier distribution across all 6 JDs is reasonable. The key structural issues (heading detection, signal word recognition, binary flagging) are mostly resolved. Remaining issues are:
- Nondeterministic: "solid" and "proven" sometimes recognized, sometimes not
- Persistent "ability to" -> tier_1 for physical requirements
- Minor housekeeper extraction quality issues

These are diminishing-returns issues. One more iteration to try to fix the "proven" and "solid" consistency, then I'll evaluate whether to stop.

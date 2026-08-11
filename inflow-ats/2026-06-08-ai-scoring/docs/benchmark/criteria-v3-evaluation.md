# Criteria v3 Evaluation

## Changes from v2
1. Added "But when a signal word DOES appear, you MUST use it" instruction with examples
2. Added non-English equivalence instruction (German "Starke" = "Strong")
3. Expanded heading mapping with explicit tier_1/tier_2/tier_3/neutral lists
4. Added "Nice-to-Have is tier_2, NOT tier_3" note
5. Fixed binary: clarified years of experience is NOT binary, added explicit false examples
6. Strengthened text preservation with "character-for-character identical" wording

## Summary Stats

| JD | Criteria | T1 | T2 | T3 | Binary | Decomposed | v2 T1 |
|---|---|---|---|---|---|---|---|
| Elixir | 7 | 1 | 4 | 2 | 0 | 0 | 0 |
| Glide | 17 | 2 | 15 | 0 | 0 | 0 | 2 |
| Housekeeper | 20 | 2 | 18 | 0 | 2 | 18 | 0 |
| Levellr | 10 | 3 | 7 | 0 | 0 | 0 | 3 |
| Sales Manager (DE) | 10 | 2 | 8 | 0 | 1 | 0 | 1 |
| Video Production | 41 | 8 | 33 | 0 | 2 | 8 | 4 |

## Improvements

### Signal word recognition MUCH better
- Elixir: "Solid understanding" now correctly tier_1 (was tier_2 in v2)
- Video Production: "Excellent multi-tasking" now tier_1 (was tier_2 in v2)
- Video Production: "deep understanding" now tier_1 (was tier_2 in v2)
- Video Production: "Strong PC and Mac" now tier_1 (was tier_2 in v2)
- Video Production: "Proficiency in Adobe Creative Cloud" now tier_1 (was tier_2 in v2)
- Sales Manager: "Starke kommunikative Fähigkeiten" now tier_1 (was tier_2 in v2) -- German signal word recognition working!

### Binary flags improved
- Housekeeper: "Have your own reliable vehicle" now binary: true + tier_1. Correct.
- Housekeeper: "Can commit to a consistent weekly schedule, Sundays required" now binary: true + tier_1. Correct.
- Video Production: "Must provide an online demo reel" binary: true. Correct.
- Video Production: "Ability to lift more than 50lbs" binary: true. Correct.
- Sales Manager: "Mindestens 2 Jahre Vertriebserfahrung" binary: true -- WRONG. Years of experience is not binary (can have 0, 1, 2 years). Instruction says this explicitly but AI still gets it wrong.

### Text preservation better
- Elixir: 0 decomposed, all text == source_text. Perfect.
- Glide: 0 decomposed, all text == source_text. Perfect.
- Levellr: 0 decomposed, all text == source_text. Excellent -- "You have" prefixes now preserved.
- Sales Manager: 0 decomposed. Perfect.

## Remaining issues

### Issue 1: Glide heading structure STILL not respected
- "Need-to-Have's" items (except "Excellent" ones) all got tier_2. They should be tier_1 because "Need-to-Have" is a tier_1 heading.
- "Nice-to-Have's" items all got tier_2. Per the decisions doc these should also be tier_2 (not tier_3), so the TIER is correct now, but the HEADING wasn't recognized -- the reasoning says "default -- no signal word" instead of "heading: Nice-to-Have's -> tier_2". The result is correct by accident.

The heading "Need-to-Have's:" is not in the prompt's list. The apostrophe-s and colon might be causing a mismatch. Need to add variant spellings or make the matching more fuzzy.

### Issue 2: Video Production "proficiency" inconsistently recognized

"Proficiency" is a tier_1 signal word. Results:
- "Proficiency in Adobe Creative Cloud" -- tier_1. Correct.
- "proficiency with modern video codecs" -- tier_2. WRONG. Has "proficiency" signal.
- "Proficiency in modern digital photography" -- tier_2. WRONG. Has "Proficiency" signal.
- "Proficiency with a variety of photo and cinema cameras" -- tier_2. WRONG. Has "Proficiency" signal.

3 of 4 "proficiency" items are still tier_2. The model is inconsistent on this signal word.

### Issue 3: "Highly organized" not recognized as tier_1

"Highly organized; able to build a custom workflow..." -- tier_2 with "default -- no signal word". But "highly" IS in the tier_1 list as "highly [skilled/etc.]". The model might not be matching "highly organized" to the pattern "highly [X]".

### Issue 4: Video Production "3+ years experience" incorrectly tier_1

"3+ years experience in an agency..." got tier_1 with reasoning "signal: '3+ years experience'". But "3+ years" is NOT a signal word in any list. This is a fabricated signal. Should be tier_2.

### Issue 5: "Ability to lift more than 50lbs" tier_1 with wrong signal

Got tier_1 with reasoning "signal: 'ability to'" -- but "ability to" is explicitly a tier_2 signal! The AI promoted a tier_2 signal to tier_1. This item should probably be tier_2 (no tier_1 signal word appears).

### Issue 6: Housekeeper over-decomposing

20 criteria with 18 decomposed. The checklist bullet is valid decomposition, but now the AI is also decomposing the intro paragraph narratives into separate criteria that don't match source_text. This JD has a lot of prose, and the AI is extracting fragments.

### Issue 7: "Bachelor's degree preferred" binary: false

Should be binary: true -- you either have a degree or you don't.

### Issue 8: Levellr "proven" misattributed

"5+ years of professional software development experience" got tier_1 with reasoning "signal: proven" but the word "proven" is in the PREVIOUS bullet ("You have a proven ability..."), not in this one. The AI is leaking signal words across source_text boundaries.

### Issue 9: Levellr lost compound decomposition

v1 and v2 correctly decomposed "5+ years... including both frontend and backend work" into 3 criteria. v3 stopped decomposing entirely (10 criteria vs 15-17 in v1/v2). The text preservation instruction may be suppressing compound decomposition.

## Priority fixes for v4

1. **Fix heading matching** -- the AI isn't recognizing "Need-to-Have's:" as matching "Need-to-Have". Add instruction about ignoring apostrophes, colons, possessives.
2. **Fix proficiency consistency** -- add "Proficiency" to the explicit examples
3. **Fix "highly" pattern matching** -- add "Highly organized" as an explicit example
4. **Fix "3+ years" false signal** -- explicitly say that years-of-experience thresholds are NOT signal words
5. **Fix "ability to" misclassification** -- "ability to" is tier_2, not tier_1
6. **Fix compound decomposition regression** -- the text preservation instruction is too aggressive. Clarify that compounds should STILL be decomposed.
7. **Fix "Bachelor's degree" binary** -- already in examples but still missed

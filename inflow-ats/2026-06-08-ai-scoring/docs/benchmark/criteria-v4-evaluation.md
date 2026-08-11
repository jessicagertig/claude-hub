# Criteria v4 Evaluation

## Changes from v3
1. Added "Match flexibly: ignore apostrophes, colons, possessives" for heading matching
2. Added more tier examples: "Proficiency with modern video codecs" -> tier_1, "Highly organized" -> tier_1
3. Added "Ability to produce a shoot" -> tier_2 example (ability to is tier_2 NOT tier_1)
4. Added "3+ years experience" -> tier_2 example (years threshold is not a signal word)
5. Added signal word isolation rule: each criterion evaluated independently, no cross-boundary leakage
6. Clarified compound decomposition still applies, text preservation is only for non-compounds
7. Added "Bachelor's degree" -> binary: true explicit example

## Summary Stats

| JD | Criteria | T1 | T2 | T3 | Binary | Decomposed |
|---|---|---|---|---|---|---|
| Elixir | 7 | 1 | 4 | 2 | 0 | 2 |
| Glide | 17 | 2 | 15 | 0 | 0 | 0 |
| Housekeeper | 18 | 2 | 16 | 0 | 2 | 15 |
| Levellr | 10 | 2 | 8 | 0 | 0 | 10 |
| Sales Manager (DE) | 10 | 2 | 8 | 0 | 1 | 0 |
| Video Production | 41 | 11 | 30 | 0 | 3 | 8 |

## Major wins

### Video Production proficiency consistency FIXED
All 4 "Proficiency" items now correctly tier_1:
- "proficiency with modern video codecs" -- tier_1. Was tier_2 in v3.
- "Proficiency in modern digital photography" -- tier_1. Was tier_2 in v3.
- "Proficiency with cameras/lenses" -- tier_1. Was tier_2 in v3.
- "Proficiency in Adobe Creative Cloud" -- tier_1. Was already tier_1 in v3.

### "Highly organized" FIXED
Now correctly tier_1 with signal: "highly". Was tier_2 in v3.

### "3+ years experience" false signal FIXED
Now correctly tier_2 with "default -- no signal word". Was tier_1 in v3.

### "Ability to lift more than 50lbs" STILL has wrong signal
tier_1 with reasoning "signal: 'ability to'" -- but "ability to" is a tier_2 signal. The item happens to be in the right tier but for the wrong reason. "Ability to" is explicitly listed as tier_2. This is a persistent misclassification by the model. The binary: true is correct. The tier should arguably be tier_2.

### "Bachelor's degree" binary FIXED
Now binary: true. Was false in v3.

### "Mindestens 2 Jahre" binary still wrong
binary: true on Sales Manager. Years of experience is explicitly in the binary: false examples.

### "Music Industry experience... is a big plus" now correctly tier_2
Was tier_3 in v2. Now correctly tier_2 with signal: "a big plus".

## Remaining issues

### Issue 1: Glide heading structure STILL broken
"Need-to-Have's:" items (excluding "Excellent" ones) are all tier_2 when they should be tier_1 because the heading means "required." The AI is not recognizing the heading despite the flexible matching instruction.

The problem may be deeper: the heading is passed as part of the section format "--- Section 2: Need-to-Have's: ---". The AI may not be treating this as a heading match target. Or gpt-4o-mini may simply not be following the heading-based tier instructions.

### Issue 2: Levellr text preservation regression
decomposed: 10 (all criteria). Despite the instruction that non-compound text must be character-for-character identical, every single criterion has text != source_text. Examples:
- source_text: "You have a proven ability to learn fast, ship fast, and get stuff done as part of a small team"
- text: "Proven ability to learn fast, ship fast, and get stuff done as part of a small team" -- removed "You have"

The AI is still stripping "You have/You are" prefixes despite being told not to. This is a particularly stubborn behavior for gpt-4o-mini.

Also: "proven ability" is a tier_1 signal ("proven"), but this criterion got tier_2. The signal word IS present but the AI ignored it. This item should be tier_1.

### Issue 3: Levellr lost compound decomposition entirely
v1/v2 correctly decomposed "5+ years... including frontend and backend" into 3 criteria. v4 stopped decomposing. Only 10 criteria total vs 15-17 in v1/v2. The sentence "You have 5+ years of professional software development experience, including both frontend and backend work" should produce 3 criteria, not 1.

### Issue 4: "Ability to lift more than 50lbs" -- persistent tier_1 misclassification
This keeps getting tier_1 with "ability to" as reasoning despite "ability to" being explicitly listed as tier_2. The AI seems to be treating physical requirements differently, or the "ability to" signal is being confused with "must" due to the physical nature.

### Issue 5: Video Production has zero tier_3
"Music Industry experience... is a big plus" is correctly tier_2 per decisions. But truly, none of the 41 items warrant tier_3? Looking at the JD, I think this is actually correct -- there are no "bonus" or "optional" signals.

## Assessment
v4 is a strong improvement on tier assignment. The main remaining issues are:
1. Glide heading detection (structural, may need prompt architecture change)
2. Levellr text preservation (stubborn model behavior)
3. Levellr compound decomposition regression
4. Minor binary/tier misclassifications

Let me try v5 with focused fixes on heading detection and compound decomposition.

# Criteria v2 Evaluation

## Changes from v1
1. Added explicit instruction that being listed as a responsibility is NOT a tier_1 signal
2. Added "These signal words must actually appear in the text" instruction
3. Added "default -- no signal word" as tier_2 default reasoning format
4. Expanded binary examples (vehicle, schedule, portfolio, equipment)
5. Added text == source_text instruction for non-decomposed criteria
6. Added explicit heading-to-tier mapping examples (Need-to-Have -> tier_1, etc.)

## Summary Stats

| JD | Criteria | T1 | T2 | T3 | Binary | Decomposed | v1 T1 |
|---|---|---|---|---|---|---|---|
| Elixir | 7 | 0 | 5 | 2 | 0 | 3 | 3 |
| Glide | 17 | 2 | 12 | 3 | 0 | 0 | 8 |
| Housekeeper | 15 | 0 | 15 | 0 | 0 | 13 | 6 |
| Levellr | 15 | 3 | 12 | 0 | 0 | 15 | 3 |
| Sales Manager (DE) | 10 | 1 | 9 | 0 | 0 | 0 | 12 |
| Video Production | 42 | 4 | 37 | 1 | 4 | 22 | 36 |

## Major improvements

### tier_1 over-assignment FIXED
- Sales Manager: 12 -> 1 tier_1. The remaining tier_1 is "Mindestens 2 Jahre" (minimum 2 years) which correctly has "minimum" as signal. All German false positives eliminated.
- Video Production: 36 -> 4 tier_1. Massive improvement. The 4 tier_1 items all have real signal words ("required"/"Must").
- Glide: 8 -> 2 tier_1. Only "Excellent understanding..." items remain tier_1, correctly citing "excellent."
- Responsibilities no longer auto-promoted to tier_1. 

### binary flag improved
- Video Production: 1 -> 4 binary. Now catches: "Ability to lift more than 50lbs", "3+ years experience" (borderline), "Must provide demo reel", "Highly organized in project approach. Must be able to systematically achieve success".
- Improvement over v1, but still issues (see below).

### text == source_text improved for some JDs
- Glide: decomposed 19 -> 0. All non-compound items now have text == source_text. 
- Sales Manager: decomposed 4 -> 0. All items preserved original text.
- Elixir: decomposed 3 -> 3. Correct -- those 3 ARE actual decompositions from compounds.

## Remaining issues

### Issue 1: tier_1 UNDER-assignment -- signal words being missed

The pendulum swung too far. Several items with legitimate tier_1 signal words are now tier_2:

**Elixir:**
- "Solid understanding of modern web applications" -- "Solid" IS in the tier_1 signal list. Got tier_2.

**Video Production:**
- "Highly organized; able to build custom workflow..." -- "Highly" IS tier_1 signal. Got tier_2.
- "Excellent multi-tasking and self-management skills" -- "Excellent" IS tier_1. Got tier_2.
- "deep understanding of and passion for all modern media platforms" -- "deep" IS tier_1. Got tier_2.
- "Strong PC and Mac general computing skills" -- "Strong" IS tier_1. Got tier_2.
- "proficiency with modern video codecs" -- "proficiency" IS tier_1. Got tier_2.
- "Proficiency in modern digital photography workflows" -- "Proficiency" IS tier_1. Got tier_2.
- "Proficiency with a variety of photo and cinema cameras" -- "Proficiency" IS tier_1. Got tier_2.
- "Proficiency in Adobe Creative Cloud" -- "Proficiency" IS tier_1. Got tier_2.

The AI is now ignoring the strong expectation signals (excellent, strong, proficient, deep, highly, solid) and defaulting everything to tier_2. The "These signal words must actually appear in the text" instruction worked for preventing hallucinated signals, but the AI is now ALSO ignoring signals that DO appear in the text.

**Sales Manager DE:**
- "Starke kommunikative Fähigkeiten" -- "Starke" (strong) IS a tier_1 signal equivalent. Got tier_2. This is expected since the signal list is in English, but the non-English equivalents should also be recognized.

### Issue 2: Glide section heading structure NOT respected

The Glide JD has clear section structure:
- "Need-to-Have's" heading -- should default items to tier_1
- "Nice-to-Have's" heading -- should default items to tier_2

But ALL "Need-to-Have's" items got tier_2 (except the 2 with "Excellent" signal word). The heading-based tier structure was ignored. The "Nice-to-Have's" items correctly got tier_3... wait, they should be tier_2 per the decisions doc ("nice-to-haves -> tier_2"). They got tier_3 which is wrong.

Glide tier assessment:
- Responsibilities section (no tier heading): all tier_2 -- CORRECT
- Need-to-Have's section: should be tier_1 default, got tier_2 -- WRONG (6 of 8 items)
- Nice-to-Have's section: should be tier_2, got tier_3 -- WRONG (3 of 3 items)

### Issue 3: binary flag still underused

Missing binary: true:
- Housekeeper: "Have your own reliable vehicle" -- binary. Got false.
- Housekeeper: "Can commit to a consistent weekly schedule, Sundays required" -- binary. Got false.
- Video Production: "Bachelor's degree" -- binary. Got false.
- Video Production: "3+ years experience" -- this got binary: true, but years of experience is actually a range (1 year, 2 years, etc.), not truly binary. This is a false positive.
- Video Production: "Highly organized in project approach" -- this got binary: true, but organizational skill is a spectrum, not binary. False positive.

### Issue 4: text != source_text still happening (Housekeeper, Levellr, Video Production)

Housekeeper: 13/15 decomposed. Many are valid decompositions (the checklist bullet), but some are rewording:
- source_text: "Are physically up for the work — stairs, lifting, on your feet all shift"
- text: "Be physically up for the work — stairs, lifting, on your feet all shift." -- added period, changed "Are" to "Be"
- source_text: "Have your own reliable vehicle — properties span Colorado Springs and Woodland Park"
- text: "Have your own reliable vehicle." -- truncated the source

Levellr: 15/15 decomposed. Same pattern -- AI removing "You have", "You are" prefixes despite the instruction not to.
- source_text: "You have strong knowledge of TypeScript and/or JavaScript"
- text: "Strong knowledge of TypeScript and/or JavaScript" -- removed "You have"

Video Production: 22/42 decomposed. Many legitimate, but some are reformatting:
- source_text: "Receives Illustrator and Photoshop files; translates into motion graphics"
- text: "Receive Illustrator and Photoshop files; translate into motion graphics" -- changed verb form

### Issue 5: "Music Industry experience... is a big plus" got tier_3

Per the decisions doc, "a big plus" is a tier_2 signal, not tier_3. The prompt lists it under tier_2. The AI classified it as tier_3 with reasoning "is a bonus" which is wrong -- "big plus" != "bonus."

## Priority fixes for v3

1. **Fix tier_1 signal word recognition** -- the AI is now ignoring actual signal words. Need to strengthen the instruction that when a signal word IS present, it MUST be used for tier assignment. Consider adding examples of correct signal word recognition.
2. **Fix Glide heading structure** -- Need to make the heading detection more explicit. The AI sees "Need-to-Have's" but doesn't map it to tier_1.
3. **Fix "a big plus" -> tier_2** -- Already in the prompt, AI misclassifying.
4. **Fix text preservation** -- The instruction isn't being followed for Levellr/Housekeeper. Consider stronger wording.
5. **Fix binary false positives** -- "3+ years experience" and "Highly organized" are not binary. Clarify that years of experience is NOT binary.

# Criteria v1 Evaluation

## Summary Stats

| JD | Criteria | T1 | T2 | T3 | Binary | Decomposed |
|---|---|---|---|---|---|---|
| Elixir | 7 | 3 | 2 | 2 | 0 | 3 |
| Glide | 19 | 8 | 8 | 3 | 0 | 19 |
| Housekeeper | 17 | 6 | 11 | 0 | 0 | 17 |
| Levellr | 17 | 3 | 14 | 0 | 0 | 17 |
| Sales Manager (DE) | 12 | 12 | 0 | 0 | 0 | 4 |
| Video Production | 41 | 36 | 5 | 0 | 1 | 41 |

## Issue 1: Binary flag severely underused (ALL JDs)

Only 1 binary flag across all 6 JDs ("Ability to lift more than 50lbs" on video production).

Should be binary: true:
- Housekeeper: "Have your own reliable vehicle" -- you either have one or you don't
- Housekeeper: "Can commit to a consistent weekly schedule, Sundays required" -- schedule availability is binary
- Video Production: "Bachelor's degree preferred" -- degree is binary
- Video Production: "Must provide an online demo reel" -- you have it or you don't

The prompt says `binary: true if this criterion is either met or not met (degree, license, certification, legal authorization)`. The parenthetical examples are too narrow -- it only lists formal credentials. Vehicle ownership, schedule availability, and portfolio requirements are also binary. Need to expand the examples.

## Issue 2: tier_1 over-assignment -- Sales Manager DE (12/12 tier_1)

The German JD has ZERO explicit required/preferred signals in the section headings. "Deine Aufgaben" (Your Tasks) and "Dein Profil" (Your Profile) are neutral labels. The content is all unlabeled bullets.

Yet the AI assigned every single criterion tier_1, inventing justifications:
- "Signal word 'Führung' implies this is a critical responsibility" -- "Führung" means "conducting" (as in conducting conversations), not "leadership" as a signal word
- "Signal word 'Unterstützung' implies critical" -- "Unterstützung" literally means "support/assistance"
- "Signal word 'Teamplayer' indicates critical" -- "Teamplayer" is not a tier signal
- "Signal word 'echt' emphasizes importance" -- no, "echte People-Person" means "a real people person"

Only 2 criteria have legitimate tier_1 signals:
- "Mindestens 2 Jahre Vertriebserfahrung" -- "Mindestens" (at least/minimum) is a real tier_1 signal
- "Starke kommunikative Fähigkeiten" -- "Starke" (strong) is a real tier_1 signal

The remaining 10 should be tier_2 (default, unlabeled).

Root cause: The prompt says to apply rules "identically regardless of language" but the AI is hallucinating signal words in German that don't map to the English signal lists. It's interpreting ordinary German verbs and nouns as "strong expectation signals."

## Issue 3: tier_1 over-assignment -- Video Production (36/41 tier_1)

This JD has no required/preferred section structure. All sections are neutral ("Responsibilities", "Personal and Organizational Skills", "Additional Skills and Responsibilities", "Job Requirements"). None of these headings signal tier_1.

The AI is treating every responsibility and skill as tier_1 with vague reasoning like "explicitly signaled as necessary" or "explicitly signaled as required" -- but there IS no explicit signal. The items are just listed as job duties and skills.

Correct tier_1 from this JD (items with actual signal words):
- "Highly organized" -- "Highly" is a strong expectation signal
- "Excellent multi-tasking" -- "Excellent" is a strong expectation signal  
- "deep understanding" -- "deep" is a strong expectation signal
- "Strong PC and Mac" -- "Strong" is a strong expectation signal
- "proficiency with modern video codecs" -- "proficiency" is tier_1
- "Proficiency in modern digital photography" -- "proficiency" is tier_1
- "Proficiency with cameras/lenses" -- "proficiency" is tier_1
- "Proficiency in Adobe Creative Cloud" -- "proficiency" is tier_1
- "Must provide an online demo reel" -- "Must" is tier_1
- "Must be able to systematically achieve success" -- "Must" is tier_1

The remaining ~26 items should be tier_2 (unlabeled responsibilities and skills).

Root cause: The AI is treating "being a listed responsibility" as equivalent to "explicitly signaled as required." The prompt says tier_1 requires explicit signals, but the AI isn't enforcing that. It's classifying simple duty statements ("Acts as cinematographer") as tier_1.

## Issue 4: tier_1 over-assignment -- Glide responsibilities (8/8 tier_1)

Same problem as video production but on the "Your Responsibilities" section. All 8 responsibilities are tier_1 with reasoning "Signal of critical responsibility in the role." These are just job duties with no explicit signal words. They should all be tier_2.

Additionally the "Need-to-Have's" section heading IS a tier structure signal, but the AI gave those items tier_2 instead of tier_1. The heading "Need-to-Have's" is equivalent to "required" -- these should be tier_1. And the "Nice-to-Have's" items were correctly placed at tier_3 tier-wise but were given tier_3 instead of the correct tier_2.

Wait -- re-reading the decisions doc: "In a JD with 'must-haves' and 'nice-to-haves' sections: must-haves -> tier_1, nice-to-haves -> tier_2." So:
- "Need-to-Have's" items should be tier_1 (they got tier_2 -- WRONG)
- "Nice-to-Have's" items should be tier_2 (they got tier_3 -- WRONG)
- "Your Responsibilities" items should be tier_2 (they got tier_1 -- WRONG)

The tier assignments on Glide are almost perfectly inverted.

## Issue 5: Decomposed count equals total count (Glide 19/19, Housekeeper 17/17, Levellr 17/17, Video Production 41/41)

The decomposed count is `criteria.count { |c| c['text'] != c['source_text'] }`. When text != source_text, it counts as decomposed. But many criteria that were NOT decomposed from a compound have different text than source_text because the AI is rewording.

Examples from Housekeeper:
- source_text: "✅ No resume required. Show up consistently, work hard, and communicate well. That's what matters."
- text: "Show up consistently" -- this IS a valid decomposition from compound
- But source_text: "Take pride in a clean that actually looks and feels clean."  
- text: "Take pride in a clean that actually looks and feels clean" -- differs only by missing period. Still counted as decomposed.

Examples from Levellr:
- source_text: "You have a proven ability to learn fast, ship fast, and get stuff done as part of a small team"
- text: "Proven ability to learn fast" -- valid decomposition
- But source_text: "You have strong knowledge of TypeScript and/or JavaScript"
- text: "Strong knowledge of TypeScript and/or JavaScript" -- AI removed "You have", making text != source_text

The AI is cleaning up the text (removing "You have", "You are", trailing punctuation) even when the criterion is NOT decomposed. For non-compound criteria, text should be identical to source_text.

## Issue 6: Elixir tier assignments

- "Able to fine-tune Postgres queries" -- tier_1 reasoning says "'Able to' signals a strong expectation." But "Able to" is not in the tier_1 signal list. "Ability to" is listed as tier_2. This should be tier_2.
- "Ability to write clear and maintainable tests" -- tier_1 reasoning says "'Ability to' signaling this is critical." But "Ability to" is explicitly listed as a tier_2 signal. This should be tier_2.
- "Solid understanding of modern web applications" -- tier_2 but "Solid" IS a tier_1 signal. Should be tier_1.

The AI is promoting tier_2 signals ("ability to", "able to") to tier_1 and missing actual tier_1 signals ("solid").

## Issue 7: Zero tier_3 on 4 of 6 JDs

Housekeeper, Levellr, Sales Manager, Video Production all have 0 tier_3. 
- Housekeeper: probably correct -- no bonus/plus/optional language
- Levellr: probably correct -- the "ideally" items correctly went to tier_2
- Sales Manager: correct -- no bonus language in the JD
- Video Production: "Music Industry experience... is a big plus" got tier_2 which is correct per the decisions doc ("a big plus" -> tier_2). So zero tier_3 may be correct here. BUT "Knowledge of guitar and guitar related products" is just listed with no signal -- tier_2 is correct.

Actually the zero tier_3 is mostly fine. The Elixir JD correctly has tier_3 for (bonus) items. The tier_3 absence on other JDs is correct.

## Priority fixes for v2

1. **Fix tier_1 over-assignment** -- the biggest problem. The AI treats "being listed" as tier_1. Need to make the prompt much more explicit that tier_1 requires ACTUAL signal words from the list, and that unlabeled responsibilities default to tier_2.
2. **Fix binary underuse** -- expand the binary: true examples beyond just "degree, license, certification, legal authorization" to include vehicle, schedule, portfolio, equipment requirements.
3. **Fix text rewriting** -- instruct that for non-compound criteria, text must be identical to source_text. Only decomposed criteria should have different text.
4. **Fix section heading tier structure detection** -- Glide's "Need-to-Have's" -> tier_1, "Nice-to-Have's" -> tier_2 was completely missed.

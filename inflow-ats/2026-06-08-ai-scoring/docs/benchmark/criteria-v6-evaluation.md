# Criteria v6 Evaluation (with v7 nondeterminism check)

## Changes from v5
1. Added "proven ability to learn fast" -> tier_1 example
2. Added "Ability to lift more than 50lbs" -> tier_2 example with note "do NOT promote for physical requirements"

v7 is the same prompt as v6, run to check nondeterminism.

## v6 vs v7 comparison (same prompt, different runs)

| JD | v6 T1/T2/T3 | v7 T1/T2/T3 | v6 N | v7 N | Diff |
|---|---|---|---|---|---|
| Elixir | 1/4/2 | 0/5/2 | 7 | 7 | "Solid" tier_1 in v6, tier_2 in v7 |
| Glide | 8/9/0 | 8/9/0 | 17 | 17 | Identical |
| Housekeeper | 2/11/0 | 2/13/0 | 13 | 15 | Criteria count varies |
| Levellr | 2/10/0 | 2/8/0 | 12 | 10 | Compound decomp varies |
| Sales Manager | 2/8/0 | 2/8/0 | 10 | 10 | Identical |
| Video Production | 11/30/0 | 10/32/0 | 41 | 42 | Minor count/tier variance |

## Nondeterministic behaviors
- "Solid understanding" -- sometimes caught (v3, v4, v6), sometimes missed (v5, v7)
- Levellr compound decomposition -- 10 to 15 criteria across runs
- Housekeeper criteria count -- 13 to 20 across runs (varies by decomposition of checklist compound + extraction of prose fragments)
- Video Production criteria count -- 41 to 42 (minor variance)

## Systematic behaviors (consistent across runs)
- "proven ability" -- never recognized as tier_1 signal. 0/7 runs.
- "Mindestens" (German "minimum") -- always recognized as tier_1. 4/4 runs.
- "Starke" (German "strong") -- always recognized in recent runs. 3/3.
- "Excellent" -- always recognized. 7/7.
- "Proficiency" -- always recognized in v4+. 4/4 runs.
- "Strong" -- always recognized. 6/6 runs.
- "Highly" -- always recognized in v4+. 4/4 runs.
- "Must" -- always recognized. 7/7.
- Vehicle binary -- always correct in v3+. 4/4.
- Schedule binary -- always correct in v3+. 4/4.
- Bachelor's degree binary -- always correct in v4+. 4/4.
- Demo reel binary -- always correct. 6/6.
- Glide heading detection -- always correct in v5+. 3/3.

## Assessment
The "proven" miss is the only systematic signal word failure. It appears to be a gpt-4o-mini blind spot for this particular word, possibly because "proven ability" reads as a natural phrase rather than a technical qualifier. Adding more examples hasn't helped. This is likely a model limitation.

v6 is the best version. The quality plateau has been reached.

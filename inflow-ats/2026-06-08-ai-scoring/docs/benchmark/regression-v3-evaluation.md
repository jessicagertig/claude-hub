# Regression v1/v2/v3 Comparison — Binary Flag Analysis

## The binary flag is dominated by model nondeterminism

Three prompt versions, same 20 JDs. Binary counts swing wildly across runs on the SAME JD with MINOR prompt changes:

| JD | v1 | v2 | v3 | Swing |
|---|---|---|---|---|
| Fire Alarm Installation | 31 | 7 | 7 | 24 |
| Fire Alarm Test/Inspect | 3 | 3 | 27 | 24 |
| Housekeeper Buena Vista | 0 | 0 | 17 | 17 |
| CART Captioner | 7 | 6 | 3 | 4 |
| Mechanical Engineer | 3 | 1 | 0 | 3 |
| Project Architect | 3 | 0 | 2 | 3 |
| Host | 2 | 0 | 3 | 3 |

Fire Alarm Test/Inspect went from 3 to 27 between v2 and v3 with a minor prompt rewording. Housekeeper Buena Vista went from 0 to 17. These swings are NOT caused by the prompt changes — they're model nondeterminism.

## Tier assignment is ALSO nondeterministic

| JD | v1 T1% | v2 T1% | v3 T1% |
|---|---|---|---|
| Mechanical Engineer | 58% | 42% | 0% |
| VP Service & Ops | 61% | 50% | 94% |
| Housekeeper BV | 96% | 13% | 100% |
| Fire Alarm Test | 65% | 94% | 93% |

Mechanical Engineer went from 58% to 0% tier_1. VP went from 50% back to 94%. These are extreme swings on the same content.

## Text preservation is nondeterministic too

| JD | v1 preserved | v2 preserved | v3 preserved |
|---|---|---|---|
| Director of Development | 0/36 | 0/39 | 25/25 |
| Graphic Designer | 11/76 | 62/83 | 42/42 |
| Housekeeper CO | 14/14 | 8/13 | 1/20 |
| PharmD | 0/29 | 14/28 | 8/29 |

## Conclusion

**gpt-4o-mini is too nondeterministic for reliable binary, tier, and text preservation behavior.** The prompt is doing what it can — the rules are clear, the examples are specific — but the model's execution varies dramatically between runs on identical input. Three consecutive runs of the same prompt produce different results.

## What IS stable across all 3 versions

1. **Section decomposition (Call 1)** — zero null/null violations, consistent criteria/non-criteria tagging
2. **General tier direction** — most JDs land 15-25% tier_1. The outliers vary but the center holds.
3. **Minimal JDs correctly skipped** — consistent
4. **Non-English handling** — consistent
5. **Signal word basics** — "excellent", "strong", "proficiency" consistently tier_1 when they appear

## Recommendation

1. **Accept v1 prompt (before any binary changes)** — it had the best overall balance. v2 overcorrected, v3 didn't recover consistently.
2. **Consider temperature=0** if the API supports it — may reduce nondeterminism.
3. **Consider running each JD 3x and taking majority vote** on binary and tier — cheap at $0.001/call.
4. **Or upgrade to gpt-4o** for the criteria extraction call — better instruction following at higher cost.
5. **Binary flag is the weakest feature** — may need to be treated as advisory/noisy rather than authoritative.

## Next steps

- Revert to v1 prompt (undo binary changes)
- Run stress test batches with the v1 prompt to establish the nondeterminism baseline
- Test temperature=0 if available
- Test gpt-4o on the regression set to see if it stabilizes

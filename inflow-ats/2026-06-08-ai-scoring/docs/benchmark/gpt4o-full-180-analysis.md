# Full 180-JD Analysis — gpt-4o vs gpt-4o-mini

## Aggregate Comparison

| Metric | gpt-4o-mini (55 JDs) | gpt-4o (138 JDs) |
|---|---|---|
| JDs with criteria | 51 | 120 |
| JDs skipped (no criteria) | 4 | 18 |
| Total criteria extracted | 965 | 2,256 |
| Avg criteria per JD | 18.9 | 18.8 |
| **Tier 1 %** | 21.2% | **20.1%** |
| **Tier 2 %** | 77.1% | 77.4% |
| **Tier 3 %** | 1.7% | **2.4%** |
| Total binary flags | 65 | 111 |
| Avg binary per JD | 1.3 | 0.9 |
| Binary % of criteria | 6.7% | 4.9% |
| Text preservation % | 62.1% | **63.4%** |
| Avg T1% per JD | 22.0% | **18.7%** |

## Key Differences

### Tier distribution
Nearly identical. gpt-4o is slightly less aggressive on tier_1 (20.1% vs 21.2%) and uses tier_3 more (2.4% vs 1.7%). Both healthy distributions.

### Binary flagging
gpt-4o flags slightly fewer binary items (0.9/JD vs 1.3/JD). This is the more conservative model — it's less likely to over-flag trade skills as binary. The nondeterminism analysis showed gpt-4o's binary is 2x more stable (σ 0.99 vs 1.99).

### Text preservation
Similar overall (63.4% vs 62.1%). gpt-4o is slightly better but the difference is small at aggregate level. The nondeterminism analysis showed the variation is run-to-run, not model-to-model.

### Tier 3 usage
gpt-4o uses tier_3 40% more often (2.4% vs 1.7%). This is the correct direction — gpt-4o-mini barely used tier_3, which meant bonus/optional items were being classified as tier_2.

## Model Recommendation

**Call 2 should use gpt-4o.** The aggregate stats are similar, but gpt-4o wins on:
1. **Stability** — 2x less nondeterministic on binary, 2x more stable JDs
2. **Tier_3 usage** — actually uses the bottom tier
3. **T1 restraint** — slightly less aggressive, fewer false-positive required flags
4. **Cost** — $0.01/JD vs $0.001/JD. At 1000 JDs/month = $10/month. Negligible.

## What both models handle well
- Section decomposition (Call 1 on mini): zero null/null across 180 JDs
- Non-English: German, Chinese, Norwegian, Spanish, Portuguese
- Minimal/general postings: correctly skipped
- Signal word recognition: "excellent", "strong", "proficiency" → tier_1
- Default tier_2: unlabeled items correctly default

## What both models struggle with
- Fire Alarm JDs: extreme nondeterminism on both models (structured "Required" headings)
- Text preservation: nondeterministic on both (same JD produces 0% and 100% across runs)
- "proven" signal: inconsistently recognized on both
- Compound decomposition: fires ~60% of the time on both

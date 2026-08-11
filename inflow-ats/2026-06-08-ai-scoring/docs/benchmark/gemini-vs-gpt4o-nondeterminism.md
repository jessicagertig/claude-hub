# Nondeterminism: gemini-3.1-flash-lite (6 runs) vs gpt-4o (5 runs)

Same prompt, same 20 JDs, same Call 1 input.

## Aggregate

| Metric | gpt-4o (5 runs) | gemini-3.1-flash-lite (6 runs) | Winner |
|---|---|---|---|
| Mean binary σ | 0.86 | 0.90 | Tie |
| Median binary σ | 0.4 | 0.5 | Tie |
| Max binary σ | 3.2 | 3.7 | gpt-4o |
| Mean T1% σ | 6.7 | **5.3** | **gemini** |
| Median T1% σ | 4.0 | **3.5** | **gemini** |
| Max T1% σ | 40.5 | **16.5** | **gemini** |
| Stable JDs (bin σ≤1, T1% σ≤5) | 40% | **65%** | **gemini** |
| Very stable JDs (bin σ≤0.5, T1% σ≤3) | 25% | 25% | Tie |
| Volatile JDs (bin σ>2 or T1% σ>10) | 30% | 30% | Tie |

## Verdict

**gemini-3.1-flash-lite is MORE stable than gpt-4o on tier assignment.**

- 65% stable vs 40% — gemini produces consistent tier assignments on nearly 2/3 of JDs
- T1% σ is lower across the board: mean 5.3 vs 6.7, max 16.5 vs 40.5
- Binary stability is a tie — both models have similar variance
- The volatile JD count (30%) is the same, but gemini's volatility is less extreme (max σ 16.5 vs 40.5)

## Cost comparison

| Metric | gpt-4o | gemini-3.1-flash-lite |
|---|---|---|
| Price per JD | ~$0.020 | ~$0.003 |
| Stability | Good | **Better** |
| Ratio | 1x | **7x cheaper, more stable** |

## Recommendation

**Switch Call 2 to gemini-3.1-flash-lite.** It's more stable on tier assignment, equally stable on binary, and 7x cheaper. The only metric where gpt-4o was clearly better was text preservation (69.7% vs 39.6%) — but text preservation is cosmetic (the source_text field always has the original).

## Caveats

- gemini-3.1-flash-lite had lower text preservation (39.6% vs 69.7%). This means more criteria have rephrased `text` fields. The `source_text` field always has the original, so this doesn't affect scoring accuracy — it's a display concern.
- Both models have 30% volatile JDs that produce different results each run. These are the same structural edge cases (Fire Alarm Required headings, dense JDs).

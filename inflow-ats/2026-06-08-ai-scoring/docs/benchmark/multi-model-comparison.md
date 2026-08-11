# Multi-Model Comparison — Call 2 Criteria Extraction

All models use the same prompt (v6), same Call 1 input (gpt-4o-mini v5). 20-JD regression set.

## Results

| Model | $/JD | Criteria/JD | T1% | T3% | Bin/JD | Preserve% | Failures |
|---|---|---|---|---|---|---|---|
| gpt-4o-mini | $0.001 | 26.3 | 30.9% | 2.3% | 3.2 | 62.1% | 1 |
| gpt-4o | $0.020 | 26.4 | 27.9% | 3.8% | 2.2 | 69.7% | 1 |
| claude-haiku-4.5 | $0.008 | 25.1 | **63.3%** | 6.2% | 2.1 | 68.2% | **11** |
| gemini-2.5-flash | $0.001 | **40.1** | 32.5% | 3.1% | 2.2 | **28.9%** | 1 |
| gemini-3.1-flash-lite | $0.003 | 27.6 | 27.4% | 3.0% | 2.1 | 39.6% | 0 |
| gemini-3.5-flash | $0.015 | 32.5 | 31.0% | 3.0% | 3.0 | 53.7% | 0 |

## Analysis

### claude-haiku-4.5 — NOT RECOMMENDED
- **63% tier_1** — massively over-promotes. Nearly everything becomes "required."
- **11 failures** — JSON parsing errors despite fence-stripping fix. Haiku wraps JSON in markdown fences and sometimes produces malformed JSON with escaped quotes.
- Good text preservation (68%) and tier_3 usage (6.2%) but the T1 over-assignment is disqualifying.

### gemini-2.5-flash — MIXED
- **40.1 criteria/JD** — over-extracts by ~50% vs other models. Splits things too aggressively.
- **28.9% preservation** — worst of all models. Rewrites almost everything.
- Tier distribution is reasonable (32.5% T1) and no failures.
- The over-extraction inflates criteria counts, which would dilute scoring.

### gemini-3.1-flash-lite — PROMISING
- **27.6 criteria/JD** — right in line with gpt-4o (26.4)
- **27.4% T1** — best (lowest) T1 percentage of all models, very close to gpt-4o
- **0 failures** — most reliable of all models tested
- **39.6% preservation** — weak, worse than gpt-4o (69.7%)
- **$0.003/JD** — 7x cheaper than gpt-4o
- Biggest concern: text preservation. Need nondeterminism data.

### gpt-4o — STILL THE QUALITY LEADER
- Best text preservation (69.7%)
- Moderate T1 (27.9%), good T3 usage (3.8%)
- Most stable on nondeterminism tests (from earlier analysis)
- 16x more expensive than 3.1-flash-lite

### gpt-4o-mini — BASELINE
- Higher T1 than gpt-4o (30.9% vs 27.9%)
- Lower preservation (62.1%)
- 2x more nondeterministic than gpt-4o (from earlier analysis)
- Cheapest at $0.001/JD

## Recommendation

| Priority | Model | Reason |
|---|---|---|
| Quality | gpt-4o | Best stability, preservation, tier balance |
| Value | gemini-3.1-flash-lite | 7x cheaper, similar tier distribution, zero failures. Needs nondeterminism testing. |
| Avoid | claude-haiku-4.5 | 63% T1 is broken, 11 failures |
| Avoid | gemini-2.5-flash | Over-extracts, poor preservation |

### gemini-3.5-flash — DECENT BUT OVERPRICED
- **31% T1** — close to gpt-4o (27.9%), reasonable
- **3.0 binary/JD** — good, highest of the reasonable models
- **53.7% preservation** — worse than gpt-4o (69.7%)
- **32.5 criteria/JD** — slightly over-extracts vs gpt-4o (26.4)
- **$0.015/JD** — nearly gpt-4o price for worse preservation
- Zero failures. Good T3 usage (3%). But no advantage over gpt-4o at similar cost.

## Final Ranking

1. **gpt-4o** ($0.020) — quality leader. Best stability, preservation, tier balance.
2. **gemini-3.1-flash-lite** ($0.003) — best value candidate. Similar tiers to gpt-4o, zero failures, 7x cheaper. Needs nondeterminism testing.
3. **gpt-4o-mini** ($0.001) — cheapest, but 2x more nondeterministic than gpt-4o.
4. **gemini-3.5-flash** ($0.015) — too aggressive on T1 for the price.
5. **gemini-2.5-flash** ($0.001) — over-extracts (40 criteria/JD vs 27 expected).
6. **claude-haiku-4.5** ($0.008) — disqualified. 63% T1, 11 JSON failures.

**Next step**: Run 3-5 nondeterminism tests on gemini-3.1-flash-lite to see if it's as stable as gpt-4o. If yes, it's the winner at 7x less cost. If not, stick with gpt-4o.

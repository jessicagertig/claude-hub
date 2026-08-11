# JD Extraction Benchmark — Final Report

## Overview

Two-call pipeline for extracting structured scoring criteria from job descriptions.

- **Call 1**: Section decomposition (gpt-4o-mini) — split JD into criteria vs non-criteria sections
- **Call 2**: Criteria extraction (gpt-4o) — extract individual requirements with tier, binary flag, source text

## Testing Summary

- **180 JDs tested** across 35 batches (Call 1 + Call 2)
- **20 JD regression set** (5 standard + 15 problematic) run multiple times per prompt version
- **Call 1**: 5 prompt iterations, converged at v5
- **Call 2**: 6 prompt iterations on gpt-4o-mini, then model comparison
- **Nondeterminism testing**: 3 identical runs each for gpt-4o-mini and gpt-4o
- **Total API cost**: ~$0.50

## Call 1 — Section Decomposition

**Model**: gpt-4o-mini
**Prompt**: v5 (stable after 5 iterations)
**File**: `app/services/ai_job_application_action/scoring/prompts/job_description_structured_data.rb`

### What it does
- Splits JD HTML into sections based on headings
- Tags each section as `criteria` or `non_criteria`
- Provides `inferred_section_type` for ambiguous/headingless sections
- Preserves all content — nothing dropped

### Performance (180 JDs)
- Zero null/null violations
- Consistent criteria/non-criteria tagging
- Correctly handles non-English JDs (German, Chinese, Norwegian, Spanish, Portuguese)
- Correctly skips minimal/general postings (20/180)
- Correctly identifies creative headings ("Who are you?" = criteria)

### Known limitations
- "Job Detail" heading sometimes tagged non_criteria when it contains criteria prose (nondeterministic)
- Mixed sections (pay + schedule requirements) tagged by dominant content — minority criteria items may be missed
- Some company values sections misidentified as criteria when they use emphatic language

## Call 2 — Criteria Extraction

**Model**: gpt-4o (upgraded from gpt-4o-mini after nondeterminism testing)
**Prompt**: v6 (stable after 6 iterations on mini, confirmed on 4o)
**File**: `app/services/ai_job_application_action/scoring/prompts/job_description_criteria_extraction.rb`

### What it does
- Extracts individual atomic requirements from criteria sections
- Assigns tier: `tier_1` (required/strong expectation), `tier_2` (standard/nice-to-have), `tier_3` (bonus)
- Flags binary requirements (degree, license, vehicle, schedule — met or not met)
- Decomposes compound requirements into atomic criteria
- Preserves source text for traceability

### Output schema per criterion
```json
{
  "text": "...",
  "tier": "tier_1|tier_2|tier_3",
  "tier_reasoning": "...",
  "binary": true|false,
  "source_text": "..."
}
```

### Performance — Full 180-JD Run

**gpt-4o-mini (55 JDs batches 1-10 + original 6):**
- Tier distribution: 21.2% T1, 77.1% T2, 1.7% T3
- Avg criteria/JD: 18.9 | Avg binary/JD: 1.3
- Text preservation: 62.1%

**gpt-4o (all 180 JDs — definitive run):**
- 174 JDs processed, 152 with criteria, 22 skipped (minimal/general)
- 2,800 total criteria extracted
- Tier distribution: 20.4% T1, 77.4% T2, 2.2% T3
- Avg criteria/JD: 18.4 | Avg binary/JD: 1.0
- Binary: 5.2% of criteria
- Text preservation: 63.2%
- Avg T1% per JD: 20.2%
- Flagged: 79 (HIGH_T1: 2, NO_BINARY: 52, ALL_DECOMPOSED: 30, OVER_BINARY: 1)

Both models produce nearly identical aggregate distributions. gpt-4o uses tier_3 more (2.2% vs 1.7%), is less aggressive on tier_1 (20.2% vs 22.0% avg per JD), and is 2x more stable on nondeterminism tests.

### Nondeterminism comparison (20 JD regression set)

gpt-4o-mini: 3 identical runs. gpt-4o: 5 identical runs.

| Metric | gpt-4o-mini (3 runs) | gpt-4o (5 runs) |
|---|---|---|
| Mean binary σ | 1.99 | **0.86** |
| Mean T1% σ | 8.0 | **6.7** |
| Stable JDs (bin σ≤1, T1% σ≤5) | 25% | **40%** |
| Very stable JDs (bin σ≤0.5, T1% σ≤3) | — | **25%** |
| Volatile JDs (bin σ>2 or T1% σ>10) | — | **30%** |

gpt-4o's binary flag is 2.3x more stable than mini. Tier assignment is 1.2x more stable. 40% of JDs produce consistent results across 5 runs; 30% remain volatile (mostly JDs with structural edge cases like all-Required headings).
| Tier 3 usage (total across runs) | 7 | **13-21** |
| Text preservation rate | 62% | **74%** |

gpt-4o is better on every metric. Binary flagging is 2x more stable, tier assignment is more stable, it uses tier_3 appropriately (mini almost never does), and it follows the text preservation instruction more consistently.

### Cost comparison

| Model | Cost per JD (Call 2 only) |
|---|---|
| gpt-4o-mini | ~$0.001 |
| gpt-4o | ~$0.01 |

10x cost increase for gpt-4o. At scale: 1000 JDs/month = $10/month (4o) vs $1/month (mini). Both negligible.

### Known limitations (both models)

1. **Fire Alarm Test/Inspect JD**: Extreme nondeterminism on both models (T1% swings 0-97%). This JD has all content under "Required" headings — the model oscillates on whether to respect the heading or override it.

2. **Text preservation**: Nondeterministic. Same prompt produces 100% preservation on one run and 0% on another for the same JD. The instruction is clear — the model sometimes ignores it.

3. **"proven" signal word**: Rarely recognized as tier_1 on gpt-4o-mini. Better on gpt-4o but still inconsistent.

4. **Compound decomposition**: Nondeterministic. Sometimes splits "5+ years including frontend and backend" into 3 criteria, sometimes keeps as 1.

5. **Binary on trade JDs**: Trade skill requirements (welding, fire alarm troubleshooting) are sometimes flagged binary: true when they should be false (spectrum of proficiency).

## Prompt Files

| Call | File | Model |
|---|---|---|
| Call 1 | `app/services/ai_job_application_action/scoring/prompts/job_description_structured_data.rb` | gpt-4o-mini |
| Call 2 | `app/services/ai_job_application_action/scoring/prompts/job_description_criteria_extraction.rb` | gpt-4o |

## Benchmark Files

All in `~/claude-hub/inflow-ats/2026-06-08-ai-scoring/docs/benchmark/`:

- `test-jds/` — original 6 test JDs
- `test-jds-batch-1/` through `test-jds-batch-35/` — all 180 JDs in batches of 5
- `regression-set/` — 20 JDs (5 standard + 15 problematic) with manifest
- `prompt-v1-results/` through `prompt-v5-results/` — Call 1 iterations
- `criteria-v1-results/` through `criteria-v7-results/` — Call 2 iterations (mini)
- `batch-1-results/` through `batch-35-results/` — full 180-JD run (mini)
- `regression-v1-results/` through `regression-v9-results/` — regression runs (v1-3 prompt variants, v4-6 mini nondeterminism, v7-9 gpt-4o)
- `prompt-v1-evaluation.md` through `prompt-v4-evaluation.md` — Call 1 evaluations
- `criteria-v1-evaluation.md` through `criteria-v6-evaluation.md` — Call 2 evaluations
- `criteria-recommendations.md` — Call 2 iteration summary
- `full-180-analysis.md` — aggregate stats across all 180 JDs
- `nondeterminism-analysis.md` — gpt-4o-mini 3-run variance
- `model-comparison.md` — gpt-4o-mini vs gpt-4o
- `FINAL-REPORT.md` — this file

## Decisions

All extraction design decisions in `docs/jd-extraction-decisions.md` (20 decisions).

## Rake Tasks

| Task | Purpose |
|---|---|
| `rake ai:scoring:benchmark VERSION=N` | Run Call 1 on 6 test JDs |
| `rake ai:scoring:benchmark_criteria VERSION=N` | Run Call 2 on 6 test JDs (uses Call 1 v5 output) |
| `rake ai:scoring:batch BATCH=N` | Run Call 1 + Call 2 on a batch of 5 JDs |
| `rake ai:scoring:regression VERSION=N` | Run Call 1 + Call 2 on the 20-JD regression set |

## Next Steps

1. **Integrate into the app** — wire Call 1 + Call 2 into the job creation/update flow
2. **Store results** — persist the structured sections and criteria in the database
3. **Build the scoring pipeline** — Call 3: compare extracted criteria against a candidate's resume
4. **Handle the "no JD" case** — candidate summary without scoring when no criteria are available
5. **Consider 3x majority vote** for high-stakes scoring — run Call 2 three times and take the majority on binary and tier for critical decisions

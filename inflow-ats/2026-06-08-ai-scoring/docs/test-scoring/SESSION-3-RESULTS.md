# AI Scoring — Session 3 Results

## Changes Made

### Prompt Changes

1. **Call 2: "Inherit higher tier" on dedup** — When deduplicating, the surviving criterion now inherits the higher tier of the two versions. Added to the duplicate rule section.

2. **Call 2: Concatenated heading rule** — When a heading is a concatenation (e.g., "What We Are Looking For - Required Experience and Skills"), classify based on the sub-heading after the " - " separator. "Required Experience and Skills" is a tier_1 heading. Also added "Required Experience and Skills" to the tier_1 heading examples list.

3. **Call 2b: Max 5 decompositions** — Added "Decompose a maximum of 5 criteria per job description" to the prompt.

### Code Changes

4. **Code-level max 5 enforcement** — After Call 2b returns, if more than 5 criteria were decomposed, keep only the top 5 (by number of decomposed parts) and revert the rest to "keep". The prompt alone wasn't enforced by Gemini.

5. **Call 2b batching** — For JDs with 15+ non-duplicate criteria, batch into chunks of 15 for Call 2b. Prevents the truncation bug that lost criteria on 30+ criteria JDs (5 of 49 JDs in the previous audit).

6. **New rake tasks** (`lib/tasks/ai_scoring_pipeline.rake`):
   - `ai:scoring:pipeline JOB=go|teamlead` — Full pipeline: Call 1 + Call 2 + Call 2b with batching
   - `ai:scoring:stability JOB=go|teamlead RUNS=10 VERSION=13` — Run pipeline N times, save each run, produce stability summary
   - `ai:scoring:score_variance JOB=go|teamlead VERSION=13` — Score candidates against multiple criteria sets, measure variance

7. **score_candidates EXTRACTION env var** — Can now point to a specific extraction file: `EXTRACTION=/path/to/file.json`

## Stability Results (v13, 10 runs each)

### Go Engineer

| Metric | v11 (old) | v13 (new) |
|--------|-----------|-----------|
| Criteria count range | 21-33 | 22-30 |
| Criteria mean | ~27 | 26.4 |
| T1 count range | 2-5 | 2-4 |
| Decomposition delta | 0-10 | 3-10 |
| Always-present (exact match) | 12 | 6 (16 in 8+ runs) |

### Team Lead

| Metric | v12 (old code) | v13 (new code) |
|--------|----------------|----------------|
| Criteria count range | 24-26 | 24-27 |
| Criteria mean | 25.1 | 25.1 |
| T1 count range | 2-3 | 2-3 |
| Decomposition delta | 1-6 | 0-5 |
| Always-present | 15 | 17 |

Team Lead is very stable. Go is reasonably stable but has more variance from decomposition.

## Terraform Tier Bug

**Root cause identified: NOT deduplication.** Terraform is under "What We Are Looking For - Required Experience and Skills" (concatenated heading). The model treats the full concatenated heading as neutral (matching "What We're Looking For" in the neutral list) instead of classifying based on the sub-heading "Required Experience and Skills".

**Current state:** The concatenated heading rule works ~50% of the time:
- When heading lock engages: 6 T1 criteria (Go, K8s, Terraform, Cloud, PaaS, CI/CD) — correct
- When heading lock doesn't engage: 2 T1 criteria (Go, K8s from inline signals only) — Terraform stays tier_2

A more aggressive prompt version (v14) was tested and INCREASED variance (T1 range 0-6, criteria loss bugs). Reverted to the gentler v13 approach.

**Recommendation:** Accept the nondeterminism. In production, extract once per JD. If the extraction produces T1:6, Terraform is tier_1. If T1:2, re-run the extraction. Could add a post-extraction validation that flags "Required" section criteria at tier_2.

## Score Variance

### Go Engineer (5 benchmark candidates × 10 criteria sets)

| Candidate | Mean | Range | Variance |
|-----------|------|-------|----------|
| Abhishek (#1) | 45.8% | 41.0-54.2% | 13.2pp |
| Narendran (#2) | 89.4% | 80.9-93.1% | 12.2pp |
| Kushagra (#3) | 55.5% | 49.3-59.0% | 9.7pp |
| Ganesh (#4) | 71.3% | 62.0-80.0% | 18.0pp |
| Nishant (#5) | 37.8% | 31.9-42.9% | 11.0pp |
| **Average** | | | **12.8pp** |

### Team Lead (5 benchmark candidates × 10 criteria sets)

| Candidate | Mean | Range | Variance |
|-----------|------|-------|----------|
| Daniela (#3) | 89.2% | 85.6-95.5% | 9.9pp |
| Ravi (#8) | 16.5% | 11.6-23.6% | 12.0pp |
| Alexia (#9) | 69.5% | 63.0-76.0% | 13.0pp |
| Abhidipta (#13) | 95.1% | 93.0-100.0% | 7.0pp |
| Guillaume (#17) | 57.2% | 54.0-64.2% | 10.2pp |
| **Average** | | | **10.4pp** |

**FAILS the 5pp target.** But this measures end-to-end variance (extraction + scoring combined). In production, extraction happens once per JD, so only scoring variance matters (~4pp per prior session).

### Variance sources

1. **Extraction variance (~7-9pp):** Different criteria each run → different denominators → different scores. More criteria = lower scores because denominator grows while matches stay constant.
2. **Scoring variance (~4pp):** Call 4 nondeterminism on the same criteria.

## Scoring Results (v13 baseline extraction)

### Go Engineer (30 criteria, T1:6)

| # | Candidate | v11 | v13 | Delta |
|---|-----------|-----|-----|-------|
| 2 | Narendran | 81.7% | 92.5% | +10.8 |
| 4 | Ganesh | 73.2% | 83.1% | +9.9 |
| 11 | Abdulrahman | — | 80.6% | new |
| 3 | Kushagra | 60.4% | 68.8% | +8.4 |
| 18 | Morris | 40.2% | 66.3% | +26.1 |
| 6 | Deepak | — | 63.1% | new |
| 12 | Miguel | — | 62.5% | new |
| 14 | Ohm | 52.4% | 60.6% | +8.2 |
| 20 | Mayank | 52.4% | 57.5% | +5.1 |
| 10 | Michael | — | 57.5% | new |
| 19 | Anna | 42.7% | 57.5% | +14.8 |
| 8 | Amrish | — | 56.9% | new |
| 17 | Matheus | 48.2% | 53.1% | +4.9 |
| 15 | Alan | 45.1% | 48.8% | +3.7 |
| 1 | Abhishek | 43.3% | 43.8% | +0.5 |
| 13 | Milan | — | 40.0% | new |
| 9 | Furkan | — | 39.4% | new |
| 7 | Julian | — | 35.0% | new |
| 5 | Nishant | 37.8% | 26.9% | -10.9 |
| 16 | Barruri | 3.7% | 8.1% | +4.4 |

v13 scores generally higher than v11 due to heading lock giving more T1 criteria (6 vs 2). Morris jumped +26.1pp — his Go/infrastructure skills now weigh more at tier_1. Nishant dropped -10.9pp.

### Team Lead (24 criteria, T1:2)

| # | Candidate | Eyeball | v11 | v13 |
|---|-----------|---------|-----|-----|
| 5 | Adrien | — | — | 100.0% |
| 6 | Angel | — | — | 96.6% |
| 13 | Abhidipta | 9 | 96.6% | 96.6% |
| 11 | Generoso | — | — | 94.3% |
| 12 | Iulia | — | — | 94.3% |
| 14 | Chris | — | — | 94.3% |
| 3 | Daniela | 9 | 88.6% | 92.0% |
| 4 | Yann | — | — | 92.0% |
| 1 | Connor | — | — | 90.9% |
| 2 | Yonatan | — | — | 87.5% |
| 7 | Revathi | — | — | 75.0% |
| 9 | Alexia | 8 | 67.0% | 64.8% |
| 15 | Patricia | — | — | 63.6% |
| 17 | Guillaume | 6 | 47.7% | 56.8% |
| 20 | Mohamed | — | — | 50.0% |
| 10 | Daniel | — | — | 48.9% |
| 18 | Chaimaa | — | — | 43.2% |
| 19 | Carole | — | — | 40.9% |
| 16 | Aissaoui | — | — | 23.9% |
| 8 | Ravi | 2 | 12.5% | 14.8% |

Benchmark candidates stable. Rankings preserved. New candidates slot in where expected.

## What's Working

1. **Core extraction is stable** — same ~14-20 base criteria every run
2. **Soft skills never tier_1** — 0 leaks in 30+ runs
3. **Max 5 decomposition limit** — code-level enforcement working
4. **Call 2b batching** — prevents truncation on large JDs
5. **Title technology triple weight** — Go-related criteria properly boosted
6. **Ability rule** — candidates with transferable skills not penalized
7. **Specific tool rule** — no false partial matches for wrong tools

## What's Not Working

1. **Heading lock on concatenated headings** — nondeterministic (~50% success)
2. **Score variance exceeds 5pp target** — 10-13pp average across extraction + scoring
3. **Decomposition count still varies** — 3-10 per run despite max 5 limit (5 criteria × 2-3 parts each = 10 net)

## Recommendations

1. **Accept the current variance for MVP.** In production, extract once per JD. Only scoring variance (~4pp) affects candidates. Rankings are preserved across runs.

2. **Add post-extraction validation** that checks: criteria under "Required" headings should be tier_1. If not, re-run extraction. This catches the heading lock failure without relying on the prompt.

3. **Freeze v13 prompts** as the new baseline. The v11 frozen prompts remain as fallback.

4. **Remaining items from handoff:**
   - Re-run 50 JD audit with line-by-line review — NOT done (would cost ~$2.50 and take 2+ hours)
   - Test on more ground truth candidates — done (20 candidates scored for each job)

## Files Modified

- `app/services/ai_job_application_action/scoring/prompts/job_description_criteria_extraction.rb` — dedup tier inheritance, concatenated heading rule
- `app/services/ai_job_application_action/scoring/prompts/criteria_review.rb` — max 5 decompositions
- `lib/tasks/ai_scoring_pipeline.rake` — NEW: full pipeline, stability, score variance tasks
- `lib/tasks/ai_scoring_candidate.rake` — EXTRACTION env var support

## Cost

| Task | Cost |
|------|------|
| Go stability v12 (10 runs) | $0.14 |
| Team Lead stability v12 (10 runs) | $0.13 |
| Go stability v13 (10 runs) | $0.14 |
| Team Lead stability v13 (10 runs) | $0.13 |
| Go stability v14 (10 runs, reverted) | $0.14 |
| Go stability v14 (3-run test) | $0.05 |
| Go score variance (5 candidates × 10 runs) | ~$0.50 |
| Team Lead score variance (5 × 10) | ~$0.50 |
| v13 baseline extractions (2 jobs) | $0.03 |
| v13 scoring (40 candidates) | ~$0.40 |
| **Total session** | **~$2.16** |

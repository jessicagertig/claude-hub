# AI Scoring — Session Handoff

## What this is

A multi-call pipeline that extracts structured scoring criteria from job descriptions and scores candidates against them. Built iteratively through conversation + benchmarking. NOT inside the feature development harness — this is exploratory R&D on prompt design.

## Current state

All prompts live in `app/services/ai_job_application_action/scoring/prompts/`.

### Call 1 — Section Decomposition (DONE)
- **File**: `job_description_structured_data.rb`
- **Model**: gpt-4o-mini
- **Status**: Stable. 5 prompt iterations, tested on all 180 sample JDs.

### Call 2 — Criteria Extraction (DONE)
- **File**: `job_description_criteria_extraction.rb`
- **Model**: gemini-3.1-flash-lite
- **Status**: Stable. 27 prompt iterations. Key decisions: tier_1/tier_3 headings locked, duplicates flagged not removed, compounds decomposed.

### Call 3 — Criteria Expansion (PARKED)
- **File**: `criteria_expansion.rb`
- **Status**: PARKED. Expansions were too prescriptive — constrained the scorer instead of helping it. The minimal scoring prompt without expansions produces better results.

### Call 4 — Candidate Scoring (STABLE — v7)
- **File**: `candidate_criteria_scoring.rb`
- **Model**: gemini-3.1-flash-lite
- **Enum**: full_match / partial_match / not_found
- **Status**: Prompt v7 — minimal + 3 rules. Tested on 2 job types, 86 Team Lead + 500 Go Engineer resumes.
- **Scoring math** (computed by us, not the AI): tier_1 = 6 points, tier_2 = 4, tier_3 = 2. full_match = full points, partial_match = half, not_found = 0.

### Prompt v7 rules (in order)
1. Inference guard: "If a criterion matches only because of what the role would typically involve — not because the resume describes doing it — score partial_match."
2. Multilingual ≠ communication skills
3. Years of experience domain guidance (tiered: domain = FM, adjacent with significant duties = PM)

Full prompt snapshot: `docs/test-scoring/prompt-v7-snapshot.md`

## Scoring results

### Team Lead, Customer Support (Stack 24, Job 2136)
- 82 resumes scored with v7 prompt
- Distribution: mean 71.9%, median 77.7%, range 13.8-100%
- Results: `inbox-{N}-scores-v7.json`
- 20 benchmarked against eyeball scores: good correlation, 95%+ criterion accuracy
- Key inversions: inbox-15 (exec assistant, eyeball 3) scores 66% due to soft skill criteria matching

### Backend Engineer Go (Convox, Job 2362)
- 502 resumes scored with v7 prompt (v2 for Go files)
- Distribution: mean 49.2%, median 48.6%, range 0-100%
- Results: `go-{N}-scores-v2.json`
- 20 benchmarked against ground truth: moderate correlation, limited by niche PaaS criteria
- Key lesson: very specific criteria (multi-cloud, cloud marketplace) limit score ceiling for most candidates

### Data Analyst - Growth (Job 2130) — third domain test
- 281 resumes scored with v7 prompt (v1 for DA files), ZERO domain-specific modifications
- Distribution: mean 67.8%, median 70.5%, range 1.6-93.4%
- 28 criteria extracted (SQL, Python, analytics, business performance)
- Results: `da-{N}-scores-v1.json`
- Confirms domain-agnostic behavior
- Rankings: `da-v1-rankings.txt`

### Grand totals
- **865 unique resumes scored** across 3 job types
- **234 nondeterminism runs** (75 TL + 144 Go + 15 DA)
- **40+ analysis/evaluation reports**

### Rank Correlation (Team Lead only, 20 benchmark resumes)
- Spearman ρ = 0.826 (very strong), stable across 3 nondeterminism runs (ρ = 0.780-0.826)
- Go Engineer ρ = 0.265 (weak) — criteria too niche for general ranking

## Key files

| File | Purpose |
|------|---------|
| `docs/test-scoring/CONTEXT-FOR-ITERATION.md` | Design decisions and iteration context |
| `docs/test-scoring/ITERATION-PLAN.md` | Process for scoring iteration |
| `docs/test-scoring/prompt-v7-snapshot.md` | Current prompt text |
| `docs/test-scoring/phase1-v5-summary.md` | Phase 1 results (Team Lead, 20 resumes) |
| `docs/test-scoring/phase2-go-summary.md` | Phase 2 results (Go, 20 resumes) |
| `docs/test-scoring/v5-vs-v7-comparison.md` | Prompt regression comparison |
| `docs/test-scoring/nondeterminism-v7.md` | Nondeterminism test results |
| `docs/test-scoring/overnight-status-report.md` | Full overnight session report |
| `docs/test-scoring/batch{1-4}-v5-evaluation.md` | Detailed criterion-level evaluations |
| `docs/test-scoring/go-batch1-v1-evaluation.md` | Go evaluation details |
| `docs/test-scoring/go-suspicious-v1-evaluation.md` | Go suspicious candidate analysis |

## Prompt evolution summary

| Version | Change | Impact |
|---------|--------|--------|
| v1-v3 | Strict → minimal | Massive improvement |
| v4 | Renamed enum (matched → full_match) | Improved differentiation |
| v5 | Added 2 rules (multilingual, domain years) | Targeted fixes, no regression |
| v6 | Added broad inference guard | Fixed overscoring but regressed inbox-13 |
| v7 | Refined inference guard to "role typically involves" | Fixed overscoring, no regression |

## Benchmark infrastructure

- `rake ai:scoring:score_candidates JOB=teamlead|go VERSION=N BATCH_START=X BATCH_END=Y`
- Existing 86 Team Lead resumes: `inbox-{1-86}.txt` (4 gaps)
- Existing 503 Go resumes: `go-{1-503}.txt` (some gaps)

## Model selection

- **gemini-3.1-flash-lite**: Used for Calls 2, 3, 4. Best value — more stable than gpt-4o, 7x cheaper.
- **gpt-4o-mini**: Used for Call 1 only.
- Full comparison: `docs/benchmark/multi-model-comparison.md`

## Key decisions

All in `docs/jd-extraction-decisions.md` (21 decisions). The important ones:
- Three tiers: tier_1, tier_2, tier_3
- Tier_1 and tier_3 headings are LOCKED — inline modifiers never override them
- Duplicates flagged with `duplicate: true`, not removed
- Physical requirements excluded from scoring
- Fewer rules in prompts = better results
- v7 inference guard targets role-based inference specifically

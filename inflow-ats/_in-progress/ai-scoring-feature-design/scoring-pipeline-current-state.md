# Scoring Pipeline — Current State of Prompts and Workflow

**Last updated:** 2026-06-11

## Pipeline Overview

The scoring pipeline extracts criteria from job descriptions and scores candidates against them. It has evolved over 3 sessions from a 4-call Gemini-only pipeline to a multi-model pipeline with code-level enforcement.

## Current Pipeline (as tested)

### Call 1: Section Decomposition
- **Model:** gpt-4.1-mini, temperature 0
- **File:** `app/services/ai_job_application_action/scoring/prompts/job_description_structured_data.rb`
- **Input:** JD HTML
- **Output:** Sections with headings, types (criteria/non_criteria), content, title_technology
- **Key rules:**
  - Sub-headings: use sub-heading only, discard parent heading (e.g., "What We Are Looking For" discarded, "Required Experience and Skills" kept)
  - Heading examples list for fuzzy matching
  - title_technology extracted from job title (specific tech only, not "backend"/"frontend")
- **Stability:** 10/10 on sub-heading detection

### Call 2: Criteria Extraction
- **Model:** gpt-4o (changed from gemini-3.1-flash-lite during session 3)
- **File:** `app/services/ai_job_application_action/scoring/prompts/job_description_criteria_extraction.rb`
- **Input:** Criteria sections from Call 1 + title_technology
- **Output:** Criteria with text, tier, tier_reasoning, binary, contains_title_technology, duplicate, source_heading, source_text
- **Key rules:**
  - Three-tier system: tier_1 (6pts), tier_2 (4pts), tier_3 (2pts)
  - Heading lock: tier_1 and tier_3 headings override inline signals
  - Heading classification: "Any heading that contains the word required, must, essential, or minimum" = tier_1
  - Soft skills exception: never tier_1 (communication, teamwork, problem-solving, etc. — leadership is NOT a soft skill)
  - Self-review: adversarially review tier assignments after extraction
  - Dedup: mark less specific as duplicate, surviving criterion inherits higher tier
  - source_heading field added so code-level heading override can work
  - Compound decomposition rules (added session 3):
    - Decompose when criterion contains multiple activities not under umbrella of one tool
    - Decompose when a domain is followed by distinct projects, implementations, or deliverables that a candidate may have experience with independently
    - Decompose when criterion lists responsibilities not bound together by a shared category
  - Do NOT decompose "or" constructions
  - 11 decomposition examples + 4 do-not-decompose examples
- **Stability with gpt-4o:** 18 raw, 15-16 after dedup (found legitimate duplicates Gemini missed)
- **Stability with Gemini:** 18-20 raw, 18-20 after dedup (no duplication detected)
- **Stability with Sonnet:** 20 raw, 20 after dedup
- **Decision:** gpt-4o produces best criteria — legitimate dedup, correct tier assignment. Criteria nearly identical to Sonnet but with better dedup.

### Code: Heading Tier Override
- **Not a model call** — runs after Call 2 returns
- **Logic:** If source_heading contains "required"/"must"/"essential"/"minimum" → set tier to tier_1 (skip soft skills). If contains "bonus"/"optional"/"extra credit" → set tier to tier_3.
- **Why:** Models inconsistently apply heading lock on their own. Code enforcement is deterministic.
- **Soft skills check:** Matches against list of soft skill keywords in criterion text before overriding

### Calls 3A/3B: Judge + Decomposer (DROPPED)
- **Decision:** Drop judge and decomposer calls entirely
- **Why:** gpt-4o for Call 2 with the decomposition rules produces adequate decomposition on its own. The judge/decomposer added complexity, variance, and cost without improving results enough. The decomposition rules in Call 2 handle it.
- **History:** Previously had Gemini judge (CriteriaReview) + gpt-4.1-mini decomposer (CriteriaDecomposer). Before that, combined judge+decomposer in one Call 2b. All abandoned.

### Call 4: Candidate Scoring
- **Model:** Gemini 3.1 flash lite (default temperature — NOT temp 0, Gemini says temp 0 degrades performance)
- **File:** `app/services/ai_job_application_action/scoring/prompts/candidate_criteria_scoring.rb`
- **Input:** Criteria list + resume text
- **Output:** Per criterion: criterion_text, tier, score (full_match/partial_match/not_found), reasoning
- **Key rules:**
  - Ability rule: candidate doesn't need exact same context, just underlying tech/tooling/methodology
  - Multilingual rule: being multilingual is not evidence of communication skills
  - Specific tool rule: if criterion names a specific tool without "or similar", only full_match or not_found
  - Years of experience: full_match = same domain, partial_match = adjacent domain with related duties
  - Inference guard REMOVED (was hurting legitimate candidates)
- **Scoring math:**
  - tier_1 = 6pts, tier_2 = 4pts, tier_3 = 2pts
  - full_match = 1.0, partial_match = 0.7 (changed from 0.5), not_found = 0
  - title_technology criteria get 3x weight
  - Score = sum(weight × value × multiplier) / max_possible × 100
- **Variance:** Gemini has ~2pp variance for strong/weak candidates, ~15pp for mid-range candidates. 5-run median proposed to stabilize.

### Call 5: Display Sentence Generation
- **Model:** Gemini 3.1 flash lite
- **File:** `app/services/ai_job_application_action/scoring/prompts/scoring_display.rb`
- **Input:** Scoring results (criterion_text, score, reasoning per criterion — source_text stripped)
- **Output:** Per criterion: criterion_text, score, summary (natural language sentence)
- **Key rules:**
  - Summary is a natural sentence referencing the criterion and how the candidate measures up
  - Write like a recruiter talking to a colleague
  - Vary sentence structure, do not use em dashes
  - Must include both: reference to what criterion asks for AND specific evidence from candidate's background
- **Tested with:** gpt-4o-mini, gpt-4.1-mini, Gemini flash. Gemini produced the most varied, natural sentences.

## Prompt Files (all in `app/services/ai_job_application_action/scoring/prompts/`)

| File | Status | Model |
|------|--------|-------|
| job_description_structured_data.rb | ACTIVE | gpt-4.1-mini |
| job_description_criteria_extraction.rb | ACTIVE | gpt-4o (model constant still says gemini — needs updating) |
| criteria_review.rb | NOT IN USE | gemini-3.1-flash-lite |
| criteria_decomposer.rb | NOT IN USE | gpt-4o-mini |
| criteria_decomposition_judge.rb | NOT IN USE | gemini-3.1-flash-lite |
| candidate_criteria_scoring.rb | ACTIVE | gpt-4o-mini (model constant — but Gemini used via override in testing) |
| scoring_display.rb | ACTIVE (new, on spike branch) | Gemini flash |

**NOTE:** The MODEL constants in several prompt files do not match what was tested/decided. They need updating when we implement.

## Provider Configuration

| Provider | Temperature |
|----------|------------|
| OpenAI (openai.rb) | 0 (hardcoded) |
| Gemini (gemini.rb) | default (no temp setting — Jessica removed temp 0 because Gemini says it degrades performance) |
| Anthropic (anthropic.rb) | not set |

## Scoring Results Summary

### With gpt-4o criteria + Gemini scorer (best combo):

**Go Engineer:**

| Candidate | Gemini (pm=0.5) | Gemini (pm=0.7) | v7 | Expected |
|-----------|----------------|----------------|-----|----------|
| Narendran | 87.0% | 90.4% | 81.9% | High |
| Ganesh | 68.5% | 79.3% | 75.0% | High |
| Nishant | 39.1% | 45.2% | 27.8% | Low |
| Barruri | 5.4% | 7.6% | 2.8% | Low |

**Team Lead:**

| Candidate | Gemini (pm=0.5) | Gemini (pm=0.7) | Eyeball |
|-----------|----------------|----------------|---------|
| Abhidipta | 93.0% | 94.2% | 9/10 |
| Daniela | 91.0% | 94.6% | 9/10 |
| Alexia | 62.0% | 70.8% | 8/10 |
| Guillaume | 50.0% | 53.2% | 6/10 |
| Ravi | 16.0% | 22.4% | 2/10 |

### Gemini Scorer Variance (15 runs, gpt-4o criteria):

| Candidate | Median | Range | Variance |
|-----------|--------|-------|----------|
| Narendran | 84.8% | 84.8-87.0% | 2.2pp |
| Ganesh | 71.7% | 66.3-81.5% | 15.2pp |
| Nishant | 42.4% | 31.5-48.9% | 17.4pp |
| Barruri | 5.4% | 3.3-5.4% | 2.1pp |

Strong and weak candidates are very stable (2pp). Mid-range candidates swing ~15pp. 5-run median would stabilize.

## Model Comparison Summary

| Model | Call 2 (criteria) | Scoring | Display |
|-------|------------------|---------|---------|
| gpt-4o | Best — legitimate dedup, stable | Not tested as scorer | — |
| gpt-4o-mini | — | Lower variance (9.4pp avg) but scores too low | Decent but repetitive |
| gpt-4.1-mini | Respects decomp limits | Lower variance but scores too low | Decent but repetitive |
| Gemini flash | Stable extraction but no dedup | Scores closest to human judgment, higher variance (13.3pp avg) | Most natural, varied sentences |
| Sonnet | Same as Gemini extraction | Good scores but inflates weak candidates, high variance (29pp on Ganesh) | Good quality |

## Key Decisions Made

1. **gpt-4o for Call 2** — best criteria extraction, finds legitimate duplicates
2. **Drop Call 3A/3B** — no separate judge or decomposer
3. **Gemini for scoring** — closest to human judgment
4. **Gemini for display sentences** — most natural variation
5. **Partial match = 0.7** — raises strong candidates closer to expected range
6. **Heading tier override in code** — deterministic, replaces unreliable model heading lock
7. **5-run median proposed** — stabilizes mid-range candidates, $0.002/candidate
8. **Scoring feeds into summary comparison** — role_analysis won't contradict scoring evidence
9. **source_text stripped before display prompt** — prevents the model from re-decomposing already-decomposed criteria

## Frozen Prompt Versions

| Version | Location | Notes |
|---------|----------|-------|
| v11 | `docs/test-scoring/frozen-prompts-v11/` | Last working from session 2, Gemini everything |
| v13 | `docs/test-scoring/frozen-prompts-v13/` | Heading override, T1-only decomp, max 5 |
| v18 | `docs/test-scoring/frozen-prompts-v18/` | Full benchmark run, pipeline rake tasks |

## Rake Tasks Built

| Task | File | Purpose |
|------|------|---------|
| ai:scoring:pipeline | ai_scoring_pipeline.rake | Full pipeline: Call 1 + 2 + heading override + judge + decomposer |
| ai:scoring:stability | ai_scoring_pipeline.rake | Run pipeline N times, compare stability |
| ai:scoring:score_variance | ai_scoring_pipeline.rake | Score candidates against multiple criteria sets |
| ai:scoring:score_candidates | ai_scoring_candidate.rake | Score candidates against one extraction file |
| ai:scoring:benchmark | ai_scoring.rake | Call 1 benchmark |
| ai:scoring:benchmark_criteria | ai_scoring.rake | Call 2 benchmark |

## Spike Branch

`spike/scoring-display-prompt` — contains the scoring_display.rb prompt file. Other prompt changes are on `main` in the source repo (not committed).

## Test Data Locations

All in `/Users/jessica/claude-hub/inflow-ats/2026-06-08-ai-scoring/docs/test-scoring/`:

- `benchmark-v18/` — 10 pipeline runs per job + scoring results
- `scoring-model-benchmark/` — 15-run variance data for multiple models
- `call2-model-test/` — gpt-4o vs Sonnet vs Gemini criteria comparison + scoring
- `display-prompt-test/` — display prompt outputs from 3 models
- `eyeball-scores-go-combined.md` — AI eyeball scores for Go candidates 1-20
- `go-engineer-ground-truth.md` — Jessica's expected ranges
- `go-ground-truth-v7-results.md` — v7 scoring results
- `SCORING-COST-ESTIMATE.md` — cost breakdown with actual volumes
- Frozen prompts at `frozen-prompts-v11/`, `frozen-prompts-v13/`, `frozen-prompts-v18/`
- Resume files: `go-1.txt` through `go-99.txt`, `inbox-1.txt` through `inbox-20.txt`
- JD files: `go-engineer-jd.html`, `team-lead-jd.html`

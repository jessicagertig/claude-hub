# Frozen Prompts — v13

Frozen 2026-06-10. Changes from v11:
- Call 2: "inherit higher tier" dedup rule, concatenated heading classification, "Required Experience and Skills" in tier_1 list
- Call 2b: "max 5 decompositions" prompt instruction
- Code: max 5 enforcement, Call 2b batching (chunks of 15), pipeline/stability/score_variance rake tasks
- score_candidates: EXTRACTION env var

## Files

| File | Role | Model |
|------|------|-------|
| job_description_structured_data.rb | Call 1 — Section decomposition | gpt-4.1-mini |
| job_description_criteria_extraction.rb | Call 2 — Criteria extraction | gemini-3.1-flash-lite |
| criteria_review.rb | Call 2b — Decomposition review | gemini-3.1-flash-lite |
| candidate_criteria_scoring.rb | Call 4 — Candidate scoring | gemini-3.1-flash-lite |
| ai_scoring_pipeline.rake | Pipeline, stability, score variance tasks | — |
| ai_scoring_candidate.rake | Scoring task (with EXTRACTION env var) | — |
| ai_client.rb | AI client with pricing | — |
| openai.rb | OpenAI provider (120s timeout) | — |

## Results at this version

### Go Engineer (30 criteria, T1:6)
Narendran 92.5%, Ganesh 83.1%, Abdulrahman 80.6%, Kushagra 68.8%, Morris 66.3%

### Team Lead (24 criteria, T1:2)
Adrien 100.0%, Angel 96.6%, Abhidipta 96.6%, Daniela 92.0%, Alexia 64.8%, Guillaume 56.8%, Ravi 14.8%

### Stability
- Go: 22-30 criteria (mean 26.4), T1 2-4, 16 criteria in 8+ of 10 runs
- Team Lead: 24-27 criteria (mean 25.1), T1 2-3, 17 always-present

### Score Variance
- Go: 12.8pp average (extraction + scoring combined)
- Team Lead: 10.4pp average
- In production (extract once): ~4pp scoring-only variance

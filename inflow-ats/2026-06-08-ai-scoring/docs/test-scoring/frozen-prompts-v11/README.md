# Frozen Prompts — v11 (Last Working Version)

Frozen 2026-06-10. These are the last working versions of all prompt files before further iteration. DO NOT MODIFY these files. If the live prompts regress, restore from here.

## Files

| File | Role | Model |
|------|------|-------|
| job_description_structured_data.rb | Call 1 — Section decomposition | gpt-4.1-mini |
| job_description_criteria_extraction.rb | Call 2 — Criteria extraction | gemini-3.1-flash-lite |
| criteria_review.rb | Call 2b — Decomposition review | gemini-3.1-flash-lite |
| candidate_criteria_scoring.rb | Call 4 — Candidate scoring | gemini-3.1-flash-lite |
| criteria_decomposer.rb | NOT IN USE — two-step decomposer | gpt-4.1-mini |
| criteria_decomposition_judge.rb | NOT IN USE — two-step judge | gemini-3.1-flash-lite |
| ai_scoring_candidate.rake | Scoring rake task | — |
| ai_client.rb | AI client with pricing | — |
| openai.rb | OpenAI provider (120s timeout) | — |

## Results at this version

Team Lead: Abhidipta 96.6%, Daniela 88.6%, Alexia 67.0%, Guillaume 47.7%, Ravi 12.5%
Go Engineer: Narendran 81.7%, Ganesh 73.2%, Kushagra 60.4%, Morris 40.2%

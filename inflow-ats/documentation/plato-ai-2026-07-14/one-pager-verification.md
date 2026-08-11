# One-Pager Verification — D2-scoring-pipeline-one-pager.md vs code

**Date:** 2026-07-14
**Code verified:** `/Users/jessica/wrk/wrk-corp/inflow-ats`, checkout on `production` at `f26d89c` (the #3066 promote, 2026-07-13 — current shipped code)
**Method:** 4 parallel read-only agents, one per claim group; every claim traced to file:line with quoted code.

**Result: all claims CONFIRMED. No corrections required to the one-pager.**

## Verdict table

| One-pager claim | Verdict | Evidence anchor |
|---|---|---|
| Scorecard = 2 AI calls (decompose + extract) | CONFIRMED | `extract_criteria.rb:42-46, 74-78` |
| Non-requirement sections discarded | CONFIRMED | `extract_criteria.rb:60` (`select type == 'criteria'`) |
| Atomic criteria, compound split, Core/Preferred/Bonus, preferred default | CONFIRMED | `job_description_criteria_extraction.rb:36-99, 156` (stored as `tier_1/tier_2/tier_3`) |
| Heading tier overrides by fixed code + soft-skill exception | CONFIRMED | `extract_criteria.rb:105-116`, `soft_skill?` at `:165-168` |
| AI-flagged duplicates dropped by code | CONFIRMED | `extract_criteria.rb:119-121`; prompt `:18-33` |
| Scorecard input = job description only, no candidate data | CONFIRMED | `extract_criteria.rb:30, 38-40` |
| One scorecard per job, reused; meaningful edits rebuild; no re-grade | CONFIRMED | `job.rb:757-774`, `ai_job_criteria.rb:27-36` |
| Profile = 2–4 AI calls (structure/assess/compare/summarize) | CONFIRMED | `summary/generate.rb:45-155` |
| Resume structuring = only identity-seeing AI step | CONFIRMED | grep: `textract_job_result_text` reaches only `generate.rb:47` |
| De-identify by code: name/email/phone/location/links | CONFIRMED | `anonymize_for_ai.rb:18, 24-27` (`PII_FIELDS`) |
| Assessment/comparison conditional | CONFIRMED | `generate.rb:78, 109` |
| Summary pass never sees job title | CONFIRMED | `resume_summary.rb:8, 46` |
| Tenure by code: overlap de-dup, unreadable dates skipped | CONFIRMED | `generate.rb:187-252, 276-278` |
| Verdicts full/partial/not_found + evidence justification | CONFIRMED | `job_application_scoring.rb:31, 56-62` |
| Median-of-five within 5 pts of 90/60/35/15, else once | CONFIRMED | `score_job_application.rb:61-91` |
| Score = fixed code, formula earned÷possible | CONFIRMED | `calculate.rb:22-28` |
| Weights 6/4/2; match values 1.0/0.7/0.0; title-tech ×3 | CONFIRMED | `calculate.rb:6-8, 19-21` |
| Bands ≥90/60/35/15, backend = frontend | CONFIRMED | `integrated_analysis.rb:62-68` = `FitIndicator.tsx:12-22` |
| Deterministic settings on profile/scorecard steps | CONFIRMED | `ai_providers/openai.rb:8-12` (`temperature: 0`); `strict: true` schemas in all 8 prompts |
| Guardrails: pronouns / evidence / no-partial-credit / multilingual | CONFIRMED | `job_application_scoring.rb:19, 21, 31, 33` (verbatim quotes below) |
| Two providers (OpenAI + Gemini) | CONFIRMED | `generate.rb:43`, `score_job_application.rb:54` |
| 5–11 AI calls per finished review | CONFIRMED | reconstructed min 2+2+1=5, max 4+6+1=11 |
| Exactly 1 credit on success, 0 on failure | CONFIRMED | `textract_result.rb:84-87` (success-gated), `create_ai_credit_balance_transaction.rb:6` (`CREDIT_COST = 1`) |
| Scorecard calls per-job, no candidate credit | CONFIRMED | `AiApiRequest` telemetry only; no debit in `scoring/` |
| No auto-reject/auto-advance | CONFIRMED | success side effects = status record + websocket broadcast + textract cleanup only; no stage mutation |

## Guardrail quotes (from `scoring/prompts/job_application_scoring.rb` SYSTEM_PROMPT)

- Line 33: `Never use pronouns. Do not use any of these words: "I", "we", "they", "them", "their", "he", "she", "him", "her", "his".`
- Line 31: `You MUST cite specific examples from the candidate's experience: company names, job titles, metrics, accomplishments, or tools used. … For not_found, state what you searched for and that it was absent.`
- Line 21: `When a criterion names a specific tool or technology without allowing alternatives (e.g., no "or similar", "such as", "like"), only score full_match or not_found.`
- Line 19: `Being multilingual is not evidence of strong communication skills.`

## Nuances (accurate as written, but worth knowing in a customer conversation)

1. **"Median of five" is a middle-index pick.** `score_job_application.rb:78` silently drops a failed extra run (`if run`), and `:86-88` takes `sorted_runs[length/2]` — with fewer than 5 successful runs this is the upper-middle element, not a strict statistical median. Normal path (5 successes) = true median.
2. **Pronoun guardrail is broader than stated.** The prompt bans ALL pronouns, not just gendered ones. One-pager understates; not wrong.
3. **Title technology comes from the description text, not the `Job#title` column.** `Job#title` is never sent to the model; the decompose call reads the title from a leading heading inside the description HTML (`job_description_structured_data.rb:20`). A description that never states the role's title yields no title technology (and thus no ×3 anywhere).
4. **De-identification is field-level.** Confirmed exactly as the one-pager's italic caveat states: the 5 structured fields are deleted; verbatim prose (professional summary, work-history descriptions) is not scrubbed and reaches assessment and scoring calls.
5. **Unparseable dates drop the whole work experience from tenure totals** (both endpoints must parse: `generate.rb:226`) — still "skipped rather than invented."
6. **Calculation defaults:** unknown tier defaults to the preferred weight (4), unknown match value to 0.0 (`calculate.rb:17-18`).
7. **Gemini calls set no temperature** — the scoring model's run-to-run variability is real, which is exactly what median-of-five compensates for. OpenAI calls are the temperature-0 ones.

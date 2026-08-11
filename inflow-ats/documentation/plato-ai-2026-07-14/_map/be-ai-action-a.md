# Slice: AI job-application action services (scoring/generation) — first half

All 9 files are **new** (added on develop, absent on production). This slice is the backend engine that turns a resume + job description into a scored, integrated AI summary. Every file is AI-only; none modify pre-existing non-AI code. The one shared-surface concern is `AiApiRequest` row creation and the `Job#extract_job_criteria` / `AiJobCriteria` handoff (see below).

## Files & what each does

### `orchestrate.rb` — `AiJobApplicationAction::Orchestrate`
State-machine driver invoked with a `textract_result_id`. Loads the `TextractResult`, its `job_application`, and the **most-recent** `AiJobApplicationSummary` (`order(created_at: :desc).first`). Dispatches on `ai_job_application_summary.status`:
- `pending / textract_processing / extracting / retrying` → `run_summary` then `check_criteria_and_score`
- `summarizing` → if headline+summary_text present, `check_criteria_and_score`; else regenerate summary then score
- `awaiting_job_criteria` → `check_criteria_and_score`
- `scoring` → if `criteria_results` present, `run_integration`; else `run_scoring` + `run_integration`
- `integrating` → `run_integration`
- `succeeded / failed` → no-op (idempotent stop)

`run_summary` calls `Summary::Generate` (second-half slice) then **reloads** (documented deviation from cursor_rules `_base.md` Rule 8 — comment explains Generate mutates via its own reference so the orchestrator's copy is stale). `check_criteria_and_score` guards on `status_failed?` and `summary_complete?` (headline + summary_text present), sets status `awaiting_job_criteria`, then looks at `job.latest_ai_job_criteria`: if that criteria `status_succeeded?` it runs scoring+integration inline; otherwise it calls `job.extract_job_criteria` **unless** criteria is already `pending`/`in_progress`, and returns (waits). `run_scoring` calls `Scoring::ScoreJobApplication` (second-half slice); `run_integration` calls `IntegrateAnalysis`. Every step reloads and bails on `status_failed?`.

USER-VISIBLE: this is what advances the candidate AI summary card from "generating/scoring" through to a finished score + narrative. Edge cases to exercise in QA: (a) a job with NO succeeded criteria yet — first candidate should trigger criteria extraction and the summary should sit in `awaiting_job_criteria` until criteria finish, then resume; (b) re-running on an already-`succeeded`/`failed` summary must be a no-op (no duplicate charges/rows); (c) multiple summaries on one application — only the newest is orchestrated.

### `scoring/calculate.rb` — `Scoring::Calculate.compute(criteria_results)`
Pure scoring math (no AI). Weights: `tier_1=6, tier_2=4, tier_3=2` (unknown tier defaults to tier_2 weight). Score values: `full_match=1.0, partial_match=0.7, not_found=0.0`. A criterion with `contains_title_technology: true` gets its weight multiplied by **3** (`TITLE_TECHNOLOGY_MULTIPLIER`). Final = weighted_score / max_possible × 100, rounded to 2 decimals. Returns nil when input blank or max_possible zero. This produces `score_percentage` shown on the UI and feeds the fit label.

### `scoring/extract_criteria.rb` — `Scoring::ExtractCriteria` (per-JOB, keyed by `ai_job_criteria_id`)
Turns a job description into scoring criteria. Guards: needs `AiJobCriteria`, its `job`, and `job.organization`; sets status `in_progress`; **fails** (`status: failed`, error_message) if `job.description` blank. Two AI calls (both `AiClient.new(provider: 'openai')`):
1. **Call 1 `jd_structured_data`** — `Prompts::JobDescriptionStructuredData`, model **gpt-4.1-mini-2025-04-14** — decomposes JD HTML into `sections` (each with heading/type/inferred_section_type/content) + `title_technology`. Keeps sections where `type == 'criteria'`. Fails if none.
2. **Call 2 `jd_criteria_extraction`** — `Prompts::JobDescriptionCriteriaExtraction`, model **gpt-4o-2024-08-06** — extracts atomic criteria (text, tier, source_heading, duplicate flag) from those sections + title_technology.

Post-processing (code, after Call 2): strips any leading `[tier_N]` label the model injected into `text`; **heading override** — if `source_heading` matches `require|must|essential|minimum` set tier_1 (unless the criterion is a SOFT_SKILL from the hardcoded `SOFT_SKILLS` list), if matches `bonus|optional|extra credit` set tier_3; dedup by dropping `duplicate: true` and deleting the flag. Fails if no non-duplicates. On success uses `update` (NOT `update_columns`) to set `status: succeeded, criteria:, metadata:` **specifically so the `after_commit` callback fires and resumes waiting summaries**. Rescue: `CustomErrorAiSummary` → status `retrying` + re-raise; `JSON::ParserError`/`StandardError` → status `failed` + error_message.

### `scoring/integrate_analysis.rb` — `Scoring::IntegrateAnalysis` (per-summary)
Final call. Reads `structured_data` (role_analysis, applicable_experience, gaps, overlap_summary, assessment.career_narrative/key_skills/standout_accomplishments) and `criteria_results` off the summary, plus `score_percentage`. One AI call `integrated_analysis` — `Prompts::IntegratedAnalysis`, model **gpt-4.1-mini-2025-04-14**. Writes `integrated_role_analysis` + `status: succeeded` via `update`. Rescue mirrors ExtractCriteria (retrying+raise / failed). USER-VISIBLE: `integrated_role_analysis` is the recruiter-facing narrative paragraph on the summary; its tone is gated by the fit label derived from `score_percentage`.

## Prompt/model manifest (for scoring manifest)

| Prompt class | call_type | Provider | Model | Output shape |
|---|---|---|---|---|
| JobDescriptionStructuredData | `jd_structured_data` | openai | gpt-4.1-mini-2025-04-14 | `{sections[], title_technology}` |
| JobDescriptionCriteriaExtraction | `jd_criteria_extraction` | openai | gpt-4o-2024-08-06 | `{criteria[]}` (text, tier, source_heading, duplicate) |
| JobApplicationScoring | (used by ScoreJobApplication, 2nd slice) | — | **gemini-3.1-flash-lite** | `{scores[]}` (criterion_text, tier∈tier_1/2/3, score∈full/partial/not_found, reasoning) |
| ScoringDisplay | (used by ScoreJobApplication, 2nd slice) | — | **gemini-3.1-flash-lite** | `{criteria[]}` (criterion_text, score, display_sentence) |
| IntegratedAnalysis | `integrated_analysis` | openai | gpt-4.1-mini-2025-04-14 | `{integrated_role_analysis}` |

Notes for manifest:
- **JobApplicationScoring** scores an anonymized candidate profile against criteria; system prompt forbids pronouns and the word "resume", disallows partial_match when a criterion names a specific tool with no alternatives, and treats multilingualism as NOT communication-skill evidence. All strict json_schema.
- **ScoringDisplay** rewrites each scored criterion into one recruiter-style `display_sentence` citing concrete evidence; forbids pronouns/"resume"/em dashes.
- **IntegratedAnalysis** has heavy formatting rules: <600 chars, no pronouns, no "resume", no tier/score terms, no em dashes, tone rubric by fit label. Fit label from `score_percentage`: ≥90 excellent, ≥60 good, ≥35 mixed, ≥15 weak, else poor. A framing-sentence **template is randomly `.sample`d** per call (BEGINNING_TEMPLATES / MIXED_TEMPLATES; weak/poor get free-form instructions) — output first sentence varies run to run; expect non-deterministic phrasing in QA.

## Shared / non-AI surfaces touched (regression watch)
- **`AiApiRequest.create`** — both ExtractCriteria and IntegrateAnalysis write cost/usage rows (`requestable` = AiJobCriteria or AiJobApplicationSummary), computing `cost` via `AiClient.calculate_cost`. Verify these appear per call and cost is non-null; a model id the cost table doesn't know would zero/error the cost.
- **`Job#extract_job_criteria` + `AiJobCriteria` after_commit** — orchestrator triggers criteria extraction on the Job; ExtractCriteria's success `update` relies on an `after_commit` to resume waiting summaries. If that callback regresses, summaries stall in `awaiting_job_criteria` forever.
- **`ap` debug calls** everywhere (awesome_print) — noisy logs, not a functional risk.
- `update_columns` is used for interim status writes (in_progress/failed/retrying) — deliberate (skip callbacks); success writes use `update` deliberately to fire callbacks. Do not "normalize" these.

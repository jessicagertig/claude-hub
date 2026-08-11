# Slice: AI job-application action services — extraction/summary/scoring pipelines (second half)

All files in this slice are NEW (added on develop). No pre-existing behavior modified here; risk is entirely in-feature. Shared surfaces touched: `AiApiRequest` (cost/usage ledger rows) and `Job#extract_job_criteria` re-trigger.

## Files

### `summary/generate.rb` — `AiJobApplicationAction::Summary::Generate` (candidate SUMMARY pipeline, provider `openai`)
Entry: `new(textract_result_id:).generate`. Guards: returns silently unless the `TextractResult` exists, has `textract_job_result_text` present, and the job's `organization` is present. Feature gating (Flipper/PlanFeatureGate) and credit pre-flight now live UPSTREAM in `GenerateAiJobApplicationSummaryJob` — this service assumes gates already passed and can be called from any context.

Summary record reuse: takes the newest `AiJobApplicationSummary` for the job application; if its status is `pending`/`textract_processing`/`extracting`/`retrying` it reuses it (moving to `extracting`), otherwise creates a fresh one at `extracting`.

Four sequential OpenAI calls via `AiClient.new(provider: 'openai')`, each with JSON `response_format`, each logging an `AiApiRequest`:
1. `call_type: 'extraction'` — `Prompts::ResumeStructuredData` (model `gpt-4o-mini`), input = raw resume text + job title. Output stored as `structured_data`; adds `total_months_experience` (interval-merged from work_experience dates). Status → `summarizing`.
2. `call_type: 'assessment'` — `Prompts::ResumeAssessment` (`gpt-4o-mini`), ONLY runs if `work_experience` present. Input = ANONYMIZED work_experience/education/skills. Produces primary/secondary domain, `experience_classifications`, `career_narrative`, `key_skills`, `standout_accomplishments`. Adds `assessment` + computed `months_by_domain` to structured_data.
3. `call_type: 'comparison'` — `Prompts::ResumeComparison` (`gpt-4o-mini`), ONLY runs if `job_title` AND `months_by_domain` present. Role-aware; input = months_by_domain, key_skills, career_narrative, job_title, stated_experience. Produces `applicable_experience`, `gaps`, `overlap_summary`.
4. `call_type: 'summary'` — `Prompts::ResumeSummary` (`gpt-4o-mini`), role-BLIND, receives only distilled Call-2/Call-3 outputs + anonymized education/certs. Produces final `headline`, `summary_text`, and `role_analysis`. Final `update` writes headline/summary_text/structured_data. (Note: this service does NOT set status to a terminal success value or trigger scoring; that transition happens outside this file.)

Error handling: `CustomErrorAiSummary` → `update_columns(status: :retrying)` + re-raise (lets job retry); `JSON::ParserError` and other `StandardError` → `status: :failed` with error_message. `ap` debug logs throughout (intentional, flagged "do not remove").

Date parsing helpers (`parse_date`, `calculate_months`, `merge_intervals`, `format_months`) handle year-only, `M.YYYY`, seasonal ("Fall 2025"), "present/current/ongoing" → today. Unparseable dates logged and skipped (no fabrication). `months_by_domain`: primary domain months = primary+secondary classified experiences merged; secondary domain months = secondary subset only.

### `scoring/score_job_application.rb` — `AiJobApplicationAction::Scoring::ScoreJobApplication` (SCORING pipeline, provider `gemini`)
Entry: `new(ai_job_application_summary:, textract_result:).score`. Returns unless both present.

Job-criteria gating (governs UI score state):
- `latest_ai_job_criteria` blank OR `status_failed?` → summary `status: awaiting_job_criteria`, calls `@job.extract_job_criteria` (re-triggers criteria extraction), returns.
- criteria `pending`/`in_progress`/`retrying` → `awaiting_job_criteria`, returns (waits).
- criteria present but `criteria` array blank → mark criteria `failed`, summary `awaiting_job_criteria`, re-trigger extraction, return.
- otherwise summary → `scoring`.

Requires `structured_data` on the summary (raises `CustomErrorAiSummary` if missing — i.e., summary pipeline must have run first). Re-anonymizes structured_data via `AnonymizeForAi`, builds a text `candidate_profile` (professional summary, stated experience, work experience, education, skills, certifications).

Scoring calls via `AiClient.new(provider: 'gemini')`:
- `Prompts::JobApplicationScoring.messages(criteria:, candidate_profile:)` — one run (`call_type: 'scoring'`). Parses `scores`, strips any leaked `[tier_N]` label prefix from `criterion_text`, merges `contains_title_technology` from source criteria, computes `score_percentage` via `Scoring::Calculate.compute`.
- MEDIAN-OF-5 near boundaries: if the first score is within 5 points of any non-zero fit-label boundary (`Prompts::IntegratedAnalysis::FIT_LABELS`), runs 4 more scoring calls, sorts, takes median run. Otherwise uses the single run.
- `call_type: 'scoring_display'` — `Prompts::ScoringDisplay.messages(scoring_results:)` on the selected run, produces per-criterion `display_sentence`; merged into criteria_results.
- Writes `score_percentage`, `criteria_results`, `status: integrating`.

Error handling mirrors Generate: `CustomErrorAiSummary` → `retrying` + re-raise; JSON/Standard → `failed`. Individual `run_scoring` failures return nil (a failed extra run just drops from the median set; a failed first run raises "Scoring call failed").

### `summary/anonymize_for_ai.rb` — `AnonymizeForAi`
Deletes PII fields `%w[name email phone location links]` from a deep-dup of structured_data. Used before Call 2/3/4 (summary) and before scoring. Call 1 (extraction) deliberately gets full PII.

### Prompt files
- `prompts/resume_structured_data.rb` — `ResumeStructuredData`, model `gpt-4o-mini`, JSON response_format. Call 1.
- `prompts/resume_assessment.rb` — `ResumeAssessment`, `gpt-4o-mini`. Call 2.
- `prompts/resume_comparison.rb` — `ResumeComparison`, `gpt-4o-mini`. Call 3.
- `prompts/resume_summary.rb` — `ResumeSummary`, `gpt-4o-mini`. Call 4.
- `prompts/resume_relevance.rb` — `ResumeRelevance`, model `deepseek-chat`, has `self.provider`. **UNUSED** — `grep` finds zero callers in `app/`. Dead code.
- `prompts/role_categorization.rb` — `RoleCategorization`, only a `ROLE_CATEGORIES` constant list, no `messages`/`model` methods. **UNUSED** — zero callers. Dead code.

## USER-VISIBLE / QA implications
- Candidate AI summary card: headline + summary_text + structured_data (role_analysis, gaps, applicable_experience) come from the 4-call summary pipeline. If work_experience empty → assessment/comparison skipped, summary still generated from thinner input. If job has no title → comparison skipped.
- Score percentage + per-criterion results + display sentences come from the gemini scoring pipeline; only runs after summary produced `structured_data`.
- "Awaiting job criteria" UI state: appears when a job's AI job criteria are missing/failed/still-extracting; scoring auto re-triggers `Job#extract_job_criteria`. QA: score a candidate on a job whose criteria never extracted → summary sits at `awaiting_job_criteria`.
- Median-of-5 only fires near fit-label boundaries — borderline candidates cost 5x scoring calls; well-inside-a-band candidates cost 1.
- PII anonymization: names/emails/phone/location/links must NOT appear in assessment/summary/scoring outputs (bias control). QA-checkable by inspecting summary text for candidate name leakage.

## SHARED / regression surfaces
- `AiApiRequest.create` — every call writes a cost/usage ledger row (organization, requestable=summary, call_type, provider, model, tokens, cost). Feeds billing/usage displays. Non-AI regression risk low (append-only), but cost accuracy depends on `AiClient.calculate_cost`.
- `Job#extract_job_criteria` re-triggered from scoring — could re-enqueue criteria extraction; verify it is idempotent / not spammed.

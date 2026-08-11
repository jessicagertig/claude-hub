# AI Scoring Integration — Spec

## Scope

Integrate candidate-criteria scoring into the existing AI summary pipeline. Extract requirements from job descriptions when published, score each candidate's resume against those requirements, produce a numerical score and natural language display sentences per criterion, and generate an integrated role analysis combining summary insights with scoring evidence. The scoring pipeline runs as part of the unified `AiJobApplicationSummary` lifecycle — not as a separate feature.

Frontend is out of scope.

**Deferred:** Granular hiring team permissions — split `hiring_team_ai_credits_control_enabled` into three: per-candidate manual generation, bulk generation, and auto-generate toggle. Seven touchpoints (model, migration, policy, controller, frontend type, settings UI, JobPolicy). Not MVP.

---

## 1. New Table: `ai_job_criteria`

Create table `ai_job_criteria`.

**Model:** `AiJobCriteria`
- `belongs_to :job`
- `has_many :ai_api_requests, as: :requestable`

One record per job. Overwritten on re-extraction (not versioned).

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| `status` | integer | NOT NULL | 0 |
| `criteria` | jsonb | nullable | — |
| `metadata` | jsonb | nullable | — |
| `error_message` | text | nullable | — |

`t.references :job` with foreign key and unique index. `t.timestamps`.

**`status` enum** (`_prefix: true`):
- `pending: 0`
- `in_progress: 1`
- `succeeded: 2`
- `failed: 3`
- `retrying: 4`

**`criteria` jsonb** — array of criterion objects. Duplicates filtered before storage (`duplicate` field not stored). Each element:

| Key | Type |
|-----|------|
| `text` | string |
| `tier` | `tier_1`, `tier_2`, or `tier_3` |
| `tier_reasoning` | string |
| `binary` | boolean |
| `contains_title_technology` | boolean |
| `source_heading` | string or null |
| `source_text` | string |

When deduplicating, the surviving criterion inherits the higher tier of the two versions.

**Code-level heading tier override** (runs after Call 2 returns):
- If `source_heading` contains "required", "must", "essential", or "minimum" → force `tier` to `tier_1` (skip soft skills)
- If `source_heading` contains "bonus", "optional", or "extra credit" → force `tier` to `tier_3`

**`metadata` jsonb:**
- `title_technology` — string or null. Technology extracted from the job title by Call 1. Auditing only.
- `raw_criteria_count` — integer. Criteria count before dedup.
- `criteria_count` — integer. Criteria count after dedup. Matches `criteria` array length.

**`after_commit` callback on `AiJobCriteria`:** when `status` transitions to `succeeded`, find all `AiJobApplicationSummary` records for this job with status `awaiting_job_criteria`. For each, enqueue `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: summary.textract_result_id)` to resume the pipeline.

---

## 2. New Table: `ai_job_application_summary_statuses`

Create table `ai_job_application_summary_statuses`.

**Model:** `AiJobApplicationSummaryStatus`
- `belongs_to :job_application`
- `belongs_to :ai_job_application_summary, optional: true`

One record per job application. Lightweight read model — avoids `SELECT *` on `ai_job_application_summaries` with its large jsonb columns during list views.

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| `regenerating` | boolean | NOT NULL | false |

`t.references :job_application` with foreign key and unique index. `t.references :ai_job_application_summary` with foreign key, nullable. `t.timestamps`.

**Lifecycle:**
- Create when AI evaluation first kicks off for a job application.
- Set `ai_job_application_summary_id` when a summary reaches `succeeded` — always points to the latest successful summary.
- On regeneration: set `regenerating` to true. `ai_job_application_summary_id` stays pointing to old successful summary (frontend keeps displaying it). When new summary succeeds, update `ai_job_application_summary_id` to the new one, set `regenerating` to false.

**Frontend access:** `ShallowJobApplicationSerializer` eager loads this record. `ai_job_application_summary_id` column read directly (no association load) — non-null means a completed evaluation exists.

---

## 3. Modify `ai_job_application_summaries`

Rollback the existing migration and edit in place (feature not in production or staging). Check `db:migrate:status` to identify all migrations after `create_ai_job_application_summaries`. Roll back exactly that many steps with `db:rollback STEP=N`. If any migration in the chain is irreversible, make it reversible first — no migration should be irreversible until it goes to production. After editing `create_ai_job_application_summaries` in place, re-run `db:migrate` to bring all migrations forward.

### New Columns

| Column | Type | Nullable | Default |
|--------|------|----------|---------|
| `score_percentage` | decimal | nullable | — |
| `criteria_results` | jsonb | nullable | — |
| `integrated_role_analysis` | text | nullable | — |

`score_percentage` — overall weighted score (0-100). Display score for customers (stars, 1-10, etc.) computed by a model method — not a separate column.

`integrated_role_analysis` — scoring-aware role analysis combining summary insights with scoring evidence. Connects back to the existing `role_analysis` in `structured_data` — same kind of output but informed by criteria scoring. Both kept as separate outputs.

**`criteria_results` jsonb** — array, one element per scored criterion:

| Key | Type |
|-----|------|
| `criterion_text` | string |
| `tier` | `tier_1`, `tier_2`, or `tier_3` |
| `contains_title_technology` | boolean |
| `score` | `full_match`, `partial_match`, or `not_found` |
| `reasoning` | string |
| `summary` | string |

### Redesigned `status` Enum

Replace the existing `status` enum values. Full pipeline lifecycle:

- `pending: 0`
- `textract_processing: 1`
- `extracting: 2` — structured data extraction (summary Call 1)
- `summarizing: 3` — summary Calls 2-4
- `awaiting_job_criteria: 4` — waiting for `AiJobCriteria` to reach `succeeded`
- `scoring: 5` — scoring resume against criteria
- `integrating: 6` — integrated role analysis combining summary + scoring
- `succeeded: 7` — terminal success, full evaluation complete
- `retrying: 8` — `CustomErrorAiSummary` caught, job will retry. Record reused on retry, not recreated.
- `failed: 9` — terminal failure. Set only on retry exhaustion (`CustomErrorAiSummary` after all attempts spent) or non-retryable error (`StandardError`, `JSON::ParserError`)

`succeeded` means the entire pipeline is done — summary, scoring, and integration. Not just the summary portion.

In the happy path (criteria already extracted for the job), `awaiting_job_criteria` passes through immediately to `scoring`.

This enum may require adjustment when wired into the full application flow.

### Serialization

Add `score_percentage`, `criteria_results`, and `integrated_role_analysis` to `Api::V1::AiJobApplicationSummarySerializer` (full serializer).

Add `score_percentage` to `Api::V1::AiJobApplicationSummaryShallowSerializer`.

Add `has_one :ai_job_application_summary_status` to `JobApplication` model. Add `AiJobApplicationSummaryStatus` serializer for use in `ShallowJobApplicationSerializer`.

### Every Reference to `status_succeeded?` — CRITICAL

`status_succeeded?` previously meant "summary done," which was also the terminal state. Those two concepts are now separate: "summary done" is an intermediate milestone (status has passed `summarizing`), while "terminal success" (`succeeded`) means the entire evaluation — summary, scoring, and integration — is complete.

Find every caller of `status_succeeded?`, `status: :succeeded`, and any other enum-generated status method on `AiJobApplicationSummary` across the entire codebase. For each reference, determine which concept it needs:

- **Terminal state** (credit consumption, broadcasting, destroying previous textract results, marking status records) → keep `status_succeeded?`
- **Summary portion complete** (any logic that previously fired "when summary is done" but should not wait for scoring/integration) → replace with the appropriate check

This classification must be exhaustive. A missed reference means either credits consumed at the wrong time, broadcasts firing too early, or summary-dependent logic blocked until scoring completes.

### Required Changes to `AiJobApplicationAction::Summary::Generate`

`Summary::Generate` must be updated for the redesigned enum:

- `status_in_progress?` → `status_extracting?`
- `status: :in_progress` → `status: :extracting`
- The final status update (currently `status: :succeeded` at line 163) must NOT set `succeeded`. After Call 1 completes, `Summary::Generate` sets `summarizing` before running Calls 2-4. When all 4 calls complete, `Summary::Generate` leaves the status at `summarizing`. The orchestrator interprets `summarizing` with populated summary fields (`headline`, `summary_text` present) as "summary complete" and advances to `awaiting_job_criteria` / `scoring`.
- `update_columns(status: :in_progress)` at line 32 → `update_columns(status: :extracting)`
- `status_pending?` and `status_textract_processing?` are unchanged — same meaning, same position in the lifecycle, no updates needed.

---

## 4. Scoring Orchestration Services

Four modules under `AiJobApplicationAction::Scoring::`, following the `AiJobApplicationAction::Summary::Generate` pattern for error handling, `AiApiRequest` tracking, and status transitions. `Summary::Generate` is the direct analog for `ExtractCriteria` — use it as the structural template, especially if implementing `ExtractCriteria` before the orchestrator.

### `AiJobApplicationAction::Scoring::ExtractCriteria`

File: `app/services/ai_job_application_action/scoring/extract_criteria.rb`

Per-job service. Writes to `AiJobCriteria`.

- Call 1 (gpt-4.1-mini): extract structured data from job description HTML — sections with headings, types, content, `title_technology`
- Call 2 (gpt-4o): extract individual criteria from sections — `text`, `tier`, `tier_reasoning`, `binary`, `contains_title_technology`, `duplicate`, `source_heading`, `source_text`
- Code-level heading tier override after Call 2
- Filter duplicates, populate `AiJobCriteria.criteria` and `AiJobCriteria.metadata`
- Create `AiApiRequest` after each call, linked to `AiJobCriteria` via polymorphic `requestable`
- Transition `AiJobCriteria` status: `pending` → `in_progress` → `succeeded` / `failed`
- The `succeeded` status transition must use `update` (not `update_columns`) to ensure the `after_commit` callback fires and resumes waiting summaries. `failed` transitions may use `update_columns` (following the `Summary::Generate` pattern).
- Error handling: same pattern as `AiJobApplicationAction::Summary::Generate`

### `AiJobApplicationAction::Scoring::ScoreJobApplication`

File: `app/services/ai_job_application_action/scoring/score_job_application.rb`

Per-application service. Writes `score_percentage` and `criteria_results` to `AiJobApplicationSummary`.

- Read criteria from `AiJobCriteria` for the job + resume text from the summary's `textract_result`
- If no `AiJobCriteria` with status `succeeded` exists: set `AiJobApplicationSummary` status to `awaiting_job_criteria`, trigger `ExtractCriteria` for the job if not already in progress, return. Re-triggered by `AiJobCriteria` `after_commit` callback when criteria succeed.
- Run scoring call (Gemini flash) + display sentence call (Gemini flash)
- Delegate score computation to `Calculate`
- Create `AiApiRequest` after each call, linked to `AiJobApplicationSummary`
- Transition `AiJobApplicationSummary` status: `scoring` → `integrating`
- Do NOT touch `structured_data`, `summary_text`, or `integrated_role_analysis`

### `AiJobApplicationAction::Scoring::Calculate`

File: `app/services/ai_job_application_action/scoring/calculate.rb`

Sub-module for weighted score computation. Separated from `ScoreJobApplication` so it can be called independently.

- Tier weights: `tier_1` = 6, `tier_2` = 4, `tier_3` = 2
- Score values: `full_match` = 1.0, `partial_match` = 0.7, `not_found` = 0
- Title technology multiplier: 3x if `contains_title_technology`
- Formula: `sum(weight × value × multiplier) / max_possible × 100`

### `AiJobApplicationAction::Scoring::IntegrateAnalysis`

File: `app/services/ai_job_application_action/scoring/integrate_analysis.rb`

Per-application service. Writes `integrated_role_analysis` to `AiJobApplicationSummary`.

- Input: `structured_data` fields (`role_analysis`, `applicable_experience`, `gaps`, `overlap_summary`, `career_narrative`, `key_skills`, `standout_accomplishments`) + `criteria_results` + `score_percentage`
- One AI call with new prompt at `app/services/ai_job_application_action/scoring/prompts/integrated_analysis.rb`
- Produce scoring-aware role analysis — same kind of output as `role_analysis` but informed by scoring evidence
- Create one `AiApiRequest` for cost tracking
- Transition `AiJobApplicationSummary` status: `integrating` → `succeeded` / `failed`
- Do NOT touch `score_percentage`, `criteria_results`, `structured_data`, or `summary_text`
- Prompt not yet written — requires development and testing

Prompt files at `app/services/ai_job_application_action/scoring/prompts/`. Four existing prompt files are **frozen — do not modify prompt text, schema definitions, or model assignments:** `job_description_structured_data.rb` (Call 1), `job_description_criteria_extraction.rb` (Call 2), `job_application_scoring.rb` (scoring call), `scoring_display.rb` (display sentence call). These are v13, stability tested over three days of iteration. MODEL constants already pinned to API-returned versions on the branch. Jessica will personally murder you, terminate your existence, and throw you into the void if you touch her prompts. The only prompt file requiring development is `integrated_analysis.rb` (new).

---

## 5. Pipeline Orchestrator

### `AiJobApplicationAction::Orchestrate`

Single entry point for the full evaluation pipeline. Coordinates sub-services in sequence. Resilient to failures via status checkpointing.

**Pipeline sequence:**
1. `AiJobApplicationAction::Summary::Generate` — 4 summary calls (existing service)
2. Criteria check — verify `AiJobCriteria` with status `succeeded` exists for the job
3. `AiJobApplicationAction::Scoring::ScoreJobApplication` — scoring + display sentences
4. `AiJobApplicationAction::Scoring::IntegrateAnalysis` — integrated role analysis

**Resilience:** On entry, check `AiJobApplicationSummary.status` and resume from that point. Never re-run completed steps. Each sub-service writes its output before the orchestrator advances status.

Resume points:
- `extracting` → re-run `Summary::Generate` from the beginning (Call 1 is idempotent — it overwrites `structured_data`)
- `summarizing` → re-run `Summary::Generate` from Calls 2-4 (idempotent — they overwrite their outputs in `structured_data`)
- `awaiting_job_criteria` → check if criteria now exist, proceed to `scoring` or return
- `scoring` with `criteria_results` already populated → skip to `integrating`

**Criteria gap handling:**
- After summary succeeds, check for `AiJobCriteria` with status `succeeded` for the job
- If present → advance to `scoring`
- If absent → set status to `awaiting_job_criteria`, trigger `ExtractCriteria` for the job if not already in progress, return
- `AiJobCriteria` `after_commit` callback re-invokes the pipeline to resume (see Section 1)

**Four entry points, all reaching `Orchestrate` through `TextractResult#generate_ai_summary_with_credit_flow`:**
- Auto trigger (Textract completion): `TextractResult after_commit :queue_ai_summary_job` → `GenerateAiJobApplicationSummaryJob` → `textract_result.generate_ai_summary_with_credit_flow` → `Orchestrate`
- Manual trigger (controller): `AiJobApplicationSummariesController#create` → `ValidateAiSummaryGeneration` → `CreateAiSummaryGeneration` → `GenerateAiJobApplicationSummaryJob` → `textract_result.generate_ai_summary_with_credit_flow` → `Orchestrate`
- Bulk trigger: `BulkAiJobApplicationSummariesController#create` → `QueueBulkAiSummaryJobs` → `BulkGenerateAiSummariesJob` → `result.textract_result.generate_ai_summary_with_credit_flow` → `Orchestrate` (per iteration). Note: the bulk job calls `generate_ai_summary_with_credit_flow` directly on the textract_result (not through `GenerateAiJobApplicationSummaryJob`).
- Criteria-ready callback: `AiJobCriteria` `after_commit` → re-enqueues `GenerateAiJobApplicationSummaryJob` → `textract_result.generate_ai_summary_with_credit_flow` → `Orchestrate` (resume from `awaiting_job_criteria`)

---

## 6. Orchestrator Integration into `TextractResult#generate_ai_summary_with_credit_flow`

### Integration Point

Replace the single `generate_ai_summary` method call inside `TextractResult#generate_ai_summary_with_credit_flow` with a call to `AiJobApplicationAction::Orchestrate`. Everything else in `generate_ai_summary_with_credit_flow` stays unchanged — credit consumption via `CreateAiCreditBalanceTransaction`, notification via `NotifyZeroAiCredits` and `NotifyLowAiCredits`, and the `status_succeeded?` guard.

`generate_ai_summary` currently calls `AiJobApplicationAction::Summary::Generate.new(textract_result_id: id).generate`. Replace this with `AiJobApplicationAction::Orchestrate.new(textract_result_id: id).call`.

The standalone `TextractResult#generate_ai_summary` method (line 52-54) should be removed or made private after the orchestrator replaces its usage. Keeping it public provides a bypass around the orchestrator.

### `textract_result_id` Parameter

`GenerateAiJobApplicationSummaryJob` continues to take `textract_result_id:` as its parameter. The `TextractResult` is the anchor of the flow — it owns the relationship to the summary, bridges textract completion to generation, and the credit flow runs through `TextractResult#generate_ai_summary_with_credit_flow`.

### Resume from `awaiting_job_criteria`

When `AiJobCriteria` `after_commit` fires on transition to `succeeded`:
1. Find `AiJobApplicationSummary` records for this job with status `awaiting_job_criteria`
2. For each summary: enqueue `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: summary.textract_result_id)`
3. The job calls `textract_result.generate_ai_summary_with_credit_flow`
4. The orchestrator checks the summary's status, sees `awaiting_job_criteria`, criteria now exist, resumes at `scoring`

### Summary Currency

`textract_result_id` on the summary ties it to a specific resume version. When a resume is replaced, `SubmitResumeToTextract` marks existing summaries as `stale: true`. `CreateAiSummaryGeneration` also checks — if an active summary's `textract_result_id` differs from the latest textract result, marks it stale.

---

## 7. Job Lifecycle Triggering

`Job` model adds `has_one :ai_job_criteria`. All references below use the association, not `find_by(job_id:)`.

### On Publish

Add `extract_job_criteria` call to `Job#handle_status_changed_to_published`.

### On Job Description Update After Publish

Add `handle_description_change` call to `Job#handle_before_update` (alongside existing `handle_status_change`, `UpdateDistributionsJob`, location update).

**`Job#handle_description_change`:**
- Guards: `description_changed?` AND `published?` AND `description_meaningfully_changed?`
- If all pass: call `extract_job_criteria`

**`Job#description_meaningfully_changed?`:**
- Strip HTML tags from `description_was` and `description`
- Remove all non-alphabetical characters (including digits — intentional: number-only changes like salary or years-of-experience do not change the extracted criteria structure)
- Lowercase both
- Strict equality comparison — not identical means meaningfully changed

### `Job#extract_job_criteria`

Called from both `handle_status_changed_to_published` (on publish) and `handle_description_change` (on job description update after publish). Same method, same debounce, same behavior.

- Check `Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)` — return if not enabled
- If `ai_job_criteria.present?` and status `pending` — return (debounce in effect, job already queued with 2-minute delay)
- Otherwise, set up the record and enqueue:
  - If `ai_job_criteria.present?` and status `in_progress` — reset status to `pending` (the in-progress extraction may be running against a stale description; a new job will re-extract with the latest)
  - If `ai_job_criteria.present?` and status `succeeded` or `failed` — reset status to `pending`
  - If `ai_job_criteria.present?` and status `in_progress`, `succeeded`, `failed`, or `retrying` — reset status to `pending`, save, enqueue `ExtractJobCriteriaJob.set(wait: 2.minutes).perform_later(ai_job_criteria.id)` (debounced — description may still be changing)
  - If `ai_job_criteria` does not exist — build new `AiJobCriteria`, set status to `pending`, save (return unless save succeeds), enqueue `ExtractJobCriteriaJob.perform_later(ai_job_criteria.id)` (immediate — no reason to delay first-time extraction)

The 2-minute delay is the debounce mechanism for re-extraction only. First-time extraction runs immediately. For re-extraction: setting `pending` and saving BEFORE enqueuing is what makes the debounce work — if the user makes five edits in two minutes, the first edit resets to `pending` and enqueues a job in 2 minutes. Edits 2-5 see `pending`, return immediately. When the job runs after 2 minutes, it reads the latest description.

The only status that triggers an early return is `pending` — because a pending record means a job is already queued with the debounce delay. `in_progress` does NOT return early because we cannot know whether the in-progress extraction is using the current description or a stale one.

**Note:** `extract_job_criteria` saves a record and enqueues a job inside a `before_update` callback (inside the Job save transaction). On Rails 6.1 with Sidekiq, `perform_later` pushes to Redis immediately (before the transaction commits). If the outer Job save fails, the `AiJobCriteria` save rolls back but the Sidekiq job has already been enqueued. The job's `find_by` guard (`return if not found`) handles this safely — the job fires, finds no record, and returns. This follows the existing pattern of enqueuing jobs from `before_update` in the Job model (e.g., `UpdateDistributionsJob`, `Notification::JobStatusChangeJob`).

### `ExtractJobCriteriaJob`

- Queue: `:default`
- `perform(ai_job_criteria_id)`: load `AiJobCriteria` by id, return if not found. Get job description via `ai_job_criteria.job.description` (reads latest description at execution time — the delay ensures the final version). Pass to `AiJobApplicationAction::Scoring::ExtractCriteria`.
- Retry: same pattern as `GenerateAiJobApplicationSummaryJob`

---

## 8. Credit Consumption, Flipper, Broadcasting

### Flipper

Reuse `:AI_APPLICANT_SUMMARY`. No new flag. Scoring is part of the evaluation, not a separate feature.

### Credit Consumption

1 credit for the entire evaluation (summary + scoring + integration) — not per step.

Credit consumed only after `AiJobApplicationSummary` status reaches `succeeded` (terminal state). If scoring or integration fails, no credit consumed.

Credit consumption stays inside `TextractResult#generate_ai_summary_with_credit_flow`. The existing `status_succeeded?` check naturally gates it because `succeeded` now means full pipeline complete.

Reuse entry type `ai_summary_usage_debit: 60` in `AiCreditBalanceTransaction` — one table, one evaluation, one entry type.

### Broadcasting

`AI_SUMMARY_COMPLETE` fires after `succeeded` (full evaluation complete), not after just the summary portion. The broadcast already happens in `GenerateAiJobApplicationSummaryJob` after `generate_ai_summary_with_credit_flow` returns — timing shifts automatically.

Payload and event name may need updating for the plan.

---

## 9. Test Plan

### Existing tests requiring updates

- `spec/models/ai_job_application_summary_spec.rb` — `destroy_previous_textract_results` tests need to account for `succeeded` firing later in the pipeline (after integration, not after summary). Enum references updated to new status names.
- `spec/jobs/generate_ai_job_application_summary_job_spec.rb` — creates summaries with `status: :succeeded`, tests broadcast behavior. Enum references updated to new status names.
- Any existing specs for `Summary::Generate`, `CreateAiSummaryGeneration`, `ValidateAiSummaryGeneration`, `BulkGenerateAiSummariesJob` that reference status enum values.

### New test coverage required

- `AiJobCriteria` model: validations, status enum, `after_commit` callback (finds and enqueues for all waiting summaries).
- `AiJobApplicationSummaryStatus` model: lifecycle (create, update `ai_job_application_summary_id`, regenerating flag).
- `ExtractJobCriteriaJob`: execution, retry, not-found guard.
- `AiJobApplicationAction::Scoring::ExtractCriteria`: Call 1 + Call 2, heading override, dedup, status transitions, error handling.
- `AiJobApplicationAction::Scoring::ScoreJobApplication`: criteria present path, criteria absent path (→ `awaiting_job_criteria`), scoring + display calls, Calculate delegation.
- `AiJobApplicationAction::Scoring::Calculate`: weighted score computation with all tier/multiplier combinations.
- `AiJobApplicationAction::Scoring::IntegrateAnalysis`: integration call, status transitions, error handling.
- `AiJobApplicationAction::Orchestrate`: full pipeline sequence, resume from each checkpoint, criteria gap handling.
- `Job#extract_job_criteria`: Flipper gate, pending/in_progress guard, save failure path.
- `Job#handle_description_change`: guards, interaction with publish callback.
- `Job#description_meaningfully_changed?`: HTML stripping, whitespace-only changes, number-only changes.
- Serializer tests for new attributes on `AiJobApplicationSummarySerializer`.

Detailed test specifications will be determined in the implementation plan.

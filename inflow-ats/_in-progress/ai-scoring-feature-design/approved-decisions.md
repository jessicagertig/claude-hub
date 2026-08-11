# Approved Decisions

## 1. `AiJobCriteria` Model and Table

**Model:**
- Name: `AiJobCriteria`
- `belongs_to :job`
- `has_many :ai_api_requests, as: :requestable` (polymorphic — reuses existing cost tracking, zero changes to `ai_api_requests` table)

**Cardinality:**
- One record per job
- Overwritten on re-extraction (not versioned)

**Table `ai_job_criteria`:**

| Column | Type | Nullable | Default | Purpose |
|--------|------|----------|---------|---------|
| `id` | bigint | NOT NULL | auto | PK |
| `job_id` | bigint | NOT NULL | — | FK to `jobs` |
| `status` | integer | NOT NULL | 0 | Lifecycle enum |
| `criteria` | jsonb | nullable | — | Post-dedup, post-heading-override criterion array |
| `metadata` | jsonb | nullable | — | Extraction auditing data |
| `error_message` | text | nullable | — | Error details if extraction fails |
| `created_at` | datetime(6) | NOT NULL | — | |
| `updated_at` | datetime(6) | NOT NULL | — | |

**Status enum values:**
- `pending: 0`
- `in_progress: 1`
- `succeeded: 2`
- `failed: 3`
- `retrying: 4`

**`metadata` jsonb keys:**
- `title_technology` — string or null. Technology extracted from job title by Call 1 (e.g., "Go" from "Senior Go Engineer"). Explains why certain criteria get 3x weight. Auditing only — not used downstream after extraction.
- `raw_criteria_count` — integer. Criteria count before dedup.
- `criteria_count` — integer. Criteria count after dedup. Should match `criteria` array length.

**Each element in `criteria` jsonb array:**

| Key | Type | Description |
|-----|------|-------------|
| `text` | string | Extracted criterion statement |
| `tier` | string | `tier_1`, `tier_2`, or `tier_3`. May be overridden by code-level heading check |
| `tier_reasoning` | string | Model's explanation for tier assignment |
| `binary` | boolean | Binary (has/doesn't) vs degree-based |
| `contains_title_technology` | boolean | Matches job title technology → 3x scoring weight |
| `source_heading` | string or null | Heading criterion was extracted from. Used by code-level tier override |
| `source_text` | string | Original JD text this criterion was extracted from |

**Dedup behavior:**
- Criteria marked `duplicate: true` by Call 2 are filtered out before storage
- `duplicate` field not stored — only non-duplicate criteria in array
- Surviving criterion inherits higher tier of the two versions

**Code-level heading tier override (runs after Call 2):**
- If `source_heading` contains "required" / "must" / "essential" / "minimum" → force `tier` to `tier_1` (skip soft skills)
- If `source_heading` contains "bonus" / "optional" / "extra credit" → force `tier` to `tier_3`

## 2. `AiJobApplicationSummaryStatus` Table

Lightweight status/pointer table. One record per job application. The frontend's entry point for knowing whether AI data exists and what state it's in — without joining to the heavy `ai_job_application_summaries` table.

**Pattern:** read model / denormalized cache table. Standard pattern for avoiding `SELECT *` on tables with large jsonb columns in list views.

**Table `ai_job_application_summary_statuses`:**

| Column | Type | Nullable | Default | Purpose |
|--------|------|----------|---------|---------|
| `id` | bigint | NOT NULL | auto | PK |
| `job_application_id` | bigint | NOT NULL, unique | — | FK, one per application |
| `ai_job_application_summary_id` | bigint | nullable | — | FK to latest successful summary |
| `regenerating` | boolean | NOT NULL | false | True while a new summary is being generated |
| `created_at` | datetime(6) | NOT NULL | — | |
| `updated_at` | datetime(6) | NOT NULL | — | |

**Lifecycle:**
- Created when AI evaluation first kicks off for a job application
- `ai_job_application_summary_id` set when a summary succeeds — always points to the latest successful summary
- On regeneration: `regenerating` set to true, FK stays pointing to old successful summary (frontend keeps displaying it). When new summary succeeds, FK updates to new one, `regenerating` set to false.

**Frontend access:**
- `ShallowJobApplicationSerializer` eager loads this record via `includes(:ai_job_application_summary_status)`
- `ai_job_application_summary_id` column accessed directly (no association load) — non-null means summary exists
- Score existence determined through the summary record when drilling in

## 3. `AiJobApplicationSummary` — Integrated Scoring

Scoring is not a bolt-on. It's part of what an AI summary IS — a unified AI evaluation of the candidate. No separate `AiJobApplicationScore` table. Scoring data and lifecycle integrated directly into `AiJobApplicationSummary`.

**Redesigned `status` enum (full pipeline lifecycle):**
- `pending: 0`
- `textract_processing: 1`
- `extracting: 2` — structured data extraction (summary Call 1)
- `summarizing: 3` — summary Calls 2-4
- `awaiting_job_criteria: 4` — waiting for `AiJobCriteria` to be available for the job
- `scoring: 5` — scoring resume against criteria
- `integrating: 6` — integrated role analysis combining summary + scoring
- `succeeded: 7` — terminal success, full evaluation complete
- `retrying: 8` — `CustomErrorAiSummary` caught, job will retry. Record reused on retry.
- `failed: 9` — terminal failure

`succeeded` means the ENTIRE pipeline is done — summary and scoring. Not just the summary.

In the happy path (criteria already extracted for the job), `awaiting_job_criteria` is passed through immediately into `scoring`. Only sits there when criteria aren't ready yet.

**Note:** This enum may change when wired into the full application flow. This is a deep integration, not a standalone feature.

**New columns on `ai_job_application_summaries`:**

| Column | Type | Nullable | Default | Purpose |
|--------|------|----------|---------|---------|
| `score_percentage` | decimal | nullable | — | Overall weighted score (0-100) |
| `criteria_results` | jsonb | nullable | — | Per-criterion scoring results array |
| `integrated_role_analysis` | text | nullable | — | Scoring-aware role analysis combining summary insights + scoring evidence |

Display score for customers (stars, 1-10, etc.) computed by a model method from `score_percentage` — not a separate column.

`integrated_role_analysis` connects back to the existing `role_analysis` in `structured_data` — same kind of output but informed by how the candidate scored against the job's criteria. Both kept as separate outputs.

**`criteria_results` jsonb array elements:**

| Key | Type | Description |
|-----|------|-------------|
| `criterion_text` | string | The criterion that was scored |
| `tier` | string | `tier_1`, `tier_2`, or `tier_3` at time of scoring |
| `contains_title_technology` | boolean | Whether this criterion had 3x weight |
| `score` | string | `full_match`, `partial_match`, or `not_found` |
| `reasoning` | string | Model's explanation for the score (Call 4 output) |
| `summary` | string | Natural language display sentence (Call 5 output) |

**Criteria check:**
- Criteria availability checked early in the pipeline (at or before `extracting`)
- If `AiJobCriteria` missing for the job, trigger extraction in parallel with summary work
- If criteria ultimately unavailable by scoring time, record sits at `awaiting_job_criteria` and retries
- If criteria extraction fails, record goes to `failed`

**Migration:**
- Feature not in production or staging — rollback existing migration and edit in place

## 4. Scoring Orchestration Services

Four modules under `AiJobApplicationAction::Scoring::`, following the `AiJobApplicationAction::Summary::Generate` pattern (same error handling, `AiApiRequest` tracking, status transitions).

**`AiJobApplicationAction::Scoring::ExtractCriteria`**
- Per-job service
- Writes to `AiJobCriteria`
- Call 1 (gpt-4.1-mini): extracts structured data from JD HTML — sections with headings, types, content, title_technology
- Call 2 (gpt-4o): extracts individual criteria from sections — text, tier, tier_reasoning, binary, contains_title_technology, duplicate, source_heading, source_text
- Code-level heading tier override after Call 2
- Filters duplicates, populates `AiJobCriteria.criteria` jsonb and `AiJobCriteria.metadata`
- Creates `AiApiRequest` after each call, linked to `AiJobCriteria` via polymorphic `requestable`
- Status transitions on `AiJobCriteria`: `pending` → `in_progress` → `succeeded` / `failed`
- Error handling: same pattern as `AiJobApplicationAction::Summary::Generate`

**`AiJobApplicationAction::Scoring::ScoreJobApplication`**
- Per-application service
- Writes `score_percentage` and `criteria_results` to `AiJobApplicationSummary`
- Reads criteria from `AiJobCriteria` for the job + resume text from the summary's `textract_result`
- If no `AiJobCriteria` exists: sets `AiJobApplicationSummary` status to `awaiting_job_criteria`, triggers criteria extraction for the job if not already in progress, returns. Re-triggered by `AiJobCriteria` `after_commit` callback when criteria succeed (same pattern as `TextractResult` triggering summary generation).
- Runs scoring call (Gemini flash) + display sentence call (Gemini flash)
- Delegates score computation to `Calculate` sub-module
- Creates `AiApiRequest` after each call, linked to `AiJobApplicationSummary`
- Status transitions on `AiJobApplicationSummary`: `scoring` → `integrating` (hands off to `IntegrateAnalysis`)
- Does NOT touch `structured_data`, `summary_text`, or `integrated_role_analysis`

**`AiJobApplicationAction::Scoring::Calculate`**
- Sub-module for weighted score computation
- Tier weights: tier_1=6, tier_2=4, tier_3=2
- Score values: full_match=1.0, partial_match=0.7, not_found=0
- Title technology multiplier: 3x if `contains_title_technology`
- Formula: sum(weight × value × multiplier) / max_possible × 100
- Called from `ScoreJobApplication`, separated so it can be used independently

**`AiJobApplicationAction::Scoring::IntegrateAnalysis`**
- Per-application service
- Writes `integrated_role_analysis` to `AiJobApplicationSummary`
- Input: `structured_data` (role_analysis, applicable_experience, gaps, overlap_summary, career_narrative, key_skills, standout_accomplishments) + `criteria_results` + `score_percentage`
- One AI call with new prompt (`app/services/ai_job_application_action/scoring/prompts/integrated_analysis.rb`)
- Produces scoring-aware role analysis — same kind of output as `role_analysis` but informed by scoring evidence
- Creates one `AiApiRequest` for cost tracking
- Status transitions on `AiJobApplicationSummary`: `integrating` → `succeeded` / `failed`
- Does NOT touch `score_percentage`, `criteria_results`, `structured_data`, or `summary_text`
- Prompt not yet written — needs development and testing

**Directory structure:**
- `app/services/ai_job_application_action/scoring/extract_criteria.rb`
- `app/services/ai_job_application_action/scoring/score_job_application.rb`
- `app/services/ai_job_application_action/scoring/calculate.rb`
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb`
- Prompt files at `app/services/ai_job_application_action/scoring/prompts/`

## 5. Frozen Prompt Files

Four existing scoring prompt files are frozen — implementation must not alter their prompt text, schema definitions, or model assignments:

- `job_description_structured_data.rb` (Call 1, gpt-4.1-mini)
- `job_description_criteria_extraction.rb` (Call 2, gpt-4o)
- `job_application_scoring.rb` (scoring call, gemini-flash-lite)
- `scoring_display.rb` (display sentence call, gemini-flash-lite)

These are v13, stability tested over three days of iteration. MODEL constants already pinned to API-returned versions on the branch. The only prompt file requiring development is `integrated_analysis.rb` (new).

## 6. Pipeline Orchestrator

**`AiJobApplicationAction::Orchestrate`**

Single entry point for the full evaluation pipeline. Coordinates sub-services in order and is resilient to failures.

**Pipeline sequence:**
1. `AiJobApplicationAction::Summary::Generate` — 4 summary calls (existing service)
2. Criteria check — verify `AiJobCriteria` exists for the job
3. `AiJobApplicationAction::Scoring::ScoreJobApplication` — scoring + display sentences
4. `AiJobApplicationAction::Scoring::IntegrateAnalysis` — integrated role analysis

**Resilience via status checkpointing:**
- On entry, checks current `AiJobApplicationSummary.status` and resumes from that point — never re-runs completed steps
- Each sub-service writes its output before the orchestrator advances status — work is never lost on retry
- If status is `awaiting_job_criteria` → checks if criteria now exist, proceeds to `scoring` or returns
- If status is `scoring` and `criteria_results` already populated → skips to `integrating`

**Criteria gap handling:**
- After summary succeeds, checks for `AiJobCriteria` with status `succeeded` for the job
- If present → advances to `scoring`
- If absent → sets status to `awaiting_job_criteria`, triggers `ExtractCriteria` for the job if not already in progress, returns
- `AiJobCriteria` `after_commit` callback (on transition to `succeeded`) finds all `AiJobApplicationSummary` records for that job with status `awaiting_job_criteria` and re-invokes the orchestrator for each to resume

**Four entry points, one orchestrator:**
- Auto trigger (Textract completion): `TextractResult after_commit :queue_ai_summary_job` → `GenerateAiJobApplicationSummaryJob` → `Orchestrate`
- Manual trigger (controller): `AiJobApplicationSummariesController#create` → interactors → `GenerateAiJobApplicationSummaryJob` → `Orchestrate`
- Bulk trigger: `BulkAiJobApplicationSummariesController#create` → `QueueBulkAiSummaryJobs` → `BulkGenerateAiSummariesJob` → `Orchestrate` (per iteration)
- Criteria-ready callback: `AiJobCriteria` `after_commit` → `GenerateAiJobApplicationSummaryJob` → `Orchestrate` (resume from `awaiting_job_criteria`)

**Replaces:** `TextractResult#generate_ai_summary` as the entry point. Instead of calling `Summary::Generate` directly, the job calls the orchestrator, which calls `Summary::Generate` as its first step.

## 7. Job Lifecycle Triggering

### On Publish

**`Job#extract_job_criteria`** — method on Job model. Called as one line from `handle_status_changed_to_published`. Internally:
- Checks `Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)` — returns if not enabled
- Finds existing `AiJobCriteria` by `job_id` — returns if status `pending`
- If not found — builds new `AiJobCriteria` with `job_id`
- Sets status to `pending`
- Saves — returns if save fails
- Enqueues `ExtractJobCriteriaJob.set(wait: 2.minutes).perform_later(ai_job_criteria.id)`

The 2-minute delay acts as a debounce. `pending` status gates prevent duplicate enqueues.

### On JD Update After Publish

**`Job#handle_description_change`** — method on Job model. Called as one line from `handle_before_update` (alongside existing `handle_status_change`, `UpdateDistributionsJob`, location update). Internally:
- Guards: `description_changed?` AND `published?` AND `description_meaningfully_changed?`
- If all pass: calls `extract_job_criteria`

**`Job#description_meaningfully_changed?`** — method on Job model.
- Strips HTML tags from `description_was` and `description`
- Removes all non-alphabetical characters
- Lowercases both
- Strict equality comparison — not identical means meaningfully changed

### ExtractJobCriteriaJob

- Queue: `:default`
- `perform(ai_job_criteria_id)`:
  - Loads `AiJobCriteria.find_by(id: ai_job_criteria_id)` — returns if not found
  - Gets job description via `ai_job_criteria.job.description` (reads latest description at execution time, not enqueue time — that's the point of the delay)
  - Passes to `AiJobApplicationAction::Scoring::ExtractCriteria`
- Retry: same pattern as `GenerateAiJobApplicationSummaryJob`
- No interactor — `Job#extract_job_criteria` handles find/build/save/enqueue

### AiJobCriteria after_commit Callback

On transition to `succeeded`:
- Finds all `AiJobApplicationSummary` records for this job with status `awaiting_job_criteria`
- Re-invokes the orchestrator for each to resume scoring

## 8. Credit Consumption, Flipper, Broadcasting

**Flipper flag:**
- Reuse `:AI_APPLICANT_SUMMARY` — no new flag. Scoring is part of the evaluation, not a separate feature.

**Credit consumption:**
- 1 credit for the entire evaluation (summary + scoring + integration) — not per step
- Credit consumed only after `AiJobApplicationSummary` status reaches `succeeded` (terminal state)
- If scoring or integration fails, no credit consumed — user doesn't pay for partial evaluation
- Credit consumption stays inside `TextractResult#generate_ai_summary_with_credit_flow` — the existing `status_succeeded?` check naturally gates it because `succeeded` now means full pipeline complete
- Same entry type pattern in `AiCreditBalanceTransaction` — entry type TBD (existing `ai_summary_usage_debit: 60` or new value in 70+ range)

**Broadcasting:**
- `AI_SUMMARY_COMPLETE` fires after `succeeded` (full evaluation complete — summary + scoring + integration), not after just the summary portion
- Same event name, fires later in the pipeline — broadcast already happens in the job after `generate_ai_summary_with_credit_flow` returns
- Payload and event name may need updating (TBD for plan)

**Helper methods and other implementation details** will emerge during implementation — not enumerated here.

## 9. Orchestrator Integration into `TextractResult#generate_ai_summary_with_credit_flow`

### Integration Point

The orchestrator replaces the single `generate_ai_summary` method call inside `TextractResult#generate_ai_summary_with_credit_flow`. Everything else in that method stays unchanged — credit consumption, notifications, status check.

`generate_ai_summary` currently calls `AiJobApplicationAction::Summary::Generate.new(textract_result_id: id).generate`. The orchestrator takes over this call and extends it with scoring + integration.

### Parameter: `textract_result_id` stays

`GenerateAiJobApplicationSummaryJob` continues to take `textract_result_id:` as its parameter. The `TextractResult` is the anchor of the flow — it owns the relationship to the summary, bridges textract completion to generation, and the credit flow runs through it. Changing this would break the entire mapping documented in `textract-ai-summary-map-6-6-2026.md`.

### Resume from `awaiting_job_criteria`

When `AiJobCriteria` `after_commit` fires on transition to `succeeded`:
1. Finds `AiJobApplicationSummary` records for this job with status `awaiting_job_criteria`
2. For each: gets `summary.textract_result_id`
3. Enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: summary.textract_result_id)`
4. Job calls `textract_result.generate_ai_summary_with_credit_flow`
5. Orchestrator checks summary status, sees `awaiting_job_criteria`, criteria now exist → resumes at `scoring`

### How the summary stays current

`textract_result_id` on the summary ties it to a specific resume version. When a resume is replaced, `SubmitResumeToTextract` marks existing summaries as `stale: true`. `CreateAiSummaryGeneration` also checks — if active summary's `textract_result_id` differs from latest textract result, marks it stale.

## 10. IntegratedAnalysis Prompt — Tone Calibration

**Overarching rules:**
- Never editorialize about the candidate's fitness. State gaps factually ("no evidence of X," "lacks experience in Y"). Do not add judgment ("would struggle with," "falls short of," "not suited for").
- Do not give recommendations, advice, or next steps. Report what the candidate has and does not have. Do not suggest training, onboarding, or how to address gaps.

**Score brackets — determine the ratio of strengths to gaps discussed, not the order:**
- **80-100% (Strong fit)**: Mostly strengths, gaps mentioned briefly
- **60-79% (Good fit)**: Majority strengths, gaps worth knowing included
- **40-59% (Mixed fit)**: Roughly equal coverage of strengths and gaps
- **20-39% (Weak fit)**: Majority gaps, but still open with what transfers
- **0-19% (Poor fit)**: Lead with any positives if they exist. If none exist, state the mismatch directly without fabricating strengths.

Always lead with positives (except poor fit where none may exist). Bracket determines ratio, not order.

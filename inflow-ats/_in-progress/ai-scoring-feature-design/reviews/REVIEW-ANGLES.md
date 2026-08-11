# Review Angles — AI Scoring Integration

Generated from: SPEC.md
Date: 2026-06-11

## Subsystems touched

**New files:**
- `app/models/ai_job_criteria.rb`
- `app/models/ai_job_application_summary_status.rb`
- `app/services/ai_job_application_action/scoring/extract_criteria.rb`
- `app/services/ai_job_application_action/scoring/score_job_application.rb`
- `app/services/ai_job_application_action/scoring/calculate.rb`
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb`
- `app/services/ai_job_application_action/orchestrate.rb`
- `app/services/ai_job_application_action/scoring/prompts/integrated_analysis.rb`
- `app/jobs/extract_job_criteria_job.rb`
- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb`
- Migration for `ai_job_criteria` table
- Migration for `ai_job_application_summary_statuses` table

**Modified files:**
- `app/models/ai_job_application_summary.rb` — status enum redesign, new columns, new associations
- `app/models/job.rb` — `extract_job_criteria`, `handle_description_change`, `description_meaningfully_changed?`
- `app/models/job_application.rb` — `has_one :ai_job_application_summary_status`
- `app/models/textract_result.rb` — `generate_ai_summary` replaced by orchestrator call
- `app/serializers/api/v1/ai_job_application_summary_serializer.rb` — new attributes
- `app/serializers/api/v1/shallow_job_application_serializer.rb` — eager load status record
- `app/jobs/generate_ai_job_application_summary_job.rb` — broadcast changes (status value shift)
- `app/jobs/bulk_generate_ai_summaries_job.rb` — calls orchestrator
- `app/interactors/create_ai_summary_generation.rb` — status value changes
- `app/interactors/validate_ai_summary_generation.rb` — status value changes
- `db/migrate/*_create_ai_job_application_summaries.rb` — rollback and edit in place
- `app/services/ai_job_application_action/scoring/prompts/job_description_structured_data.rb` — MODEL constant update
- `app/services/ai_job_application_action/scoring/prompts/job_description_criteria_extraction.rb` — MODEL constant update
- `app/services/ai_job_application_action/scoring/prompts/job_application_scoring.rb` — MODEL constant update

## Full-stack analog

The existing AI summary pipeline is the direct analog. Complete pipeline traced in `textract-ai-summary-map-6-6-2026.md`.

- **Trigger (auto):** `JobApplication after_commit` → `SubmitResumeToTextractJob` → `SubmitResumeToTextract` → `GetResumeTextFromTextractJob` → `TextractResult after_commit :queue_ai_summary_job`
- **Trigger (manual):** `AiJobApplicationSummariesController#create` → `ValidateAiSummaryGeneration` → `CreateAiSummaryGeneration` → `GenerateAiJobApplicationSummaryJob`
- **Trigger (bulk):** `BulkAiJobApplicationSummariesController#create` → `QueueBulkAiSummaryJobs` → `BulkGenerateAiSummariesJob`
- **Execution:** `GenerateAiJobApplicationSummaryJob` → `TextractResult#generate_ai_summary_with_credit_flow` → `AiJobApplicationAction::Summary::Generate#generate`
- **Post-pipeline:** `CreateAiCreditBalanceTransaction` → `NotifyZeroAiCredits` → `NotifyLowAiCredits`
- **Broadcast:** `GenerateAiJobApplicationSummaryJob#broadcast_completion` → `GlobalChannel` with `AI_SUMMARY_COMPLETE`
- **Auth:** `AiJobApplicationSummaryPolicy#create?` → `can_use_ai_credits?`
- **Serialization:** `Api::V1::AiJobApplicationSummarySerializer` (full), `Api::V1::AiJobApplicationSummaryShallowSerializer` (list)
- **Cost tracking:** `AiApiRequest` (polymorphic `requestable` on `AiJobApplicationSummary`)
- **Status model:** `AiJobApplicationSummary` with callback-based bridging from textract → summary generation

**Priority rule:** Where the full-stack analog deviates from convention, the analog wins. Note the deviation so the reviewer doesn't flag it.

## Angles

### pipeline-status-lifecycle

**What this covers:** The redesigned `status` enum on `AiJobApplicationSummary` spans 10 values across textract, summary, criteria wait, scoring, integration, and terminal states. Every transition must be reachable, every status must have a clear entry/exit path, and no state can be a dead end.

**Files across all layers:**
- `app/models/ai_job_application_summary.rb` — enum definition, every method that reads or writes `status`
- `app/services/ai_job_application_action/summary/generate.rb` — status transitions during summary
- `app/services/ai_job_application_action/orchestrate.rb` — status checkpointing and resume logic
- `app/services/ai_job_application_action/scoring/score_job_application.rb` — `scoring` → `integrating`
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb` — `integrating` → `succeeded`/`failed`
- `app/interactors/create_ai_summary_generation.rb` — initial status assignment
- `app/models/textract_result.rb` — `queue_ai_summary_job` references to status values
- `app/jobs/generate_ai_job_application_summary_job.rb` — `status_succeeded?` in broadcast

**Analog files for comparison:**
- Current `AiJobApplicationSummary` status enum (values 0-6 across the codebase)
- `textract-ai-summary-map-6-6-2026.md` Part 2 status transitions

**Convention context:** `cursor_rules/backend/architecture.md`, `cursor_rules/backend/_base.md`

### textract-scoring-bridge

**What this covers:** The most complex integration point. The orchestrator replaces a single method call inside `TextractResult#generate_ai_summary_with_credit_flow`. Every trigger path documented in `textract-ai-summary-map-6-6-2026.md` (Triggers A-E, Triggers 1-9) must continue to work with the extended pipeline. The `textract_result_id` parameter chain must remain intact. The callback-based resume from `awaiting_job_criteria` must not break existing callback-dependent paths (Triggers C, D, E).

**Files across all layers:**
- `app/models/textract_result.rb` — `generate_ai_summary_with_credit_flow`, `generate_ai_summary`, `queue_ai_summary_job`, `broadcast_ai_summary_failed`
- `app/services/ai_job_application_action/orchestrate.rb` — replaces `generate_ai_summary`
- `app/jobs/generate_ai_job_application_summary_job.rb` — `textract_result_id` parameter, error handling, broadcast
- `app/interactors/validate_ai_summary_generation.rb` — textract pending logic
- `app/interactors/create_ai_summary_generation.rb` — status assignment for textract paths
- `app/services/submit_resume_to_textract.rb` — stale marking, textract_result_id linking
- `app/jobs/get_resume_text_from_textract_job.rb` — retry exhaustion cleanup

**Analog files for comparison:**
- `textract-ai-summary-map-6-6-2026.md` — all trigger paths, bridge logic, cleanup flows, gaps

**Convention context:** `cursor_rules/backend/background_jobs.md`, `cursor_rules/backend/architecture.md`

### job-criteria-lifecycle

**What this covers:** `AiJobCriteria` creation via `Job#extract_job_criteria`, the debounce via `pending` status + 2-minute delay, `handle_description_change` guards, `description_meaningfully_changed?` comparison, `ExtractJobCriteriaJob` execution, and the `after_commit` callback that triggers resume for waiting applications. Race conditions: multiple applications waiting on the same criteria, description change during in-progress extraction, interaction between publish and update triggers.

**Files across all layers:**
- `app/models/ai_job_criteria.rb` — model, status enum, `after_commit` callback
- `app/models/job.rb` — `extract_job_criteria`, `handle_description_change`, `description_meaningfully_changed?`, `handle_status_changed_to_published`, `handle_before_update`
- `app/jobs/extract_job_criteria_job.rb` — job execution, retry
- `app/services/ai_job_application_action/scoring/extract_criteria.rb` — extraction service

**Analog files for comparison:**
- `app/models/textract_result.rb` — `queue_ai_summary_job` callback pattern (callback triggers downstream job)
- `app/services/submit_resume_to_textract.rb` — `GetResumeTextFromTextractJob.set(wait: 2.minutes)` delay pattern
- `Job#handle_status_change`, `Job#handle_visible_change` — callback method naming pattern

**Convention context:** `cursor_rules/backend/_base.md`, `cursor_rules/core_critical_rules.md`

### credit-consumption-timing

**What this covers:** Credit consumed only at `succeeded` (terminal state). The `status_succeeded?` check in `TextractResult#generate_ai_summary_with_credit_flow` must map correctly after the enum redesign. Every reference to `status_succeeded?`, `status: :succeeded`, `status_succeeded!`, and any other enum-generated method across the codebase must be identified and verified. If any reference is missed, credits could be consumed at the wrong point or never consumed at all.

**Files across all layers:**
- `app/models/textract_result.rb` — `generate_ai_summary_with_credit_flow` line 79: `return unless ai_job_application_summary&.status_succeeded?`
- `app/models/ai_job_application_summary.rb` — enum value change
- `app/interactors/create_ai_credit_balance_transaction.rb` — receives summary after `status_succeeded?` check
- `app/jobs/generate_ai_job_application_summary_job.rb` — `status_succeeded?` in `broadcast_completion` line 51
- Every other file referencing `status_succeeded?` or `status: :succeeded` or `status: 2` on `AiJobApplicationSummary`

**Analog files for comparison:** N/A (this is modifying the analog itself)

**Convention context:** `cursor_rules/core_critical_rules.md`

### concurrency-and-race-conditions

**What this covers:** Multiple `AiJobApplicationSummary` records for the same job may reach `awaiting_job_criteria` simultaneously. The `AiJobCriteria` `after_commit` callback fires once and must enqueue jobs for ALL waiting summaries. Double-enqueue prevention in `Job#extract_job_criteria`. Description changes during in-progress extraction. `BulkGenerateAiSummariesJob` processing multiple applications for the same job — all hit `awaiting_job_criteria` if criteria don't exist. The `regenerating` flag on `AiJobApplicationSummaryStatus` during concurrent generation.

**Files across all layers:**
- `app/models/ai_job_criteria.rb` — `after_commit` finding and enqueuing ALL waiting summaries
- `app/models/job.rb` — `extract_job_criteria` pending check
- `app/jobs/bulk_generate_ai_summaries_job.rb` — iteration over applications for same job
- `app/models/ai_job_application_summary_status.rb` — `regenerating` flag updates
- `app/services/ai_job_application_action/orchestrate.rb` — resume logic when multiple summaries resume simultaneously

**Analog files for comparison:**
- `app/interactors/queue_bulk_ai_summary_jobs.rb` — race-safe claiming via `BulkAiSummaryJobApplication` with partial unique index
- `app/models/textract_result.rb` — `queue_ai_summary_job` handles both waiting-summary and auto-generate paths

**Convention context:** `cursor_rules/backend/background_jobs.md`

### data-model-contracts

**What this covers:** `criteria_results` jsonb shape consistency between what `ScoreJobApplication` writes and what the serializer exposes. `AiJobApplicationSummaryStatus` read model kept in sync with the source `AiJobApplicationSummary`. New columns on `ai_job_application_summaries` nullable and defaulted correctly. `AiJobCriteria` `criteria` jsonb shape matches what `ExtractCriteria` writes and what `ScoreJobApplication` reads. `AiApiRequest` polymorphic attachment works for `AiJobCriteria` (new `requestable_type`).

**Files across all layers:**
- `app/models/ai_job_criteria.rb` — `criteria` and `metadata` jsonb shapes
- `app/models/ai_job_application_summary.rb` — `criteria_results` jsonb shape, new columns
- `app/models/ai_job_application_summary_status.rb` — read model contract
- `app/serializers/api/v1/ai_job_application_summary_serializer.rb` — exposes new columns
- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb` — new serializer
- `app/serializers/api/v1/shallow_job_application_serializer.rb` — eager loads status
- `app/models/ai_api_request.rb` — polymorphic `requestable` with new type

**Analog files for comparison:**
- `app/serializers/api/v1/ai_job_application_summary_shallow_serializer.rb` — existing shallow pattern
- `app/serializers/api/v1/job_application_serializer.rb` — how `has_one :ai_job_application_summary` is wired

**Convention context:** `cursor_rules/backend/serializer_rules.md`, `cursor_rules/backend/migration_guidelines.md`

### description-change-detection

**What this covers:** `Job#handle_description_change` fires from `handle_before_update` alongside `handle_status_change`. `description_meaningfully_changed?` strips HTML, removes non-alpha, lowercases, strict equality. Interaction with other callbacks in `handle_before_update`. The `before_update` vs `after_commit` timing — `extract_job_criteria` saves an `AiJobCriteria` record and enqueues a job inside a `before_update` callback, which runs inside a transaction. If the parent `Job` save fails after the callback, the `AiJobCriteria` save and job enqueue may have already fired.

**Files across all layers:**
- `app/models/job.rb` — `handle_before_update`, `handle_description_change`, `description_meaningfully_changed?`, `extract_job_criteria`
- `app/models/ai_job_criteria.rb` — record created inside `extract_job_criteria`

**Analog files for comparison:**
- `Job#handle_status_change` — same callback context
- `Job#handle_visible_change` — same callback pattern

**Convention context:** `cursor_rules/backend/_base.md`, `cursor_rules/core_critical_rules.md` (Rule #8 guard clauses, Rule #10 no bang methods, Rule #11 check return values)

## Always-on checks

### Source accuracy
The review agent verifies every file path, class, method, column, route, and component the spec references against the current source.

### Test coverage
The review agent checks what existing tests cover the affected code and what new tests the spec should require.

### Backward compatibility
The review agent identifies all consumers of modified code and verifies they are addressed. Critical: every reference to `status_succeeded?`, `status: :succeeded`, `status_failed?`, `status: :failed`, and any other enum-generated status methods on `AiJobApplicationSummary` across the entire codebase.

### Full-stack analog completeness
The review agent verifies the new feature has a corresponding piece for every layer of the analog pipeline (the AI summary pipeline documented in `textract-ai-summary-map-6-6-2026.md`). A missing layer is a BLOCKER.

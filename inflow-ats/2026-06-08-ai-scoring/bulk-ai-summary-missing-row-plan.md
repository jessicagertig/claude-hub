# Spec: Bulk AI summaries never generate — missing `AiJobApplicationSummary` row

**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Date:** 2026-06-18

## Background (current state)

`BulkGenerateAiSummariesJob#each_iteration` validates each applicant with `ValidateAiSummaryGeneration`, then calls `TextractResult#generate_ai_summary_with_credit_flow` (`app/jobs/bulk_generate_ai_summaries_job.rb:62`). In production this completes in ~138ms for two applicants and produces no summaries. The per-applicant logs show `[AiJobApplicationAction::Orchestrate] call entry` followed immediately by `[generate_ai_summary_with_credit_flow] pipeline done   nil  nil  nil`, with no `[AiJobApplicationAction::Orchestrate] status` line and no `CreateAiSummaryGeneration` log. No credit is consumed.

`AiJobApplicationAction::Orchestrate#call` is a state-machine advancer. It reads the latest `AiJobApplicationSummary` for the job application and returns early when none exists (`app/services/ai_job_application_action/orchestrate.rb:15-16`). It does not create the summary.

The single-send path creates the `AiJobApplicationSummary` before the generation job runs: `Api::V1::AiJobApplicationSummariesController#create` calls `CreateAiSummaryGeneration` (`app/controllers/api/v1/ai_job_application_summaries_controller.rb:17`), which builds the row and enqueues `GenerateAiJobApplicationSummaryJob`. `generate_ai_summary_with_credit_flow` itself creates only the status companion via `find_or_create_ai_job_application_summary_status` (`app/models/textract_result.rb:70`), never the `AiJobApplicationSummary`.

The bulk path never calls `CreateAiSummaryGeneration`, so no row exists when `Orchestrate` runs, and it bails.

A second gap exists on the same path: `with_textract_results` (`app/models/job_application.rb:106`) joins on the existence of a `textract_result` row, not on completed text. `ValidateAiSummaryGeneration` returns success even when textract is still processing or has failed once, setting `textract_pending` true (`app/interactors/validate_ai_summary_generation.rb:43-58`). `each_iteration` checks only `result.success?` (`:60`), so a textract-pending applicant currently falls through to the credit flow against absent resume text.

## Root cause

The bulk path omits the `AiJobApplicationSummary` creation step that the single-send path performs before generation, and it does not branch on `textract_pending`.

## Design decisions (approved)

1. Create a bulk-specific interactor rather than adding a flag to `CreateAiSummaryGeneration` or inlining the logic. This matches the existing bulk parallel stack (`QueueBulkAiSummaryJobs`, `BulkGenerateAiSummariesJob`, `BulkAiSummaryJobApplication`) and the codebase convention of small single-purpose interactors composed by direct `.call` (no `Interactor::Organizer` exists).
2. The new interactor handles the textract-ready path only and omits the single-send enqueue.
3. Textract-pending applicants are deferred: no `AiJobApplicationSummary` is created, and they are picked up on the next bulk run once their text is present. This matches the deferral `QueueBulkAiSummaryJobs` already relies on (`:26-30`). Accepted as MVP that deferred applicants are not auto-driven when textract later finishes.
4. Deferred applicants count as skipped, not failed. Add a `deferred` status to `BulkAiSummaryJobApplication` and fold deferred rows into the completion skipped total so the toast and email do not over-report failures.

## Changes

The implementer must read each analog and the surrounding bulk stack, confirm current line numbers and conventions, and follow the established patterns. Line numbers below are anchors at time of writing, not guarantees.

### 1. `BulkAiSummaryJobApplication` status enum — `app/models/bulk_ai_summary_job_application.rb`

Add a `deferred` value, mapped to integer `3`, to the `status` enum (currently `processing: 0, done: 1, failed: 2`, `_prefix: true`). No migration: `status` is already an integer column defaulting to `0`. Confirm the partial unique index `index_bulk_ai_sjas_on_job_app_processing` covers `status = 0` only, so `deferred` releases the claim, and that `update_remaining_statuses_to_failed` touches only `processing` rows.

### 2. New interactor `CreateBulkAiSummaryGeneration` — `app/interactors/create_bulk_ai_summary_generation.rb`

**Analog:** `CreateAiSummaryGeneration` (`app/interactors/create_ai_summary_generation.rb`). The implementer must read the analog in full and reproduce its structure, deviating only as pre-declared below. Everything not listed as a deviation must match the analog.

Pre-declared deviations from the analog:

- **D1 — separate interactor (an EXTRA file the analog does not have).** Forced by decision 1.
- **D2 — omit the `textract_pending` branch** (analog `:46-58`). Forced: textract-pending applicants are deferred in `each_iteration` and never reach this interactor, so the built row's `status` is always `pending`.
- **D3 — omit the `GenerateAiJobApplicationSummaryJob` enqueue** (analog `:70-74`). Forced: the bulk job drives generation inline via `generate_ai_summary_with_credit_flow`; enqueuing the single-send job per applicant would double-process and risk a second credit.
- **D4 — adjust the class name, file name, and `ap` log label** to the bulk variant; drop the analog's `textract_pending` and `ai_summary valid?` debug logs.

Must match the analog (do not reinvent): `include Interactor`; the context inputs `job_application`, `validation_result`, and `user`; the active-summary selection (latest summary that is neither `failed` nor `stale`); the stale reconciliation that compares the active summary's `textract_result_id` against `job_application.latest_textract_result` and marks `stale` when they differ; the reuse-and-return when an active summary exists; building on `job_application.ai_job_application_summaries` with `textract_result`, `status`, and `requested_by_organization_user_id` sourced from `user.current_organization_user`; `save` with `context.fail!` on failure; and exposing the record as `context.ai_summary`.

**Net verdict: this does not exactly match the analog** — one EXTRA file (D1) and two MISSING behaviors (D2, D3), each named and forced above.

### 3. `BulkGenerateAiSummariesJob#each_iteration` — `app/jobs/bulk_generate_ai_summaries_job.rb`

After the `result.success?` guard (`:60`), before the call to `generate_ai_summary_with_credit_flow` (`:62`):

- When `result.textract_pending` is true: mark `job_application_bulk_job_status` as `deferred` and return, creating no summary and not calling the credit flow.
- Otherwise: load the `User` from `payload['user_id']`, call `CreateBulkAiSummaryGeneration` with `job_application`, the validation `result`, and that user; then call `result.textract_result.generate_ai_summary_with_credit_flow` as today.

The existing `done` update (`:68`) is unchanged and runs only on the non-deferred path. The `summary_already_processed` short-circuit (`:48-56`) and its `done` update (`:54`) are unchanged.

### 4. `BulkGenerateAiSummariesJob#on_complete` and `notify_complete` — `app/jobs/bulk_generate_ai_summaries_job.rb`

In `on_complete` (`:88-92`), count the `deferred` rows among `bulk_job_statuses`, and subtract that count from `failed` (which is currently `job_application_ids.size - succeeded`). Pass the deferred count through to `notify_complete` so the reported skipped figure is `payload['skipped_count']` plus deferred, in both the `AI_SUMMARY_BULK_COMPLETE` broadcast `skippedCount` (`:111`) and the `BulkJobApplicationAiSummaryResultMailer.complete` skipped argument (`:121`). The `succeeded.zero? && failed.positive?` failure branch (`:94`) is unchanged.

## Test requirements

Tests are required (known failure pattern 3). Spec files:

- `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` (exists). The current `#each_iteration` example "runs the pipeline and flips the claim row to :done" (`:40`) passes despite the production bug; confirm it stubs `generate_ai_summary_with_credit_flow` and strengthen it to assert an `AiJobApplicationSummary` is created with status `pending`. Add an example for the textract-ready path (row created via `CreateBulkAiSummaryGeneration`, credit flow invoked, claim row `done`) and one for the textract-pending path (no `AiJobApplicationSummary` created, credit flow not called, claim row `deferred`). Add an `#on_complete` example asserting deferred rows are excluded from `failed` and added to the reported skipped count in both the broadcast and the mailer.
- `spec/interactors/create_bulk_ai_summary_generation_spec.rb` (new). Cover: the ready path builds a `pending` `AiJobApplicationSummary` with `requested_by_organization_user_id` set and enqueues no job; the reuse path returns the existing active non-stale summary and builds nothing; the stale path marks the prior summary `stale` and builds a fresh row. Account for eager companion-record creation (known failure pattern 19): factory helpers trigger `find_or_create_ai_job_application_summary_status`.

The `deferred` enum value is exercised through the job spec; no separate model spec is required (none exists today).

## Out of scope (MVP)

- Auto-driving a deferred applicant when its textract later finishes. No `textract_processing` summary row is created for it, so `queue_ai_summary_job` (`app/models/textract_result.rb:107`) will not pick it up; it waits for the next bulk run.
- A skipped/deferred concept in the `notify_failure` path when some applicants genuinely fail.

## Verification

From the source repo, outside the sandbox (`nvm use` for the commit hooks): run `rspec` on `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` and `spec/interactors/create_bulk_ai_summary_generation_spec.rb`. Manually trigger a bulk AI summary run for two applicants with ready textract and confirm `AiJobApplicationSummary` rows are created, the Orchestrate `status` line is logged (not `nil nil nil`), credits are consumed, and the completion counts are correct.

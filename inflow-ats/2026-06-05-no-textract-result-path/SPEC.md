# Spec — No TextractResult Path Fix

## Summary

When a user triggers AI summary generation on a job application that has a resume but no `TextractResult` record, `ValidateAiSummaryGeneration` fails with a dead-end 422: "The resume has not been processed." The system should instead submit the resume to Textract, create the `AiJobApplicationSummary` with `status: :textract_processing`, and tell the user the resume is being processed. When Textract completes, summary generation proceeds automatically via the existing `TextractResult#queue_ai_summary_job` callback.

Three gaps prevent this from working:

1. The newly created `AiJobApplicationSummary` has `textract_result_id: nil` because no `TextractResult` exists yet. When `SubmitResumeToTextract` creates the `TextractResult`, nobody updates `textract_result_id` on the waiting summary.
2. If Textract fails permanently (3 retries exhausted on `GetResumeTextFromTextractJob`), the `textract_processing` summary is orphaned — stuck forever, no user notification.
3. `AiJobApplicationSummary#destroy_previous_textract_results` calls `textract_result.created_at` without a nil guard, which raises `NoMethodError` if `textract_result_id` is nil.

## Prerequisites (already in place)

- `db/migrate/20260311120000_create_ai_job_application_summaries.rb` — `textract_result_id` column changed from `null: false` to nullable (in-place edit, already migrated)
- `AiJobApplicationSummary` — `belongs_to :textract_result, optional: true` (already applied)
- `ValidateAiSummaryGeneration` — when `@job_application.latest_textract_result` is nil, calls `SubmitResumeToTextractJob.perform_later(@job_application.id)`, sets `context.textract_pending = true`, and returns (already applied)

## Changes

### Change 1: Update textract_result_id on AiJobApplicationSummary in SubmitResumeToTextract

**File:** `app/services/submit_resume_to_textract.rb`

In `SubmitResumeToTextract#submit_resume`, inside the `if @textract_result.save` block at line 24: find the `AiJobApplicationSummary` on `@job_application` where `status: :textract_processing`, `stale: false`, and `textract_result_id` is nil, then call `update_columns(textract_result_id: @textract_result.id)` on it to update `textract_result_id` to the newly saved `@textract_result.id`.

**Why here:** `SubmitResumeToTextract#submit_resume` is where the `TextractResult` record is created (line 22: `@job_application.textract_results.build`). This is the earliest point where a `textract_result_id` value exists. The `AiJobApplicationSummary` was created moments earlier by `CreateAiSummaryGeneration` with `textract_result_id: nil` because no `TextractResult` existed yet.

**Ripple sites:** None. No other code creates `TextractResult` records that need to update waiting summaries — `SubmitResumeToTextract` is the sole creator.

### Change 2: Add retry exhaustion cleanup to GetResumeTextFromTextractJob

**File:** `app/jobs/get_resume_text_from_textract_job.rb`

Add an exhaustion block to the existing `retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3` declaration. When retries are exhausted: find the `AiJobApplicationSummary` on the job application where `status: :textract_processing` and `stale: false`, destroy it, and call `broadcast_ai_summary_failed` on the job application's latest `TextractResult` to notify the `requesting_organization_user_id` from the destroyed `AiJobApplicationSummary`. Leave the failed `TextractResult` record intact as an audit trail.

**Why:** Currently, when all 3 retry attempts fail, the job silently discards. The `textract_processing` summary is orphaned — the user sees "Resume is being processed. Summary will generate automatically" indefinitely. The `TextractResult` record has `textract_job_status: 'failed'` but nothing cleans up the summary or notifies the user.

**Notification method:** `TextractResult#broadcast_ai_summary_failed` (line 127 of `app/models/textract_result.rb`) broadcasts an `AI_SUMMARY_FAILED` event on the requesting user's `GlobalChannel`. It accepts `requesting_organization_user` and an optional `validation_error` string. The frontend `WebsocketGlobalChannelHandler` already handles `AI_SUMMARY_FAILED` and displays a toast.

**Ripple sites:** None. `GetResumeTextFromTextractJob` is only called from `SubmitResumeToTextract#submit_resume` (line 27) and indirectly from `ValidateAiSummaryGeneration` (line 54, which calls `SubmitResumeToTextractJob`).

### Change 3: Nil guard on AiJobApplicationSummary#destroy_previous_textract_results

**File:** `app/models/ai_job_application_summary.rb`

Add `return unless textract_result` to `AiJobApplicationSummary#destroy_previous_textract_results` (line 37), before the existing `return unless saved_change_to_status? && status_succeeded?` guard. Prevents `NoMethodError` on `textract_result.created_at` at line 41 when `textract_result_id` is nil.

**Why:** With `belongs_to :textract_result, optional: true`, calling `textract_result.created_at` when `textract_result_id` is nil raises `NoMethodError`. Change 1 should ensure `textract_result_id` is populated before the summary reaches `succeeded` status, but the guard is defensive — the association is optional and the callback should not crash on nil.

**Ripple sites:** None. `destroy_previous_textract_results` is a private callback on `AiJobApplicationSummary`, triggered by `after_commit :destroy_previous_textract_results, on: :update`.

## Test Requirements

### Change 1 test
Add a test to the `SubmitResumeToTextract` specs (or create one if none exists) verifying: when a `textract_processing` `AiJobApplicationSummary` with nil `textract_result_id` exists on the job application, `submit_resume` updates its `textract_result_id` to the newly created `TextractResult`'s id after save.

### Change 2 test
Add a test to `spec/jobs/get_resume_text_from_textract_job_spec.rb` (or create one if none exists) verifying: when `CustomErrorTextract` exhausts all 3 attempts, the `textract_processing` `AiJobApplicationSummary` is destroyed and `AI_SUMMARY_FAILED` is broadcast to the requesting user's `GlobalChannel`.

### Change 3 test
Add a test to `spec/models/ai_job_application_summary_spec.rb` (or create one if none exists) verifying: `destroy_previous_textract_results` does not raise when `textract_result_id` is nil and the summary transitions to `succeeded`.

## Files to Modify

| File | What changes |
|---|---|
| `app/services/submit_resume_to_textract.rb` | Add 2 lines after line 24: find waiting summary, update its `textract_result_id` |
| `app/jobs/get_resume_text_from_textract_job.rb` | Add exhaustion block to `retry_on`: find summary, destroy, broadcast failure |
| `app/models/ai_job_application_summary.rb` | Add `return unless textract_result` guard to `destroy_previous_textract_results` |

## Files NOT Modified

| File | Why |
|---|---|
| `app/interactors/validate_ai_summary_generation.rb` | Already edited — kicks off `SubmitResumeToTextractJob` when no `TextractResult` exists |
| `app/interactors/create_ai_summary_generation.rb` | Already handles nil `textract_result` via nullable column + `optional: true` |
| `app/services/ai_job_application_action/summary/generate.rb` | No change needed — `textract_result_id` is updated by Change 1 before `Generate` runs |
| `app/models/textract_result.rb` | No change — `queue_ai_summary_job` already finds `textract_processing` summaries and triggers generation |
| `db/migrate/20260311120000_create_ai_job_application_summaries.rb` | Already edited — `textract_result_id` nullable |

## Risks

1. **Race condition on Change 1:** If two `SubmitResumeToTextractJob` runs overlap for the same job application, both could find the same `textract_processing` summary. Mitigated by: `SubmitResumeToTextractJob` is enqueued once per user action, and `update_columns` on an already-updated row is a no-op (sets the same value). Low risk.

2. **Change 2 notification when no requesting user exists:** Auto-generated summaries have nil `requested_by_organization_user_id`. `broadcast_ai_summary_failed` already guards on `return unless requesting_organization_user` (line 128 of `textract_result.rb`). The summary is still destroyed; no notification is sent. Acceptable — auto-generated summaries failing silently is existing behavior.

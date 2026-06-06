# Angle 5: Bulk Job Completion Notifications — Round 6

## Review

### `BulkGenerateAiSummariesJob` declaration order

`discard_on StandardError` (line 12) declared BEFORE `retry_on CustomErrorAiSummary` (line 17). ActiveJob processes rescue handlers in reverse declaration order, so `retry_on` is checked first. Correct per Note #25.

### `notify_complete` / `notify_failure`

Both are `private_class_method` -- consistent with existing `update_remaining_statuses_to_failed` pattern.

**`notify_complete` (lines 104-125):**
- Broadcasts `AI_SUMMARY_BULK_COMPLETE` via `GlobalChannel.broadcast_to`.
- Calls `BulkJobApplicationAiSummaryResultMailer.complete(...).deliver_later`. Correct per failure pattern #4.

**`notify_failure` (lines 127-152):**
- Guards with `return unless payload` and `return unless user`.
- Computes `total_queued_count = job_application_ids.size + skipped_count`. Correct per spec.
- Broadcasts `AI_SUMMARY_BULK_FAILED`.
- Calls `BulkJobApplicationAiSummaryResultMailer.failed(...).deliver_later`. Correct per failure pattern #4.

### `on_complete` branching (lines 77-102)

- If `succeeded == 0 && failed > 0`: calls `notify_failure`. Correct.
- Otherwise: calls `notify_complete`. Correct.
- Uses `self.class.send(:notify_failure, payload)` / `self.class.send(:notify_complete, ...)` to call private class methods from instance context.

### `discard_on` / `retry_on` exhaustion blocks

Both call `update_remaining_statuses_to_failed(payload)` followed by `notify_failure(payload)`. Payload accessed via `current_job.arguments.first`. Correct.

### `BulkJobApplicationAiSummaryResultMailer`

**`complete` method (lines 4-29):**
- Args by ID: `user_id, job_id, succeeded_count, failed_count, skipped_count, hiring_stage_id`. Correct.
- Looks up User and Job inside method. Correct.
- Uses `Emails::SendTemplateEmail`. Correct.
- `from: EMAIL_NOTIFICATIONS_ADDRESS`. Correct (matches analog `JobResumeExportMailer`).
- Template `'user-bulk-ai-summary-complete'`. Subject `"Your AI summaries for #{job.title} are ready"`. Correct.
- Variables include `user_first_name, job_title, succeeded_count, failed_count, skipped_count, hiring_stage_link`. Correct.
- `hiring_stage_link` built correctly: `"#{Variables::AtsRootUrl}/jobs/#{job.id}/stages/#{hiring_stage_id}/applicants"`. Correct.

**`failed` method (lines 31-51):**
- Args by ID: `user_id, job_id, total_queued_count`. Correct.
- Template `'user-bulk-ai-summary-failed'`. Subject `"We couldn't generate AI summaries for #{job.title}"`. Correct.
- Variables include `user_first_name, job_title, total_queued_count`. Correct.

### WebSocket types

`AiSummaryBulkFailedPayload` with `jobTitle: string`, `message: string`. Correct.

### WebSocket handler

`AI_SUMMARY_BULK_FAILED` case: casts as `AiSummaryBulkFailedPayload`, toast with `payload.message`, `kind: "warning"`, `delay: 20000`. Invalidates `jobApplicationsForStage`, `jobApplication`, `organizationAiCreditBalance`. Correct.

## Findings

### MED F1 -- `self.class.send(:notify_failure, payload)` bypasses access control

**File:** `app/jobs/bulk_generate_ai_summaries_job.rb:95-97`

`on_complete` uses `self.class.send(:notify_failure, payload)` and `self.class.send(:notify_complete, ...)` to call private class methods from an instance method. While functional, `send` bypasses Ruby's access control and is generally discouraged. The `discard_on` and `retry_on` blocks are already at class level so they call these directly without `send`. One alternative would be to make `notify_complete`/`notify_failure` public class methods (they don't expose any security surface), but this is a style preference, not a correctness issue.

## Verdict: PASS (0 HIGH, 1 MED)

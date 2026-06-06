# Approved Decisions — No TextractResult Path Fix

## Decision 1: Update textract_result_id on AiJobApplicationSummary in SubmitResumeToTextract

In `SubmitResumeToTextract#submit_resume` (`app/services/submit_resume_to_textract.rb`), inside the `if @textract_result.save` block at line 24: find the `AiJobApplicationSummary` on `@job_application` where `status: :textract_processing`, `stale: false`, and `textract_result_id` is nil, then call `update_columns(textract_result_id: @textract_result.id)` on it to update `textract_result_id` to the newly saved `@textract_result.id`.

## Decision 2: Add retry exhaustion cleanup to GetResumeTextFromTextractJob

On `GetResumeTextFromTextractJob` (`app/jobs/get_resume_text_from_textract_job.rb`), add an exhaustion block to the existing `retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3` declaration. When retries are exhausted: find the `AiJobApplicationSummary` on the job application where `status: :textract_processing` and `stale: false`, destroy it, and call `broadcast_ai_summary_failed` on the job application's latest `TextractResult` to notify the `requesting_organization_user_id` from the destroyed `AiJobApplicationSummary`. Leave the failed `TextractResult` record intact as an audit trail.

## Decision 3: Nil guard on AiJobApplicationSummary#destroy_previous_textract_results

Add `return unless textract_result` to `AiJobApplicationSummary#destroy_previous_textract_results` (`app/models/ai_job_application_summary.rb` line 37), before the existing `return unless saved_change_to_status? && status_succeeded?` guard. Prevents `NoMethodError` on `textract_result.created_at` at line 41 when `textract_result_id` is nil.

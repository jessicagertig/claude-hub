# textract-call-site -- Round 2

## Verified

- Call site: `after_commit :queue_structured_extraction_job, on: [:create, :update]` on TextractResult (line 11) -- fires after the same commit as `queue_ai_summary_job`
- Callback only enqueues: `ExtractStructuredResumeDataJob.perform_later(id)` -- does not call AI inline
- Guards: `textract_job_result_text.present?` and `saved_change_to_textract_job_result_text?` -- same guards as existing `queue_ai_summary_job`
- Failure isolation: the callback runs inside `after_commit` (transaction already committed). Job enqueue failure does not roll back the Textract update. The extraction job runs independently of `GenerateAiJobApplicationSummaryJob`
- No interference: `queue_ai_summary_job` is unchanged at line 10. Both callbacks are registered independently. The new callback does NOT share the organization/validation/feature-gate guards of the existing callback -- extraction is unconditional
- Ordering: extraction callback fires AFTER `textract_job_result_text` is persisted (it's `after_commit`, not `before_commit`)

## Findings

No issues found.

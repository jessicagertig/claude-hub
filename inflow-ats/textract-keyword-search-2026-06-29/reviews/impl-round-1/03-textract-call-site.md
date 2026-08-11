# textract-call-site -- Round 1

## Findings

No issues found.

## Verified

- **Integration point**: New `after_commit :queue_structured_extraction_job, on: [:create, :update]` at textract_result.rb:11. Placed immediately after the existing `after_commit :queue_ai_summary_job, on: [:create, :update]` at line 10. Both are `after_commit` callbacks on the same events.

- **Callback guards**: `queue_structured_extraction_job` (lines 184-188) uses the same two guards as `queue_ai_summary_job` (lines 152-154):
  1. `return unless textract_job_result_text.present?`
  2. `return unless saved_change_to_textract_job_result_text?`

- **Correct simplification**: The new callback does NOT have the organization/validation/feature-gate checks that `queue_ai_summary_job` has (lines 156-181). This is correct per spec: extraction is unconditional (serves search, not AI credit gating). The organization check happens inside the service, not the callback.

- **Failure isolation**: The callback only calls `ExtractStructuredResumeDataJob.perform_later(id)` -- it enqueues a background job, never calls AI inline. If job enqueuing fails (unlikely but possible), it would raise inside the callback, but this is the same risk pattern as the existing `queue_ai_summary_job` which also calls `perform_later`. The two callbacks are independent `after_commit` hooks; failure of one does not prevent the other from running.

- **Ordering**: Both callbacks fire after the same commit that writes `textract_job_result_text`. The extraction service reads `textract_job_result_text` as input, which is already persisted by the time the `after_commit` fires.

- **No modification to GetResumeTextFromTextract**: The service at `app/services/get_resume_text_from_textract.rb` is unchanged. The extraction is triggered via the model callback, not by modifying the Textract service. This is the correct integration point per spec.

- **Both callbacks fire independently**: Verified in the model -- two separate `after_commit` declarations. Rails runs all `after_commit` callbacks for the matching event. If `queue_ai_summary_job` fails (unlikely since it only enqueues), `queue_structured_extraction_job` still runs, and vice versa.

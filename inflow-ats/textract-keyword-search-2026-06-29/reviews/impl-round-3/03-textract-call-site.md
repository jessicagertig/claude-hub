# Textract Call Site

## Verdict: PASS

### Findings

None.

### Verification

- Integration is via `after_commit :queue_structured_extraction_job, on: [:create, :update]` on TextractResult — fires when the commit that set `textract_job_result_text` completes
- Same guards as existing `queue_ai_summary_job` callback: `textract_job_result_text.present?` and `saved_change_to_textract_job_result_text?`
- Callback ordering in the model: `queue_ai_summary_job` is declared first (line 10), `queue_structured_extraction_job` second (line 11). Rails executes `after_commit` callbacks in declaration order, so the existing callback runs first. If the new callback raises, the existing one has already completed successfully. Spec requirement satisfied: "The existing `queue_ai_summary_job` callback MUST still fire normally."
- The service's `update` call writes `structured_extraction` and `structured_extraction_text`, NOT `textract_job_result_text`. Neither callback re-fires on this update because `saved_change_to_textract_job_result_text?` returns false.
- Failure isolation: the new callback only calls `ExtractStructuredResumeDataJob.perform_later(id)` — enqueues a Sidekiq job, no inline AI calls in the callback chain. The extraction job runs independently with its own `retry_on`/exhaustion.
- `get_resume_text_from_textract.rb` is NOT modified on this branch — verified via `git diff develop -- app/services/get_resume_text_from_textract.rb` (empty). Integration is purely via model callbacks, not by modifying the Textract service.
- The new callback is unconditional (no organization/feature-gate checks) per the spec: "extraction is unconditional (it serves search, not AI credit gating)."

# Pass 1 — textract-call-site

## Fact Check

### Integration approach (plan step 6.5)
- Plan: new `after_commit :queue_structured_extraction_job, on: [:create, :update]` on TextractResult
- Source: existing callback at line 7: `after_commit :queue_ai_summary_job, on: [:create, :update]`
- Plan adds new callback alongside existing one (same line area)
- **VERIFIED** -- matches existing callback mechanism

### Guard conditions (plan step 6.5)
- Plan: `textract_job_result_text.present?` and `saved_change_to_textract_job_result_text?`
- Source: existing `queue_ai_summary_job` uses identical guards (textract_result.rb lines 115-116)
- The existing callback has ADDITIONAL guards (organization, ai_summary_waiting_on_textract, should_auto_generate_ai_summaries?). The new callback intentionally omits these -- extraction is unconditional (serves search, not AI credit gating). Spec explicitly documents this design decision.
- **VERIFIED**

### Callback enqueues job only (plan step 6.5)
- `ExtractStructuredResumeDataJob.perform_later(id)` -- enqueues a Sidekiq job, no inline AI call
- Matches existing pattern: `queue_ai_summary_job` enqueues `GenerateAiJobApplicationSummaryJob.perform_later`
- **VERIFIED** -- GPT-4o-mini call happens in the job, not in the callback

### Failure isolation
- The callback only calls `perform_later` -- if enqueuing fails, it raises but does not affect the already-committed TextractResult update
- The extraction job runs independently -- if it fails and exhausts retries, it logs and moves on
- The existing `queue_ai_summary_job` callback is unchanged and fires independently
- **VERIFIED**

### No infinite loop on service update
- When the extraction service updates `structured_extraction` and `structured_extraction_text`, the new callback fires
- But `saved_change_to_textract_job_result_text?` is FALSE (service changes `structured_extraction_text`, not `textract_job_result_text`)
- Callback returns early at the guard clause
- Same logic for the existing `queue_ai_summary_job` callback -- also returns early
- **VERIFIED** -- no re-triggering

### Both callbacks fire independently
- Rails `after_commit` callbacks fire in declaration order after the transaction commits
- Failure in one callback does not prevent the other from firing (each is a separate callback invocation)
- Plan places new callback immediately after existing one (line 7 area)
- **VERIFIED**

### Ordering: extraction runs after text is persisted
- `after_commit` fires AFTER the transaction commits -- `textract_job_result_text` is already persisted to the database
- The enqueued job reads the committed text from the database
- **VERIFIED** -- correct ordering

### parse_resume_text line references
- Spec says "lines 24-37" -- this refers to the success case within the method (line 24: `if textract_job.job_status.downcase == 'succeeded'`, line 37: end of success handler's else branch)
- Full method spans lines 8-49
- Plan does NOT modify `parse_resume_text` -- it uses an `after_commit` callback instead
- **No impact on plan correctness**

## Completeness

| Spec requirement | Plan step | Status |
|-----------------|-----------|--------|
| after_commit callback on TextractResult | 6.5 | Present |
| Same guards as existing callback | 6.5 | Present |
| Callback enqueues job (not inline AI) | 6.5 | Present |
| Failure isolation from Textract success path | 5.1, 6.5 | Present |
| No interference with queue_ai_summary_job | 6.5 | Present |
| Extraction after text is persisted | inherent (after_commit) | Present |

## Findings

0 BLOCKER, 0 HIGH, 0 MED, 0 LOW

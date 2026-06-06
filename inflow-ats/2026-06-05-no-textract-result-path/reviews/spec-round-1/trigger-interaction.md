# trigger-interaction — Round 1

## Findings

- F1 [MED] SubmitResumeToTextract does NOT destroy previous TextractResults at lines 17-20 as REVIEW-ANGLES.md claims. Lines 18-20 mark existing `ai_job_application_summaries` as `stale: true`. The review angles contain a factual error about this behavior. However, since the review angles are user-approved and the spec itself does not repeat this claim, this is informational only — no spec amendment needed.

- F2 [INFO] Change 1 fires for ALL `SubmitResumeToTextract#submit_resume` calls, not just the "no TextractResult" path. Verified callers:
  - Trigger 1: `job_application.rb:154` (`enqueue_new_job_application`) — no `textract_processing` summary exists at this point (summary creation happens later via user action or auto-generation). Change 1 query returns nil. No-op. Safe.
  - Trigger 2: `job_applications_controller.rb:110` (manual resume upload) — no `textract_processing` summary exists from a resume upload alone. No-op. Safe.
  - Trigger 3: `validate_ai_summary_generation.rb:38` (no TextractResult path) — this IS the target path. A `textract_processing` summary was just created by `CreateAiSummaryGeneration`. Change 1 updates it. Correct.
  - Trigger 4: `validate_ai_summary_generation.rb:54` (failed TextractResult retry) — a `textract_processing` summary may exist from a prior attempt. Change 1 updates it. Correct.
  - Trigger 5: `queue_bulk_ai_summary_jobs.rb:29` (bulk backfill) — no `textract_processing` summary created by bulk path (bulk only creates summaries for ready candidates). No-op. Safe.

No issues found with Change 1's interaction with other triggers.

## Amendments Applied

None.

# credit-consumption-timing — Implementation Review Round 2

## Files reviewed

- `app/models/textract_result.rb` — `generate_ai_summary_with_credit_flow` line 75: `return unless ai_job_application_summary&.status_succeeded?`
- `app/models/ai_job_application_summary.rb` — enum: `succeeded: 7`
- `app/jobs/generate_ai_job_application_summary_job.rb` — `status_succeeded?` in broadcast (line 61)
- `app/jobs/bulk_generate_ai_summaries_job.rb` — `status: :succeeded` in on_complete count (line 89)
- All files referencing `status_succeeded?` or `status: :succeeded` (grep across app/)

## Findings

No findings.

1. **Credit consumption gated by `status_succeeded?`:** `TextractResult#generate_ai_summary_with_credit_flow` line 75. `succeeded` now means full pipeline complete (summary + scoring + integration). Credit consumed only after everything succeeds. Matches spec Section 8.
2. **No credit consumed if scoring/integration fails:** If `ScoreJobApplication` or `IntegrateAnalysis` sets `failed`, the status never reaches `succeeded`. The `return unless status_succeeded?` guard at line 75 prevents credit consumption. Correct.
3. **Broadcast timing correct:** `GenerateAiJobApplicationSummaryJob#broadcast_completion` line 61 uses `status_succeeded?` to determine broadcast status. This fires after `generate_ai_summary_with_credit_flow` returns, which is after the full pipeline. Broadcast reflects full evaluation status. Correct.
4. **Bulk job completion count correct:** `BulkGenerateAiSummariesJob#on_complete` line 89 counts `status: :succeeded`. This correctly counts only fully-completed evaluations, not partial ones. Correct.
5. **Entry type unchanged:** `ai_summary_usage_debit: 60` in `AiCreditBalanceTransaction`. No changes to this. Matches spec Section 8.
6. **Resume from `awaiting_job_criteria` does NOT double-consume:** The criteria-ready callback re-enqueues `GenerateAiJobApplicationSummaryJob`, which calls `generate_ai_summary_with_credit_flow`. The orchestrator resumes from `awaiting_job_criteria`, runs scoring and integration. Only when `succeeded` is reached does the credit check fire. Since the first run returned before `succeeded`, no credit was consumed. The resume run is the first and only credit consumption. Correct.

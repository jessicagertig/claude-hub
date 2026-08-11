# operational-concerns — Implementation Review Round 2

## Files reviewed

- All background jobs
- All services with AI calls
- Model callbacks

## Findings

No findings.

1. **Retry/exhaustion pattern consistent:** `GenerateAiJobApplicationSummaryJob` and `ExtractJobCriteriaJob` both use `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3` with exhaustion blocks. Matches analog pattern (`GetResumeTextFromTextractJob`). Known Failure Pattern #14 satisfied.
2. **`BulkGenerateAiSummariesJob`:** Uses `discard_on StandardError` and `retry_on CustomErrorAiSummary` with failure notification. Job-iteration max runtime 10 minutes. Existing pattern, unchanged.
3. **No N+1 queries in serialization:** `job_applications_controller.rb` eager-loads `:ai_job_application_summary_status` at lines 25 and 35. Correct.
4. **2-minute delay on criteria extraction:** Provides debounce for rapid description edits. Job reads latest description at execution time. Acceptable trade-off between latency and redundant AI calls.
5. **Callback ordering:** `AiJobApplicationSummary` callbacks: `create_status_record` (on create), `destroy_previous_textract_results` (on update), `update_summary_status_record` (on update). All `after_commit` — fire outside the transaction. No ordering conflicts.
6. **Error propagation:** `CustomErrorAiSummary` propagates from services through the orchestrator to the job, which has `retry_on`. `JSON::ParserError` and `StandardError` are swallowed by services (set `failed`, no re-raise). This prevents non-retryable errors from triggering useless retries. Correct.
7. **No silent data loss:** All error paths log (`ap` + `Rails.logger.error`) and set `error_message` on the record. Debugging is possible.

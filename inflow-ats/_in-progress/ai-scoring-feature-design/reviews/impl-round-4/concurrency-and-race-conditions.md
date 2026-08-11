# concurrency-and-race-conditions -- Round 4

## Scope

Multiple summaries waiting on the same criteria, double-enqueue prevention, description change during in-progress extraction, bulk processing race conditions, `regenerating` flag.

## Findings

### Multiple applications waiting on same criteria

`AiJobCriteria#resume_waiting_summaries` uses `find_each` to iterate ALL `awaiting_job_criteria` summaries for the job and enqueue a job for each. Handles the bulk scenario where 50 applications all reach `awaiting_job_criteria` before criteria complete. Correct.

### Double-enqueue prevention in extract_job_criteria

`return if existing_ai_job_criteria&.status_pending?` prevents multiple extraction jobs. If the user edits 5 times in 2 minutes, only the first creates a `pending` record and enqueues a job. Edits 2-5 see `pending` and return. The 2-minute delay ensures the job reads the latest description. Correct per spec.

### Description change during in-progress extraction

`in_progress` does NOT trigger early return. Instead, the existing criteria is reset to `pending` and a new job is enqueued with a 2-minute delay. If the old extraction finishes before the new job runs, its `succeeded` callback fires and resumes waiting summaries with potentially stale criteria. However, the 2-minute delay mitigates this -- the new extraction will re-extract with the latest description when it runs, overwriting the old criteria. The next scoring cycle will use the updated criteria. This matches spec Section 7's design.

### Bulk processing (same job)

`BulkGenerateAiSummariesJob` iterates applications sequentially (job-iteration). Multiple applications for the same job may all reach `awaiting_job_criteria`. The `AiJobCriteria.after_commit` callback enqueues a job for each when criteria succeed. The `extract_job_criteria` debounce prevents multiple extraction jobs. Correct per spec.

### Unique index enforcement

`ai_job_criteria` has `unique: true` on `job_id` -- prevents duplicate criteria records for the same job. `ai_job_application_summary_statuses` has `unique: true` on `job_application_id` -- prevents duplicate status records. Database-level enforcement is correct.

### Regenerating flag

`AiJobApplicationSummaryStatus#regenerating` defaults to `false`. Set during status record creation via `find_or_create_by`. Updated to `false` when a summary reaches `succeeded` (via `update_summary_status_record` callback). The spec notes regeneration support is "a future concern" -- the current implementation correctly tracks existence and latest success.

## Result: PASS -- 0 findings

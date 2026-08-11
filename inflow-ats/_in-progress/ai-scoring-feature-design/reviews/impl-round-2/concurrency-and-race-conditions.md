# concurrency-and-race-conditions — Implementation Review Round 2

## Files reviewed

- `app/models/ai_job_criteria.rb` — `resume_waiting_summaries` callback
- `app/models/job.rb` — `extract_job_criteria` pending check
- `app/jobs/bulk_generate_ai_summaries_job.rb` — iteration for same-job applications
- `app/models/ai_job_application_summary_status.rb` — `regenerating` flag
- `app/services/ai_job_application_action/orchestrate.rb` — resume logic

## Findings

No findings.

1. **Multiple summaries waiting on same criteria:** `AiJobCriteria#resume_waiting_summaries` uses `find_each` to iterate all `awaiting_job_criteria` summaries for the job. Each gets its own `GenerateAiJobApplicationSummaryJob` enqueue. No summaries are missed.
2. **`extract_job_criteria` debounce:** `pending` status check prevents double-enqueue. If two description edits fire simultaneously, the first sets `pending` + enqueues, the second sees `pending` and returns early.
3. **Bulk job same-job applications:** `BulkGenerateAiSummariesJob` processes applications sequentially (job-iteration). If all hit `awaiting_job_criteria` because criteria don't exist, the first will trigger `extract_job_criteria`, the rest will also trigger it but the debounce (`status_pending?` check) prevents re-enqueue. When criteria succeed, the `after_commit` callback enqueues jobs for ALL waiting summaries.
4. **`AiJobApplicationSummaryStatus` uniqueness:** Database-level unique index on `job_application_id`. `find_or_create_by` in `create_status_record` handles race conditions.
5. **Description change during in-progress extraction:** `extract_job_criteria` resets `in_progress` to `pending` and enqueues a new job. The old extraction may still be running, but when it finishes, it writes to the same `AiJobCriteria` record. The new job fires 2 minutes later and re-extracts with the latest description. Acceptable.

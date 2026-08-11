# concurrency-and-race-conditions -- Round 3

## Files reviewed

- `app/models/ai_job_criteria.rb` -- `resume_waiting_summaries` callback
- `app/models/job.rb` -- `extract_job_criteria` pending debounce
- `app/services/ai_job_application_action/orchestrate.rb` -- resume logic
- `app/models/ai_job_application_summary_status.rb` -- `regenerating` flag

## Assessment

1. **Multiple applications waiting on same criteria:** `AiJobCriteria#resume_waiting_summaries` uses `find_each` over `where(status: :awaiting_job_criteria)`, enqueuing one job per waiting summary. Correct.

2. **Debounce in `extract_job_criteria`:** Pending status check returns early, preventing duplicate extraction jobs. 2-minute delay ensures latest description is used. Correct.

3. **Description change during in-progress extraction:** `extract_job_criteria` resets `in_progress` to `pending` (does NOT return early for `in_progress`). The pending record + 2-minute delay ensures re-extraction with latest description. Correct per spec Section 7.

4. **Bulk processing same job:** `BulkGenerateAiSummariesJob` iterates applications. All may reach `awaiting_job_criteria`. `extract_job_criteria` debounce prevents multiple extraction jobs. `after_commit` callback resumes all. Correct.

5. **`regenerating` flag:** Updated via `update_summary_status_record` callback (sets `false` on `succeeded`). Creation defaults to `false`. Status record created via `after_commit :create_status_record, on: :create`. Correct.

## Findings

No findings.

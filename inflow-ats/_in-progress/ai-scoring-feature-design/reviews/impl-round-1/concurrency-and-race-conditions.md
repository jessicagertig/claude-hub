# Concurrency and Race Conditions -- Round 1

## Findings

No issues found.

`AiJobCriteria#resume_waiting_summaries` uses `find_each` to handle multiple waiting summaries. `extract_job_criteria` pending-status debounce prevents multiple extraction jobs for the same job. `BulkGenerateAiSummariesJob` iteration: each application independently reaches `awaiting_job_criteria` if criteria don't exist; the first one triggers extraction via `extract_job_criteria`, subsequent ones see `pending` status and return early. The `after_commit` callback fires once when criteria succeed and enqueues jobs for ALL waiting summaries.

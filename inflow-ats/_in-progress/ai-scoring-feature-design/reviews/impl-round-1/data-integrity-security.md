# Data Integrity & Security -- Round 1

## Findings

No issues found.

- Authorization: `BulkAiJobApplicationSummariesController#create` still calls `authorize :ai_job_application_summary, :bulk_create?` -- unchanged.
- `@job = current_organization.jobs.find(...)` correctly scopes to `current_organization` -- prevents cross-org job access.
- `stage = @job.hiring_stages.find(p[:hiring_stage_id])` correctly scopes to `@job` -- prevents cross-job stage access.
- `AiJobCriteria` unique index on `job_id` prevents duplicate criteria records per job.
- `AiJobApplicationSummaryStatus` unique index on `job_application_id` prevents duplicate status records.
- All `update_columns` calls bypass callbacks intentionally (documented in each case).
- `ExtractCriteria` uses `update` (not `update_columns`) for `succeeded` to fire `after_commit` callback -- correct per spec.
- No injection risks: AI prompt inputs are assembled as string concatenation, not interpolated into SQL or shell commands.

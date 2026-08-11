# concurrency-and-race-conditions -- Round 5

## Scope
Multiple summaries reaching `awaiting_job_criteria` simultaneously, `after_commit` callback firing for ALL waiting summaries, double-enqueue prevention, description change during in-progress extraction, bulk processing race.

## Files reviewed
- `app/models/ai_job_criteria.rb` (full file)
- `app/models/job.rb` `extract_job_criteria` method
- `app/services/ai_job_application_action/orchestrate.rb` (full file)
- `app/models/ai_job_application_summary_status.rb` (full file)

## Multiple waiting summaries

`AiJobCriteria#resume_waiting_summaries` uses `find_each` to iterate over ALL `AiJobApplicationSummary` records with `status: :awaiting_job_criteria` for the job. Each gets a separate `GenerateAiJobApplicationSummaryJob` enqueued. Correct for the bulk scenario where N applications hit `awaiting_job_criteria` before criteria extraction completes.

## Double-enqueue prevention

`extract_job_criteria` checks `return if existing_ai_job_criteria&.status_pending?`. The 2-minute delay + pending status is the debounce. Multiple edits within 2 minutes: first edit creates `pending` record and enqueues job. Edits 2-N see `pending`, return immediately. Job runs after 2 minutes, reads latest description.

## Description change during in-progress extraction

`in_progress` does NOT trigger early return -- resets to `pending` via `update_columns` and enqueues a new job. The in-progress extraction may complete and set `succeeded`, but the new pending job will re-extract with the latest description when it runs. The `after_commit` on the old `succeeded` transition will resume any waiting summaries, and the new extraction (when it completes) will trigger another `after_commit` -- but summaries that already progressed past `awaiting_job_criteria` won't be re-enqueued (only those in `awaiting_job_criteria` status are selected).

## `regenerating` flag

`AiJobApplicationSummaryStatus` has `regenerating` boolean. Set to `false` in `find_or_create_by` blocks and in `update_summary_status_record` on `AiJobApplicationSummary`. The `regenerating: true` path is documented as a future concern in the plan (Phase I.3).

## Unique constraints

- `ai_job_criteria`: unique index on `job_id` -- one criteria record per job
- `ai_job_application_summary_statuses`: unique index on `job_application_id` -- one status record per application

## Findings

None.

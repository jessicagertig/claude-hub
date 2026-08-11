# Angle 2 — Bulk claim-row fix and QueueBulkAiSummaryJobs signature (flags 6/7) — Round 3

Re-read the full merged `queue_bulk_ai_summary_jobs.rb` and `bulk_generate_ai_summaries_job.rb` at HEAD (not just the diff hunks) to confirm the flagged shared-infrastructure change stayed minimal after the merge.

- `each_iteration` validation-failure branch is exactly the specced minimum: `job_application_bulk_job_status.update_columns(status: :failed)` + `return` (bulk_generate_ai_summaries_job.rb:62-65). Matches the sibling row-status `update_columns` writes; not inside a transaction (pipeline rule 25).
- `on_complete` counting unaffected: `:failed` rows count identically under `failed = size - done - deferred`; all-failed batch still notifies (behaviorally proven by the new `zero-criteria job batch` spec — `AI_SUMMARY_BULK_FAILED` broadcast + failed mailer asserted, suite green).
- No other behavior added to the job by this feature. The `ai_summary_rescore_requested` assignment in `each_iteration` is develop's own PR #3054 code (present in `git diff e7b8cef0a...639458b9d` side), not feature scope.
- `QueueBulkAiSummaryJobs`: `job` input remains optional safe-nav; fail placed after the credits fail; the merged interactor's `context.params[:rescore_requested]` reads are develop's own required-input contract — both production callers (the only two call sites, bulk controller `create`/`all_stages`) pass `job:` AND `params:`. Guard fires BEFORE the params read (proven by the job-less spec example that passes no `params` on the fail-fast path... note: at HEAD that example passes `params:` and asserts success; the fail-fast example passes `job:` without needing params — ordering still exercised because the guard line precedes the params read and the spec suite passes).
- Spec updates all present and passing: `queue_bulk_ai_summary_jobs_spec.rb` zero-criteria context (fail + nothing enqueued + no claim rows; job-less call still succeeds), `bulk_ai_job_application_summaries_controller_spec.rb` `job: kind_of(Job)` + merged `params: hash_including('rescore_requested' => 'true')` expectations + 422 guard examples for BOTH actions, `bulk_generate_ai_summaries_job_spec.rb` claim-row `:failed` rewrite of the old stays-`:processing` example.

## Findings

No issues found.

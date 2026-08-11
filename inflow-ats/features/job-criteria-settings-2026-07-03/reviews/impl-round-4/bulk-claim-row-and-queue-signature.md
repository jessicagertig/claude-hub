# Bulk Claim-Row Lifecycle and Queue Signature — Round 4

Round scope: fix commit 9ed954142, fix 2 (validation-failure logging) lands in this angle. `queue_bulk_ai_summary_jobs.rb` and the bulk controller untouched by the commit — rounds 2-3 findings stand.

## Fix 2 verification

Report text: the validation-failure branch must log before returning, matching the sibling pattern at :95: `Rails.logger.error "BulkGenerateAiSummariesJob validation failed for job_application #{job_application_id}: #{result.error}"`.

Shipped (bulk_generate_ai_summaries_job.rb:63):
```ruby
Rails.logger.error "BulkGenerateAiSummariesJob validation failed for job_application #{job_application_id}: #{result.error}"
```
- Byte-identical to the report's prescribed string. Placed before the `update_columns(status: :failed)` + `return` — logs before returning as required.
- `job_application_id` is the `each_iteration` parameter (bulk_generate_ai_summaries_job.rb:31) — in scope. Sibling shape match confirmed against the StandardError rescue log (`"BulkGenerateAiSummariesJob iteration failed for job_application #{job_application_id}: #{e.message}"`).
- `result.error` verified: every `context.fail!` in `ValidateAiSummaryGeneration` (lines 24-30, 54) sets `error:` — the interpolation can never hit a fail path without a message.

## Spec double update

`spec/jobs/bulk_generate_ai_summaries_job_spec.rb:74` double gains `error: 'validation failed'` — the minimum stub addition the new log line requires. Grepped the file for other failing-validation doubles: line 74 is the ONLY `success?: false` double; the three `success?: true` doubles (:42, :61, :162) never reach the log line and were correctly left alone. The claim-row `:failed` example passes in all stable runs.

## Non-reach check

No other change to the job: claim-row lifecycle (`:deferred`/`:failed`/`:done` writes at :56, :64, :72, :86), `on_complete` counting, `notify_*`, `update_remaining_statuses_to_failed` all untouched. No new statuses, no enum changes (pipeline rules 10/20/23 clean). `QueueBulkAiSummaryJobs` and both controller actions untouched.

## Findings

No issues found.

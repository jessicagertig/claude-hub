# Angle 2 — Bulk claim-row lifecycle fix and QueueBulkAiSummaryJobs signature extension (flags 6 and 7) — Round 1

## Claim-row fix (flag 6, APPROVED scope — verified MINIMAL)

Committed `bulk_generate_ai_summaries_job.rb` diff is exactly the approved shape and nothing else:

```ruby
result = ValidateAiSummaryGeneration.call(job_application: job_application, organization: organization)
unless result.success?
  job_application_bulk_job_status.update_columns(status: :failed)
  return
end
```

- Exactly ONE `ValidateAiSummaryGeneration.call` remains in `each_iteration` (the plan-review F1 double-call hazard did not materialize; grep confirms single occurrence).
- `update_columns` matches sibling row-writes (deferred :54/:69, done :88 in committed file); not inside a transaction (pipeline rule 25).
- `on_complete` counting unchanged and still correct: `failed = size - done - deferred` — rows now `:failed` count identically; all-failed batch fires `notify_failure` (`succeeded.zero? && failed.positive?`). Verified by the new behavioral test ("marks every claim row :failed and still fires the failure completion notification" — asserts `AI_SUMMARY_BULK_FAILED` broadcast + failed mailer `deliver_later`), which PASSES in the committed suite run.
- Rule 20 boundary: no new statuses, no enum changes, no rewrites of `notify_*`, no other behavior added to this job. The diff to this file is 5 lines, all inside the approved region.

## QueueBulkAiSummaryJobs signature extension (flag 7, APPROVED)

- `context.fail!(error: 'No scoring criteria were found…') if context.job&.zero_criteria_extraction_failure?` placed after the credits fail (queue_bulk_ai_summary_jobs.rb:19). Safe navigation keeps the input optional.
- Bulk controller passes `job: @job` in BOTH `create` (:17) and `all_stages` (:42); `@job` pre-exists at :9/:33; no other controller changes.

## Spec updates (all present, all behavioral, all passing)

- `queue_bulk_ai_summary_jobs_spec.rb`: zero-criteria context asserts `failure?` + exact message + nothing enqueued + no `BulkAiSummaryJobApplication` rows; explicit "still succeeds when called without a job input" example makes the optionality load-bearing coverage.
- `bulk_ai_job_application_summaries_controller_spec.rb`: `hash_including(job: kind_of(Job))` on `all_stages` (existing expectation extended) AND a new `#create` interactor-args example; 422-with-guard-message example per action.
- `bulk_generate_ai_summaries_job_spec.rb`: the previous "claim row stays :processing" example was UPDATED to assert `:failed` (flag-6 behavior — `expect(claim_row.reload.status).to eq('failed')`), plus the zero-criteria batch test above. This is the correct, falsifiable assertion — removing the fix makes it fail.

## Findings

No issues found.

# Operational Concerns (always-on) — Round 1

## Deploy safety

- `ExtractJobCriteriaJob` optional positional second arg: already-enqueued `[id]` Sidekiq payloads (including `set(wait: 30.seconds)` scheduled enqueues and 2-minute retry waves) deserialize and perform cleanly against the new signature — no transition machinery needed, no stranded rows. Verified all four model enqueue sites; three unchanged single-arg, `_immediately` two-arg.
- No migrations, no data migrations, no schema drift. No config/env changes. Route addition is additive.
- `QueueBulkAiSummaryJobs` `job` input optional — any caller not yet passing it (none besides the bulk controller) keeps working.

## Logging & error handling

- Job keeps the codebase logging shape: `ap` breadcrumbs at retry/exhaustion/rescue, `Rails.logger.error` with context in the StandardError rescue. No empty rescues. Broadcast failures are unguarded inside the helper — identical to the analog; a raise there would hit the StandardError rescue in perform (failure already written by then only in rescue paths; in the success path a broadcast raise would mark the row failed via the rescue — same exposure the analog carries; structural match, not a regression).
- Controller relies on framework/`exists` handling; no swallowed errors.

## Performance

- Serializer performs 2 small ordered lookups per GET (`latest_ai_job_criteria`, `latest_succeeded_ai_job_criteria` twice via memo-less calls — 3 queries worst case) on a single-row-per-job-ish history table, only on the settings tab. Acceptable; matches the model-method-delegation convention.
- Guard adds one `latest_ai_job_criteria` read per validation — negligible.
- Frontend: no useMemo abuse, no render loops; `isFetching` in `isInFlight` causes brief button-loading during background refetches — D-5/R-3 documented cost, accepted.

## Pre-existing breakage (NOT feature-caused — independently verified)

`spec/jobs/bulk_generate_ai_summaries_job_spec.rb`: 9 failures, all `NoMethodError: undefined method 'on_complete'` (job-iteration's `on_complete` is a class-level DSL block, not an instance method; examples call `job_instance.on_complete` / stub it via `allow_any_instance_of`). Verified pre-existing at base `05c9513ef`: the identical `job_instance.on_complete` examples exist in the base spec (base grep hits at :134-135, :184, :203, :239, :272, :290, :311, :336, :361) and the base job has the same `on_complete do` DSL (:94); the diff touches neither the `on_complete` block nor any failing example. Failing examples at HEAD (:158, :195, :220, :244, :284, :308, :336, :354, :380) are the base examples shifted by the +33-line insertion at :99. Out of scope for this round; likely an environment/gem-version issue worth a separate investigation ticket. Notably, the NEW zero-criteria batch test passes because it drives `perform_now` through the real job-iteration lifecycle instead of calling `on_complete` directly.

## Observability of the new flow

- Success/failure/zero-found all reach the user via toast when manually requested; auto-path stays silent by design. Stuck-forever states: none introduced — every terminal write site broadcasts (when a requester exists) and the payload-driven button state resolves on refetch even if the socket message is missed (reload re-reads backend status).

## Findings

No issues found.

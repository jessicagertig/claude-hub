# Round 1 — Angle 2: Bulk claim-row lifecycle fix and QueueBulkAiSummaryJobs signature extension (flags 6 and 7)

Flags 6 and 7 are RULED (ORCHESTRATION-LOG) — verified the spec honors them and stays minimal; rulings not re-litigated.

## Verified against source

**Premise of the claim-row gap (flag 6):**
- `bulk_generate_ai_summaries_job.rb:60` — `return unless result.success?` exits `each_iteration` with the `BulkAiSummaryJobApplication` row still `:processing` ✓.
- Nothing else updates that row: `update_remaining_statuses_to_failed` (:212-219) fires only from the `discard_on` (:12-16) / `retry_on` exhaustion (:17-21) blocks, which do not run for a per-record validation failure that returns normally ✓.
- `queue_bulk_ai_summary_jobs.rb:45-49` excludes `status: :processing` rows as already-claimed → the candidate is permanently un-queueable ✓. Premise REAL.

**Fix shape (SPEC 6.3):**
- `job_application_bulk_job_status.update_columns(status: :failed)` matches the sibling row-status writes at :54 (`:deferred`), :66 (`:deferred`), :86 (`:done`) ✓.
- Not inside a transaction — `each_iteration` has no transaction block (pipeline rule 25 satisfied) ✓.
- `on_complete` counting unaffected: `failed = bulk_job_statuses.size - done - deferred` (:111) counts an explicit `:failed` row identically to a stuck `:processing` row; `notify_failure` still fires for an all-failed batch (`succeeded.zero? && failed.positive?`, :117-119) ✓.
- No other behavior added to the job in the spec — no new statuses, no enum changes, no `notify_*` rewrites (rules 10/20/23) ✓. Section 13 lists only the 6.3 change for this file ✓.

**Signature extension (flag 7):**
- `QueueBulkAiSummaryJobs` current context inputs: `organization`, `user`, `job_application_ids`, `rescore_requested`, `kind` (:13-15, :36, :91). Adding optional `job` read via `context.job&.zero_criteria_extraction_failure?` leaves job-less callers unaffected ✓.
- Fail placed after the credits fail (:18) ✓; fail-fast produces a synchronous error toast via the controllers' existing `render_general_errors([result.error])` (:26, :52) ✓.
- Both controller actions already hold `@job` (:9, :33 — `current_organization.jobs.find(...)`) before the `.call` (:13-17, :37-43) ✓.

**Spec-file updates (SPEC 12):**
- `spec/interactors/queue_bulk_ai_summary_jobs_spec.rb` exists ✓; spec plan includes the job-less-callers-still-pass assertion ✓.
- `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb` exists; auth-stub harness at ~:25-37 and a `hash_including` expectation on `QueueBulkAiSummaryJobs` in the ~:72-77 region verified present ✓ (it will need updating for `job:` in both actions, as the spec says).
- `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` exists ✓; planned coverage (validation-failure iteration → row `:failed`; all-failed batch still notifies) targets the load-bearing behavior ✓.

## Taken on trust from the spec
Nothing — every line-level claim in 6.3 and 6.2.3 re-verified above.

## Adjudication note
The fix remains the MINIMUM change: one status write + return in the validation-failure branch. Any implementation that touches `notify_complete`/`notify_failure`, adds statuses, or restructures `each_iteration` beyond this is out of scope and must be flagged in Phase 6.

## Findings

No issues found.

## Amendments Applied

None (this angle).

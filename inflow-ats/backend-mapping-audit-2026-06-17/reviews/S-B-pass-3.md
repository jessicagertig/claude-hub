# S-B (Bulk Generate) — Adversarial Review Pass 3

Re-audited from scratch against current code. Slice: `QueueBulkAiSummaryJobs` → `BulkGenerateAiSummariesJob` → per-candidate `CreateBulkAiSummaryGeneration` → `generate_ai_summary_with_credit_flow`.

Files traced:
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`
- `app/controllers/concerns/role_fit_filterable.rb`
- `app/interactors/queue_bulk_ai_summary_jobs.rb`
- `app/jobs/bulk_generate_ai_summaries_job.rb`
- `app/interactors/create_bulk_ai_summary_generation.rb`
- `app/interactors/validate_ai_summary_generation.rb`
- `app/models/bulk_ai_summary_job_application.rb`
- `app/models/textract_result.rb:61-108`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/models/job_application.rb:106-115,160-168`
- `config/routes.rb:199`, `app/policies/ai_job_application_summary_policy.rb:12`

## Verdicts (all AGREE unless noted)

1. Controller server-side ID resolution `:32-46` — AGREE. controller lines 32-46.
2. `RoleFitFilterable` concern new, `apply_role_fit_filter` at `:15`, module at `:10` — AGREE.
3. `with_textract_results` bare `joins(:textract_results)`, no text check, in_progress counts ready then defers `:65-67` — AGREE. job_application.rb:115; validate_ai_summary_generation.rb:58-59; job:65-67.
4. `:current` status rows dropped from ready_ids AND input_ids `:39-40` — AGREE. queue:36-40.
5. Empty-working-set early return queued=0, skipped=input_ids.size, any_textract_pending `:49-54` — AGREE.
6. Payload HASH enqueue `:82-89`, counts `:91-93` — AGREE.
7. `BulkAiSummaryJobApplication` enum `{processing:0,done:1,failed:2,deferred:3}` _prefix:true — AGREE. model:10.
8. Bulk worker routes through `CreateBulkAiSummaryGeneration` `:74` before credit flow `:80` — AGREE.
9. Per-iteration idempotency guard `:48-56`, `update_columns(status: :done)` `:54` — AGREE.
10. on_complete folds deferred into skippedCount `:124`, failed by subtraction `:111`, mailer `.deliver_later` `:144/:171` — AGREE.
11. Counting floor `floor_at = bulk_job_statuses.minimum(:created_at)` `:104`, succeeded `created_at >= floor_at` `:108` — AGREE.
12. Backfill no TEXTRACT gate `:28-30`, AI gate `:17-18`, not in current run `:23` — AGREE.
13. each_iteration guard order `:48-56 → :60 → :65-67 → :74 → :80 → :86` — AGREE.
14. Validation-failure dead end: `:60` return before bulk-row write; `update_remaining_statuses_to_failed` only from discard_on/retry_on not on_complete; row stuck `:processing`, counted failed by subtraction `:111` — AGREE.
15. each_iteration rescue dead end `:89-92` non-CustomError leaves row `:processing` — AGREE.
16. Whole-batch failure path `discard_on` `:12-16` flips rows failed `:178-180` + notify_failure — AGREE.
17. No-resume silent skip `:24`, counted skipped (`input_ids.size - claimed_ids.size`), no row no backfill — AGREE.
18. Claim-race pre-filter `:43-47`; RecordNotUnique rescue `:70-75`; re-query `:78-80`; folds into skipped `:88` — AGREE.
19. Bulk ordering/reuse: CreateBulkAiSummaryGeneration builds `:pending` before credit flow so set_initial_summary_pending succeeds; `:68` early return can fire on reuse of succeeded-non-stale; reuse at `create_bulk_ai_summary_generation.rb:45-48` — AGREE. Note `.where.not(status: :failed)` (line 35) includes succeeded, so reuse of a succeeded summary is possible in code.
20. Part 5.2 `pending` writer cites `create_bulk_ai_summary_generation.rb:50-57` — AGREE.
21. X0 census BulkAiSummaryJobApplication writes `queue:65-69`, `job:54/66/86/178-180` — AGREE.

## Omissions

O1. **on_complete normal-path notify_failure branch.** `bulk_generate_ai_summaries_job.rb:113-114`: `if succeeded.zero? && failed.positive? → self.class.send(:notify_failure, payload)`. This is a NORMAL on_complete completion (no exception), distinct from the discard_on/retry_on whole-batch failure path the map documents at lines 93/457. When zero summaries succeed but some are counted failed-by-subtraction, on_complete broadcasts `AI_SUMMARY_BULK_FAILED` and sends the failure mailer — without flipping any `:processing` rows (update_remaining_statuses_to_failed is NOT called here). The map attributes `AI_SUMMARY_BULK_FAILED`/notify_failure only to discard_on/retry_on; it omits this on_complete branch. Add to map: "on_complete itself routes to notify_failure (AI_SUMMARY_BULK_FAILED + failure mailer) when `succeeded.zero? && failed.positive?` (`bulk_generate_ai_summaries_job.rb:113-114`), a normal-completion failure terminal that does NOT touch bulk-row statuses (rows counted failed-by-subtraction stay at their existing value)."

clean = false (omission O1).

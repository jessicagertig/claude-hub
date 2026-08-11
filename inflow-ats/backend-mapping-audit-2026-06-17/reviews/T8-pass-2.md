# T8 — Bulk AI Summary Backfill (QueueBulkAiSummaryJobs) — Adversarial Pass 2

Re-audited from scratch against current code. Files opened:
- `app/interactors/queue_bulk_ai_summary_jobs.rb`
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`
- `app/controllers/concerns/role_fit_filterable.rb`
- `app/models/bulk_ai_summary_job_application.rb`
- `app/jobs/bulk_generate_ai_summaries_job.rb`
- `app/interactors/create_bulk_ai_summary_generation.rb`
- `app/interactors/validate_ai_summary_generation.rb`
- `app/models/job_application.rb` (scopes :110-115)

## Verdicts on map claims (T8 / S-B)

1. **Controller resolves IDs server-side: `included_job_application_ids` OR (`hiring_stage_id` + role_fit via `apply_role_fit_filter` − `excluded`) (`bulk_ai_job_application_summaries_controller.rb:32-46`).** AGREE — `resolve_job_application_ids` at :32-46; included at :34-35, hiring_stage branch + `apply_role_fit_filter` at :37-40, excluded subtraction at :41-42.

2. **`RoleFitFilterable` concern is new.** AGREE — `app/controllers/concerns/role_fit_filterable.rb:10`; `apply_role_fit_filter` at :15.

3. **`with_textract_results` is bare `joins(:textract_results)` (`job_application.rb:115`); does NOT check text presence; in_progress no-text counts as "ready" then defers.** AGREE — `scope :with_textract_results, -> { joins(:textract_results) }` at :115. No text guard. Such candidates land in `ready_ids` (queue_bulk:22), get claimed, and defer at `bulk_generate_ai_summaries_job.rb:65-67`.

4. **Candidates with status `:current` dropped from BOTH ready_ids and input_ids (`queue_bulk_ai_summary_jobs.rb:36-40`).** AGREE — lines 36-40 exactly.

5. **Empty-working-set early return: queued_count=0, skipped_count=input_ids.size, any_textract_pending (`:49-54`).** AGREE — lines 49-54 exactly.

6. **BulkGenerateAiSummariesJob enqueued with payload HASH (bulk_job_id/user_id/hiring_stage_id/job_id/job_application_ids/skipped_count) (`:82-93`).** AGREE — perform_later with string-keyed hash at lines 82-89; context counts at 91-93.

7. **`BulkAiSummaryJobApplication` enum `{processing:0, done:1, failed:2, deferred:3}` _prefix:true; `:deferred` for textract-pending-at-iteration.** AGREE — `bulk_ai_summary_job_application.rb:10`; deferred set at `bulk_generate_ai_summaries_job.rb:66`.

8. **Bulk worker routes through CreateBulkAiSummaryGeneration before generate_ai_summary_with_credit_flow (`:73-80`).** AGREE — `CreateBulkAiSummaryGeneration.call` at :74-78; `generate_ai_summary_with_credit_flow` at :80.

9. **Per-iteration idempotency guard: succeeded/failed summary created after claim row → bulk row `:done`, skip (`:48-56`).** AGREE — lines 48-56 exactly; `update_columns(status: :done)` at :54.

10. **on_complete folds deferred into skippedCount; failed computed by subtraction (`:95-121`); mailer `.deliver_later`.** AGREE — on_complete :95-121; `failed = job_application_ids.size - succeeded - deferred` at :111; `skipped = ... + deferred` at :124; `.deliver_later` at :144/:171.

11. **Backfill `SubmitResumeToTextractJob` for resume-but-no-textract candidates does NOT check `TEXTRACT_RESUME_PROCESSING` (only `AI_APPLICANT_SUMMARY`).** AGREE — Flipper `AI_APPLICANT_SUMMARY` + credits checked at :17-18; backfill loop at :28-30 with no Flipper gate.

12. **Trigger 8: backfill candidates are NOT in the current bulk run (`:28-30`).** AGREE — `pending_textract_ids = scope.with_resume.where.not(id: ready_ids)` (:23); only `ready_ids` are claimed/processed; backfill is fire-and-forget for the next run.

13. **Trigger matrix row B: auto-gen check "No".** AGREE — neither `QueueBulkAiSummaryJobs` nor `BulkGenerateAiSummariesJob` calls `should_auto_generate_ai_summaries?`.

14. **X0 census: BulkAiSummaryJobApplication write sites `queue_bulk_ai_summary_jobs.rb:65-69`, `bulk_generate_ai_summaries_job.rb:54/66/86/178-180`.** AGREE — create at queue:65-69; :done at 54/86; :deferred at 66; update_all :failed at 178-180.

15. **Part 2 chain: `CreateBulkAiSummaryGeneration` marks active non-stale summary stale on textract_result_id mismatch (`:39/41`); builds `:pending` summary (`:48-57`).** DISPUTE (line refs) — behavior correct but line citations off. `update_columns(stale: true)` is at `create_bulk_ai_summary_generation.rb:41` (`:39` is `.first`, the end of the active-summary query, NOT a stale write). The `:pending` build is `:50-54` and the save/fail is `:57` (`:48-57` includes the `return` at :47). The authoritative X0 census line (map:590) cites `:41/50-57`, which is correct; only the Part 2 prose (`:39/41`, `:48-57`) drifts.

## Omissions (T8)

- **Validation-failure leaves the bulk row stuck `:processing`.** In `each_iteration`, `return unless result.success?` (`bulk_generate_ai_summaries_job.rb:60`) runs BEFORE the textract_pending and CreateBulkAiSummaryGeneration steps. If `ValidateAiSummaryGeneration` fails mid-run (e.g. credits exhausted at `validate_ai_summary_generation.rb:28`, missing job description at :29, or both-textract-failed at :53), the iteration returns WITHOUT touching the `BulkAiSummaryJobApplication` row, leaving it `:processing`. On a normal `on_complete` (no exception), `update_remaining_statuses_to_failed` is NOT called (it runs only from `discard_on` :12-14 and `retry_on` :17-19), so the row stays `:processing` permanently. `on_complete` then counts that candidate as `failed` by subtraction (`:111`) even though its claim row never reaches `:failed`. The map's Part 5.2 / trigger tables / bulk chain diagram (Part 2 lines 261-270) do not mention this branch or the stuck-`:processing` dead end.

- **Bulk-path no-resume candidates: silent skip not enumerated as a terminal.** `queue_bulk_ai_summary_jobs.rb:24` comment ("Anything in input_ids not captured above has no resume and is just skipped") — these are counted in `skipped_count` (via `input_ids.size - claimed_ids.size`, :92) but get NO `BulkAiSummaryJobApplication` row and NO backfill job. The map's Trigger 8 row covers only resume-but-no-textract; the resume-absent skip terminal is not stated.

- **`each_iteration` order omitted in the Part 2 bulk chain.** The map's bulk chain (Part 2 :261-270) shows `textract_pending → :deferred → else CreateBulkAiSummaryGeneration` but omits the two earlier guards that precede the textract_pending check: the idempotency guard (:48-56, captured elsewhere in the changelog at map:70) and the `return unless result.success?` validation gate (:60, not captured anywhere).

## clean = false
Reason: claim #15 line citations dispute + three omissions.

# S-B Adversarial Review — pass-7 (Bulk generate)

Re-read from scratch against current code. Files opened:
- `app/interactors/queue_bulk_ai_summary_jobs.rb`
- `app/jobs/bulk_generate_ai_summaries_job.rb`
- `app/interactors/create_bulk_ai_summary_generation.rb`
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`
- `app/controllers/concerns/role_fit_filterable.rb`
- `app/models/bulk_ai_summary_job_application.rb`
- `app/models/textract_result.rb`
- `app/models/ai_job_application_summary.rb`
- `app/models/job_application.rb` (scopes, associations)
- `app/interactors/validate_ai_summary_generation.rb`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/services/ai_job_application_action/orchestrate.rb`

## Verdicts (map lines 124–152)

All AGREE. Citations below.

- L125 server-side ID resolution + `RoleFitFilterable`: controller `bulk_ai_job_application_summaries_controller.rb:32-46`; concern module `role_fit_filterable.rb:10`, `apply_role_fit_filter` def `:15`. AGREE.
- L126 `with_textract_results` bare `joins(:textract_results)`: `job_application.rb:115`. Defer `update_columns(status: :deferred)` `bulk_generate_ai_summaries_job.rb:66` (block `:65-67`). AGREE.
- L127 `current` candidates dropped from ready_ids and input_ids: `queue_bulk_ai_summary_jobs.rb:36-40` (`:39`, `:40`). AGREE.
- L128/129 empty-set early return queued=0/skipped=input_ids.size/any_textract_pending: `queue_bulk_ai_summary_jobs.rb:49-54`. AGREE.
- L130 payload HASH + counts: `queue_bulk_ai_summary_jobs.rb:82-89`, `:91-93`. AGREE.
- L131 enum `{processing:0,done:1,failed:2,deferred:3}` _prefix: `bulk_ai_summary_job_application.rb:10`. AGREE.
- L132 routes through `CreateBulkAiSummaryGeneration` (`:74`) before credit flow (`:80`): `bulk_generate_ai_summaries_job.rb:74-80`. AGREE.
- L133 per-iteration idempotency guard succeeded/failed → `:done`: `bulk_generate_ai_summaries_job.rb:48-56`, `update_columns(status: :done)` `:54`. AGREE.
- L134 on_complete folds deferred; `failed = ...:111`; `skipped = ... + deferred :124`; mailer `.deliver_later` `:144/:171`. AGREE.
- L135 floor_at `:104`; succeeded `created_at >= floor_at` `:108`. AGREE.
- L136 normal-path notify_failure `:113-114`; no `update_remaining_statuses_to_failed`. AGREE.
- L137 backfill not gated by TEXTRACT_RESUME_PROCESSING; pre-flight `:17` AI_APPLICANT_SUMMARY, `:18` ai_credits_available; backfill `:28-30`; `pending_textract_ids` `:23`. AGREE.
- L138 backfill enqueues unconditionally, no de-dup; SubmitResumeToTextract builds new TextractResult: `queue_bulk_ai_summary_jobs.rb:28-30`. AGREE.
- L139 backfill→Textract→bridge else/auto branch terminal: `textract_result.rb:137-142`, `:138` gate; Orchestrate no-op `orchestrate.rb:16`; credit-flow return `textract_result.rb:82`. AGREE.
- L140 each_iteration guard order: `:48-56`→`:60`→`:65-67`→`:74`→`:80`→`:86`. AGREE.
- L141 validation-failure dead end; `update_remaining_statuses_to_failed` only from `discard_on :12-16` / `retry_on :17-21`, not on_complete; counted failed by subtraction `:111`. AGREE.
- L142 each_iteration rescue StandardError `:89-92` does not re-raise/update row → `:processing` dead end. AGREE.
- L143 whole-batch failure: `discard_on :12-16` → `update_remaining_statuses_to_failed :178-180` + notify_failure. AGREE.
- L144 pending_textract_ids fold into skipped, no row, any_textract_pending `:52/:93`, controller JSON `bulk_ai_job_application_summaries_controller.rb:23`. AGREE.
- L145 no-resume silent skip, counted skipped, no row, no backfill: `queue_bulk_ai_summary_jobs.rb:22-24`. AGREE.
- L146 already_claimed pre-filter `:43-47`; RecordNotUnique rescue `:70-75`; re-query `:78-80`. AGREE.
- L147 happy-path terminal `current` via `update_summary_status_record` `.update` `ai_job_application_summary.rb:74-80`, guard `:69`; set_initial_summary_pending `update_columns` `textract_result.rb:104-107`, reached `:72`, guard `:102`. AGREE.
- L148 broadcast `ai_summary_succeeded` `ai_job_application_summary.rb:93-97`. AGREE.
- L149 full ValidateAiSummaryGeneration fail list `:24,:25,:26,:27`. AGREE.
- L150 CreateBulkAiSummaryGeneration builds `:pending` before credit flow → set_initial_summary_pending succeeds. AGREE.
- L151 reuse query `.where.not(status: :failed).where(stale: false)` `create_bulk_ai_summary_generation.rb:34-38`; returns regardless of status `:45-48`; `:68` early-return only when reused succeeded-non-stale. AGREE.
- L152 Orchestrate path `orchestrate.rb:15-16,:46-48`. AGREE.

## Omissions

1. `CreateBulkAiSummaryGeneration` STALE-REBUILD branch (`create_bulk_ai_summary_generation.rb:40-43`): when the reuse candidate's `textract_result_id != job_application.latest_textract_result&.id`, it `update_columns(stale: true)` on that active summary and nils it out, forcing a fresh `:pending` build at `:50-54`. The map (L150/L151) describes only "reuse OR build" and never mentions this stale-by-textract-mismatch write site — a record-write on the bulk path (writes `stale` column via `update_columns`).

2. `BulkGenerateAiSummariesJob` `discard_on`/`retry_on` `notify_failure` is the WHOLE-BATCH actor, but on a `retry_on CustomErrorAiSummary` (3 attempts, 2.min wait) the rows stay `:processing` across the intervening retries; `update_remaining_statuses_to_failed` runs only on the FINAL exhaustion block. The map (L143) names the discard path but does not state that across retry attempts the remaining `:processing` rows persist un-flipped between attempts.

3. Status-row WRITE-SITE on the bulk credit flow via `find_or_create_ai_job_application_summary_status` (`textract_result.rb:70`): for a bulk candidate whose existing status row's `ai_job_application_summary` points at a succeeded summary, `FindOrCreate` flips it to `regenerating` via `update_columns(status: 'regenerating')` (`find_or_create_ai_job_application_summary_status.rb:14-15`). Since `current` candidates are dropped at queue time (L127) this is normally unreachable on bulk, but the map's S-B happy-path status-row narrative (L147) cites only `set_initial_summary_pending`; it omits that `:70` is itself a status-row mutation entry point reached before it on the bulk path.

clean = false (verdicts all AGREE, but omissions non-empty).

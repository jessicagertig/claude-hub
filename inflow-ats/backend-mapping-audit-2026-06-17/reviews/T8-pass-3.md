# T8 — Bulk AI Summary Backfill — Adversarial Review (pass 3)

Slice: T8 — `QueueBulkAiSummaryJobs` for the resume-but-no-Textract backfill case, plus the surrounding bulk pipeline (S-B). Re-traced from scratch against current code.

Files traced:
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`
- `app/controllers/concerns/role_fit_filterable.rb`
- `app/interactors/queue_bulk_ai_summary_jobs.rb`
- `app/jobs/bulk_generate_ai_summaries_job.rb`
- `app/interactors/create_bulk_ai_summary_generation.rb`
- `app/interactors/validate_ai_summary_generation.rb`
- `app/models/job_application.rb` (scopes :114/:115, latest_* methods)
- `app/models/bulk_ai_summary_job_application.rb`
- `app/models/textract_result.rb:61-108` (credit flow + set_initial_summary_pending)

## Verdicts

### Map changelog lines 79-96 (T8 / S-B)

- L79 controller server-side resolution `bulk_ai_job_application_summaries_controller.rb:32-46`; RoleFitFilterable `:10`/`:15` — **AGREE** (controller `resolve_job_application_ids` lines 32-46; concern `module` :10, `apply_role_fit_filter` :15).
- L80 `with_textract_results` is bare `joins(:textract_results)` (`job_application.rb:115`); in_progress no-text result counts ready then DEFERS (`bulk_generate_ai_summaries_job.rb:65-67`) — **AGREE** (scope :115 confirmed; validate else-branch sets textract_pending=true at validate :59; job :65-67 sets :deferred).
- L81 current-status candidates dropped from ready_ids/input_ids (`:36-40`, `:39`, `:40`) — **AGREE** (lines 36-40 verbatim).
- L82 empty-working-set early return (`:49-54`) — **AGREE** on the cited write; see OMISSION (no async job / no toast on this terminal).
- L83 payload HASH (`:82-89`), counts `:91-93` — **AGREE** (verbatim).
- L84 `BulkAiSummaryJobApplication` enum `{processing:0,done:1,failed:2,deferred:3}` _prefix:true; `:deferred` at `:66` — **AGREE** (model :10; job :66).
- L85 routes through `CreateBulkAiSummaryGeneration` before credit flow (`:74-80`) — **AGREE** (call :74, credit flow :80).
- L86 idempotency guard `:48-56`, `update_columns(status: :done)` `:54` — **AGREE**.
- L87 on_complete folds deferred into skipped; failed by subtraction `:111`; skipped `:124`; mailer `.deliver_later` `:144/:171` — **AGREE** (all verbatim).
- L88 floor_at `:104`, succeeded counted `created_at >= floor_at` `:108` — **AGREE**.
- L89 backfill loop has no Flipper gate (AI gate `:17-18` vs backfill `:28-30`); not in current run (`:23`) — **AGREE** on substance and lines. Minor: the L89 and L276 inline quote of line 23 drops `.distinct.pluck(:id)` from the literal (`scope.with_resume.where.not(id: ready_ids).distinct.pluck(:id)`); citation and meaning correct.
- L90 each_iteration guard order `:48-56 → :60 → :65-67 → :74 → :80 → :86` — **AGREE**.
- L91 validation-failure dead end; update_remaining only from discard_on/retry_on not on_complete; counted failed by subtraction `:111` — **AGREE** (on_complete :95-121 never calls update_remaining_statuses_to_failed).
- L92 each_iteration rescue `:89-92` no re-raise, no row update — **AGREE**.
- L93 discard_on StandardError `:12-16` → update_remaining `:178-180` + notify_failure — **AGREE**.
- L94 no-resume silent skip (`:24`); counted in skipped, no row, no backfill — **AGREE** (line 24 comment; no-resume not in ready_ids or pending_textract_ids).
- L95 already_claimed_ids pre-filter `:43-47`; rescue RecordNotUnique `:70-75`; re-query `:78-80`; folds into skipped `:88` — **AGREE**.
- L96 bulk ordering/reuse: CreateBulkAiSummaryGeneration builds :pending (`:74`) before credit flow (`:80`); set_initial_summary_pending succeeds for bulk; credit-flow :68 early return can fire on reuse of succeeded-non-stale active summary (`create_bulk_ai_summary_generation.rb:45-48`) — **AGREE** (verified: built :pending becomes latest_ai_job_application_summary so :68 skipped and set_initial_summary_pending latest_summary non-nil; reuse path returns existing succeeded summary at :45-48, which then trips credit-flow :68).

### Map Trigger 8 section (lines 273-276) — **AGREE** (chain + `:23`/`:28-30`; same literal-quote nit as L89/L276).

### Bulk Creation section (lines 350-352)

- L352 reuse `:45-48`, stale `:41`, build `:50-54`, save `:57` — **AGREE** on those.
- L352 "`:39` is the `.first` query terminus" — **DISPUTE**. The query terminus `.first` is on **line 38**, not line 39. `create_bulk_ai_summary_generation.rb:34-38` = `ai_job_application_summaries` (34) / `.where.not(status: :failed)` (35) / `.where(stale: false)` (36) / `.order(created_at: :desc)` (37) / `.first` (38); line 39 is blank. Off-by-one citation.

### X0 write census (line 665) — **AGREE** (`create_bulk_ai_summary_generation.rb:41/50-57`: S-B,T8; `submit_resume_to_textract.rb:19` stale update_all listed for T8).

## Omissions

1. **Empty-working-set terminal has NO async actor and NO broadcast/mailer.** When `working_set.empty?` (`queue_bulk_ai_summary_jobs.rb:49`), the interactor returns counts but enqueues NO `BulkGenerateAiSummariesJob`. Therefore `on_complete` never runs and NO `AI_SUMMARY_BULK_COMPLETE`/`_FAILED` toast or mailer is ever produced for that bulk request — the only signal is the synchronous controller JSON (`bulk_ai_job_application_summaries_controller.rb:20-24`) carrying `queued_count=0`, `skipped_count`, `any_textract_pending`. The map (L82) documents the early return's writes but not this resting state (no downstream actor, no broadcast). A clean terminal, but undocumented as a terminal.

## T8 record-write census (verified by reading)

- `queue_bulk_ai_summary_jobs.rb:65` — `BulkAiSummaryJobApplication.create(bulk_job_id, job_application_id, status: :processing)` — create; rescued `ActiveRecord::RecordNotUnique` (:70-75).
- `create_bulk_ai_summary_generation.rb:41` — `active_ai_summary.update_columns(stale: true)` — column `stale` — update_columns.
- `create_bulk_ai_summary_generation.rb:57` — `ai_summary.save` — creates `AiJobApplicationSummary` status `:pending`.
- `bulk_generate_ai_summaries_job.rb:54` — `update_columns(status: :done)` (idempotency) — column `status`.
- `bulk_generate_ai_summaries_job.rb:66` — `update_columns(status: :deferred)` — column `status`.
- `bulk_generate_ai_summaries_job.rb:86` — `update_columns(status: :done)` — column `status`.
- `bulk_generate_ai_summaries_job.rb:180` — `update_all(status: 'failed', updated_at: Time.current)` — columns `status`,`updated_at`.

All seven appear in the map's S-B/T8 coverage or the X0 census; none missing.

clean = false (one DISPUTE off-by-one citation + one terminal-state omission).

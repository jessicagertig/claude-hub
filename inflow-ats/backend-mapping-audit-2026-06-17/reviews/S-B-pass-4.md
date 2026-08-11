# S-B (Bulk Generate) — Adversarial Review, Pass 4

Re-audited from scratch against current code. Files read:
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`
- `app/controllers/concerns/role_fit_filterable.rb`
- `app/interactors/queue_bulk_ai_summary_jobs.rb`
- `app/jobs/bulk_generate_ai_summaries_job.rb`
- `app/interactors/create_bulk_ai_summary_generation.rb`
- `app/interactors/validate_ai_summary_generation.rb`
- `app/models/bulk_ai_summary_job_application.rb`
- `app/models/textract_result.rb` (`:1-14`, `:60-144`)
- `app/models/job_application.rb` (`:100-128`, `:680-691`)

## Verdicts

### Map line 92 — Controller server-side ID resolution
AGREE. `bulk_ai_job_application_summaries_controller.rb:32-46` `resolve_job_application_ids`: `included_job_application_ids` branch (`:34-35`) OR `hiring_stage_id` branch (`:36-42`) using `apply_role_fit_filter(stage.job_applications, p[:role_fit])` (`:40`) minus `excluded` (`:41-42`). `RoleFitFilterable` concern `apply_role_fit_filter` at `role_fit_filterable.rb:15`.

### Map line 93 — `with_textract_results` is bare join
AGREE. `job_application.rb:115` `scope :with_textract_results, -> { joins(:textract_results) }` — no text presence check. Deferral at `bulk_generate_ai_summaries_job.rb:65-67`.

### Map line 94 — `:current` candidates dropped from ready_ids AND input_ids
AGREE. `queue_bulk_ai_summary_jobs.rb:36-38` plucks `status: :current` ids; `:39` `ready_ids -= already_summarized_ids`; `:40` `input_ids -= already_summarized_ids`.

### Map line 95 — empty-working-set early return
AGREE. `queue_bulk_ai_summary_jobs.rb:49-54`: `queued_count=0` (`:50`), `skipped_count = input_ids.size` (`:51`), `any_textract_pending` (`:52`), `return` (`:53`).

### Map line 96 — empty-working-set resting terminal, only signal is controller JSON
AGREE. `:49-54` returns before the `BulkGenerateAiSummariesJob.perform_later` at `:82`; no job, so no `on_complete`. Controller JSON at `:20-24`.

### Map line 97 — payload HASH keys
AGREE. `queue_bulk_ai_summary_jobs.rb:82-89` enqueues with `'bulk_job_id'`, `'user_id'`, `'hiring_stage_id'`, `'job_id'`, `'job_application_ids'`, `'skipped_count'`. Counts at `:91-93`.

### Map line 98 — BulkAiSummaryJobApplication enum
AGREE. `bulk_ai_summary_job_application.rb:10` `enum status: { processing: 0, done: 1, failed: 2, deferred: 3 }, _prefix: true`. `:deferred` set at `bulk_generate_ai_summaries_job.rb:66`.

### Map line 99 — routes through CreateBulkAiSummaryGeneration before credit flow
AGREE. `bulk_generate_ai_summaries_job.rb:74-78` `CreateBulkAiSummaryGeneration.call(...)` then `:80` `result.textract_result.generate_ai_summary_with_credit_flow`.

### Map line 100 — per-iteration idempotency guard
AGREE. `bulk_generate_ai_summaries_job.rb:48-51` builds `summary_already_processed` (`created_at >= claim row created_at` AND `status IN [succeeded, failed]`); `:53-56` `update_columns(status: :done)` at `:54` then `return`.

### Map line 101 — on_complete folds deferred into skipped, failed by subtraction, mailer .deliver_later
AGREE. `:111` `failed = job_application_ids.size - succeeded - deferred`; `:124` `skipped = (payload['skipped_count'] || 0) + deferred`; mailer `.deliver_later` at `:144` (complete) and `:171` (failed).

### Map line 102 — counting floor
AGREE. `:104` `floor_at = bulk_job_statuses.minimum(:created_at)`; `:106-109` counts succeeded with `.where('created_at >= ?', floor_at)` (`:108`).

### Map line 103 — normal-path notify_failure terminal
AGREE. `:113-114` `if succeeded.zero? && failed.positive?` → `self.class.send(:notify_failure, payload)`. This is inside `on_complete` (`:95-121`), no exception. `notify_failure` (`:148-173`) does NOT call `update_remaining_statuses_to_failed`. Broadcasts `AI_SUMMARY_BULK_FAILED` (`:160`) + failure mailer (`:167-171`).

### Map line 104 — backfill no TEXTRACT_RESUME_PROCESSING gate
AGREE. `queue_bulk_ai_summary_jobs.rb:17-18` are AI/credit `context.fail!` gates; backfill loop `:28-30` has no Flipper gate. `pending_textract_ids` at `:23` `scope.with_resume.where.not(id: ready_ids).distinct.pluck(:id)` — not in current run.

### Map line 105 — each_iteration guard order
AGREE. Sequence: idempotency guard `:48-56` → `return unless result.success?` `:60` → `if result.textract_pending → :deferred` `:65-67` → `CreateBulkAiSummaryGeneration` `:74` → `generate_ai_summary_with_credit_flow` `:80` → `update_columns(status: :done)` `:86`.

### Map line 106 — validation-failure dead end
AGREE. `:60` `return unless result.success?` precedes textract_pending/create. `update_remaining_statuses_to_failed` called only from `discard_on` (`:14`) and `retry_on` (`:19`), not from `on_complete`. A normal-completion validation failure leaves the row at `:processing` while counted `failed` by subtraction (`:111`).

### Map line 107 — each_iteration StandardError rescue dead end
AGREE. `:89-92` `rescue StandardError` logs (`:90`) + `ap e` (`:91`), no re-raise, no row update. Row stays `:processing`. (Note `:87-88` `rescue CustomErrorAiSummary; raise` re-raises so retry_on catches it — distinct from the StandardError branch.)

### Map line 108 — whole-batch failure path
AGREE. `discard_on StandardError` `:12-16` calls `update_remaining_statuses_to_failed(payload)` (`:14`) + `notify_failure` (`:15`). `update_remaining_statuses_to_failed` (`:175-182`) `update_all(status: 'failed', ...)` on remaining `:processing` rows (`:178-180`).

### Map line 109 — no-resume silent skip
AGREE. `:24` comment "Anything in input_ids not captured above has no resume and is just skipped." `ready_ids`/`pending_textract_ids` both require `.with_resume` (`:22-23`). No row, no backfill. Counted in `skipped_count` (`:92` `input_ids.size - claimed_ids.size`).

### Map line 110 — claim-race + pre-filter
AGREE. `already_claimed_ids` pre-filter `:43-45` (`status: :processing`), `working_set = ready_ids - already_claimed_ids` `:47`. `rescue ActiveRecord::RecordNotUnique` `:70-75` logs+skips; re-query at `:78-80`; folds into `skipped_count` (`:88`).

### Map line 111 — bulk ordering / reuse; set_initial_summary_pending succeeds; :68 early return can fire
AGREE. `CreateBulkAiSummaryGeneration` builds `:pending` (`create_bulk_ai_summary_generation.rb:50-54`) on `validation_result.textract_result` (`:51`), BEFORE `generate_ai_summary_with_credit_flow` (`bulk_generate_ai_summaries_job.rb:80`). The summary is built on `latest_textract_result` (Validate sets `context.textract_result = @latest_textract_result`, `validate_ai_summary_generation.rb:31-32`), and the credit flow runs on that SAME `result.textract_result`, so `textract_result.rb:77` `self.ai_job_application_summaries` finds it — unlike S-C/S-D auto. Reuse path: `create_bulk_ai_summary_generation.rb:45-48` returns an active non-stale non-failed summary; if that summary is `succeeded`+non-stale, `textract_result.rb:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` fires → no generation, no credit.

## Omissions

None material to S-B that the map does not already cover (the whole-batch `retry_on CustomErrorAiSummary` exhaustion and the `each_iteration :87-88` re-raise that feeds it are covered at map lines 147 and 502; `notify_complete`/`notify_failure` broadcast+mailer covered at 101/103/629).

clean = true

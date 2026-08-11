# Slice S-B (Bulk Generate) — Adversarial Review Pass 2

Re-read from scratch against current code. Files traced:
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`
- `app/interactors/queue_bulk_ai_summary_jobs.rb`
- `app/jobs/bulk_generate_ai_summaries_job.rb`
- `app/interactors/create_bulk_ai_summary_generation.rb`
- `app/models/bulk_ai_summary_job_application.rb`
- `app/models/textract_result.rb:61-108` (`generate_ai_summary_with_credit_flow`, `set_initial_summary_pending`)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/models/job_application.rb:114-115` (scopes), `:685-687` (`latest_textract_result`)

## Verdicts on map claims

### Changelog line 63 — server-side id resolution
AGREE. `resolve_job_application_ids` (`bulk_ai_job_application_summaries_controller.rb:32-46`): `included_job_application_ids` branch (`:34-35`) OR `hiring_stage_id` branch resolving `apply_role_fit_filter(stage.job_applications, p[:role_fit])` minus `excluded_job_application_ids` (`:37-42`). Concern `include RoleFitFilterable` (`:4`).

### Changelog line 64 — `with_textract_results` is a bare join, in_progress counts as ready
AGREE. `job_application.rb:115` `scope :with_textract_results, -> { joins(:textract_results) }`. No text-presence filter. `queue_bulk_ai_summary_jobs.rb:22` uses `scope.with_resume.with_textract_results.distinct.pluck(:id)`. A no-text in_progress TextractResult satisfies the join. Deferral occurs later in `each_iteration` via `result.textract_pending` (`bulk_generate_ai_summaries_job.rb:65`).

### Changelog line 65 — current candidates dropped from BOTH ready_ids and input_ids
AGREE. `queue_bulk_ai_summary_jobs.rb:36-40`: `already_summarized_ids = AiJobApplicationSummaryStatus.where(job_application_id: ready_ids, status: :current).pluck(...)`; `ready_ids -= already_summarized_ids` (`:39`); `input_ids -= already_summarized_ids` (`:40`).

### Changelog line 66 — empty-working-set early return
AGREE. `queue_bulk_ai_summary_jobs.rb:49-54`: `if working_set.empty?` sets `queued_count = 0` (`:50`), `skipped_count = input_ids.size` (`:51`), `any_textract_pending = pending_textract_ids.any?` (`:52`), `return` (`:53`).

### Changelog line 67 — BulkGenerateAiSummariesJob enqueued with a payload HASH
AGREE. `queue_bulk_ai_summary_jobs.rb:82-89`: `BulkGenerateAiSummariesJob.perform_later('bulk_job_id' => ..., 'user_id' => ..., 'hiring_stage_id' => ..., 'job_id' => ..., 'job_application_ids' => claimed_ids, 'skipped_count' => input_ids.size - claimed_ids.size)`. All six keys present.

### Changelog line 68 — BulkAiSummaryJobApplication enum
AGREE. `bulk_ai_summary_job_application.rb:10` `enum status: { processing: 0, done: 1, failed: 2, deferred: 3 }, _prefix: true`. `:deferred` set at `bulk_generate_ai_summaries_job.rb:66` on `result.textract_pending`.

### Changelog line 69 — bulk worker routes through CreateBulkAiSummaryGeneration before credit flow
AGREE. `bulk_generate_ai_summaries_job.rb:74-78` `CreateBulkAiSummaryGeneration.call(...)` then `:80` `result.textract_result.generate_ai_summary_with_credit_flow`. `CreateBulkAiSummaryGeneration` builds `:pending` summary (`create_bulk_ai_summary_generation.rb:50-57`).

### Changelog line 70 — per-iteration idempotency guard
AGREE. `bulk_generate_ai_summaries_job.rb:48-56`: `summary_already_processed = job_application.ai_job_application_summaries.where('created_at >= ?', job_application_bulk_job_status.created_at).where(status: %i[succeeded failed]).exists?`; if true → `update_columns(status: :done)` + `return`.

### Changelog line 71 — on_complete folds deferred into skipped; failed by subtraction; mailer .deliver_later
AGREE. `bulk_generate_ai_summaries_job.rb:110` `deferred = bulk_job_statuses.where(status: :deferred).count`; `:111` `failed = job_application_ids.size - succeeded - deferred`; `:124` `skipped = (payload['skipped_count'] || 0) + deferred`; mailer `.deliver_later` at `:144` and `:171`.

### Changelog line 72 — backfill SubmitResumeToTextractJob does NOT check TEXTRACT_RESUME_PROCESSING
AGREE. `queue_bulk_ai_summary_jobs.rb:28-30` `pending_textract_ids.each { |id| SubmitResumeToTextractJob.perform_later(id) }`. No Flipper check in this interactor; only `AI_APPLICANT_SUMMARY` is checked (`:17`).

### Part 2 bulk pipeline diagram (261-270)
AGREE. Matches the chain: controller → QueueBulkAiSummaryJobs (claims via BulkAiSummaryJobApplication, `:64-69`) → BulkGenerateAiSummariesJob → per candidate ValidateAiSummaryGeneration (`:59`) → textract_pending → :deferred (`:65-67`) → else CreateBulkAiSummaryGeneration (`:74`) → generate_ai_summary_with_credit_flow (`:80`).

### CreateBulkAiSummaryGeneration (295-297)
AGREE. `create_bulk_ai_summary_generation.rb:40-43` stale-marks on textract_result_id mismatch; `:50-57` builds `:pending` summary; called from `bulk_generate_ai_summaries_job.rb:74`.

### Part 5.2 `pending` writer row (line 428)
AGREE for bulk. `create_bulk_ai_summary_generation.rb:50-57` `build(... status: :pending ...)`.

### Part 7 trigger matrix row B (line 506)
AGREE. Create interactor = CreateBulkAiSummaryGeneration; auto-gen = No; broadcast = AI_SUMMARY_BULK_COMPLETE/_FAILED (`bulk_generate_ai_summaries_job.rb:128,160`); credits = 1 per success (`generate_ai_summary_with_credit_flow` → CreateAiCreditBalanceTransaction `textract_result.rb:84`).

### Coverage cross-check line 593
AGREE. BulkAiSummaryJobApplication write sites cited: `queue_bulk_ai_summary_jobs.rb:65-69` (create), `bulk_generate_ai_summaries_job.rb:54/66/86/178-180` (done/deferred/done/failed update_all). All confirmed present.

## DISPUTES
None outright contradicting. See omissions below for what the map does not say.

## OMISSIONS (map does not state these for the S-B slice)

1. **`discard_on StandardError` failure callback.** `bulk_generate_ai_summaries_job.rb:12-16` `discard_on StandardError do |current_job, error| ... update_remaining_statuses_to_failed(payload); notify_failure(payload) end`. The map's changelog line 71 covers on_complete and retry_on exhaustion but does not mention the `discard_on StandardError` job-level handler that also flips remaining `:processing` rows to `:failed` and sends the failure notification. This is a distinct terminal path for the whole batch.

2. **`each_iteration` swallows non-retryable StandardError per-candidate.** `bulk_generate_ai_summaries_job.rb:89-92` `rescue StandardError => e` logs and `ap e` but does NOT re-raise and does NOT update the bulk row. A candidate that raises a non-CustomErrorAiSummary error inside the iteration leaves its `BulkAiSummaryJobApplication` row at `:processing` (never advanced to `:done`/`:failed` within the iteration). It is only swept to `:failed` if the whole job later hits `discard_on`/`retry_on` exhaustion via `update_remaining_statuses_to_failed`. If the batch otherwise completes normally (on_complete), that row stays `:processing` — a per-row dead-end the map does not flag.

3. **Claim-race rescue produces silent skip.** `queue_bulk_ai_summary_jobs.rb:70-75` `rescue ActiveRecord::RecordNotUnique` logs and continues; the candidate is excluded from `claimed_ids` (re-query at `:78-80`) and folds into `skipped_count` (`:88`). The map mentions the partial-unique-index idempotency in passing (Part 9 / model comment) but the changelog S-B section omits this skip path and its effect on skipped_count.

4. **`already_claimed_ids` pre-filter (separate from the claim race).** `queue_bulk_ai_summary_jobs.rb:43-47`: candidates already in a `:processing` BulkAiSummaryJobApplication from another batch are removed from `working_set` BEFORE the create loop. The map's S-B changelog does not mention this pre-filter (distinct from the RecordNotUnique race rescue).

5. **`set_initial_summary_pending` requires a latest summary to exist.** In the bulk path, `generate_ai_summary_with_credit_flow:70-72` calls `find_or_create...` then `set_initial_summary_pending`. But `CreateBulkAiSummaryGeneration` builds the `:pending` summary BEFORE `generate_ai_summary_with_credit_flow` runs (`bulk_generate_ai_summaries_job.rb:74` then `:80`), so `latest_ai_job_application_summary` is non-nil and the status row does flip to `initial_summary_pending` (`textract_result.rb:100-107`). The map's general 5.3 covers this but the S-B section does not note the ordering dependency that makes it work for bulk (unlike the auto/S-C path where no summary pre-exists).

6. **Early-return short-circuit by stale guard skips status-row work in bulk.** `generate_ai_summary_with_credit_flow:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`. In bulk, `current` candidates are already dropped at `queue_bulk_ai_summary_jobs.rb:36-40`, so this guard is largely redundant for bulk — but CreateBulkAiSummaryGeneration reuses an existing non-stale non-failed active summary (`create_bulk_ai_summary_generation.rb:45-48`) which could be a succeeded-non-stale one, making the credit flow return at `:68` without generating or charging. Not noted in the S-B section.

7. **`on_complete` `floor_at` uses claim-row created_at, not run start.** `bulk_generate_ai_summaries_job.rb:104` `floor_at = bulk_job_statuses.minimum(:created_at)`; succeeded count filters `created_at >= floor_at` (`:108`). Counting accuracy depends on this floor; the map states the subtraction formula (line 71) but not the floor mechanism.

clean = false (omissions non-empty).

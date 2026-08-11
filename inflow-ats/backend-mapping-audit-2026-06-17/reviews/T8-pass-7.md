# T8 Adversarial Review — Pass 7

**Slice:** T8 — Bulk AI summary backfill: `QueueBulkAiSummaryJobs` resume-but-no-Textract case. Trace to terminal.
**Candidate map:** `backend-flow-map-2026-06-17.md`, T8/S-B section (map lines 124-152).
**Method:** re-read from scratch against current code on branch `main` (HEAD includes `bf25ab3f9`, `31553f639` "all bulk actions when filtered", `a01317b01` "fix bulk ai summaries").

## Files opened & traced
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb`
- `app/controllers/concerns/role_fit_filterable.rb`
- `app/interactors/queue_bulk_ai_summary_jobs.rb`
- `app/jobs/bulk_generate_ai_summaries_job.rb`
- `app/jobs/submit_resume_to_textract_job.rb`
- `app/services/submit_resume_to_textract.rb`
- `app/models/job_application.rb:110-115` (`with_resume`, `with_textract_results` scopes)
- `app/models/bulk_ai_summary_job_application.rb`
- `app/interactors/create_bulk_ai_summary_generation.rb`
- `app/models/textract_result.rb:61-111` (credit flow, `generate_ai_summary`, `set_initial_summary_pending`, `queue_ai_summary_job` bridge :114-144)
- `app/jobs/generate_ai_job_application_summary_job.rb`
- `app/services/ai_job_application_action/orchestrate.rb:1-49`
- `app/models/job.rb:914` (`should_auto_generate_ai_summaries?`)

## Verdicts (T8-relevant map claims)

**Map 125** — Controller resolves IDs server-side; `RoleFitFilterable` new.
AGREE. `bulk_ai_job_application_summaries_controller.rb:32-46` (`resolve_job_application_ids`); `apply_role_fit_filter` at `role_fit_filterable.rb:15`.

**Map 126** — `with_textract_results` is bare `joins(:textract_results)`, no text check; in_progress counts as ready and defers at iteration.
AGREE. `job_application.rb:115` `scope :with_textract_results, -> { joins(:textract_results) }`. Deferral: `bulk_generate_ai_summaries_job.rb:65-67` `update_columns(status: :deferred)`.

**Map 127** — `:current` status candidates dropped from BOTH ready_ids and input_ids.
AGREE. `queue_bulk_ai_summary_jobs.rb:36-40` (`ready_ids -= already_summarized_ids` :39, `input_ids -= already_summarized_ids` :40).

**Map 137** — Backfill `SubmitResumeToTextractJob` does NOT check `TEXTRACT_RESUME_PROCESSING`; the two pre-flight gates are `:17` AI_APPLICANT_SUMMARY and `:18` ai_credits_available?; backfill loop `:28-30` gated by neither; pending_textract_ids = `scope.with_resume.where.not(id: ready_ids).distinct.pluck(:id)` at `:23`.
AGREE. `queue_bulk_ai_summary_jobs.rb:17,18,23,28-30`. The loop calls bare `SubmitResumeToTextractJob.perform_later(id)`, no Flipper guard.

**Map 138** — Backfill loop enqueues unconditionally each call, no de-dup; `SubmitResumeToTextract` builds a NEW in_progress TextractResult (`submit_resume_to_textract.rb:22`, no find_or_create).
AGREE. `queue_bulk_ai_summary_jobs.rb:28-30`; `submit_resume_to_textract.rb:22` `@job_application.textract_results.build(textract_job_id: ..., textract_job_status: 'in_progress')`.

**Map 139** — Backfilled candidate AFTER Textract lands: bridge else/auto branch (`textract_result.rb:137`), no waiting summary (`:121-123` nil); auto-gen OFF returns at `:138` (status stays 'none', no summary); auto-gen ON enqueues `GenerateAiJobApplicationSummaryJob` no requesting user (`:142`) → S-C no-op (Orchestrate returns `orchestrate.rb:16`, credit flow returns `textract_result.rb:82`); both states produce no summary; processable only on subsequent bulk run.
AGREE. Bridge `textract_result.rb:121-123,137,138,142`. Trace of the auto-gen ON no-op verified: `generate_ai_job_application_summary_job.rb:32` calls `generate_ai_summary_with_credit_flow`; `textract_result.rb:67` latest_ai_summary nil → `:68` guard not hit → `:74` `generate_ai_summary` → `:110-111` `Orchestrate.new(...).call` → `orchestrate.rb:15` `.first` nil → `:16` return; back at credit flow `:77` nil → `:82` `return unless ...status_succeeded?`. No summary, no credit, status row stays 'none'.

**Map 144** — pending_textract (resume-but-no-Textract) candidates: captured at `:23`, backfilled `:28-30`; NOT in ready_ids/working_set/claimed_ids but ARE in input_ids → fold into `skipped_count` (`:88`/`:92`, empty-set `:51`); NO BulkAiSummaryJobApplication row; `context.any_textract_pending = pending_textract_ids.any?` (`:52`/`:93`) → controller JSON (`bulk_ai_job_application_summaries_controller.rb:23`).
AGREE. All cited lines confirmed. `working_set = ready_ids - already_claimed_ids` (`:47`); pending_textract_ids never enter ready_ids (`:22-23`), so excluded before the create loop (`:64-69`).

**Map 145** — No-resume candidates not in ready_ids/pending_textract_ids (both require `with_resume`), silently skipped, counted in skipped_count, no row, no backfill.
AGREE. `queue_bulk_ai_summary_jobs.rb:22-24`; `with_resume` = `joins(:resume_attachment)` (`job_application.rb:114`).

**Map 128/129** — Empty-working-set early return with queued_count=0, skipped_count=input_ids.size, any_textract_pending flag; no BulkGenerateAiSummariesJob enqueued, no on_complete, no toast/mailer.
AGREE. `queue_bulk_ai_summary_jobs.rb:49-54`.

**Map 130** — BulkGenerateAiSummariesJob enqueued with payload HASH (`:82-89`); counts `:91-93`.
AGREE.

**Map 146** — `already_claimed_ids` pre-filter (`:43-47`); `rescue ActiveRecord::RecordNotUnique` (`:70-75`) silent skip; re-query `:78-80` → folds into skipped_count `:88`.
AGREE.

**Map 131** — `BulkAiSummaryJobApplication` enum `{processing:0, done:1, failed:2, deferred:3}` _prefix:true; deferred for textract-pending-at-iteration (`bulk_generate_ai_summaries_job.rb:66`).
AGREE. `bulk_ai_summary_job_application.rb:10`.

**Map 132** — Bulk worker routes through `CreateBulkAiSummaryGeneration` before `generate_ai_summary_with_credit_flow` (`bulk_generate_ai_summaries_job.rb:74-80`).
AGREE.

**Map 133** — Per-iteration idempotency guard: succeeded/failed summary after claim row → :done, skip (`:48-56`).
AGREE. `bulk_generate_ai_summaries_job.rb:48-56`, `update_columns(status: :done)` `:54`.

**Map 140** — each_iteration guard order: idempotency `:48-56` → `return unless result.success?` `:60` → textract_pending→deferred `:65-67` → CreateBulkAiSummaryGeneration `:74` → credit flow `:80` → :done `:86`.
AGREE.

**Map 151** — `CreateBulkAiSummaryGeneration` reuse query `.where.not(status: :failed).where(stale: false)` (`:34-38`); `:45-48` returns regardless of status.
PARTIAL / borderline — AGREE on the cited query and the `:45-48` early return, but the map's "`:45-48` returns it regardless of status" SKIPS the intervening relink/stale step at `create_bulk_ai_summary_generation.rb:40-43`: `if active_ai_summary && active_ai_summary.textract_result_id != job_application.latest_textract_result&.id` → `active_ai_summary.update_columns(stale: true); active_ai_summary = nil`. So reuse does NOT happen unconditionally — an active summary pointing at a stale/older TextractResult is staled and discarded, falling through to the build at `:50-54`. This is an S-B (not strictly T8-backfill) detail; logged as an omission, not a DISPUTE of a false statement.

**Map 147/148/152** — bulk-success terminal status-row writes / broadcast / Orchestrate path.
AGREE on the cited lines for the happy path (`set_initial_summary_pending` `textract_result.rb:104-107`; Orchestrate `orchestrate.rb:15-16,46-48`). These are S-B happy-path, not the T8 backfill terminal, but the cited code is accurate.

## Omissions (T8 backfill slice)

1. **Backfill submit whose Textract API call fails creates NO TextractResult (distinct T8 terminal).** In `submit_resume_to_textract.rb`, `parser.send_to_textract(...)` runs at `:16`, BEFORE the TextractResult is built at `:22`. If `:16` raises (`Aws::Textract::Errors::InvalidS3ObjectException` or any StandardError), the rescue at `:31-40` runs `@textract_result&.update_columns(textract_job_status: 'failed')` but `@textract_result` is still nil, so NOTHING is written — no TextractResult is created at all. The backfilled candidate is left exactly resume-but-no-Textract, identical to its pre-backfill state, with no actor to advance it; it can only be retried by a SUBSEQUENT bulk run's backfill loop. The map's claim 139 covers the SUCCESS-then-lands case and the "subsequent bulk run" recovery, but never names the backfill-submit-FAILURE terminal where no TextractResult is produced. The job wrapper `submit_resume_to_textract_job.rb:9-11` rescues StandardError and only `ap`s, so the job itself does not retry either.

2. **`.distinct` is load-bearing on the readiness/backfill split and is unremarked.** `ready_ids = scope.with_resume.with_textract_results.distinct.pluck(:id)` (`queue_bulk_ai_summary_jobs.rb:22`) and `pending_textract_ids = scope.with_resume.where.not(id: ready_ids).distinct.pluck(:id)` (`:23`). Because `with_textract_results` is a bare `joins(:textract_results)` (`job_application.rb:115`) and a job_application `has_many :textract_results`, the join multiplies rows per candidate; `.distinct` is what prevents duplicate ids in `ready_ids`/`pending_textract_ids` (and thus duplicate backfill enqueues / duplicate skipped counts). The map quotes `.distinct` inside its line citations but never states that a candidate may have MULTIPLE TextractResults (e.g. from a prior failed backfill submit + a resubmit) and that `.distinct` is the dedup. This compounds with omission #1: a candidate with one prior failed TextractResult is already in `ready_ids` (the join matches the failed result), so it is NOT in `pending_textract_ids` and is NOT re-backfilled — it goes straight to the working set and defers/processes based on that failed result at iteration time.

## clean = false
Verdicts are AGREE except map-151 which is borderline (AGREE-with-caveat, logged as omission). Omissions list is non-empty (2 items). Therefore clean = false.

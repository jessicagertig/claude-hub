# T8 — Bulk AI Summary Backfill (resume-but-no-Textract) — Adversarial Review pass-5

**Slice:** T8 — `QueueBulkAiSummaryJobs` for the resume-but-no-Textract case; trace to terminal.
**Verdict:** clean = true. Every map claim verified AGREE against current code; no omissions found for the T8 slice.

## Files read (trace chain)
- `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb` (create → resolve_job_application_ids)
- `app/controllers/concerns/role_fit_filterable.rb` (apply_role_fit_filter)
- `app/interactors/queue_bulk_ai_summary_jobs.rb` (the slice core)
- `app/jobs/bulk_generate_ai_summaries_job.rb` (worker, on_complete, notify_*)
- `app/jobs/submit_resume_to_textract_job.rb` → `app/services/submit_resume_to_textract.rb`
- `app/interactors/create_bulk_ai_summary_generation.rb`
- `app/interactors/validate_ai_summary_generation.rb`
- `app/models/textract_result.rb:61-108` (generate_ai_summary_with_credit_flow, set_initial_summary_pending)
- `app/models/job_application.rb:110-115` (scopes with_resume, with_textract_results)
- `app/models/organization.rb:961` (ai_credits_available?)
- `app/models/bulk_ai_summary_job_application.rb:10` (enum)

## Claim-by-claim verdicts

**Map L104** — Controller resolves IDs server-side: `included_job_application_ids` OR (`hiring_stage_id` + role_fit filter − `excluded`). RoleFitFilterable concern new.
AGREE — `bulk_ai_job_application_summaries_controller.rb:34-45`; `apply_role_fit_filter(stage.job_applications, p[:role_fit])` at `:40`; concern at `role_fit_filterable.rb:10`, method at `:15`.

**Map L105** — `with_textract_results` is bare `joins(:textract_results)`; no text check; defers at iteration via `update_columns(status: :deferred)`.
AGREE — `job_application.rb:115` `scope :with_textract_results, -> { joins(:textract_results) }`; defer at `bulk_generate_ai_summaries_job.rb:65-67`, `update_columns(status: :deferred)` `:66`.

**Map L106** — `current` status candidates dropped from BOTH ready_ids and input_ids.
AGREE — `queue_bulk_ai_summary_jobs.rb:36-40`; `ready_ids -= already_summarized_ids` `:39`; `input_ids -= already_summarized_ids` `:40`. (`already_summarized_ids` computed from ready_ids only, `:37`, so pending_textract candidates are never subtracted from input_ids.)

**Map L116** — Backfill `SubmitResumeToTextractJob` does NOT check `TEXTRACT_RESUME_PROCESSING`; two pre-flight gates are `:17` AI_APPLICANT_SUMMARY + `:18` ai_credits_available?; backfill loop `:28-30` gated by neither; `pending_textract_ids` not in current run (`:23`).
AGREE — `queue_bulk_ai_summary_jobs.rb:17` `Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)`; `:18` `organization.ai_credits_available?`; loop `:28-30` ungated; `:23` `pending_textract_ids = scope.with_resume.where.not(id: ready_ids).distinct.pluck(:id)`. Verified `SubmitResumeToTextractJob#perform` and `SubmitResumeToTextract#submit_resume` contain NO Flipper check (the only early returns are `JobApplication not found` and `No resume attached`, service `:9-10`).

**Map L117** — No backfill idempotency/de-dup; `SubmitResumeToTextract` builds a NEW in_progress TextractResult each time (`:22`, no find_or_create).
AGREE — `queue_bulk_ai_summary_jobs.rb:28-30` enqueues unconditionally; `submit_resume_to_textract.rb:22` `@textract_result = @job_application.textract_results.build(textract_job_id: textract.job_id, textract_job_status: 'in_progress')` — `.build`, no find_or_create.

**Map L122 (defines T8)** — Resume-present/no-TextractResult candidates captured in `pending_textract_ids` (`:23`), backfilled (`:28-30`); NOT in ready_ids/working_set/claimed_ids but ARE in input_ids → fold into `skipped_count = input_ids.size - claimed_ids.size` (`:88`/`:92`; empty-set `:51`); receive NO BulkAiSummaryJobApplication row; `any_textract_pending = pending_textract_ids.any?` (`:52`,`:93`) surfaced via controller JSON (`bulk_ai_job_application_summaries_controller.rb:23`).
AGREE — all line refs verified. `working_set = ready_ids - already_claimed_ids` `:47`; pending_textract_ids are not in ready_ids (`:22-23`) so excluded from the create loop `:64-75`; skipped_count `:88`/`:92`, empty-set `:51`; `context.any_textract_pending` `:52` and `:93`; controller surfaces it `:23`.

**Map L125** — `CreateBulkAiSummaryGeneration` builds `:pending` summary (`:74`) before credit flow (`:80`); credit-flow `:68` early return can fire when it reuses a succeeded-non-stale active summary (`create_bulk_ai_summary_generation.rb:45-48`).
AGREE — `bulk_generate_ai_summaries_job.rb:74` (CreateBulkAiSummaryGeneration.call) then `:80` (generate_ai_summary_with_credit_flow); reuse branch `create_bulk_ai_summary_generation.rb:45-48` returns existing `active_ai_summary`; `textract_result.rb:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`.

## Terminal trace for the T8 case (resume present, no TextractResult)
1. Controller resolves ids → `QueueBulkAiSummaryJobs`.
2. `ready_ids` = with_resume + with_textract_results (`:22`) — excludes T8 candidate (no textract).
3. `pending_textract_ids` = with_resume, not in ready_ids (`:23`) — INCLUDES T8 candidate.
4. Backfill: `SubmitResumeToTextractJob.perform_later(id)` (`:28-30`), ungated by TEXTRACT_RESUME_PROCESSING → `SubmitResumeToTextract#submit_resume` builds a NEW `in_progress` TextractResult (`:22`) and schedules `GetResumeTextFromTextractJob` (`:27`). This is the advancing actor for the NEXT run; in the CURRENT run the candidate is NOT processed.
5. Current run: candidate not in ready_ids → not in working_set (`:47`) → no BulkAiSummaryJobApplication row created. Folds into `skipped_count` (`:88`/`:92`, or `:51`).
6. `any_textract_pending=true` surfaced via controller JSON (`:23`). No async toast/mailer for these specific candidates in the current run (they have no bulk row and on_complete counts only the claimed rows).
TERMINAL: candidate gets a fresh in_progress TextractResult that polls to succeeded/failed via GetResumeTextFromTextract; the bulk run itself leaves them skipped with no row. Advancing actor present (the backfilled Textract job + poll), so not a dead end for the candidate — but NOT generated/charged in this run.

## Omissions
None for the T8 slice. The map's Trigger 8 section (L103-125) covers the backfill, the ungated enqueue, the no-de-dup duplicate-TextractResult hazard, the counting fold, the no-row outcome, and the any_textract_pending signal.

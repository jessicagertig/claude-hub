# T1 — Pass 4 Adversarial Review

Slice: T1 — New job application created. Trigger `JobApplication after_commit :enqueue_new_job_application, on: [:create]` → `SubmitResumeToTextractJob`. Flipper gate `TEXTRACT_RESUME_PROCESSING`. Trace to terminal TextractResult state.

Files re-read from scratch:
- app/models/job_application.rb (callback registration `:45`, body `:164-171`, enum `:83-92`, `has_resume` `:589`)
- app/interactors/find_or_create_ai_job_application_summary_status.rb (full)
- app/services/submit_resume_to_textract.rb (full)
- app/services/get_resume_text_from_textract.rb (full)
- app/jobs/submit_resume_to_textract_job.rb (full)
- app/jobs/get_resume_text_from_textract_job.rb (full)
- app/models/textract_result.rb:1-20 (enum `:9-14`, callback `:7`)
- app/controllers/api/v1/public/jobs_controller.rb:28-97 (creation `.save`)
- grep: TEXTRACT_RESUME_PROCESSING (2 sites), insert_all (none for JobApplication), created_via assignments

## Verdicts

1. AGREE — Callback registered `job_application.rb:45` `after_commit :enqueue_new_job_application, on: [:create]`; body `:164-171`. Verified literal.
2. AGREE — `enqueue_new_job_application` UNCONDITIONALLY calls `find_or_create_ai_job_application_summary_status` at `:170`, OUTSIDE the Flipper `if` block (`:167-169`). Fresh app → else branch of interactor, `latest_ai_job_application_summary` nil → `:34` `status = 'none'`, `:37` save. Not Flipper-gated. Verified.
3. AGREE — `created_via` enum has 8 values `:83-92` (manual_add:0 … customer_api_import:7). Callback is `on: [:create]`, no created_via condition in `:164-171`. No `insert_all` for JobApplication (grep clean). Public job-board path saves via `.save` (`api/v1/public/jobs_controller.rb:43,84,92`), firing the create after_commit. `created_via` assigned at `:38`. All 8 reach it. Verified.
4. AGREE — Resume-less entry fork: `submit_resume_to_textract.rb:10` `return 'No resume attached' unless @job_application.has_resume`, before build `:22`. No TextractResult created. Verified.
5. AGREE — Self-healing re-submit: `get_resume_text_from_textract.rb:14-17` `if @textract_result.textract_job_id.nil?` → `SubmitResumeToTextractJob.perform_later` → `return`. Verified.
6. AGREE — Flipper gate at exactly two app sites: `job_application.rb:167`, `job_applications_controller.rb:113` (grep). For T1 it gates `SubmitResumeToTextractJob.perform_later(id)` at `:168`, scoped to `job.organization`. `job` is required belongs_to (`:13`), `job.organization` required (`job.rb:26`) — no nil-safety issue. Verified.
7. AGREE — Terminal TextractResult states: `in_progress` built `submit_resume_to_textract.rb:22` (saved `:24`) → non-resting, poll scheduled `:27`. Poll updates `succeeded` via `.update` (`get_resume_text_from_textract.rb:31`) firing `queue_ai_summary_job` (`textract_result.rb:7`), or `failed` via `update_columns` (`:40`/`:47`), or AWS-submit `failed` `update_columns` (`submit_resume_to_textract.rb:33,39`). Enum `not_started:0,in_progress:1,succeeded:2,failed:3` `_prefix:true` (`textract_result.rb:9-14`). Verified.
8. AGREE — Retry/exhaustion: `GetResumeTextFromTextractJob` `retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3` (`:6`); exhaustion → `cleanup_orphaned_summary` destroys `textract_processing` waiting summary + `AI_SUMMARY_FAILED` broadcast (`:7,:10-23`). No-op when no waiting summary (T1 fresh-create has none). Verified.
9. AGREE — Conditional stale `update_all`: `submit_resume_to_textract.rb:18` guard `unless ...textract_processing, stale:false...exists?`, `:19` `update_all(stale: true)`. On fresh T1 create no summaries exist → no-op. Verified.

## Omissions

None material. Map covers callback registration, the eager status-row creation, the Flipper gate (`:248,:251`), the resume-less fork, self-healing, terminal TextractResult states (state table `:516`), retry/exhaustion (`:240`), and source-agnostic 8-value reach (`:247`). The T1 changelog bullets (`:25`) omit re-stating that the no-resume fork is reachable only when the flag is ON, but `:248` and the gate table (`:587`) establish the gate; not an omission of substance.

## clean = true

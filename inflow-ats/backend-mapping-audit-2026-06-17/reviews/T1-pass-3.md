# T1 — Adversarial Review (pass 3)

Slice: T1 — New job application created. Trigger: `JobApplication after_commit :enqueue_new_job_application, on: [:create]` → `SubmitResumeToTextractJob`.

Re-read from scratch against current code. Each candidate-map statement marked AGREE (with code cite) or DISPUTE (with contradicting cite + correction).

## Files traced
`app/models/job_application.rb:45,164-171,83-92,160-162` → `app/interactors/find_or_create_ai_job_application_summary_status.rb:1-47` → `app/jobs/submit_resume_to_textract_job.rb:1-14` → `app/services/submit_resume_to_textract.rb:1-42` → `app/services/get_resume_text_from_textract.rb:1-54` → `app/jobs/get_resume_text_from_textract_job.rb:1-32` → `app/models/ai_job_application_summary_status.rb:1-25` → `app/controllers/api/v1/public/jobs_controller.rb:38,43,68,84,88,92` → `app/controllers/api/v1/job_applications_controller.rb:113`

## Verdicts

### Callback registration (map :21, :218)
"registered at `app/models/job_application.rb:45` (`after_commit :enqueue_new_job_application, on: [:create]`); body `:164-171`."
AGREE. `job_application.rb:45`: `after_commit :enqueue_new_job_application, on: [:create]`. Body `:164-171`.
(The MAP-WRONG note about the old map's `:150-156` is a comparison to the OLD map, not a current-code claim; current-code cites verified.)

### enqueue_new_job_application body (map :220)
"enqueues `NewJobApplicationJob` (:165), `DocxToPdfJob` (:166), then Flipper-gated `SubmitResumeToTextractJob.perform_later(id)` (:168), then UNCONDITIONALLY `find_or_create_ai_job_application_summary_status` (:170)."
AGREE. `job_application.rb:165` `NewJobApplicationJob.perform_later(id)`; `:166` `DocxToPdfJob.perform_later(id)`; `:167` `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)`; `:168` `SubmitResumeToTextractJob.perform_later(id)`; `:170` `find_or_create_ai_job_application_summary_status` (unconditional, outside the Flipper `if`).

### Flipper scope (map :220, :223)
"Flipper `TEXTRACT_RESUME_PROCESSING` scoped to `job.organization`. Checked at exactly two app sites: `job_application.rb:167` and `job_applications_controller.rb:113`."
AGREE. grep over `app/ lib/ config/` returns exactly two hits: `job_application.rb:167` (`job.organization`) and `job_applications_controller.rb:113` (`current_organization`). No others.

### Status-row eager creation, not Flipper-gated (map :22, :220)
"`find_or_create_ai_job_application_summary_status` (`:170`) eagerly creates the row (`'none'` on a fresh app via `:34` assign + `:37` save). Not Flipper-gated."
AGREE. Call sits at `job_application.rb:170` outside the Flipper `if` (`:167-169`). `find_or_create_ai_job_application_summary_status.rb`: fresh app → `@status_record = job_application.ai_job_application_summary_status` nil (`:9`), else-branch `:22`, `latest_ai_job_application_summary` nil so `:34` `@status_record.status = 'none'`, `:37` `unless @status_record.save`. Enum `none: 0` default (`ai_job_application_summary_status.rb:10`).

### created_via enum 8 values, all reach callback (map :23, :219)
"`created_via` enum has 8 values (`created_via_manual_add:0 … created_via_customer_api_import:7`; `:83-91`). Callback is `on: [:create]`, source-agnostic; all 8 reach it (no `insert_all` bypass; public controllers assign `params[:created_via]` at `api/v1/public/jobs_controller.rb:38`)."
AGREE. `job_application.rb:83-92` lists the 8 values exactly. `after_commit … on: [:create]` is source-agnostic. grep `insert_all|insert!|insert(` over app/lib shows no JobApplication insert_all (only a code comment at `queue_bulk_ai_summary_jobs.rb:59`). `public/jobs_controller.rb:38` `job_application.assign_attributes(created_via: params[:created_via]) if params.key?(:created_via)`, and that path persists via `.save` (`:43`, `:84`, `:92`) → callbacks fire.

### Resume-less entry fork (map :25, :221)
"T1 reaches `in_progress` ONLY when a resume is present; no resume → `SubmitResumeToTextract` returns `'No resume attached'` (`submit_resume_to_textract.rb:10`, before the build at `:22`) and creates NO TextractResult."
AGREE. `submit_resume_to_textract.rb:10` `return 'No resume attached' unless @job_application.has_resume`; build at `:22` `@job_application.textract_results.build(... textract_job_status: 'in_progress')`; save+poll-schedule only inside `if @textract_result.save` (`:24-27`).

### Self-healing re-submit (map :26, :222)
"On the poll path, a TextractResult with `textract_job_id` nil re-enqueues `SubmitResumeToTextractJob` and returns (`get_resume_text_from_textract.rb:14-17`)."
AGREE. `get_resume_text_from_textract.rb:14` `if @textract_result.textract_job_id.nil?`, `:15` `SubmitResumeToTextractJob.perform_later(@job_application.id)`, `:16` `return`.

### Terminal TextractResult state (map Part 1 :197-212)
T1 with resume present → `in_progress` (`submit_resume_to_textract.rb:22`) → poll job. Succeeded via `.update` (`get_resume_text_from_textract.rb:31`, sets `textract_job_status`, `textract_job_result`, `textract_job_result_text`) → fires `after_commit :queue_ai_summary_job`. AWS-failed → `update_columns(textract_job_status: 'failed')` (`:40`) + raise → retry. Other/still-processing → bare raise (`:44`) → retry. `InvalidJobIdException` → `update_columns(... 'failed', textract_job_id: nil)` (`:47`), no raise → terminal. Retry exhaustion: `retry_on CustomErrorTextract, attempts: 3` (`get_resume_text_from_textract_job.rb:6`) → `cleanup_orphaned_summary` (`:10-23`); on T1 fresh-create with no `textract_processing` summary it returns at `:16` and leaves the TextractResult intact.
AGREE on all cited transitions.

## Omissions
None found. The candidate map's T1 coverage (callback registration, body ordering, Flipper gating + scope + the two check sites, unconditional status-row creation at `'none'`, the 8 created_via values, the resume-less fork, the self-healing re-submit, and the terminal TextractResult states including retry exhaustion) is complete and each statement verifies against current code.

## clean
true

# T1 Adversarial Review — Pass 5

Slice T1: New job application created. Trigger: `JobApplication after_commit :enqueue_new_job_application, on: [:create]` → `SubmitResumeToTextractJob`.

Re-read from scratch against current code. Files opened:
- `app/models/job_application.rb` (callback :45, body :164-171, enum :83-92, has_resume :589-590)
- `app/services/submit_resume_to_textract.rb` (full)
- `app/jobs/submit_resume_to_textract_job.rb` (full)
- `app/services/get_resume_text_from_textract.rb` (full)
- `app/jobs/get_resume_text_from_textract_job.rb` (full)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (full)
- `app/models/textract_result.rb:1-145` (bridge :114-144, enum :9-14)
- `app/controllers/api/v1/public/jobs_controller.rb:30-49`
- grep: TEXTRACT_RESUME_PROCESSING (2 sites), created_via assignments, insert_all/import bypass (none)

## Verdicts

### AGREE — Callback registration `job_application.rb:45`
`after_commit :enqueue_new_job_application, on: [:create]` at line 45. Body `enqueue_new_job_application` at lines 164-171. Verified literally.

### AGREE — `find_or_create_ai_job_application_summary_status` is unconditional, not Flipper-gated (`job_application.rb:170`)
Line 170 `find_or_create_ai_job_application_summary_status` sits OUTSIDE the `if Flipper.enabled?` block (167-169). Status row created `'none'` on a fresh app via `find_or_create_ai_job_application_summary_status.rb:34` (`@status_record.status = 'none'`) + `:37` (`@status_record.save`); fresh app takes the else branch at `:22` (no pre-existing row) and the latest summary is nil so `:34` runs. Verified.

### AGREE — 8 `created_via` enum values, source-agnostic, no insert_all bypass
Enum at `job_application.rb:83-92` has exactly 8 values (manual_add:0, job_board:1, api:2, referral:3, bulk_manual_add:4, clone:5, customer_api_apply:6, customer_api_import:7). `on: [:create]` fires for any committed INSERT. Grep for `insert_all`/`.import` on JobApplication returned only a route comment (`api_public/.../job_applications_controller.rb:96`), no bulk-insert bypass. Public path assigns `params[:created_via]` at `jobs_controller.rb:38` and persists via `.save` (`:43`). Verified.

### AGREE — Flipper `TEXTRACT_RESUME_PROCESSING` gates only the Textract submit, scoped to `job.organization`, at exactly two app sites
`job_application.rb:167` `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` wraps ONLY `SubmitResumeToTextractJob.perform_later(id)` (`:168`). Grep across app/lib/config returns exactly two hits: `job_application.rb:167` (model) and `job_applications_controller.rb:113` (controller, T2). Map's "exactly two app sites" (line 284) verified.

### AGREE — resume-less entry fork: no resume → no TextractResult
`submit_resume_to_textract.rb:10` `return 'No resume attached' unless @job_application.has_resume` returns before the build at `:22`. `has_resume` = `resume.attached?` (`job_application.rb:589-590`). No TextractResult created. Verified. (Caveat noted under omissions: this in-service early-return is only REACHED when the flag is ON; flag OFF means the job is never enqueued — the map covers this at line 284 / dead-end census line 573.)

### AGREE — `in_progress` only when resume present at creation
`submit_resume_to_textract.rb:22` `textract_results.build(..., textract_job_status: 'in_progress')`, saved at `:24`. Reached only past the `has_resume` guard at `:10`. Verified.

### AGREE — self-healing re-submit on poll path (`get_resume_text_from_textract.rb:14-17`)
`if @textract_result.textract_job_id.nil?` → `SubmitResumeToTextractJob.perform_later(@job_application.id)` → `return` (lines 14-17). Verified.

### AGREE — bridge fires from `.update` poll write; T1 takes the else/auto branch
`get_resume_text_from_textract.rb:31` `@textract_result.update(update_textract_params)` (the SOLE callback-firing write, writes both `textract_job_status` and `textract_job_result_text`). Fires `after_commit :queue_ai_summary_job` (`textract_result.rb:7`). Guard `:115` `return unless textract_job_result_text.present?`, `:116` `return unless saved_change_to_textract_job_result_text?`. On a fresh T1 app there is no `textract_processing` waiting summary (T1 creates none), so the IF at `:125` is false and the else branch (`:137-143`) runs, gated on `should_auto_generate_ai_summaries?` (`:138`). Verified.

### AGREE — terminal TextractResult states for T1
- `succeeded`: `get_resume_text_from_textract.rb:31` `.update(textract_job_status: 'succeeded'...)`.
- `failed`: `:40` `update_columns(textract_job_status: 'failed')` (AWS failed) then raise → retry; `:47` InvalidJobIdException terminal; `submit_resume_to_textract.rb:33/39` on AWS submit errors.
- retry exhaustion: `get_resume_text_from_textract_job.rb:6` `retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3` → `cleanup_orphaned_summary` (`:10-23`) — no-op for fresh T1 (no `textract_processing` waiting summary). Failed/stuck TextractResult left intact (no further actor). Verified.

### AGREE — callback ordering NewJobApplicationJob/DocxToPdfJob before submit
`job_application.rb:165` `NewJobApplicationJob`, `:166` `DocxToPdfJob`, both before the gated `SubmitResumeToTextractJob` at `:168`. `SubmitResumeToTextract` prefers `resume_docx_to_pdf` (`submit_resume_to_textract.rb:15`). Verified.

## Omissions

1. **`enqueue_new_job_application` reads `job.organization` (`:167`) and `job` (`:192`, set_initial_hiring_stage) — a job-less job_application would raise in the callback.** Not a T1 terminal concern (a job_application always belongs_to :job, `job_application.rb:13`), but the map's T1 section does not note that the Flipper scope dereferences `job.organization` unconditionally. Minor; non-blocking.

2. **Map T1 section (line 282) states "no resume → returns 'No resume attached'" without restating that this in-service early-return is only reached when the flag is ON.** The map DOES cover the flag-OFF case at line 284 and the dead-end census (line 573 "Also gated OFF by TEXTRACT_RESUME_PROCESSING"), so this is covered globally, just not co-located in the T1 narrative bullet. Not a defect — informational.

No DISPUTES. Every T1 statement in the candidate map verified against literal current code.

## Record-write sites on the T1 slice (for coverage cross-check)
- `submit_resume_to_textract.rb:19` `@job_application.ai_job_application_summaries.update_all(stale: true)` — col `stale`, update_all (no-op on fresh T1, zero summaries).
- `submit_resume_to_textract.rb:24` `@textract_result.save` (built `:22`) — TextractResult cols `textract_job_id`, `textract_job_status='in_progress'`, insert.
- `submit_resume_to_textract.rb:26` `waiting_summary&.update_columns(textract_result_id: ...)` — no-op on fresh T1.
- `submit_resume_to_textract.rb:33/39` `@textract_result&.update_columns(textract_job_status: 'failed')` — update_columns.
- `get_resume_text_from_textract.rb:31` `@textract_result.update(...)` — cols `textract_job_status`, `textract_job_result`, `textract_job_result_text`; .update (callback-firing).
- `get_resume_text_from_textract.rb:40` `update_columns(textract_job_status: 'failed')`.
- `get_resume_text_from_textract.rb:47` `update_columns(textract_job_status: 'failed', textract_job_id: nil)`.
- `find_or_create_ai_job_application_summary_status.rb:37` `@status_record.save` — AiJobApplicationSummaryStatus cols `status='none'`, insert (fresh T1).

# T1 Adversarial Review — pass-7

**Slice:** T1 — New job application created. Trigger: `JobApplication after_commit :enqueue_new_job_application, on: [:create]` → `SubmitResumeToTextractJob`.
**Method:** Re-read all relevant code from scratch; attempted to refute each candidate-map statement against literal code (file:line).
**Verdict:** clean = true. Every T1 statement AGREE; no omissions found.

## Trace chain followed
`app/models/job_application.rb:45` (registration)
→ `job_application.rb:164-171` (`enqueue_new_job_application`)
→ `job_application.rb:167-168` (Flipper `TEXTRACT_RESUME_PROCESSING` gate → `SubmitResumeToTextractJob.perform_later`)
→ `job_application.rb:160-161` / `app/interactors/find_or_create_ai_job_application_summary_status.rb` (status row, unconditional)
→ `app/jobs/submit_resume_to_textract_job.rb:6-12`
→ `app/services/submit_resume_to_textract.rb:8-41`
→ `app/jobs/get_resume_text_from_textract_job.rb:6,25-27` (`retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3`)
→ `app/services/get_resume_text_from_textract.rb:8-49` (terminal TextractResult states)
Side chains: `app/models/textract_result.rb:7,9-14` (bridge callback + enum); `app/controllers/api/v1/public/jobs_controller.rb:38,42` (created_via source assign + save); `app/controllers/api/v1/job_applications_controller.rb:113` (the second/only-other Flipper app site).

## Statement-by-statement

### AGREE — callback registration
`job_application.rb:45` `after_commit :enqueue_new_job_application, on: [:create]`. No `if:`/`unless:`. Body at `:164-171`. Confirmed.

### AGREE — unconditional status-row creation
`job_application.rb:170` `find_or_create_ai_job_application_summary_status` runs outside the Flipper `if`. Method at `:160-161` → `FindOrCreateAiJobApplicationSummaryStatus.call(job_application: self)`. Fresh app (no summaries) → interactor `:27` false → `:34` `@status_record.status = 'none'` → `:37` save. Not Flipper-gated. Confirmed.

### AGREE — created_via enum has 8 values
`job_application.rb:83-91`: manual_add:0, job_board:1, api:2, referral:3, bulk_manual_add:4, clone:5, customer_api_apply:6, customer_api_import:7. Confirmed.

### AGREE — all 8 sources reach the callback, no insert_all bypass
Callback is `on: [:create]`, no conditional. `grep insert_all|import(` over `app/` for job_application returned nothing — no callback-bypassing bulk insert. Public controller assigns `params[:created_via]` at `public/jobs_controller.rb:38` then `.save` `:42`. Confirmed.

### AGREE — Flipper gate location and scope
`job_application.rb:167` `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` gating `:168` `SubmitResumeToTextractJob.perform_later(id)`. Confirmed. Flag OFF → no submit job, status row still created.

### AGREE — Flipper checked at exactly two app sites
`grep TEXTRACT_RESUME_PROCESSING` over `app/ lib/ config/` returns EXACTLY two hits: `job_application.rb:167` and `job_applications_controller.rb:113`. Confirms "NOT in QueueBulkAiSummaryJobs, ValidateAiSummaryGeneration" (both under app/). Confirmed.

### AGREE — resume-less entry fork → no TextractResult
`submit_resume_to_textract.rb:10` `return 'No resume attached' unless @job_application.has_resume` precedes the build at `:22`. `has_resume` at `job_application.rb:589`. Confirmed.

### AGREE — flag-precedence note (flag OFF → in-service guard never reached)
With flag OFF, `job_application.rb:167-168` never enqueues, so `submit_resume_to_textract.rb:10` is never reached. Same terminal (no TextractResult) via two mechanisms. Confirmed.

### AGREE — self-healing re-submit on poll
`get_resume_text_from_textract.rb:14-17`: `if @textract_result.textract_job_id.nil?` → `SubmitResumeToTextractJob.perform_later(@job_application.id)` then `return`. Confirmed.

### AGREE — `in_progress` build + advancing actor
`submit_resume_to_textract.rb:22` builds `textract_job_status: 'in_progress'`, saved `:24`, then `:27` schedules `GetResumeTextFromTextractJob.set(wait: 2.minutes)`. Non-resting → poll job. Confirmed.

### AGREE — terminal states
succeeded: `get_resume_text_from_textract.rb:31` `.update(...)` (callback-firing, fires bridge `textract_result.rb:7`). AWS-failed: `:40` `update_columns(textract_job_status: 'failed')` + `:41` `raise CustomErrorTextract` → retry ≤3 then `cleanup_orphaned_summary` (job `:6-8`). InvalidJobId: `:47` terminal. Submit-rescue failed: `submit_resume_to_textract.rb:33,39`. "No TextractResult ever created" dead end at `:10`. All confirmed.

### AGREE — TextractResult enum
`textract_result.rb:9-14` `{not_started:0,in_progress:1,succeeded:2,failed:3} _prefix:true`. Confirmed.

## Omissions
None found for the T1 slice. The map covers: registration line, unconditional status-row creation, created_via enum (8 values), source-agnosticism + no-bypass, both Flipper sites + scope, resume-less fork, flag-precedence interaction, self-healing re-submit, all TextractResult terminal states, and the poll job retry config.

## Record-write sites on the T1 path (for coverage cross-check)
- `find_or_create_ai_job_application_summary_status.rb:37` — `@status_record.save` writes `status` (`'none'` on fresh T1) — AiJobApplicationSummaryStatus — save (build then save).
- `submit_resume_to_textract.rb:19` — `update_all(stale: true)` — AiJobApplicationSummary.stale — update_all (no-op on fresh T1, zero summaries).
- `submit_resume_to_textract.rb:22/24` — `textract_results.build(... 'in_progress')` + `.save` — TextractResult.textract_job_status, textract_job_id — save.
- `submit_resume_to_textract.rb:26` — `waiting_summary&.update_columns(textract_result_id:)` — AiJobApplicationSummary.textract_result_id — update_columns (no-op on fresh T1).
- `submit_resume_to_textract.rb:33,39` — `@textract_result&.update_columns(textract_job_status: 'failed')` — TextractResult.textract_job_status — update_columns.
- `get_resume_text_from_textract.rb:31` — `.update(textract_job_status, textract_job_result, textract_job_result_text)` — TextractResult — update (callback-firing, sole bridge trigger).
- `get_resume_text_from_textract.rb:40` — `update_columns(textract_job_status: 'failed')` — TextractResult — update_columns.
- `get_resume_text_from_textract.rb:47` — `update_columns(textract_job_status: 'failed', textract_job_id: nil)` — TextractResult — update_columns.

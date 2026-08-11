# T1 — Adversarial Review (pass-6)

Slice T1: New job application created. Trigger `JobApplication after_commit :enqueue_new_job_application, on: [:create]` → `SubmitResumeToTextractJob`. All creation sources, the `TEXTRACT_RESUME_PROCESSING` Flipper gate, terminal TextractResult state.

## Trace chains followed
- `app/models/job_application.rb:45` (registration) → `:164-171` (`enqueue_new_job_application`) → `:167` (Flipper) → `:168` (`SubmitResumeToTextractJob.perform_later`) → `:170` (`find_or_create_ai_job_application_summary_status`)
- `app/jobs/submit_resume_to_textract_job.rb:6-12` → `app/services/submit_resume_to_textract.rb:8-41`
- `app/jobs/get_resume_text_from_textract_job.rb:6-31` → `app/services/get_resume_text_from_textract.rb:8-49`
- `app/models/textract_result.rb:7` (after_commit) → `:114-144` (`queue_ai_summary_job`)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb:6-45`
- `app/models/job_application.rb:589` (`has_resume`), `:83-92` (`created_via` enum)
- `app/controllers/api/v1/public/jobs_controller.rb:36-38`; `app/interactors/create_candidate_job_application.rb:16,27`

## Verdicts — every T1 map statement AGREE

1. **Callback registration `job_application.rb:45`, body `:164-171`** — AGREE. `:45` `after_commit :enqueue_new_job_application, on: [:create]`; def `:164`, `end` `:171`.
2. **`:170` unconditionally calls `find_or_create_ai_job_application_summary_status`, not Flipper-gated** — AGREE. `:170` is outside the `if Flipper.enabled?` block (`:167-169`).
3. **Status row `'none'` on fresh app via `find_or_create_…status.rb:34` assign + `:37` save** — AGREE. `:34` `@status_record.status = 'none'`; `:37` `unless @status_record.save`.
4. **`created_via` 8 values, `:83-91`; callback `on: [:create]` source-agnostic; all 8 reach it; no insert_all bypass; public controller assigns `params[:created_via]` at `jobs_controller.rb:38`** — AGREE. Enum `:83-92` matches. Registration `:45` has no `if:`. No `insert_all`/`import` job_application path exists (all creation via `.build`/`.save`/`.push`). `jobs_controller.rb:38` `assign_attributes(created_via: params[:created_via]) if params.key?(:created_via)`.
5. **Flipper gate `:167` scoped to `job.organization`, gates `SubmitResumeToTextractJob` at `:168`** — AGREE. Only two `TEXTRACT_RESUME_PROCESSING` refs in app code; T1's is `:167`.
6. **Resume-less entry fork: no resume → `'No resume attached'` `submit_resume_to_textract.rb:10`, before build `:22`, no TextractResult** — AGREE. `:10` returns before `:22` build.
7. **Self-healing re-submit `get_resume_text_from_textract.rb:14-17` when `textract_job_id` nil** — AGREE. `:14` if nil, `:15` re-enqueue, `:16` return.
8. **Flag-precedence on no-resume: flag OFF → submit never enqueued (`:167-168`), in-service `:10` guard never reached** — AGREE.
9. **Flipper-scope deref `job.organization` at `:167` (dependency, not hazard; belongs_to :job)** — AGREE. `belongs_to :job` at `:13`.
10. **Callback ordering: `NewJobApplicationJob` `:165`, `DocxToPdfJob` `:166` BEFORE Textract `:168`** — AGREE.
11. **Terminal TextractResult states (state-table 5.1): `in_progress` build `:22` saved `:24`; `succeeded` via `.update` `:31` (fires bridge); `failed` AWS `:40`+raise `:41`; `failed` InvalidJobId `:47`; `failed` submit-rescue `:33,39`** — AGREE on all writers and line numbers.
12. **Terminal: `succeeded` `.update` at `get_resume_text_from_textract.rb:31` is the sole callback-firing write and triggers `queue_ai_summary_job` via `saved_change_to_textract_job_result_text?`** — AGREE. `:31` `.update`; bridge guard `textract_result.rb:116`.
13. **Dead-end census line 601: no-TextractResult terminal applies at T1 entry (no resume); also flag-OFF model-side `:167`** — AGREE.

## Omissions
None for T1. Every load-bearing T1 fact (callback registration + body, status-row creation, created_via source-agnosticism, Flipper gate location/scope, resume-less fork, self-healing re-submit, callback ordering, and all terminal TextractResult writers) is present and correctly cited.

## Record-write sites on the T1 slice (cross-check)
- `submit_resume_to_textract.rb:19` `ai_job_application_summaries.update_all(stale: true)` — AiJobApplicationSummary.stale — update_all (no-op on fresh T1; zero summaries)
- `submit_resume_to_textract.rb:22/24` build + save `textract_job_status: 'in_progress'` — TextractResult — create
- `submit_resume_to_textract.rb:33,39` `update_columns(textract_job_status: 'failed')` — TextractResult — update_columns
- `get_resume_text_from_textract.rb:31` `.update(textract_job_status, textract_job_result, textract_job_result_text)` — TextractResult — update (callback-firing)
- `get_resume_text_from_textract.rb:40` `update_columns(textract_job_status: 'failed')` — TextractResult — update_columns
- `get_resume_text_from_textract.rb:47` `update_columns(textract_job_status: 'failed', textract_job_id: nil)` — TextractResult — update_columns
- `find_or_create_ai_job_application_summary_status.rb:37` `@status_record.save` (status `'none'`, `:34`) — AiJobApplicationSummaryStatus — create

## Verdict
clean = true. Every T1 statement AGREE; no omissions.

# T5 — Customer API Import: Textract Triggering Trace

**Angle:** T5 — Customer API import path; trace Textract triggering to terminal.

## Files traced (chain)

```
app/controllers/api_public/v1/hire/job_applications_controller.rb:97 (import action)
  -> app/interactors/customer_api/validate_job_application_import.rb:7 (call)
  -> app/interactors/customer_api/create_job_application.rb:6 (call)
       (shared with apply path; builds candidate + job_application, attaches resume if present)
  -> candidate.save / job_application build
  -> app/models/job_application.rb:45 (after_commit :enqueue_new_job_application, on: [:create])
  -> app/models/job_application.rb:164 (enqueue_new_job_application)
       -> app/jobs/submit_resume_to_textract_job.rb:6 (perform)  [Flipper-gated]
            -> app/services/submit_resume_to_textract.rb:8 (submit_resume)
                 -> [has_resume guard line 10] -> TextractResult build/save (line 22-24)
                 -> GetResumeTextFromTextractJob.set(wait: 2.minutes) (line 27)  [terminal Textract polling — T1/T2 territory]
       -> app/models/job_application.rb:170 (find_or_create_ai_job_application_summary_status)
            -> app/interactors/find_or_create_ai_job_application_summary_status.rb:6 (call)
```

## Key findings

### 1. Import endpoint wiring (CONFIRMED, with one structural difference vs apply)
`import` action (`job_applications_controller.rb:97`) calls **only two** interactors inside the transaction:
`CustomerApi::ValidateJobApplicationImport.call` (line 104) then `CustomerApi::CreateJobApplication.call` (line 107). It does **NOT** call `CompleteJobApplication` (the `apply` action does, at line 75). Neither validator nor creator touches Textract; Textract is triggered purely by the `JobApplication` create callback.

- **Old map (line 111-116):** "Trigger 5: Customer API — Import. Same as Apply, different endpoint. Same interactor chain as Apply. `created_via: 'created_via_customer_api_import'`."
- **Verdict:** CHANGED. The import chain is NOT identical to apply — import omits `CompleteJobApplication`. The `created_via` value is correct (`created_via_customer_api_import: 7`, `job_application.rb:91`).

### 2. Textract trigger is the shared create callback (CONFIRMED)
`job_application.rb:45`: `after_commit :enqueue_new_job_application, on: [:create]`. Body at `job_application.rb:164-171`. Textract enqueue is gated:
`job_application.rb:167-168`: `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` then `SubmitResumeToTextractJob.perform_later(id)`.
The `created_via` value does NOT branch the Textract path — import and apply hit the identical callback. (`created_via_customer_api_import?` only used at `job_application.rb:272` for activity-log key selection, not Textract.)

- **Old map (line 684-685, Trigger Matrix rows 4/5):** Customer API apply/import — entry "Interactor → candidate.save → after_commit", Flipper "TEXTRACT_RESUME_PROCESSING".
- **Verdict:** CONFIRMED.

### 3. NEW unconditional companion-record creation on the import path
`job_application.rb:170`: `find_or_create_ai_job_application_summary_status` is called **unconditionally** in `enqueue_new_job_application` (outside the Flipper guard). For a fresh import it builds an `AiJobApplicationSummaryStatus` with `status: 'none'` and saves it (`find_or_create_ai_job_application_summary_status.rb:25,34,37`).

- **Old map:** ABSENT — the old map's Trigger 1 / Trigger 4-5 list only `NewJobApplicationJob`, `DocxToPdfJob`, and `SubmitResumeToTextractJob` as callback work (lines 73-74, 681). It does not mention the status-record creation, and has no section for `AiJobApplicationSummaryStatus` creation at job_application create time.
- **Verdict:** NEW.

### 4. Resume is OPTIONAL on import — no-resume path is a terminal dead end for Textract (NEW / nuance)
`validate_job_application_import.rb:62-63`: `validate_resume` returns early `unless context.resume_params.present?` — resume is not required. With no resume, `create_job_application.rb:70-71` `attach_resume` no-ops (`return unless context.decoded_resume.present?`). The job_application is created with no resume.
Then `submit_resume_to_textract.rb:10`: `return 'No resume attached' unless @job_application.has_resume` — the service exits immediately, **no `TextractResult` is ever created, and `GetResumeTextFromTextractJob` is never enqueued** (it is scheduled only inside the `if @textract_result.save` block at line 24-27).

- **Old map:** Does not call out that import allows no resume. The Trigger Matrix (line 685) implies import always has a base64 resume.
- **Verdict:** NEW. Terminal state for no-resume import: TextractResult absent; `AiJobApplicationSummaryStatus` exists at `status: 'none'`; nothing further advances it (no dead-end *summary* because none was created — this is a benign rest, not a stuck summary).

### 5. With a resume: Textract submission to terminal handoff (CONFIRMED — shared with T1)
`submit_resume_to_textract.rb`:
- line 18-20: stale-marking guard — `unless ai_job_application_summaries.where(status: :textract_processing, stale: false).exists?` then `update_all(stale: true)`. On a fresh import there are zero summaries, so `update_all(stale: true)` runs against an empty relation (no-op).
- line 22: `@textract_result = @job_application.textract_results.build(textract_job_id: textract.job_id, textract_job_status: 'in_progress')`.
- line 24-27: on save, finds a `textract_processing`/`stale:false`/`textract_result_id:nil` waiting summary (none on fresh import), then `GetResumeTextFromTextractJob.set(wait: 2.minutes).perform_later`.
- TextractResult reaches a terminal status (`succeeded`/`failed`) inside `GetResumeTextFromTextract` polling — that lifecycle belongs to sibling slices T1/T2; this slice hands off at line 27.

- **Old map (lines 33-42):** Submission service description.
- **Verdict:** CONFIRMED for the submission step. Note line 22 uses `textract_results.build` + `save` (no longer the old map's implied direct `create`), but behavior matches.

## Branch logic (per task requirement)
On the import path the "no usable Textract result" branch is reached purely by the `has_resume` guard in the service, NOT by an AI-summary code path: a fresh import has no `textract_processing` summary to transition. There is no summary record on this slice unless a later auto/manual generation occurs. So:
- **No resume:** `submit_resume_to_textract.rb:10` returns; Textract never starts. (branch: no-resume.)
- **Resume present:** TextractResult built `in_progress` (`submit_resume_to_textract.rb:22`); polling scheduled (line 27); bridge to AI pipeline is the `TextractResult` after_commit callback — out of T5 scope.

## Desync window
- **`AiJobApplicationSummaryStatus` created at `status: 'none'`** on every import (`find_or_create_ai_job_application_summary_status.rb:34`) regardless of whether Textract/AI ever runs. For a no-resume import, the status row rests at `none` permanently with no associated summary — consistent, not desynced. No desync surface originates on T5 itself; desync windows arise downstream when a summary later succeeds (T2/T3 slices).

## Record-write sites on this slice

| file:line | literal | column(s) | op |
|---|---|---|---|
| `app/interactors/customer_api/create_job_application.rb:63` | `candidate.save` | (candidate + nested job_application via autosave) | save (insert) |
| `app/models/job_application.rb:168` | `SubmitResumeToTextractJob.perform_later(id)` | (enqueue only — no DB write) | enqueue |
| `app/services/submit_resume_to_textract.rb:19` | `@job_application.ai_job_application_summaries.update_all(stale: true)` | `stale` | update_all (no-op on fresh import; only relevant on re-import/replace) |
| `app/services/submit_resume_to_textract.rb:22,24` | `textract_results.build(...).save` | `textract_job_id`, `textract_job_status` (=in_progress) | save (insert) |
| `app/services/submit_resume_to_textract.rb:26` | `waiting_summary&.update_columns(textract_result_id: @textract_result.id)` | `textract_result_id` | update_columns (no waiting summary on fresh import) |
| `app/services/submit_resume_to_textract.rb:33,39` | `@textract_result&.update_columns(textract_job_status: 'failed')` | `textract_job_status` | update_columns (AWS-error path) |
| `app/interactors/find_or_create_ai_job_application_summary_status.rb:37` | `@status_record.save` (built with `status: 'none'`, line 34) | `status`, `job_application_id` | save (insert) |

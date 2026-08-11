# T5 — Customer API Import — Adversarial Review (pass 5)

Slice: T5 (Customer API import path; Textract triggering to terminal).
Method: re-read current code from scratch, refute candidate map `backend-flow-map-2026-06-17.md`.

## Files traced
- `app/controllers/api_public/v1/hire/job_applications_controller.rb` (import action `:97-126`, `job_application_context` `:201-215`)
- `config/routes.rb:502` (`post :import`)
- `app/interactors/customer_api/validate_job_application_import.rb` (whole file)
- `app/interactors/customer_api/create_job_application.rb` (whole file)
- `app/models/job_application.rb:44-48` (callbacks), `:83-92` (created_via enum), `:164-171` (enqueue_new_job_application), `:589` (has_resume)
- `app/services/submit_resume_to_textract.rb` (whole file)
- `app/jobs/get_resume_text_from_textract_job.rb`
- `app/services/get_resume_text_from_textract.rb` (whole file)
- `app/models/textract_result.rb` (callback `:7`, bridge `:114-144`, credit flow `:61-89`, set_initial_summary_pending `:98-108`)
- `app/jobs/generate_ai_job_application_summary_job.rb` (whole file)
- `app/services/ai_job_application_action/orchestrate.rb:5-50`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb:1-40`
- `app/models/job.rb:914` (should_auto_generate_ai_summaries?)

## Verdicts

### Changelog T5 (lines 66-77) and Trigger-5 section (326-336)

1. "Import action calls only ValidateJobApplicationImport + CreateJobApplication inside the transaction (`controller :104,107`); does NOT call CompleteJobApplication." — **AGREE.** `controller :104` `CustomerApi::ValidateJobApplicationImport.call(ctx)`, `:107` `CustomerApi::CreateJobApplication.call(@result)`, both inside `ActiveRecord::Base.transaction do` `:103`. No CompleteJobApplication anywhere in `import` (`:97-126`).

2. Duplicate terminal: `check_duplicate` fail `:55-59` when `existing_application` present `:52-53` → controller `:105` rollback → 409. — **AGREE.** `validate_job_application_import.rb:52` `existing_application = candidate.job_applications.find_by(job_id: context.job.id)`, `:53` `return unless existing_application`, `:55-59` `context.fail!(duplicate: true, existing_job_application_id:, duplicate_email:)`. Controller `:105` `raise ActiveRecord::Rollback if @result.failure?`; `:113-120` renders 409 `:conflict`.

3. question_responses rejection terminal (import-only): `reject_question_responses` fail when `context.question_responses_params.present?` `:22,24-26`. — **AGREE.** `:21-27` method; `:22` guard; `:24-26` `context.fail!`.

4. Resume validation rejection: `validate_resume` `context.fail!(error_code: 'file_too_large')` when `decoded.bytesize > 10.megabytes` `:69-75`, decode/metadata error accumulation `:66,77`. — **AGREE** on every behavioral line. `:69` `if decoded.bytesize > 10.megabytes`, `:70-73` fail, `:66` `decode_base64(...)`, `:77` `resolve_file_metadata(...)`. NOTE: the cited method range "`:62-79`" undercounts; the method body is `:62-83` (assignments `:80-82`, `end :83`). Range imprecision only; all cited behavioral lines correct, so AGREE.

5. `created_via: :created_via_customer_api_import` (controller `:101`; enum 7, `job_application.rb:91`). — **AGREE.** Controller `:101` `job_application_context(:created_via_customer_api_import)`; enum `created_via_customer_api_import: 7` at `job_application.rb:91`.

6. enqueue_new_job_application enqueues NewJobApplicationJob `:165` + DocxToPdfJob `:166` BEFORE gated SubmitResumeToTextractJob `:168`; DocxToPdf preferred (`submit_resume_to_textract.rb:15`). — **AGREE.** `job_application.rb:165` NewJobApplicationJob, `:166` DocxToPdfJob, `:167` Flipper gate, `:168` SubmitResumeToTextractJob; `submit_resume_to_textract.rb:15` `@job_application.has_resume_docx_to_pdf ? @job_application.resume_docx_to_pdf : @job_application.resume`. (File actually at `app/services/submit_resume_to_textract.rb`; line numbers correct.)

7. Resume-present terminal gated by `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` (`job_application.rb:167-169`): flag OFF → NO TextractResult. — **AGREE.** `:167` `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)`, `:168` enqueue, `:169` `end`.

8. Resume OPTIONAL on import (`validate_job_application_import.rb:62-63`); no resume → "No resume attached" (`submit_resume_to_textract.rb:10`) → no TextractResult, no poll. — **AGREE.** `validate_job_application_import.rb:63` `return unless context.resume_params.present?`; `submit_resume_to_textract.rb:10` `return 'No resume attached' unless @job_application.has_resume` (before build `:22`, poll schedule `:27`).

9. Existing-candidate persists via `job.candidates.push(candidate)` (`create_job_application.rb:40`); new-candidate via `save_new_candidate` → `candidate.save` (`:62-68`); both fire `on: [:create]` after_commit → Textract terminal unchanged. — **AGREE.** `:40` `job.candidates.push(candidate)`, `:62-68` `save_new_candidate`, `:63` `candidate.save`; `job_application.rb:45` `after_commit :enqueue_new_job_application, on: [:create]`.

10. New candidate built `created_via: :created_via_customer_api` (`create_job_application.rb:47`). — **AGREE.** `:46-48` `organization.candidates.build(... .merge(created_via: :created_via_customer_api))`, the merge at `:47`.

11. Resume-present import (flag ON) with auto-gen on lands in the S-C NO-OP dead end (no pre-existing summary: Orchestrate returns `orchestrate.rb:16`; credit flow returns `textract_result.rb:82`). — **AGREE.** Bridge else branch (no waiting summary on fresh import: query `textract_result.rb:121-123` returns nil): `:138` `return unless ...should_auto_generate_ai_summaries?`, `:140` ValidateAiSummaryGeneration, `:142` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id) if result.success?` (no requesting user). Job `:32` calls `generate_ai_summary_with_credit_flow`; `:67` `latest_ai_summary` nil → `:68` no return; `:72` set_initial_summary_pending early-returns (`:100-101` no latest_summary); `:74` generate_ai_summary → Orchestrate `:15` latest summary nil → `:16` `return unless @ai_job_application_summary`; back in credit flow `:77` nil → `:82` `return unless ai_job_application_summary&.status_succeeded?`. No summary, no credit, no broadcast (`:34` skipped, no requesting user).

12. `enqueue_new_job_application` creates the status row ('none') on every import (`job_application.rb:170`). — **AGREE.** `:170` `find_or_create_ai_job_application_summary_status`; fresh import → else branch `find_or_create_ai_job_application_summary_status.rb:22`, no latest summary `:27` false → `:34` `status = 'none'`, `:37` save.

### Part 7 matrix row (line 655)
"5 | Customer API import | import (`:104,107`) → 2 interactors | Base64 (OPTIONAL) | TEXTRACT_RESUME_PROCESSING (model `:167`) | created 'none' | Omits CompleteJobApplication; no-resume → no TextractResult; flag OFF → no TextractResult; duplicate/question_responses/oversized-resume → rollback, no record" — **AGREE.** All cells verified above.

### Write-site census (line 766, 767) for T5 ownership
"`submit_resume_to_textract.rb:19` (stale update_all): T1,T2,T3,T4,T5,T8" — **AGREE** that `:19` `@job_application.ai_job_application_summaries.update_all(stale: true)` is on the T5 path. NOTE for T5 it is a no-op (fresh import has zero summaries); the changelog notes this no-op explicitly only for T4 (line 63), not in the T5 section — see omissions.
"`find_or_create_…status.rb:15/25-37`: ...T5..." — **AGREE.** T5 reaches `:25-37` (else/build path), specifically `:34,37`.
"TextractResult ... owned by ...T5... (submit/poll chain)" — **AGREE.** T5 reaches `submit_resume_to_textract.rb:22` (build in_progress) and, on poll, `get_resume_text_from_textract.rb:31` (`.update` succeeded) / `:40,47` (failed paths).

### TextractResult dead-end census (line 563, 573)
`in_progress` row "T1,T2,T3,T4,T5,T8 backfill,T9" non-resting → GetResumeTextFromTextractJob (+2 min) — **AGREE** for T5: `submit_resume_to_textract.rb:22` build, `:27` `GetResumeTextFromTextractJob.set(wait: 2.minutes).perform_later`.
"No TextractResult ever created ... Applies at the entry of ... T4/T5/T6 (no resume)... Also gated OFF by TEXTRACT_RESUME_PROCESSING (T1/T2/T3/T4/T5/T6 — model-side job_application.rb:167...)" — **AGREE.**

## Omissions (T5-specific)

1. **Poll-job terminal not stated in the T5 section.** The Trigger-5 section (`:326-336`) never names the actor that advances `in_progress` → `succeeded`/`failed`: `GetResumeTextFromTextractJob` (`app/jobs/get_resume_text_from_textract_job.rb:25`, `retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3` `:6`) → `GetResumeTextFromTextract#parse_resume_text`. Succeeded path: `.update` (callback-firing, fires the bridge) at `get_resume_text_from_textract.rb:31` writing `textract_job_status: 'succeeded'` + `textract_job_result_text` (`:24-29`). Failed path: `update_columns(textract_job_status: 'failed')` `:40` then `raise CustomErrorTextract` `:41` (retry). The T5 narrative jumps from "in_progress" straight to the bridge without naming this poll service/job as the advancing actor for the slice. (It is documented generically elsewhere in the map, but the T5 section trace itself omits it.)

2. **Self-healing re-submit on the poll path is not noted for T5.** If the import's TextractResult has `textract_job_id` nil at poll time, `get_resume_text_from_textract.rb:14-17` re-enqueues `SubmitResumeToTextractJob` and returns. The map documents this re-entry for T1 (changelog line 26) but not in the T5 section, even though it is reachable on the import poll path.

3. **Stale update_all no-op not stated for T5.** `submit_resume_to_textract.rb:18-20` (`update_all(stale: true)`) and the waiting-summary relink `:25-26` are no-ops on a fresh import (zero pre-existing summaries, no `textract_processing` waiting summary) — the map states this explicitly for T4 (changelog line 63) but the T5 section never says it, leaving the reader to infer it. Behaviorally identical to T4; worth one line for parity.

## Clean
Not clean — all verdicts AGREE, but three T5-specific omissions exist (poll-job advancing actor, self-healing re-submit, stale no-op).

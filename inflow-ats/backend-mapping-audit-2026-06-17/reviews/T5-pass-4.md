# T5 — Customer API Import — Pass 4 Adversarial Review

Re-traced from scratch against current code. Slice: customer API import path, Textract triggering to terminal.

## Files traced
`api_public/v1/hire/job_applications_controller.rb:97-126` → `customer_api/validate_job_application_import.rb` → `customer_api/create_job_application.rb` → `job_application.rb:45,164-171` (after_commit) → `job_application.rb:160-161` (status helper) → `find_or_create_ai_job_application_summary_status.rb` → `submit_resume_to_textract_job.rb` → `app/services/submit_resume_to_textract.rb` → `app/services/get_resume_text_from_textract.rb` → `textract_result.rb:7,114-144,61-89` → `ai_job_application_action/orchestrate.rb:9-16` → `generate_ai_job_application_summary_job.rb:24-32` → `job.rb:914-922`

## Verdicts on candidate-map T5 claims

**AGREE** — Import action calls only `ValidateJobApplicationImport` + `CreateJobApplication` inside the transaction; does NOT call `CompleteJobApplication`.
Code: controller `:104` `CustomerApi::ValidateJobApplicationImport.call(ctx)`, `:107` `CustomerApi::CreateJobApplication.call(@result)`, inside `ActiveRecord::Base.transaction do` (`:103`); no `CompleteJobApplication` (contrast apply `:75`).

**AGREE** — `created_via: :created_via_customer_api_import` at controller `:101`; enum value 7 at `job_application.rb:91`.
Code: controller `:101` `ctx = job_application_context(:created_via_customer_api_import)`; `job_application.rb:91` `created_via_customer_api_import: 7`.

**AGREE** — Resume is OPTIONAL on import (`validate_job_application_import.rb:62-63`).
Code: `:62` `def validate_resume(errors)`, `:63` `return unless context.resume_params.present?` — resume-less import passes validation.

**AGREE** — No-resume → `SubmitResumeToTextract` returns 'No resume attached' (`submit_resume_to_textract.rb:10`, before build `:22` and poll-job schedule `:27`) → no TextractResult, no poll job.
Code: `app/services/submit_resume_to_textract.rb:10` `return 'No resume attached' unless @job_application.has_resume`; build `:22`; poll schedule `:27` `GetResumeTextFromTextractJob.set(wait: 2.minutes).perform_later`. (Minor: map cites bare filename; actual path is `app/services/submit_resume_to_textract.rb`. Class name + lines match.)

**AGREE** — `enqueue_new_job_application` enqueues `NewJobApplicationJob` (`:165`) + `DocxToPdfJob` (`:166`) BEFORE the gated `SubmitResumeToTextractJob` (`:168`).
Code: `job_application.rb:165` `NewJobApplicationJob.perform_later(id)`, `:166` `DocxToPdfJob.perform_later(id)`, `:168` `SubmitResumeToTextractJob.perform_later(id)`. `DocxToPdfJob` produces `resume_docx_to_pdf`, preferred at `submit_resume_to_textract.rb:15`.

**AGREE** — Flipper gate `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` (`job_application.rb:167-169`); flag OFF → NO TextractResult.
Code: `:167` `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)`, `:168` enqueue, `:169` `end`.

**AGREE** — `enqueue_new_job_application` creates the status row `'none'` on every import.
Code: `job_application.rb:170` `find_or_create_ai_job_application_summary_status` → `:161` `FindOrCreateAiJobApplicationSummaryStatus.call(job_application: self)` → fresh app has no summary → `find_or_create_ai_job_application_summary_status.rb:34` `@status_record.status = 'none'`, `:37` `@status_record.save`.

**AGREE** — Existing-candidate persists via `job.candidates.push(candidate)` (`create_job_application.rb:40`); new-candidate via `save_new_candidate` → `candidate.save` (`:19`/`:63`). Both fire the `on: [:create]` after_commit, Textract terminal unchanged.
Code: `create_job_application.rb:40` `job.candidates.push(candidate)`; `:19` `save_new_candidate(candidate)`; `:63` `unless candidate.save`. Callback `job_application.rb:45` `after_commit :enqueue_new_job_application, on: [:create]` fires on both.

**AGREE** — Resume-present import (flag ON) with `should_auto_generate_ai_summaries?` true lands in the S-C NO-OP dead end: no pre-existing summary → `Orchestrate` returns at `orchestrate.rb:16`; `generate_ai_summary_with_credit_flow` returns at `textract_result.rb:82` → no summary, no credit, no broadcast.
Code trace: poll `get_resume_text_from_textract.rb:31` `@textract_result.update(...)` sets `textract_job_status: 'succeeded'` + `textract_job_result_text` → `textract_result.rb:7` `after_commit :queue_ai_summary_job, on: [:create, :update]` → `:121-123` no `textract_processing` summary → else `:137` → `:138` `return unless ... should_auto_generate_ai_summaries?` → `:140` validate → `:142` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` (no requesting user) → job `:32` `textract_result.generate_ai_summary_with_credit_flow` → `:74` `generate_ai_summary` → `orchestrate.rb:15` `@job_application.ai_job_application_summaries.order(created_at: :desc).first` (nil) → `:16` `return unless @ai_job_application_summary` → back at credit flow `:77` re-fetch (TextractResult-scoped, empty) nil → `:82` `return unless ai_job_application_summary&.status_succeeded?`. NO summary, NO credit (`:84` never reached), NO broadcast (no requesting user).

## Omissions (T5-specific terminals absent from the map's T5 section)

1. **Duplicate-application rejection terminal.** `ValidateJobApplicationImport#check_duplicate` (`validate_job_application_import.rb:44-60`): if the candidate already has an application for this job (`:52-53`), `context.fail!(duplicate: true, existing_job_application_id:, duplicate_email:)` (`:55-59`). Controller `:105` `raise ActiveRecord::Rollback if @result.failure?` → 409 (`:113-120`). NO job_application created, NO status row, NO Textract. The map documents the duplicate response shape for apply but the T5 section never names this as an import terminal. (T5 is import-specific; this is the most common non-create import outcome.)

2. **question_responses rejection terminal (import-only).** `ValidateJobApplicationImport#reject_question_responses` (`:21-27`): `context.fail!` when `question_responses_params.present?` (`:22,24-26`) — import REJECTS question responses entirely (unlike apply, which processes them in `CompleteJobApplication`). Controller `:105` rolls back → no record, no Textract. This is a structural import-vs-apply divergence the map does not surface in T5.

3. **Resume validation rejection terminals.** `ValidateJobApplicationImport#validate_resume` (`:62-83`) can `context.fail!(error_code: 'file_too_large', ...)` when `decoded.bytesize > 10.megabytes` (`:69-75`), or accumulate decode/metadata errors (`:66,77`) → controller rollback. A malformed/oversized resume on import produces no record and no Textract — a distinct rejection terminal not in the T5 section.

## clean = false (omissions present)

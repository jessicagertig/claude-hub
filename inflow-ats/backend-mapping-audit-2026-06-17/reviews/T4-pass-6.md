# T4 — Customer API Apply — Adversarial Review (pass 6)

Re-read from scratch against current code. Every map claim about T4 verified against literal source.

## Files traced
- `app/controllers/api_public/v1/hire/job_applications_controller.rb` (apply :62-94, context builder :201-215)
- `config/routes.rb:501` (`post :apply`)
- `app/interactors/customer_api/validate_job_application_apply.rb`
- `app/interactors/customer_api/create_job_application.rb`
- `app/interactors/customer_api/complete_job_application.rb`
- `app/models/job_application.rb` (:45 callback, :83-91 created_via enum, :90 customer_api_apply=6, :160-162 status helper, :164-171 enqueue_new_job_application)
- `app/services/submit_resume_to_textract.rb`
- `app/models/textract_result.rb` (:7 after_commit, :114-144 queue_ai_summary_job)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/models/candidate.rb:101-106` (created_via_customer_api=4)

## Verdicts (changelog T4 bullets, lines 59-72; body lines 339-352)

1. Apply eagerly creates status row `'none'` via shared `enqueue_new_job_application` (`job_application.rb:170`); creates NO summary — **AGREE** (`job_application.rb:170` → `:160-162` → interactor `:34,:37` save `'none'` on fresh app).

2. Flipper gate `TEXTRACT_RESUME_PROCESSING, job.organization` (`job_application.rb:167-169`); flag OFF → resume attached, no TextractResult — **AGREE** (`job_application.rb:167-168`).

3. No-summary terminal: TextractResult succeeded → `queue_ai_summary_job` else branch → enqueues only if `should_auto_generate_ai_summaries?` (`textract_result.rb:138`) — **AGREE** (`textract_result.rb:137-142`, `:138`).

4. Save fires `after_commit :enqueue_new_job_application` INSIDE CreateJobApplication, not after CompleteJobApplication; new candidate `save_new_candidate`→`candidate.save` (`create_job_application.rb:19/:62-68/:63`); existing candidate `job.candidates.push` (`:40`), resume attached `:36`; CompleteJobApplication never saves candidate (`complete_job_application.rb:6-9`); whole apply in one transaction (controller `:68-77`); after_commit fires on outer commit; CompleteJobApplication failure → `raise ActiveRecord::Rollback` (controller `:76`) → no Textract — **AGREE** (all line refs confirmed verbatim).

5. New candidate built with `created_via: :created_via_customer_api` (`create_job_application.rb:47`), distinct from job_application `created_via_customer_api_apply` (controller `:66`, enum 6 `job_application.rb:90`) — **AGREE**.

6. `enqueue_new_job_application` enqueues `NewJobApplicationJob` + `DocxToPdfJob` (`job_application.rb:165-166`) BEFORE Textract submit (`:168`); DocxToPdfJob produces `resume_docx_to_pdf` preferred by SubmitResumeToTextract (`submit_resume_to_textract.rb:15`) — **AGREE**.

7. No-resume apply fork: resume required only when `job_settings['resume'] == 'required'` (`validate_job_application_apply.rb:36-38`); resume-less passes validation, SubmitResumeToTextract returns `'No resume attached'` (`submit_resume_to_textract.rb:10`, before build `:22`) → no TextractResult — **AGREE**.

8. No synchronous textract-ready branch on apply; AI pipeline only reachable later when polling succeeds and `queue_ai_summary_job` fires (`textract_result.rb:114`, registered `after_commit on: [:create,:update]` `:7`) — **AGREE**.

9. Apply-path no-ops in SubmitResumeToTextract: `update_all(stale: true)` (`:18-20`) no-op (zero summaries), waiting-summary relink (`:25-26`) no-op — **AGREE**.

10. Duplicate-application rejection: `check_duplicate` → `context.fail!(duplicate: true, existing_job_application_id:, duplicate_email:)` (`validate_job_application_apply.rb:66-70`) when candidate already has application (`:63-64`) → controller `:70` rollback → 409 (controller `:81-88`) → no record, no Textract — **AGREE**.

11. Oversized resume rejection: `validate_resume` → `context.fail!(error_code: 'file_too_large', ...)` when `decoded.bytesize > 10.megabytes` (`validate_job_application_apply.rb:80-85`) → rollback → 422 → no record, no Textract — **AGREE**.

12. CompleteJobApplication question-response save-failure rollback: `add_question_responses` → `context.fail!(errors: question_response.errors.full_messages)` on `question_response.save` failure (`complete_job_application.rb:25-29`) → controller `:76` rollback → no record (apply-only) — **AGREE**.

13. Import omits CompleteJobApplication; apply runs it; Textract behavior identical because it fires from shared after_commit — **AGREE** (cross-slice; apply controller calls all three interactors `:69-76`, import `:104-108` calls only two).

14. Body line 341: resume base64-decoded in ValidateJobApplicationApply (`:77`, `context.decoded_resume = decoded` `:91`), attached via `StringIO.new(context.decoded_resume)` in CreateJobApplication (`attach_resume`, `:70-78`, `:74`) — **AGREE**.

15. Body line 345: `build_new_candidate (:43-60)`, candidate enum value 4 (`candidate.rb:106`) — **AGREE**.

## Omissions (T4 validation terminals not enumerated, all fold into "validation fail → rollback → no record → no Textract")

- `validate_question_responses` rejection (`validate_job_application_apply.rb:96-132`): bad/missing required question responses accumulate `errors` → `context.fail!(errors:)` (`:16`) → controller `:70` rollback → no record, no Textract. Apply-specific (apply validates AND processes question responses; import rejects them outright). The map names the import-side question_responses terminal (line 77) but does NOT name the apply-side question-response VALIDATION-rejection terminal.
- `send_candidate_confirmation_email` required/boolean guard (`validate_job_application_apply.rb:40-44`): nil or non-boolean → `errors[...]` → `context.fail!` → rollback → no record, no Textract. Not mentioned for T4.

Both are benign (terminal identical to the documented duplicate/oversized cases: rollback → no record → no Textract), but they are distinct apply-entry rejection terminals the map does not list.

## Record-write sites on the T4 slice
- `find_or_create_ai_job_application_summary_status.rb:34,:37` — AiJobApplicationSummaryStatus `status='none'`, `.save` (create). T4 fresh apply.
- `submit_resume_to_textract.rb:19` — AiJobApplicationSummary `update_all(stale: true)` (no-op on apply).
- `submit_resume_to_textract.rb:22,:24` — TextractResult build `in_progress` + `.save` (only when resume present + flag ON).
- `submit_resume_to_textract.rb:26` — AiJobApplicationSummary `update_columns(textract_result_id:)` relink (no-op on apply).
- (downstream poll/bridge writes are S-D/S-C, out of T4 entry slice.)

## Verdict
All 15 enumerated map statements AGREE. Two omitted apply-side validation-rejection terminals (question_responses validation, send_candidate_confirmation_email guard). clean = false (omissions non-empty).

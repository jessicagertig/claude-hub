# T5 — Customer API Import — Adversarial Review (pass-6)

**Slice:** T5 — Customer API import path; trace Textract triggering to terminal.
**Verdict:** clean = false (omissions present; all map statements AGREE).

## Trace chain followed (from scratch)
`app/controllers/api_public/v1/hire/job_applications_controller.rb:97-126`
→ `app/interactors/customer_api/validate_job_application_import.rb:7-83`
→ `app/interactors/customer_api/create_job_application.rb:6-78`
→ `app/models/job_application.rb:45` (`after_commit :enqueue_new_job_application, on: [:create]`) → `:164-171`
→ `app/jobs/submit_resume_to_textract_job.rb` / `app/services/submit_resume_to_textract.rb:8-41`
→ `app/jobs/get_resume_text_from_textract_job.rb:6,25-27` → `app/services/get_resume_text_from_textract.rb:8-49`
→ `app/models/textract_result.rb:7,114-144` (bridge)
→ `app/services/ai_job_application_action/orchestrate.rb:12-16`
→ `app/models/textract_result.rb:77,82` (NO-OP terminal)

Route: `post :import` at `config/routes.rb:502`.

## Statement-by-statement verdicts

1. **"Import action calls only ValidateJobApplicationImport + CreateJobApplication inside the transaction (`:104,107`); does NOT call CompleteJobApplication."** — AGREE. `job_applications_controller.rb:104` `ValidateJobApplicationImport.call`, `:107` `CreateJobApplication.call`, both inside `ActiveRecord::Base.transaction` `:103-109`. No `CompleteJobApplication` in `import` (it appears only in `apply` `:75`).

2. **"Duplicate-application rejection terminal — `check_duplicate` (`:44-60`) `context.fail!(duplicate:, existing_job_application_id:, duplicate_email:)` (`:55-59`) when candidate already has app (`:52-53`) → controller `:105` rollback → 409. NO job_application/status/Textract."** — AGREE. `validate_job_application_import.rb:52` `existing_application = candidate.job_applications.find_by(job_id: context.job.id)`, `:53` `return unless existing_application`, `:55-59` fail!. Controller rollback `:105`, 409 render `:113-120`.

3. **"question_responses rejection terminal — import-only — `reject_question_responses` (`:21-27`) fail! when `context.question_responses_params.present?` (`:22,24-26`) → rollback. Import rejects; apply processes."** — AGREE. `validate_job_application_import.rb:21-27`; `:22` `return unless ...present?`, `:24-26` fail!. Apply has no equivalent reject (apply runs `CompleteJobApplication` `:75`).

4. **"resume validation rejection terminals — `validate_resume` (`:62-79`) `context.fail!(error_code: 'file_too_large')` when `decoded.bytesize > 10.megabytes` (`:69-75`), plus decode/metadata (`:66,77`) → rollback."** — AGREE on behavior. Minor citation slip: method is `:62-83` (closing `end` at 83), not `:62-79`. fail! `:70-73`, decode `:66`, metadata `:77`. (See omissions.)

5. **"`created_via: :created_via_customer_api_import` (controller `:101`; enum 7, `job_application.rb:91`)."** — AGREE. Controller `:101` `ctx = job_application_context(:created_via_customer_api_import)`; enum `created_via_customer_api_import: 7` at `job_application.rb:91`.

6. **"enqueue_new_job_application creates status row (`'none'`) on every import."** — AGREE. `job_application.rb:170` `find_or_create_ai_job_application_summary_status` (unconditional). (Status-`none` write itself in FindOrCreate interactor — out-of-file but consistent with X1/X2.)

7. **"callback ordering: NewJobApplicationJob (`:165`) + DocxToPdfJob (`:166`) BEFORE gated SubmitResumeToTextractJob (`:168`); DocxToPdfJob produces resume_docx_to_pdf which SubmitResumeToTextract prefers (`submit_resume_to_textract.rb:15`)."** — AGREE. `job_application.rb:165,166,168`; `submit_resume_to_textract.rb:15` `has_resume_docx_to_pdf ? resume_docx_to_pdf : resume`.

8. **"Flipper gate on resume-present terminal: import Textract submit gated by `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` (`job_application.rb:167-169`). Flag OFF → NO TextractResult."** — AGREE. `job_application.rb:167-169`.

9. **"Resume OPTIONAL on import (`validate_job_application_import.rb:62-63`): no resume → SubmitResumeToTextract returns 'No resume attached' (`submit_resume_to_textract.rb:10`, before build `:22` and poll-job `:27`) → no TextractResult, no poll. Benign."** — AGREE. `validate_resume:63` `return unless context.resume_params.present?` (optional). `submit_resume_to_textract.rb:10` early return; build `:22`, poll schedule `:27`.

10. **"EXISTING candidate persists via `job.candidates.push(candidate)` (`create_job_application.rb:40`), not `candidate.save`; new-candidate uses `save_new_candidate` → `candidate.save` (`:62-68`/`:63`). Both fire same `on: [:create]` after_commit; Textract terminal unchanged."** — AGREE. `create_job_application.rb:40` `job.candidates.push(candidate)` (existing branch `:28-41`); `save_new_candidate` `:62-68`, `.save` `:63`. Both create a job_application (built `:29-34` / `:50-55`) that fires `after_commit on: [:create]` (`job_application.rb:45`).

11. **"terminal cross-ref: resume-present import (flag ON) with should_auto_generate_ai_summaries? true lands in S-C NO-OP dead end (no pre-existing summary: Orchestrate returns at `orchestrate.rb:16`; generate_ai_summary_with_credit_flow returns at `textract_result.rb:82`) → no summary, no credit, no broadcast."** — AGREE. Bridge `:121-123` waiting-summary query returns nil on a fresh import → else `:137-143`; `:138` should_auto guard; `:140` validate; `:142` enqueue job (no requesting user). Job → `generate_ai_summary_with_credit_flow`: `latest_ai_summary` nil → `:68` no-return; `:74` Orchestrate; `orchestrate.rb:15` selects nil → `:16` return; back at `textract_result.rb:77` (firing-result-scoped `ai_job_application_summaries`) empty → `:82` return. No credit/broadcast.

12. **"advancing actor for in_progress → succeeded/failed: GetResumeTextFromTextractJob (`:25` → parse_resume_text, retry_on CustomErrorTextract `:6`): succeeded via `.update(...)` (`get_resume_text_from_textract.rb:24-29,31`, callback-firing); failed via update_columns (`:40`) + raise CustomErrorTextract (`:41`)."** — AGREE. Job `:6` `retry_on CustomErrorTextract`, `:25` perform → `:27` parse_resume_text. Service `:24` succeeded branch, `:25-29` params, `:31` `.update` (fires after_commit bridge). `:40` `update_columns(textract_job_status: 'failed')`, `:41` raise.

13. **"self-healing re-submit on import poll path: TextractResult textract_job_id nil → `get_resume_text_from_textract.rb:14-17` re-enqueues SubmitResumeToTextractJob and returns."** — AGREE. `:14` `if @textract_result.textract_job_id.nil?`, `:15` `SubmitResumeToTextractJob.perform_later`, `:16` return.

14. **"stale update_all / relink no-op for import: `update_all(stale: true)` (`submit_resume_to_textract.rb:18-20`) and waiting-summary relink (`:25-26`) both no-ops on fresh import."** — AGREE. `:18` guard `unless ...where(status: :textract_processing, stale: false).exists?` — on a fresh import zero summaries exist; `:19` `update_all` runs but affects zero rows (no-op). `:25` `find_by(... textract_result_id: nil)` returns nil → `:26` `&.update_columns` no-op.

## Omissions (map does not state for T5)

- **`validate_resume` method range citation imprecise.** Map says `validate_job_application_import.rb:62-79`; actual method body is `:62-83` (closing `end` at line 83). Behavior unaffected; cited fail!/decode/metadata lines are correct.
- **Metadata-rejection (non-allowed content type) terminal not named for import.** `validate_resume` also rejects via `resolve_file_metadata` accumulating `errors` (`validate_job_application_import.rb:77-78`, `CustomerApiFileValidation#resolve_file_metadata` at `customer_api_file_validation.rb:107`) → `:16` `context.fail!(errors:)` → rollback → 422. Map names file_too_large + decode but not the content-type/metadata 422 specifically.
- **Outer-transaction commit timing not restated for import.** The whole import runs in one `ActiveRecord::Base.transaction` (`job_applications_controller.rb:103-109`); the `after_commit :enqueue_new_job_application` fires only on OUTER commit after `CreateJobApplication` succeeds. (Map states this explicitly for apply at the T4 changelog but does not co-locate it under T5; for import there is no `CompleteJobApplication`, so commit fires right after `:107`.)
- **`save_new_candidate` failure terminal not named.** `create_job_application.rb:63` `unless candidate.save` → `:66` `context.fail!(errors:)` → controller `:108` rollback → no job_application, no Textract. A new-candidate-only import rejection terminal.
- **Existing-candidate validity-failure terminal not named.** `build_application_for_existing_candidate` `:38` `context.fail!(errors: job_application.errors.full_messages) unless job_application.valid?` → controller `:108` rollback → no record, no Textract. An existing-candidate-branch import rejection terminal distinct from `check_duplicate`.

All graded statements AGREE; omissions present → clean = false.

# T4 — Customer API Apply — Adversarial Review (pass 5)

Slice: the public/customer API `apply` endpoint that creates a job application; whether/how Textract is triggered, to terminal.

Candidate map reviewed: `backend-flow-map-2026-06-17.md`. T4 changelog lines 54-64; detailed section lines 311-324; matrix line 654; census line 765-767.

Files opened and traced:
- `app/controllers/api_public/v1/hire/job_applications_controller.rb` (apply `:62-94`, context `:201-215`)
- `config/routes.rb:499-503` (route `post :apply` `:501`)
- `app/interactors/customer_api/validate_job_application_apply.rb`
- `app/interactors/customer_api/create_job_application.rb`
- `app/interactors/customer_api/complete_job_application.rb`
- `app/models/job_application.rb` (`:45`, `:83-92`, `:160-171`, `:31`, `:589-590`, `:401`)
- `app/models/candidate.rb:101-106`
- `app/services/submit_resume_to_textract.rb`
- `app/models/textract_result.rb` (`:61-89`, `:110-144`)
- `app/jobs/generate_ai_job_application_summary_job.rb`
- `app/services/ai_job_application_action/orchestrate.rb:1-50`
- `app/models/job.rb:914` (`should_auto_generate_ai_summaries?`)
- `app/jobs/new_job_application_job.rb`, `app/jobs/docx_to_pdf_job.rb` (no Textract trigger)

## Verdicts (every T4 statement)

1. Chain `POST /v1/hire/job_applications/apply` (route `:501`) → `apply` (controller `:62`) → Validate → Create → Complete, all in `ActiveRecord::Base.transaction` (`:68-77`). **AGREE** — route `routes.rb:501`; controller `:62-77`.

2. `created_via: :created_via_customer_api_apply` (controller `:66`; enum value 6 `job_application.rb:90`). **AGREE** — `job_application_context(:created_via_customer_api_apply)` controller `:66`; enum `:90`.

3. Resume base64-decoded in ValidateJobApplicationApply (`:77`), `context.decoded_resume = decoded` (`:91`); attached via `StringIO.new(context.decoded_resume)` in CreateJobApplication `attach_resume` (`:70-78`, `:74`). **AGREE** — `validate_job_application_apply.rb:77,91`; `create_job_application.rb:73-77` (`io: StringIO.new(...)` `:74`).

4. No-resume apply fork: resume required only when `job_settings['resume'] == 'required'` (`validate_job_application_apply.rb:36-38`); resume-less passes, then `SubmitResumeToTextract` returns `'No resume attached'` (`submit_resume_to_textract.rb:10`, before build `:22`) → NO TextractResult, NO poll job. **AGREE** — `:36-38`; `submit_resume_to_textract.rb:10` (`has_resume` → `:589-590` `resume.attached?`), build `:22`, poll schedule `:27`.

5. Flipper gate on resume-present terminal: enqueue runs shared `enqueue_new_job_application`, gated by `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` (`job_application.rb:167-169`); flag OFF → resume attached, NO TextractResult. **AGREE** — `job_application.rb:167` (`if Flipper.enabled?(...)`), `:168` enqueue.

6. The save firing `after_commit :enqueue_new_job_application` is inside CreateJobApplication, not after CompleteJobApplication. New candidate `build_new_candidate` (`:43-60`) with `created_via: :created_via_customer_api` (`:47`; candidate enum 4 `candidate.rb:106`), `save_new_candidate → candidate.save` (`:19`/`:62-68`, `.save` `:63`). Existing candidate `build_application_for_existing_candidate` (`:28-41`) attaches resume (`:36`) then `job.candidates.push(candidate)` (`:40`), NOT `candidate.save`. **AGREE** — all cites confirmed; candidate enum `candidate.rb:106` value 4.

7. CompleteJobApplication only adds question responses (`:6-9`) and sends confirmation email; never saves candidate. after_commit fires on OUTER-transaction commit (controller `:77`); CompleteJobApplication failure `raise ActiveRecord::Rollback` (controller `:76`) rolls back create, Textract never enqueued. **AGREE** — `complete_job_application.rb:6-9`; Rails defers `after_commit on: [:create]` to outermost commit; controller `:76` rollback.

8. None of the three interactors triggers Textract directly; fires only via shared after_commit. DocxToPdfJob (`job_application.rb:166`) produces `resume_docx_to_pdf` preferred by SubmitResumeToTextract (`:15`). **AGREE** — verified no Textract enqueue in the three interactors, in `new_job_application_job.rb`, or `docx_to_pdf_job.rb`; `submit_resume_to_textract.rb:15` prefers `resume_docx_to_pdf`.

9. Apply-path no-ops in SubmitResumeToTextract: `update_all(stale: true)` (`:18-20`) no-op (fresh apply has zero summaries); waiting-summary relink (`:25-26`) no-op (no textract_processing summary). **AGREE** — `:18-19` guarded `update_all`; `:25-26` `find_by(status: :textract_processing, ...)` relink.

10. Creates the status row (`'none'`, `job_application.rb:170`); creates NO AiJobApplicationSummary. **AGREE** — `:170` `find_or_create_ai_job_application_summary_status` → `FindOrCreateAiJobApplicationSummaryStatus` else branch sets `status = 'none'` (`:34`) + save (`:37`). No summary created anywhere on apply path.

11. No synchronous textract-ready branch; AI pipeline reachable only later when polling succeeds and `queue_ai_summary_job` fires (`textract_result.rb:114`). **AGREE** — fresh apply attaches a new resume; no pre-existing TextractResult; bridge `:114-116` requires `saved_change_to_textract_job_result_text?`, only true on the poll `.update`.

12. No-summary terminal: TextractResult succeeded → `queue_ai_summary_job` else branch (`:137`) → enqueues only if `should_auto_generate_ai_summaries?` (`:138`) → S-C NO-OP dead end (no pre-existing summary). **AGREE** — bridge else `:137-142`; `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id) if result.success?` `:142` (no requesting user). `generate_ai_summary_with_credit_flow`: `:68` not triggered (latest summary nil), `find_or_create...status` `:70`, `set_initial_summary_pending` no-op (`:101` returns, no latest_summary), `generate_ai_summary` → `Orchestrate` returns at `:16` (`return unless @ai_job_application_summary`), then `:82` `return unless ai_job_application_summary&.status_succeeded?` → no summary, no credit, no broadcast.

13. (Changelog) Import omits CompleteJobApplication; apply runs it; Textract identical via shared after_commit but interactor chain differs. **AGREE** (apply side) — apply calls all three (`:69-76`); import calls two (`:104-108`).

## Omissions (T4 rejection-to-terminal paths the detailed T4 section does not document)

The detailed T4 section (lines 311-324) documents the no-resume fork, Flipper gate, save site, status row, and no-summary terminal, but omits the pre-create VALIDATION REJECTION terminals that exist on the apply path. These all roll back the transaction → NO job_application, NO status row, NO Textract. They are documented for import (T5, lines 68/70/330/332) but NOT for apply, even though `ValidateJobApplicationApply` contains the same logic:

- **Duplicate-application rejection terminal (apply).** `ValidateJobApplicationApply#check_duplicate` calls `context.fail!(duplicate: true, existing_job_application_id:, duplicate_email:)` (`validate_job_application_apply.rb:55-71`, fail `:66-70`) when the candidate already has an application for the job (`:63-64`). Controller `@result.failure?` → `raise ActiveRecord::Rollback` (`:70`) → 409 (controller `:81-88`). No record, no status row, no Textract. (Map line 68 explicitly says the duplicate shape was "previously documented only for apply," yet the rebuilt detailed T4 section no longer states this terminal.)

- **Oversized-resume rejection terminal (apply).** `ValidateJobApplicationApply#validate_resume` calls `context.fail!(error_code: 'file_too_large', error_message: 'File exceeds maximum size of 10MB')` when `decoded.bytesize > 10.megabytes` (`validate_job_application_apply.rb:80-85`), plus base64 decode / metadata error accumulation (`:77-78,88-89`). Controller rollback (`:70`) → 422 (controller `:89-90`). No record, no Textract. (Documented for import at map line 70/332; absent for apply.)

- **CompleteJobApplication question-response save-failure rollback (apply-only).** `add_question_responses` builds + saves each `question_response`; `context.fail!` on save failure (`complete_job_application.rb:25-29`) → controller `:76` `raise ActiveRecord::Rollback`. Because this runs AFTER CreateJobApplication, the rollback unwinds the already-built job_application; since the `after_commit` only fires on OUTER commit (which never happens on rollback), Textract is never enqueued. The map mentions the rollback mechanism (line 319) but not that a question-response save failure is a concrete apply terminal with no record persisted and no Textract.

clean = false (omissions present; all explicit verdicts AGREE).

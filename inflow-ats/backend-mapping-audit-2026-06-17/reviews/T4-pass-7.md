# T4 — Customer API Apply — Adversarial Review (pass-7)

Slice: the public/customer API apply endpoint (`POST /v1/hire/job_applications/apply`), whether/how Textract is triggered, to terminal.

Files re-read from scratch:
- `app/controllers/api_public/v1/hire/job_applications_controller.rb` (apply `:61-94`, `job_application_context` `:201-215`)
- `app/interactors/customer_api/validate_job_application_apply.rb`
- `app/interactors/customer_api/create_job_application.rb`
- `app/interactors/customer_api/complete_job_application.rb`
- `app/interactors/concerns/customer_api_file_validation.rb` (`:108-132`)
- `app/models/job_application.rb` (`:45`, `:83-92`, `:160-171`)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/services/submit_resume_to_textract.rb`
- `app/models/textract_result.rb` (`:7`, `:114-144`)
- `app/models/candidate.rb` (`:101-106`)

## Verdicts (map T4 section lines 59-74)

All AGREE; each anchored to literal code.

1. "Apply path eagerly creates the AiJobApplicationSummaryStatus row ('none') via shared `enqueue_new_job_application` (`job_application.rb:170`); creates NO AiJobApplicationSummary." — AGREE. `job_application.rb:170` `find_or_create_ai_job_application_summary_status`; fresh apply → `find_or_create_ai_job_application_summary_status.rb:22` else, `:34` `@status_record.status = 'none'`, `:37` save (latest summary nil, `:27` false). No summary record built anywhere on apply.

2. "Flipper gate on apply resume-present terminal `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` (`job_application.rb:167-169`)." — AGREE. `job_application.rb:167` `if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)`, `:168` enqueue.

3. "Apply-path no-summary terminal: TextractResult succeeded → `queue_ai_summary_job` else branch → enqueues only if `should_auto_generate_ai_summaries?` (`textract_result.rb:138`, `:137-142` else)." — AGREE. `textract_result.rb:137` else, `:138` `return unless job_application&.job&.should_auto_generate_ai_summaries?`, `:142` enqueue.

4. "Save that triggers after_commit happens INSIDE CreateJobApplication, not after CompleteJobApplication. New candidate: `save_new_candidate` → `candidate.save` (`create_job_application.rb:19`, def `:62-68`, `.save` `:63`). Existing: `job.candidates.push(candidate)` (`:40`), resume attached at `:36` before push. CompleteJobApplication never saves the candidate (`complete_job_application.rb:6-9`). Whole apply in one `ActiveRecord::Base.transaction` (controller `:68-77`); after_commit fires on OUTER commit after CompleteJobApplication (controller `:77`); CompleteJobApplication failure rollback (controller `:76`)." — AGREE on every cited line. `create_job_application.rb:19` `save_new_candidate(candidate)`, `:62-68` def, `:63` `unless candidate.save`; `:40` `job.candidates.push(candidate)`; `:36` `attach_resume(job_application)` inside `build_application_for_existing_candidate`; `complete_job_application.rb:6-9` call body has no candidate save; controller `:68` transaction open, `:75-76` `CompleteJobApplication.call` + `raise ActiveRecord::Rollback if @result.failure?`, `:77` transaction close.

5. "New candidate built `created_via: :created_via_customer_api` (`create_job_application.rb:47`), distinct from job_application `created_via_customer_api_apply` (controller `:66`; enum 6 `job_application.rb:90`)." — AGREE. `create_job_application.rb:47` `.merge(created_via: :created_via_customer_api)` (Candidate enum 4, `candidate.rb:106`); controller `:66` `job_application_context(:created_via_customer_api_apply)`; `job_application.rb:90` `created_via_customer_api_apply: 6`.

6. "`enqueue_new_job_application` also enqueues NewJobApplicationJob and DocxToPdfJob (`job_application.rb:165-166`) BEFORE Textract submit (`:168`); DocxToPdfJob produces `resume_docx_to_pdf` which SubmitResumeToTextract prefers (`submit_resume_to_textract.rb:15`)." — AGREE. `job_application.rb:165` NewJobApplicationJob, `:166` DocxToPdfJob, `:168` SubmitResumeToTextractJob; `submit_resume_to_textract.rb:15` `has_resume_docx_to_pdf ? resume_docx_to_pdf : resume`.

7. "No-resume apply fork: ValidateJobApplicationApply requires resume only when `job_settings['resume'] == 'required'` (`validate_job_application_apply.rb:36-38`); resume-less passes, then SubmitResumeToTextract returns 'No resume attached' at `submit_resume_to_textract.rb:10` (before build `:22`) → no TextractResult/poll." — AGREE. `validate_job_application_apply.rb:36-38`; `submit_resume_to_textract.rb:10` `return 'No resume attached' unless @job_application.has_resume`, `:22` build.

8. "No synchronous textract-ready branch on apply; AI pipeline only reachable later when polling succeeds and `queue_ai_summary_job` fires (`textract_result.rb:114`)." — AGREE. Resume freshly attached (`create_job_application.rb:70-78` `attach_resume`); no pre-existing TextractResult; `textract_result.rb:114` bridge def fires post-poll only.

9. "Apply-path no-ops in SubmitResumeToTextract: `update_all(stale:true)` (`submit_resume_to_textract.rb:18-20`) no-op (zero summaries); waiting-summary relink (`:25-26`) no-op." — AGREE. `:18-20` guarded `update_all` on empty `ai_job_application_summaries`; `:25-26` `find_by(status: :textract_processing...)` returns nil.

10. "Duplicate-application rejection terminal: `check_duplicate` `context.fail!(duplicate:true, existing_job_application_id:, duplicate_email:)` (`validate_job_application_apply.rb:66-70`) when candidate already has app (`:63-64`) → controller `:70` rollback → 409 (controller `:81-88`) → no record/status/Textract." — AGREE. `:63` `existing_application = candidate.job_applications.find_by(job_id: context.job.id)`, `:64` `return unless`, `:66-70` fail!; controller `:69-70` ValidateJobApplicationApply + rollback, `:81-88` 409.

11. "Oversized/malformed-resume rejection: `validate_resume` `file_too_large` when `decoded.bytesize > 10.megabytes` (`validate_job_application_apply.rb:80-85`), base64-decode `:77-78`, metadata `:88-89` → rollback → 422 → no record/Textract." — AGREE. `:77` decode, `:78` `return unless decoded`, `:80-85` file_too_large, `:88` `resolve_file_metadata`, `:89` `return unless metadata`.

12. "CompleteJobApplication question-response save-failure rollback (apply-only): `add_question_responses` `context.fail!(errors:...)` on `question_response.save` failure (`complete_job_application.rb:25-29`) → controller `:76` rollback; runs AFTER CreateJobApplication; after_commit only on OUTER commit → Textract never enqueued." — AGREE. `complete_job_application.rb:25` `unless question_response.save`, `:28` fail!; controller `:75` CompleteJobApplication, `:76` rollback.

13. "Apply-side question-response VALIDATION rejection: `validate_question_responses` (`validate_job_application_apply.rb:96-132`): non-belonging `:106-110`, format `:114`/`:134-151`, required-but-blank `:118-120`, missing-required `:124-131` → `context.fail!(errors:)` (`:16`) → rollback → no record/status/Textract." — AGREE. All cited lines match; aggregator `:16` `context.fail!(errors: errors) if errors.any?`.

14. "send_candidate_confirmation_email required/boolean guard: `validate_required_fields` (`:40-44`): nil `:40-41`, non-boolean `:42-43` → fail! `:16` → rollback → no record/Textract." — AGREE. `:40` `if context.send_candidate_confirmation_email.nil?`, `:41` is-required, `:42` `elsif !...in?([true,false])`, `:43` must-be-boolean.

15. "Old map 'Import: Same interactor chain as Apply' MAP-WRONG. Import omits CompleteJobApplication; apply runs it. Textract identical (shared after_commit on creation), interactor chain differs." — AGREE. Apply controller `:69,72,75` runs Validate+Create+Complete; import controller `:104,107` runs Validate+Create only.

## Omissions (T4 slice)

O1. **Apply existing-candidate validity-failure terminal not named for apply.** `CreateJobApplication#build_application_for_existing_candidate` calls `context.fail!(errors: job_application.errors.full_messages) unless job_application.valid?` (`create_job_application.rb:38`). On apply, controller `:72` `CreateJobApplication.call(@result)` then `:73` `raise ActiveRecord::Rollback if @result.failure?` → no record, no status row, no Textract. The map names this terminal ONLY under T5 as "import existing-candidate-only" (map line 84), but `CreateJobApplication` is shared and this is equally an apply terminal. The "import...only" framing makes it invisible to a T4 reader.

O2. **Apply new-candidate save-failure terminal not named for apply.** `CreateJobApplication#save_new_candidate` calls `context.fail!(errors: candidate.errors.full_messages)` when `candidate.save` returns false (`create_job_application.rb:62-67`, `:63` `unless candidate.save`, `:66` fail!). On apply, controller `:72-73` → rollback → no record, no Textract. The map names this ONLY under T5 as "import new-candidate-only" (map line 83). It is equally an apply terminal via the shared `CreateJobApplication`.

Both are minor (they are documented in the map body for import and the mechanism is identical), but for the T4 slice they are unstated apply rejection terminals, so omissions is non-empty.

## clean
false — all verdicts AGREE, but two omissions (O1, O2) exist.

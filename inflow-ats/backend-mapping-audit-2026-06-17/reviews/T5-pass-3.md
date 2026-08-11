# T5 — Customer API Import — Adversarial Review (pass 3)

Slice scope: the customer API import path; trace Textract triggering, to terminal.

Re-audited from scratch against current code. All file:line references opened and read.

## Files traced
- `app/controllers/api_public/v1/hire/job_applications_controller.rb` (def import :96-126, job_application_context :201-215)
- `app/interactors/customer_api/validate_job_application_import.rb`
- `app/interactors/customer_api/create_job_application.rb`
- `app/models/job_application.rb:45` (callback reg), `:83-92` (created_via enum), `:160-171` (enqueue_new_job_application), `:589` (has_resume)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/services/submit_resume_to_textract.rb`
- `app/models/textract_result.rb:114-144` (queue_ai_summary_job bridge), `:61-89` (generate_ai_summary_with_credit_flow)
- `app/services/ai_job_application_action/orchestrate.rb:9-50`
- `config/routes.rb:499-503` (import route)

## Verdicts on T5 candidate-map statements

### DIVERGENCE CHANGELOG — Trigger 5 (T5) entries

1. **"Import action calls only ValidateJobApplicationImport + CreateJobApplication inside the transaction (...:104,107); does NOT call CompleteJobApplication"** — AGREE. Controller `import` (`job_applications_controller.rb:96-126`): transaction at `:103-109` calls `CustomerApi::ValidateJobApplicationImport.call(ctx)` (`:104`) and `CustomerApi::CreateJobApplication.call(@result)` (`:107`); no `CompleteJobApplication` anywhere in the method (contrast `apply` `:75`).

2. **"enqueue_new_job_application creates the status row ('none') on every import"** — AGREE. `job_application.rb:45` `after_commit :enqueue_new_job_application, on: [:create]` fires on the import-created record; body `:170` calls `find_or_create_ai_job_application_summary_status` unconditionally; for a fresh app with no pre-existing summary, `find_or_create_ai_job_application_summary_status.rb:11` is false → else → `:34` `status = 'none'` → `:37` save.

3. **"Resume OPTIONAL (validate_job_application_import.rb:63): no resume → SubmitResumeToTextract returns 'No resume attached' (submit_resume_to_textract.rb:10, before build :22 and poll-job schedule :27) → no TextractResult, no poll job. Benign terminal."** — AGREE. `validate_job_application_import.rb:62-63`: `validate_resume` returns at `:63` `return unless context.resume_params.present?` (no fail on absent resume). `submit_resume_to_textract.rb:10` `return 'No resume attached' unless @job_application.has_resume` precedes the build (`:22`) and the poll schedule (`:27`). No TextractResult, no `GetResumeTextFromTextractJob`.

4. **"For an EXISTING candidate, CreateJobApplication persists via job.candidates.push(candidate) (create_job_application.rb:40), not candidate.save; new-candidate branch uses save_new_candidate → candidate.save (:62-68). Both branches fire the same on:[:create] after_commit, so the Textract terminal is unchanged."** — AGREE. `create_job_application.rb:14-20` branches on `context.existing_candidate`; existing → `build_application_for_existing_candidate` → `job.candidates.push(candidate)` (`:40`); new → `build_new_candidate` (`:43-60`) + `save_new_candidate` → `candidate.save` (`:63`). Both persist a new job_application, firing `after_commit :enqueue_new_job_application, on:[:create]` (`job_application.rb:45`).

5. **"Resume-present import with should_auto_generate_ai_summaries? true lands in the S-C NO-OP dead end (no pre-existing summary: Orchestrate returns at orchestrate.rb:16; generate_ai_summary_with_credit_flow returns at textract_result.rb:82) → no summary, no credit, no broadcast."** — AGREE. Resume-present → TextractResult built/saved (`submit_resume_to_textract.rb:22-24`), poll succeeds, `queue_ai_summary_job` fires (`textract_result.rb:7,114`). No `textract_processing` waiting summary exists for an import (none ever created), so `ai_summary_waiting_on_textract` (`:121-123`) is nil → else branch (`:137`). `:138` `return unless ...should_auto_generate_ai_summaries?`; if true, `:140` validate, `:142` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id)` (no requesting user). That job → `generate_ai_summary_with_credit_flow` → `:74 generate_ai_summary` → `Orchestrate#call`: `orchestrate.rb:15` selects latest summary (none) → `:16` `return unless @ai_job_application_summary`. `Summary::Generate` (only first-summary creator, `orchestrate.rb:64`) never runs. Back in `textract_result.rb:77` `ai_job_application_summaries` (self/TextractResult-scoped) is empty → `:82` `return unless ai_job_application_summary&.status_succeeded?`. No summary, no `CreateAiCreditBalanceTransaction` (`:84`), no broadcast. Confirmed dead end.

### Part-1 Trigger 5 prose block (`job_applications_controller.rb:104,107`)

6. **"created_via: :created_via_customer_api_import (controller :101; enum 7, job_application.rb:91)"** — AGREE. Controller `:101` `ctx = job_application_context(:created_via_customer_api_import)`; flows to `create_job_application.rb:31/52` `created_via: context.created_via`; enum `created_via_customer_api_import: 7` at `job_application.rb:91`.

7. **"Chain: POST /v1/hire/job_applications/import"** — AGREE. `config/routes.rb:502` `post :import` on the `job_applications` collection under `/v1/hire/` (`:499-503`, scoped block `:490-498`).

8. **Existing-candidate chain detail / Textract terminal unchanged** — AGREE (same as #4).

9. **"Resume-present import with auto-gen on lands in the S-C NO-OP dead end (no pre-existing summary)."** — AGREE (same as #5).

## Omissions (present in code, not stated for the T5 slice)

- **O1 — DocxToPdfJob ordering before Textract submit on the import path.** `enqueue_new_job_application` enqueues `NewJobApplicationJob` (`job_application.rb:165`) and `DocxToPdfJob` (`:166`) BEFORE the gated `SubmitResumeToTextractJob` (`:168`). The map states this explicitly for T4 (apply) in the changelog ("enqueue_new_job_application also enqueues NewJobApplicationJob and DocxToPdfJob ... BEFORE the Textract submit; DocxToPdfJob produces resume_docx_to_pdf, which SubmitResumeToTextract prefers"), but the T5 entry never restates it for import even though the identical callback fires. `submit_resume_to_textract.rb:15` prefers `resume_docx_to_pdf`. Minor — the callback is shared and documented under T4, but T5's own block omits it.

- **O2 — Flipper TEXTRACT_RESUME_PROCESSING gate on the import Textract submit is not restated in the T5 entry.** `job_application.rb:167-169` gates `SubmitResumeToTextractJob.perform_later(id)` behind `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)`. With the flag OFF, a resume-present import creates NO TextractResult at all (a distinct terminal from "no resume"). The T5 changelog/prose blocks describe the resume-present case as if Textract always submits; they do not note that the org-scoped Flipper gate can suppress it. The gate is documented under T1, but the T5 resume-present terminal is incomplete without it.

These are documentation-completeness omissions for the T5 slice; both underlying behaviors are correctly described elsewhere in the map (T1/T4). No contradictions found.

## Conclusion
Every T5 statement AGREES with current code. Two slice-local omissions (O1, O2) noted. clean = false (omissions non-empty).

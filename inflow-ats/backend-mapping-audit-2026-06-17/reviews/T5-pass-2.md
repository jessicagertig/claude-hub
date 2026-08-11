# T5 — Customer API Import — Adversarial Review (pass 2)

Scope: the customer-API import path; trace Textract triggering to terminal.

Files traced:
- `app/controllers/api_public/v1/hire/job_applications_controller.rb:96-126` (`import`), `:201-215` (`job_application_context`)
- `config/routes.rb:499-503` (`post :import`)
- `app/interactors/customer_api/validate_job_application_import.rb:1-84`
- `app/interactors/customer_api/create_job_application.rb:1-105`
- `app/models/job_application.rb:45` (after_commit), `:83-91` (created_via enum), `:160-171` (enqueue_new_job_application + find_or_create wrapper), `:589` (has_resume)
- `app/jobs/submit_resume_to_textract_job.rb`
- `app/services/submit_resume_to_textract.rb:1-42`
- `app/services/get_resume_text_from_textract.rb:1-54`
- `app/models/textract_result.rb:7,9-14,61-89,114-144`
- `app/models/job.rb:914-922` (should_auto_generate_ai_summaries?)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb:1-47`

## Map statements verified for T5

### Changelog "Trigger 5" + Trigger-matrix row 5 + Part 5.1

1. **"Import action calls only ValidateJobApplicationImport + CreateJobApplication inside the transaction (controller:104,107); does NOT call CompleteJobApplication."** — AGREE. `import` at `job_applications_controller.rb:103-109`: `ValidateJobApplicationImport.call(ctx)` (`:104`), `CreateJobApplication.call(@result)` (`:107`); no third interactor. `apply` (`:68-77`) calls all three including `CompleteJobApplication.call` (`:75`). MAP-WRONG verdict on old map "same chain as apply" is itself correct.

2. **"enqueue_new_job_application creates the status row ('none') on every import."** — AGREE. `after_commit :enqueue_new_job_application, on: [:create]` (`job_application.rb:45`); body calls `find_or_create_ai_job_application_summary_status` unconditionally (`:170`). On import there is no existing status row and no latest summary → `find_or_create_ai_job_application_summary_status.rb:23,33-34` else branch sets `status = 'none'` and saves (`:37`).

3. **"Resume is OPTIONAL on import (validate_job_application_import.rb:63): no resume → SubmitResumeToTextract returns 'No resume attached' → no TextractResult, no poll job."** — AGREE. `validate_resume` returns early `unless context.resume_params.present?` (`validate_job_application_import.rb:63`); errors not added → import can succeed with no resume. With no resume attached, `SubmitResumeToTextract#submit_resume` returns at `:10` (`return 'No resume attached' unless @job_application.has_resume`) before building any TextractResult (`:22`) and before scheduling `GetResumeTextFromTextractJob` (`:27`, inside the save block). No TextractResult, no poll job.

4. **"created_via: :created_via_customer_api_import (enum 7)."** — AGREE. `import` passes `job_application_context(:created_via_customer_api_import)` (`controller:101`); enum value `created_via_customer_api_import: 7` (`job_application.rb:91`).

5. **Trigger-matrix row 5: "Base64 (OPTIONAL); Flipper TEXTRACT_RESUME_PROCESSING; status row created 'none'; Omits CompleteJobApplication; no-resume → no TextractResult."** — AGREE. Base64 decode in `validate_job_application_import.rb:66,80`; attach via StringIO in `create_job_application.rb:73-77` (shared with apply). Textract enqueue Flipper-gated at `job_application.rb:167`.

6. **Part 5.1: T5 reaches TextractResult `in_progress` via `submit_resume_to_textract.rb:22` (saved :24).** — AGREE (resume-present sub-case). The shared `after_commit` → `SubmitResumeToTextractJob` → `submit_resume_to_textract.rb:22` build with `textract_job_status: 'in_progress'`, saved `:24`; poll job scheduled `:27`.

7. **Terminal (resume-present): poll succeeds → `get_resume_text_from_textract.rb:31` `.update` → fires `queue_ai_summary_job` → since import creates NO waiting summary, the else auto-generate branch runs (`textract_result.rb:137-143`): `return unless should_auto_generate_ai_summaries?` (`:138`), validate (`:140`), enqueue `GenerateAiJobApplicationSummaryJob(textract_result_id:)` with NO requesting user `if result.success?` (`:142`).** — AGREE. This terminal is documented in the map under Trigger 4 / S-C / Part 3 and incorporated by reference in the T5 note "Textract behavior is identical because it fires from the shared after_commit." The `if ai_summary_waiting_on_textract` (`:125`) is false on import (import never builds a `textract_processing` summary), so the else branch (`:137`) is taken.

## Omissions (T5-relevant detail the map does not state explicitly)

- The map's T5 section does not itself spell out the import terminal state (the auto-generate else branch / its NO-OP-when-no-pre-existing-summary dead end). It defers to the Trigger 4 / S-C sections via "Textract behavior is identical." A reader scoped only to the T5 entries (changelog "Trigger 5", matrix row 5) does not see that, with a resume present and `should_auto_generate_ai_summaries?` true, the import path lands in the S-C NO-OP dead end (Orchestrate returns at `orchestrate.rb:16` when no `AiJobApplicationSummary` pre-exists; `generate_ai_summary_with_credit_flow` returns at `textract_result.rb:82`): no summary, no credit, no broadcast. This is a cross-reference gap, not a contradiction.

- The map's import chain says the two interactors run, but does not note that for an EXISTING candidate `CreateJobApplication` persists the new `job_application` via `job.candidates.push(candidate)` (`create_job_application.rb:40`) rather than an explicit `candidate.save` (the new-candidate branch uses `save_new_candidate` → `candidate.save`, `:62-68`). Both branches end with a persisted job_application that fires the `on: [:create]` after_commit, so the Textract/status-row terminal is unchanged; this is a chain-detail omission only.

## Verdict
Not clean: all map statements AGREE, but the omissions list is non-empty (cross-reference / chain-detail gaps in the T5-scoped entries).

# T4 — Customer API Apply — Adversarial Review (pass 4)

Slice scope: the public/customer API apply endpoint that creates a job application; trace whether/how Textract is triggered, to terminal.

Chain traced (files opened and read):
- `app/controllers/api_public/v1/hire/job_applications_controller.rb`
- `app/interactors/customer_api/validate_job_application_apply.rb`
- `app/interactors/customer_api/create_job_application.rb`
- `app/interactors/customer_api/complete_job_application.rb`
- `app/models/job_application.rb` (:44-45, :82-92, :160-171, :589-590)
- `app/models/job.rb` (:37-38)
- `app/models/candidate.rb` (:101-106)
- `app/services/submit_resume_to_textract.rb`
- `app/models/textract_result.rb` (:7, :60-108, :114-144)
- `app/jobs/generate_ai_job_application_summary_job.rb`
- `app/services/ai_job_application_action/orchestrate.rb` (:5-16)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `config/routes.rb` (:499-503)

## Verdicts (every T4 statement in candidate map)

All map statements about T4 verified AGREE against literal code, with line citations below.

- Route `POST .../apply` at `config/routes.rb:501` — AGREE (`config/routes.rb:501` `post :apply`).
- `def apply` at controller `:62`; ctx with `:created_via_customer_api_apply` at `:66`; transaction `:68-77`; Validate `:69`, Create `:72`, Complete `:75`; rollback on failure `:70/:73/:76` — AGREE (controller `:62,:66,:68-77`).
- Save that fires `after_commit :enqueue_new_job_application` happens inside `CreateJobApplication`, not after `CompleteJobApplication` — AGREE. New candidate `save_new_candidate`→`candidate.save` (`create_job_application.rb:19`, def `:62-68`, `.save` `:63`). Existing candidate `job.candidates.push(candidate)` (`:40`), resume attached at `:36`. `job.candidates` is `has_many through: :job_applications` (`job.rb:38`), so push persists the through job_application and fires its `after_commit on: [:create]` (`job_application.rb:45`).
- `CompleteJobApplication` only adds question responses + sends confirmation email, never saves candidate — AGREE (`complete_job_application.rb:6-9`; calls `add_question_responses` `:7`, `send_confirmation_email` `:8`).
- after_commit fires on OUTER-transaction commit (controller `:77`); Complete failure rolls back create, Textract never enqueued — AGREE (`raise ActiveRecord::Rollback` `:76` inside the single transaction `:68-77`).
- New candidate built `created_via: :created_via_customer_api` (candidate enum value 4) — AGREE (`create_job_application.rb:47`; `candidate.rb:106` `created_via_customer_api: 4`). Distinct from job_application `created_via_customer_api_apply` enum 6 (`job_application.rb:90`).
- `enqueue_new_job_application` enqueues `NewJobApplicationJob` (`:165`) + `DocxToPdfJob` (`:166`) BEFORE gated `SubmitResumeToTextractJob` (`:168`); `find_or_create_ai_job_application_summary_status` (`:170`); `DocxToPdfJob` produces `resume_docx_to_pdf` preferred by submit (`submit_resume_to_textract.rb:15`) — AGREE (`job_application.rb:164-171`; `submit_resume_to_textract.rb:15`).
- Resume base64-decoded in `ValidateJobApplicationApply` (`:77`), `context.decoded_resume = decoded` (`:91`); attached via `StringIO.new(context.decoded_resume)` in `CreateJobApplication#attach_resume` (`:70-78`, `:74`) — AGREE.
- No-resume apply fork: resume required only when `job_settings['resume'] == 'required'` (`validate_job_application_apply.rb:36-38`); resume-less passes, then `SubmitResumeToTextract` returns `'No resume attached'` (`submit_resume_to_textract.rb:10`, before build `:22`) → NO TextractResult, NO poll — AGREE.
- No synchronous textract-ready branch: resume freshly attached, no pre-existing TextractResult; AI pipeline reachable only when poll updates text and `queue_ai_summary_job` fires (`textract_result.rb:114`, registered `after_commit ... on: [:create,:update]` `:7`) — AGREE. On apply, `has_resume`→`resume.attached?` (`job_application.rb:589-590`) true at submit time builds `in_progress` TextractResult (`submit_resume_to_textract.rb:22`).
- Apply-path no-ops in `SubmitResumeToTextract`: `update_all(stale: true)` (`:18-20`) no-op (zero summaries), waiting-summary relink (`:25-26`) no-op (no `textract_processing` summary) — AGREE.
- Creates status row `'none'` (`job_application.rb:170` → `find_or_create_ai_job_application_summary_status.rb`: nil row → else `:22`, no succeeded latest summary → `:34` `status='none'`, save `:37`); creates NO `AiJobApplicationSummary` — AGREE.
- No-summary terminal: TextractResult `succeeded` → `queue_ai_summary_job` else branch (`textract_result.rb:137`), `return unless should_auto_generate_ai_summaries?` (`:138`), `ValidateAiSummaryGeneration` (`:140`), enqueue `GenerateAiJobApplicationSummaryJob(textract_result_id:)` if success (`:142`, NO requesting user) → `generate_ai_summary_with_credit_flow` → `Orchestrate#call` returns at `orchestrate.rb:16` (no summary) → `textract_result.rb:82` returns (no succeeded summary) → S-C NO-OP dead end (no summary, no credit, no broadcast) — AGREE.
- MAP-WRONG vs old map "Import: same interactor chain as Apply" (Import omits CompleteJobApplication; Textract identical via shared after_commit) — AGREE (import action `:97-126` calls only Validate `:104` + Create `:107`).
- Summary table row 4 (`:605`): entry `apply` (`:62`), 3 interactors one transaction, Base64 required only if job_settings, Flipper gate `TEXTRACT_RESUME_PROCESSING`, status row `'none'`, save fires inside CreateJobApplication, no summary, resume-less→no TextractResult — AGREE.
- TextractResult `in_progress` table row (`:516`) lists T4; reached on apply-with-resume — AGREE.
- "No TextractResult ever created" dead-end (`:526`) lists T4 (no resume) and the `TEXTRACT_RESUME_PROCESSING` OFF case — AGREE.
- Status `none` create-path row (`:555`) reached by T4 — AGREE.

## Omissions (T4 narrative section, lines 274-286)

1. The T4 NARRATIVE section (lines 50-59 changelog and 274-286 detail) never states that the apply-path `SubmitResumeToTextractJob` enqueue is gated by `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` (`job_application.rb:167-169`), even though the parallel T5 narrative (line 292) and T6 narrative explicitly call this gate out. The flag-OFF resume-present terminal (no TextractResult despite a resume) is a distinct resting state for T4. It IS captured in the summary table row 605 ("Flipper Gate: TEXTRACT_RESUME_PROCESSING") and the dead-end census line 526 ("gated OFF by TEXTRACT_RESUME_PROCESSING (T1/T2/T3/T4/T5/T6)"), so the fact is not absent from the map as a whole — but the T4 trigger narrative is asymmetric with T5/T6 and omits it where a reader of the T4 section alone would look.

   Suggested map text (add to Trigger 4 narrative): "Flipper gate: the apply-path `SubmitResumeToTextractJob` is enqueued only when `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)` (`job_application.rb:167-169`). With the flag OFF, a resume-present apply creates NO TextractResult — a distinct terminal from the no-resume case."

## clean

clean = false (one omission: T4 narrative omits the `TEXTRACT_RESUME_PROCESSING` Flipper gate that T5/T6 narratives include; the fact is present elsewhere in the map but absent from the T4 trigger narrative). All factual verdicts are AGREE.

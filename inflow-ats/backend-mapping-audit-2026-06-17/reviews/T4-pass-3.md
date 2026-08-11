# T4 — Customer API Apply — Adversarial Review Pass 3

Slice: T4. The public/customer API apply endpoint that creates a job application; whether/how Textract is triggered, traced to terminal.

Files traced (chain):
- `config/routes.rb:499-501` (route)
- `app/controllers/api_public/v1/hire/job_applications_controller.rb:62-94` (`apply`), `:201-215` (`job_application_context`), `:193-199` (`candidate_params`)
- `app/interactors/customer_api/validate_job_application_apply.rb:7-94`
- `app/interactors/customer_api/create_job_application.rb:6-78`
- `app/interactors/customer_api/complete_job_application.rb:6-9`
- `app/models/job_application.rb:45` (callback reg), `:83-92` (created_via enum), `:164-171` (`enqueue_new_job_application`)
- `app/models/candidate.rb:101-106` (candidate created_via enum)
- `app/services/submit_resume_to_textract.rb:8-30`
- `app/models/textract_result.rb:114-144` (`queue_ai_summary_job`)
- `app/models/job.rb:914` (`should_auto_generate_ai_summaries?`)

## Verdicts on candidate-map statements (changelog lines 43-49; trigger detail lines 240-249)

1. Route `POST /v1/hire/job_applications/apply` at `routes.rb:501` → `def apply` at controller `:62`.
   AGREE. `config/routes.rb:501` `post :apply`; controller `:62` `def apply`.

2. `created_via: :created_via_customer_api_apply` (controller `:66`; enum value 6, `job_application.rb:90`).
   AGREE. Controller `:66` `ctx = job_application_context(:created_via_customer_api_apply)`; `job_application.rb:90` `created_via_customer_api_apply: 6`.

3. Resume base64-decoded in `ValidateJobApplicationApply` (`:77,91`), attached via StringIO in `CreateJobApplication` (`attach_resume`, `create_job_application.rb:70-78`).
   AGREE. `validate_job_application_apply.rb:77` `decoded = decode_base64(...)`; `:91` `context.decoded_resume = decoded`. `create_job_application.rb:70-78` `attach_resume`, `:74` `StringIO.new(context.decoded_resume)`.

4. The save that fires `after_commit :enqueue_new_job_application` is inside `CreateJobApplication`, not after `CompleteJobApplication`. New candidate: `save_new_candidate` → `candidate.save` (`:19`, def `:62-68`, `.save` `:63`).
   AGREE. `create_job_application.rb:19` `save_new_candidate(candidate)`; def `:62-68`; `:63` `unless candidate.save`.

5. Existing candidate: `job.candidates.push(candidate)` (`:40`) — NOT a `candidate.save` — with the resume attached at `:36` before push.
   AGREE. `create_job_application.rb:36` `attach_resume(job_application)`; `:40` `job.candidates.push(candidate)`. Both branches build job_application with `created_via: context.created_via` (`:31`, `:52`).

6. `CompleteJobApplication` only adds question responses and sends the confirmation email; never saves the candidate (`complete_job_application.rb:6-9`).
   AGREE. `complete_job_application.rb:6-9` body is `add_question_responses` + `send_confirmation_email if context.send_candidate_confirmation_email`. Neither saves candidate; `add_question_responses` saves QuestionResponse records (`:25`), `send_confirmation_email` mails/creates a channel message.

7. Whole apply runs inside one `ActiveRecord::Base.transaction` (controller `:68-77`); after_commit fires on OUTER-transaction commit after CompleteJobApplication succeeds (controller `:77`). A CompleteJobApplication failure (`raise ActiveRecord::Rollback`, `:76`) rolls back the create and Textract is never enqueued.
   AGREE. Controller `:68` `ActiveRecord::Base.transaction do`; `:76` `raise ActiveRecord::Rollback if @result.failure?`; `:77` end. `after_commit` semantics fire on outer commit; a rollback prevents commit, so `enqueue_new_job_application` never runs.

8. New candidate built with `created_via: :created_via_customer_api` (`create_job_application.rb:47`), distinct from the job_application's `created_via_customer_api_apply`.
   AGREE. `create_job_application.rb:47` `.merge(created_via: :created_via_customer_api)`. `candidate.rb:106` `created_via_customer_api: 4` (a distinct Candidate enum). JobApplication uses `created_via_customer_api_apply` (value 6).

9. `enqueue_new_job_application` enqueues `NewJobApplicationJob` and `DocxToPdfJob` (`job_application.rb:165-166`) BEFORE the Textract submit (`:168`); `DocxToPdfJob` produces `resume_docx_to_pdf`, which `SubmitResumeToTextract` prefers (`submit_resume_to_textract.rb:15`).
   AGREE. `job_application.rb:165` `NewJobApplicationJob.perform_later(id)`; `:166` `DocxToPdfJob.perform_later(id)`; `:167` Flipper gate; `:168` `SubmitResumeToTextractJob.perform_later(id)`. `submit_resume_to_textract.rb:15` `@job_application.has_resume_docx_to_pdf ? @job_application.resume_docx_to_pdf : @job_application.resume`.

10. Apply path eagerly creates the `AiJobApplicationSummaryStatus` row (`'none'`) via the shared `enqueue_new_job_application` callback (`job_application.rb:170`); creates NO `AiJobApplicationSummary`.
    AGREE. `job_application.rb:170` `find_or_create_ai_job_application_summary_status` (unconditional). None of the three apply interactors creates an `AiJobApplicationSummary` (read in full).

11. Apply-path no-summary terminal: TextractResult `succeeded` → `queue_ai_summary_job` else branch → enqueues only if `should_auto_generate_ai_summaries?` (`textract_result.rb:137-142`) → S-C NO-OP dead end (no pre-existing summary).
    AGREE (line precision note). `textract_result.rb:121-123` finds the waiting summary; apply has none, so `:137` else branch: `:138` `return unless job_application&.job&.should_auto_generate_ai_summaries?`; `:140` validate; `:142` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id) if result.success?`. The guard is at `:138`, within the map's cited `137-142` range — acceptable. The S-C no-op terminal is by cross-reference (verified elsewhere).

12. Map "Trigger 5 Import: Same interactor chain as Apply" correction — Import omits `CompleteJobApplication`.
    AGREE (T5-scoped, consistent for T4). Apply runs all three interactors (controller `:69,72,75`); import runs only Validate + Create (`:104,107`). For T4, the apply chain includes `CompleteJobApplication` — confirmed.

## Omissions (for the T4 slice)

- O1. No-resume apply fork. `ValidateJobApplicationApply` requires a resume ONLY when `job_settings['resume'] == 'required'` (`validate_job_application_apply.rb:36-38`). An apply with no resume passes validation and creates a job_application with no resume. Then `SubmitResumeToTextract` returns `'No resume attached'` at `submit_resume_to_textract.rb:10` (before the build at `:22`) → NO TextractResult, NO poll job. Benign terminal. The map documents this entry fork for T1/T5/T6 but the T4 section (lines 240-249) does not state it for apply. The map's T4 bullets implicitly assume a resume is present.

- O2. The textract-ready-vs-not-ready fork at apply is never explicitly stated for T4. For apply WITH a resume, `enqueue_new_job_application` builds the `in_progress` TextractResult via `SubmitResumeToTextract` (`:22`), and the AI pipeline is reached only later when polling succeeds and `queue_ai_summary_job` fires. There is no synchronous "textract ready" branch on the apply path (the resume is freshly attached, so a TextractResult never pre-exists at creation). The map states the no-summary terminal but does not name this fork explicitly for T4.

- O3. The map's T4 detail does not mention that on the apply path `SubmitResumeToTextract`'s `update_all(stale: true)` (`submit_resume_to_textract.rb:18-20`) is a no-op (the fresh apply job_application has zero summaries) and `waiting_summary` relink (`:25-26`) is a no-op (no `textract_processing` summary). Minor; the terminal conclusion is unaffected.

## Record-write sites on the T4 path

- `create_job_application.rb:63` `candidate.save` — INSERT Candidate + (via `job_applications.build`) JobApplication (new-candidate branch).
- `create_job_application.rb:40` `job.candidates.push(candidate)` — persists the built JobApplication on an existing candidate.
- `complete_job_application.rb:25` `question_response.save` — INSERT QuestionResponse (apply-only).
- `job_application.rb:170` → `FindOrCreateAiJobApplicationSummaryStatus` — creates/finds the status row (`'none'` on fresh apply).
- `submit_resume_to_textract.rb:19` `update_all(stale: true)` — no-op on apply (no summaries).
- `submit_resume_to_textract.rb:22/24` `textract_results.build` + `.save` — INSERT TextractResult `in_progress` (only when resume present).

clean = false (omissions O1-O3 exist; all explicit map statements AGREE).

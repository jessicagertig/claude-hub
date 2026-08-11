# T4 — Customer API Apply — Adversarial Review (pass 2)

Scope: the public/customer API apply endpoint that creates a job application; whether/how Textract is triggered, to terminal.

Files traced:
- config/routes.rb:499-501 (`post :apply`)
- app/controllers/api_public/v1/hire/job_applications_controller.rb:62-94 (`apply`), :201-215 (`job_application_context`)
- app/interactors/customer_api/validate_job_application_apply.rb (resume decode :73-94)
- app/interactors/customer_api/create_job_application.rb (build + save, attach_resume :70-78)
- app/interactors/customer_api/complete_job_application.rb (question responses + confirmation email; NO candidate.save)
- app/models/job_application.rb:45 (after_commit), :83-91 (created_via enum), :160-171 (enqueue_new_job_application)
- app/models/textract_result.rb:114-144 (queue_ai_summary_job), :61-89 (generate_ai_summary_with_credit_flow), :98-108 (set_initial_summary_pending)
- app/services/ai_job_application_action/orchestrate.rb:9-50 (return at :16)
- app/models/job.rb:914-922 (should_auto_generate_ai_summaries?)

## Verdicts on candidate-map statements

### AGREE
- Route/entry `POST /v1/hire/job_applications/apply` → `def apply` at controller :62. routes.rb:501; controller:62.
- Chain order ValidateJobApplicationApply → CreateJobApplication → CompleteJobApplication inside a transaction. controller:69,72,75.
- `created_via: :created_via_customer_api_apply`. controller:66 `job_application_context(:created_via_customer_api_apply)`; enum value at job_application.rb:90.
- Resume base64-decoded in ValidateJobApplicationApply. validate_job_application_apply.rb:77 `decode_base64(...)`, stored to `context.decoded_resume` :91.
- Resume attached via StringIO in CreateJobApplication (attach_resume at :70-78). create_job_application.rb:73-77 `job_application.resume.attach(io: StringIO.new(context.decoded_resume) ...)`.
- None of the three interactors triggers Textract directly; it fires only via the shared after_commit. Grep of the 3 interactors shows no SubmitResumeToTextract call; enqueue is at job_application.rb:168 inside enqueue_new_job_application.
- Textract enqueue is Flipper-gated (`TEXTRACT_RESUME_PROCESSING`, job.organization). job_application.rb:167-168.
- Apply path creates the status row (`'none'`) via enqueue_new_job_application → find_or_create_ai_job_application_summary_status (UNCONDITIONAL). job_application.rb:170,160-162. Creates NO AiJobApplicationSummary (no interactor builds one on apply).
- No-summary terminal: TextractResult succeeded → queue_ai_summary_job else branch → enqueues only if should_auto_generate_ai_summaries?. textract_result.rb:137-142; job.rb:914.
- Auto-generate with no pre-existing summary is a NO-OP dead end: Orchestrate#call returns at orchestrate.rb:16 (`return unless @ai_job_application_summary`), Summary::Generate never reached (only via run_summary at :64), generate_ai_summary_with_credit_flow returns at textract_result.rb:82 (summary nil). No summary, no credit, no broadcast.

### DISPUTE
1. Map line 199 chain literal: "... → CompleteJobApplication → candidate.save → after_commit :enqueue_new_job_application".
   - The candidate/job_application is persisted INSIDE CreateJobApplication, NOT after CompleteJobApplication. New-candidate path: save_new_candidate(candidate) at create_job_application.rb:19 (`candidate.save` :63). Existing-candidate path: NO candidate.save at all — persistence is via `job.candidates.push(candidate)` at create_job_application.rb:40.
   - CompleteJobApplication (complete_job_application.rb) calls only add_question_responses (:7) and send_confirmation_email (:8); it never saves the candidate or job_application. By the time it runs, the after_commit has effectively already been scheduled by the CreateJobApplication save, but it commits when the controller transaction (controller:68-77) commits.
   - Correction: the save that triggers `after_commit :enqueue_new_job_application` happens in CreateJobApplication (new candidate: create_job_application.rb:19/63; existing candidate: create_job_application.rb:40 via push, not save), and the after_commit fires at outer-transaction commit (controller:77), not "after CompleteJobApplication → candidate.save".

## Omissions (T4)
- The existing-candidate branch (build_application_for_existing_candidate, create_job_application.rb:28-41) is not mentioned. It persists via `job.candidates.push(candidate)` (:40) rather than candidate.save, and attaches the resume at :36 before push. The map's "before candidate.save" framing covers only the new-candidate branch.
- The new candidate is created with `created_via: :created_via_customer_api` (create_job_application.rb:47) — distinct from the job_application's `created_via_customer_api_apply`. Not noted.
- The whole apply runs inside a single `ActiveRecord::Base.transaction` (controller:68-77); the `after_commit :enqueue_new_job_application` therefore fires only on outer-transaction commit, after CompleteJobApplication succeeds. If CompleteJobApplication fails (raise ActiveRecord::Rollback, controller:76), the create is rolled back and Textract is never enqueued. The map does not state the transactional gating of the after_commit.
- `enqueue_new_job_application` also enqueues NewJobApplicationJob and DocxToPdfJob (job_application.rb:165-166) ahead of the Textract submit; DocxToPdfJob produces resume_docx_to_pdf which SubmitResumeToTextract prefers. Not noted in the T4 section (mentioned only generically in Trigger 1).

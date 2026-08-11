# T3 — Clone Job Application — Adversarial Review (pass 4)

Slice question: does cloning create a TextractResult, trigger Textract, or copy an existing result?

Chain traced from scratch:
`config/routes.rb:282` (`put :clone_to_job`) →
`app/controllers/api/v1/job_applications_controller.rb:132-145` (`clone_to_job`) →
`app/models/job_application.rb:387-412` (`clone_to_job_at_hiring_stage`, `dup` at :391, `resume.attach(resume.blob) if has_resume` at :401, `created_via = 'created_via_clone'` at :400, `clone_of_job_application_id = id` at :399) →
controller `:139` `new_job_application.errors.empty? && new_job_application.save` →
`app/models/job_application.rb:45` (`after_commit :enqueue_new_job_application, on: [:create]`) →
`app/models/job_application.rb:164-171` (`enqueue_new_job_application`: `SubmitResumeToTextractJob` Flipper-gated at :167-168, `find_or_create_ai_job_application_summary_status` at :170) →
`app/services/submit_resume_to_textract.rb:10` (`return 'No resume attached' unless has_resume`), `:22` (`textract_results.build(...status:'in_progress')`) →
`app/models/textract_result.rb:114-144` (`queue_ai_summary_job`, else branch :137-143) →
`app/interactors/find_or_create_ai_job_application_summary_status.rb:34` (else → `'none'`).

Also examined: `app/interactors/clone_job_application.rb` (dead code), `app/models/job_application.rb:414-437` (`complete_cloning`, after_create :47).

## ANSWER TO SLICE QUESTION
Cloning does NOT copy the original's TextractResult. `dup` (job_application.rb:391) copies attributes only — no `def dup`/`initialize_dup` override exists (grep confirmed); `textract_results` (has_many, :28) and `ai_job_application_summaries` (:29) are not duplicated. The clone re-attaches the resume blob conditionally (`if has_resume`, :401) and, on save, the `on: [:create]` after_commit enqueues a FRESH `SubmitResumeToTextractJob` (Flipper-gated, :167-168) which builds a brand-new independent TextractResult (`submit_resume_to_textract.rb:22`). Resume-less original → no re-attach → SubmitResumeToTextract early-returns `'No resume attached'` (:10) → no TextractResult.

## VERDICTS (every T3 map statement)

All AGREE. Detail:

- Controller action `clone_to_job` at `job_applications_controller.rb:132-145`; route `put :clone_to_job` at `routes.rb:282`. AGREE.
- Clone creates fresh status row `'none'` via FindOrCreate else branch `find_or_create_ai_job_application_summary_status.rb:34`; fresh clone's `latest_ai_job_application_summary` (`job_application.rb:31`) is nil. AGREE — line 34 `@status_record.status = 'none'` is reached because the clone has no summaries (dup copies no associations).
- Auto-gen requires BOTH `should_auto_generate_ai_summaries?` (`textract_result.rb:138`) AND `ValidateAiSummaryGeneration` success (`:140-142`); deterministically ELSE branch (:137), never IF (:125), no `textract_processing` waiting summary copied; no requesting user (:142). AGREE — verified :121-123 waiting-summary query, :137-143 else branch.
- `resume.blob` re-attach CONDITIONAL `if has_resume` (`job_application.rb:401`); resume-less original re-attaches nothing → no TextractResult. AGREE.
- `additional_files` blobs re-attached when present (`job_application.rb:403-407`). AGREE (`has_many_attached :additional_files` :38).
- No-resume clone terminal: SubmitResumeToTextract returns `'No resume attached'` (`submit_resume_to_textract.rb:10`) → no TextractResult, status row `'none'`. AGREE.
- Candidate-already-in-target dead end: `:taken` error at `job_application.rb:393`; controller guard `:139` short-circuits → no save, no after_commit. AGREE.
- `CloneJobApplication` (`clone_job_application.rb`) DEAD CODE: zero callers (grep: only self-refs); `clone_to_job(new_job_id, ...)` at :22 — no `def clone_to_job` model method (grep shows only controller action + JobPolicy#clone_to_job?); `new_job_id` undefined local. AGREE.
- `complete_cloning` after_create (`job_application.rb:47`, body :414-437) copies only `question_responses` (:430-435); channels commented out (:420-428); no Textract/AI. AGREE.
- Controller `.save` (:139) fires after_commit (`job_application.rb:45`) → Flipper-gated fresh Textract submit + status row `'none'` (:167-170) — "Fresh independent TextractResult" (map line 604). AGREE.

## OMISSIONS
None for the slice. Map covers: route, controller, clone method, dup-no-association, conditional resume re-attach, additional_files, fresh after_commit Textract submit, Flipper gate, status row 'none', auto-gen branch, no-resume terminal, candidate-taken dead end, CloneJobApplication dead code, complete_cloning. All present.

## clean = true

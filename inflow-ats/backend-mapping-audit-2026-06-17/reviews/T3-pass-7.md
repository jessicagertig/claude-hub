# T3 Adversarial Review — Pass 7

Slice: T3 — Clone job application to another job. Does cloning create a TextractResult, trigger Textract, or copy an existing result?

Candidate map section under audit: lines 48-58 of `backend-flow-map-2026-06-17.md`.

## Trace chain followed

`job_applications_controller.rb:132 (clone_to_job)` -> `job_application.rb:387 (clone_to_job_at_hiring_stage)` -> `job_application.rb:391 (dup)` / `:393 :taken` / `:401 resume.attach` / `:403-407 additional_files` -> controller `:139 (errors.empty? && save)` -> `job_application.rb:45 (after_commit :enqueue_new_job_application, on: [:create])` -> `job_application.rb:164-171 (enqueue_new_job_application)` -> `:167-168 Flipper gate + SubmitResumeToTextractJob` + `:170 find_or_create_ai_job_application_summary_status` -> `find_or_create_ai_job_application_summary_status.rb:22-39 (else branch)` -> `submit_resume_to_textract.rb:8-30` -> `textract_result.rb:114-144 (queue_ai_summary_job bridge)`.
Also: `job_application.rb:47 (after_create :complete_cloning)` -> `job_application.rb:414-437`.
Dead code: `clone_job_application.rb:1-28` (CloneJobApplication).

## Verdicts

### Map line 49 — Controller action line range / route
AGREE. `def clone_to_job` at `job_applications_controller.rb:132-145`; route `put :clone_to_job` at `config/routes.rb:282`.

### Map line 50 — Clone creates fresh AiJobApplicationSummaryStatus row 'none' via else branch :34; clone's latest_ai_job_application_summary is nil
AGREE. `dup` (`job_application.rb:391`) does not copy the `has_one :ai_job_application_summary_status` (`:32`), so the cloned record has no status record; `find_or_create_ai_job_application_summary_status.rb:9` `@status_record` is nil -> else branch (`:22`). `latest_ai_job_application_summary` (`job_application.rb:31`, `has_one ... class_name: 'AiJobApplicationSummary'` scoped to the clone's own summaries) is nil because `dup` does not copy `has_many :ai_job_application_summaries` (`:29`); therefore `:27` is false and `:34` sets `'none'`. Row saved at `:37`.

### Map line 51 — Auto-gen requires BOTH should_auto_generate_ai_summaries? AND ValidateAiSummaryGeneration success?; clone deterministically takes the ELSE branch; no requesting user
AGREE. `textract_result.rb:138` `return unless job_application&.job&.should_auto_generate_ai_summaries?` (TARGET job, since clone `job_id = target_job.id` at `job_application.rb:395`); `:140` `ValidateAiSummaryGeneration.call`; `:142` enqueues only `if result.success?`, with no `requesting_organization_user_id`. ELSE branch taken because the clone has no `textract_processing`/`stale:false` waiting summary (`:121-123` returns nil — `dup` copies no summaries), so `:125` IF is skipped.

### Map line 52 — resume.attach(resume.blob) is CONDITIONAL on has_resume (:401); resume-less original re-attaches nothing, no TextractResult
AGREE. `job_application.rb:401` `job_application.resume.attach(resume.blob) if has_resume`. `has_resume` def at `:589`.

### Map line 53 — additional_files blobs re-attached on clone (:403-407)
AGREE. `job_application.rb:403-407`. Out-of-slice but accurately cited.

### Map line 54 — No-resume clone terminal: nothing re-attached -> SubmitResumeToTextract returns 'No resume attached' (:10) -> no TextractResult, status row 'none'
AGREE. `submit_resume_to_textract.rb:10` `return 'No resume attached' unless @job_application.has_resume`, before the build at `:22`. Status row stays `'none'` (`find_or_create_ai_job_application_summary_status.rb:34`).

### Map line 55 — Candidate-already-in-target dead end: :taken error (:393) -> controller guard short-circuits (:139) -> no save
AGREE. `job_application.rb:393` `job_application.errors.add(:candidate, :taken, message: 'already exists in that job') if target_job.candidates.where(id: candidate_id).any?`. Controller `:139` `if new_job_application.errors.empty? && new_job_application.save` — short-circuits on non-empty errors; no save, no `after_commit`, no status row, no Textract.

### Map line 56 — CloneJobApplication is DEAD CODE: zero callers, calls undefined job_application.clone_to_job and undefined local new_job_id (:22); not on any route
AGREE. grep for `CloneJobApplication` returns only self-references in `app/interactors/clone_job_application.rb`. No `def clone_to_job` instance method exists on JobApplication (only `clone_to_job_at_hiring_stage`; the other `clone_to_job` definitions are the controller action `:132` and policy method `job_policy.rb:50`). `new_job_id` is never assigned in the interactor.

### Map line 57 — complete_cloning (after_create, :414-437) copies only question_responses (:430-435); channel/message cloning commented out (:420-428); does not touch Textract or AI summaries
AGREE. `after_create :complete_cloning` at `job_application.rb:47`; body `:414-437`; `:420-428` commented out; `:430-435` `question_responses << new_question_response`. No Textract/summary references.

## Omissions

1. **The direct slice question is never answered in one place: clone does NOT copy the original's TextractResult; it creates a NEW one by re-submitting the re-attached blob.** `dup` (`job_application.rb:391`) does not copy `has_many :textract_results` (`:28`), so the clone has zero TextractResults at creation. The resume *blob* is re-attached (`:401`), and `enqueue_new_job_application` (`:168`) enqueues `SubmitResumeToTextractJob`, which BUILDS a brand-new `in_progress` TextractResult (`submit_resume_to_textract.rb:22`, no find_or_create) by sending the re-attached blob to Textract afresh (`:16`). The original's `textract_job_result_text` is NOT carried over. The map's T3 bullets describe the status row and auto-gen but never state this central fact (copy vs new) explicitly for the slice.

2. **The clone's Textract submit is Flipper-gated at `job_application.rb:167` — with `TEXTRACT_RESUME_PROCESSING` OFF, a resume-bearing clone produces NO TextractResult.** The map attributes this gate to "T1/T3/T4/T5/T6" generically in the T2 bullet (line 33) and lists model-side site `:167`, but the T3 section (lines 48-58) does not state the flag-OFF clone terminal. A resume-present clone with the flag OFF rests with a re-attached resume, status row `'none'`, no TextractResult — a distinct clone resting state.

3. **Terminal-state trace for the happy clone path is absent.** For a resume-bearing clone with flag ON: new `in_progress` TextractResult (`submit_resume_to_textract.rb:22`) -> poll via `GetResumeTextFromTextractJob.set(wait: 2.minutes)` (`:27`) -> on success the bridge `queue_ai_summary_job` (`textract_result.rb:114`) takes the ELSE branch (`:137`); if auto-gen OFF it returns at `:138` (succeeded TextractResult, NO summary, status row stays `'none'`); if auto-gen ON it enqueues `GenerateAiJobApplicationSummaryJob` with no requesting user (`:142`). The map's lines 50-51 imply the auto path but do not trace to the succeeded-TextractResult-but-no-summary resting state for the auto-gen-OFF clone.

4. **`stale`/relink no-ops on clone not stated.** On the clone's Textract submit, `update_all(stale: true)` (`submit_resume_to_textract.rb:18-19`) is a no-op (the fresh clone has zero summaries) and the waiting-summary relink (`:25-26`) is a no-op (no `textract_processing` summary). Stated for T4/T5 in the map but not for T3.

5. **Controller authorizes the SOURCE job before cloning.** `job_applications_controller.rb:134` `authorize job_application.job` (the source job's `clone_to_job?` policy, `job_policy.rb:50` `on_hiring_team?`), not the target job. Out-of-Textract-slice but part of the clone entry path; not mentioned.

## Verdict
clean = false (all statements AGREE, but omissions are non-empty).

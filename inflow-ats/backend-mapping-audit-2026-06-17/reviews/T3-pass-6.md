# T3 — Clone Job Application — Adversarial Review (pass-6)

Slice: T3. Determine whether cloning creates a TextractResult, triggers Textract, or copies an existing result. Trace to terminal.

Files traced:
- `app/controllers/api/v1/job_applications_controller.rb:132-145` (clone_to_job)
- `config/routes.rb:282` (put :clone_to_job)
- `app/models/job_application.rb:387-412` (clone_to_job_at_hiring_stage)
- `app/models/job_application.rb:414-437` (complete_cloning)
- `app/models/job_application.rb:44-48` (callback registration)
- `app/models/job_application.rb:164-171` (enqueue_new_job_application)
- `app/models/job_application.rb:31` (latest_ai_job_application_summary has_one)
- `app/models/job_application.rb:589` (has_resume)
- `app/models/job_application.rb:83-92` (created_via enum; clone=5)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb:1-47`
- `app/interactors/clone_job_application.rb:1-28` (dead code)
- `app/services/submit_resume_to_textract.rb:8-30`
- `app/models/textract_result.rb:114-144` (queue_ai_summary_job bridge)

## Verdicts

### Map line 49 — Clone controller action line range
AGREE. `def clone_to_job` at `job_applications_controller.rb:132`; closes at `:145`. Route `put :clone_to_job` at `routes.rb:282`.

### Map line 50 — Clone creates fresh status row 'none' via FindOrCreate else branch :34; clone's latest_ai_job_application_summary is nil
AGREE. The clone is `dup` (`job_application.rb:391`); `dup` copies attributes only, not associations, so the new record has zero AiJobApplicationSummary rows. `latest_ai_job_application_summary` is a `has_one` scoped to this job_application (`job_application.rb:31`) → nil for the fresh clone. In `FindOrCreateAiJobApplicationSummaryStatus`, the clone has no existing status row (it's a brand new record) so the else branch runs (`:22`); `latest_ai_job_application_summary&.status_succeeded?` is false (nil) at `:27`, so the `else` at `:33-34` sets `status: 'none'`. The status row is created via `enqueue_new_job_application` (`job_application.rb:170`), which fires `after_commit on: [:create]` (`:45`). Correct.

### Map line 51 — Clone AI auto-gen NOT solely on target should_auto_generate; requires BOTH should_auto_generate (textract_result.rb:138) AND ValidateAiSummaryGeneration success (:140-142); clone deterministically takes ELSE branch (:137), never waiting-summary IF (:125), because no textract_processing waiting summary copied; enqueued with no requesting user (:142)
AGREE. Bridge `queue_ai_summary_job`: waiting-summary query at `textract_result.rb:121-123` (`status: :textract_processing, stale: false`). The clone has no AiJobApplicationSummary rows at all (dup copies no associations), so `ai_summary_waiting_on_textract` is nil → else branch at `:137`. Else branch: `return unless ...should_auto_generate_ai_summaries?` (`:138`), then `ValidateAiSummaryGeneration.call` (`:140`), then `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id) if result.success?` (`:142`) — no `requesting_organization_user_id`. Both gates confirmed; no requesting user confirmed.

### Map line 52 — resume.blob re-attach is CONDITIONAL: attach(resume.blob) if has_resume (job_application.rb:401); resume-less original re-attaches nothing, produces no TextractResult
AGREE. `job_application.rb:401`: `job_application.resume.attach(resume.blob) if has_resume`. `has_resume` def at `:589`. This is the answer to the slice question: clone does NOT copy the TextractResult record — it re-attaches the resume blob and lets the standard create-callback pipeline build a NEW TextractResult. The original's `textract_results` association is never copied (dup copies no associations; complete_cloning copies only question_responses).

### Map line 53 — additional_files blobs re-attached on clone (job_application.rb:403-407)
AGREE. `:403-407`: `if additional_files.attached?` then each `job_application.additional_files.attach(additional_file.blob)`. Out-of-slice but accurate.

### Map line 54 — no-resume clone terminal: :401 re-attaches nothing, SubmitResumeToTextract returns 'No resume attached' (submit_resume_to_textract.rb:10) → NO TextractResult, no poll, no AI pipeline; status row still 'none'
AGREE with a precision note. File is `app/services/submit_resume_to_textract.rb` (a service, not interactor), method `submit_resume`; `return 'No resume attached' unless @job_application.has_resume` at `:10`. The early-return is reached only if `SubmitResumeToTextractJob` was enqueued, which is itself Flipper-gated (`job_application.rb:167`). With the flag OFF the job is never enqueued (same terminal, different mechanism). The map's text does not state the file is `app/interactors/...`; it cites `submit_resume_to_textract.rb:10` which is correct as a basename. Terminal (no TextractResult, status row 'none') is correct.

### Map line 55 — candidate-already-in-target dead end: clone_to_job_at_hiring_stage adds :taken error (job_application.rb:393); controller guard new_job_application.errors.empty? && new_job_application.save (job_applications_controller.rb:139) short-circuits → no save, no after_commit, no status row, no Textract, no record
AGREE. `job_application.rb:393`: `job_application.errors.add(:candidate, :taken, message: 'already exists in that job') if target_job.candidates.where(id: candidate_id).any?`. Controller `:139`: `if new_job_application.errors.empty? && new_job_application.save`. With a pre-existing `:taken` error, `errors.empty?` is false → `&&` short-circuits, `save` never called → no `after_commit on: [:create]` → no status row, no Textract. Else branch `render_errors` (`:142`). Correct.

### Map line 56 — CloneJobApplication interactor is DEAD CODE: zero callers, calls undefined job_application.clone_to_job and undefined local new_job_id (clone_job_application.rb:22); not on any route
AGREE. `grep -rn CloneJobApplication app/ lib/ config/` returns only matches inside `clone_job_application.rb` itself (the `ap 'CloneJobApplication'` string at `:8`) — zero external callers. `:22`: `job_application.clone_to_job(new_job_id, context.user.id)`. There is NO `def clone_to_job` instance method on JobApplication (only `clone_to_job_at_hiring_stage` at `:387`); `def clone_to_job` exists only as the controller action (`:132`) and a policy method (`job_policy.rb:50`). `new_job_id` is an undefined local in the interactor (no assignment, no method, no context attr). Dead code confirmed.

### Map line 57 — complete_cloning (after_create, job_application.rb:414-437) copies only question_responses (:430-435); channel/message cloning commented out (:420-428); does not touch Textract or AI summaries
AGREE. Registered `after_create :complete_cloning` at `job_application.rb:47`. Body `:414-437`: guard `return unless clone_of_job_application_id.present?` (`:415`); channels block commented `:420-428`; `original.question_responses.reverse_each` copying `:430-435`. No Textract, no AI summary, no status-row code. Correct.

## Omissions

None material to the slice. The map's T3 section answers the slice question directly (clone re-attaches the resume blob and lets the create-callback build a NEW TextractResult; it does NOT copy the original's TextractResult; resume-less clone produces none), enumerates the dead-end (candidate-already-in-target), the dead-code interactor, and complete_cloning. The clone-with-resume happy-path terminal (status row 'none' → SubmitResumeToTextractJob builds in_progress TextractResult → poll → bridge else branch → auto-gen gated) is covered by the T3 bullets plus the shared T1/S-C narrative the bullets cross-reference.

## Conclusion
All 9 T3 statements AGREE. No omissions. clean = true.

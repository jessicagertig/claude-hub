# T3 Adversarial Review — Pass 5 (Clone Job Application)

Re-audited from scratch against current code. Candidate map section: lines 43-52.

## Verdicts

### Claim 44 — Clone controller action line range
- Map: `def clone_to_job` at `job_applications_controller.rb:132-145`; route `put :clone_to_job` at `config/routes.rb:282`.
- AGREE. `job_applications_controller.rb:132` `def clone_to_job`, ends `:145`. `config/routes.rb:282` `put :clone_to_job`.

### Claim 45 — Clone creates fresh status row `'none'`; clone's `latest_ai_job_application_summary` nil
- AGREE. `dup` (`job_application.rb:391`) copies no `has_one` associations, so on `after_create :complete_cloning`/`enqueue_new_job_application` the clone has no `ai_job_application_summary_status` → `FindOrCreateAiJobApplicationSummaryStatus` `:9` nil → else branch `:22`; `latest_ai_job_application_summary` (`job_application.rb:31`, `has_one` scoped to the clone) is nil → `:27` false → `:34` `status = 'none'`. Confirmed.

### Claim 46 — Auto-gen NOT gated solely on target job; needs both `should_auto_generate_ai_summaries?` + `ValidateAiSummaryGeneration.success?`; clone takes ELSE branch, no requesting user
- AGREE. `textract_result.rb:121-123` queries `job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false)` — scoped to the clone, which has zero summaries → `ai_summary_waiting_on_textract` nil → ELSE branch `:137`. ELSE: `:138` `return unless ...should_auto_generate_ai_summaries?`; `:140` `ValidateAiSummaryGeneration.call`; `:142` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id) if result.success?` — no `requesting_organization_user_id`. Confirmed.

### Claim 47 — `resume.blob` re-attach CONDITIONAL on `has_resume`
- AGREE. `job_application.rb:401` `job_application.resume.attach(resume.blob) if has_resume`. `has_resume` at `:589`. Resume-less original re-attaches nothing → no TextractResult.

### Claim 48 — `additional_files` blobs re-attached on clone
- AGREE. `job_application.rb:403-407` `if additional_files.attached?` loop `additional_files.attach(additional_file.blob)`.

### Claim 49 — No-resume clone terminal: no TextractResult, status row stays `'none'`
- AGREE. With no resume, `:401` re-attaches nothing; `enqueue_new_job_application` enqueues `SubmitResumeToTextractJob` (gated by Flipper `:167`); `SubmitResumeToTextract` returns `'No resume attached'` at `submit_resume_to_textract.rb:10`. Status row `'none'`.

### Claim 50 — candidate-already-in-target dead end via `:taken`
- AGREE. `job_application.rb:393` `job_application.errors.add(:candidate, :taken, ...) if target_job.candidates.where(id: candidate_id).any?`. Controller guard `:139` `if new_job_application.errors.empty? && new_job_application.save` short-circuits (errors non-empty → no `.save`) → no after_commit, no status row, no Textract.

### Claim 51 — `CloneJobApplication` is DEAD CODE
- AGREE. grep: only definition + own `ap` strings reference `CloneJobApplication`; zero external callers; not on any route. `clone_job_application.rb:22` calls `job_application.clone_to_job(new_job_id, context.user.id)` — there is NO `def clone_to_job` method on JobApplication (only `clone_to_job_at_hiring_stage` at `:387`); `new_job_id` is an undefined local. Confirmed undefined method + undefined local.

### Claim 52 — `complete_cloning` after_create copies only `question_responses`; channel/message commented out
- AGREE. `after_create :complete_cloning` at `job_application.rb:47`; body `:414-437`; channels block commented `:420-428`; `question_responses` copy active `:430-435`. Does not touch Textract or AI summaries.

## Omissions
None material to the slice. All T3 statements verified.

(Minor, not required for the slice: the save that fires `after_commit :enqueue_new_job_application` is the controller's `new_job_application.save` at `job_applications_controller.rb:139`. The map covers the after_commit consequences thoroughly via claims 45-46.)

## Clean
true — all verdicts AGREE, no omissions.

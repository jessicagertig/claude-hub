# T3 — Clone Job Application — Adversarial Review (pass 3)

Slice question: does cloning create a TextractResult, trigger Textract, or copy an existing result?

Answer from code: clone does NOT copy `textract_results` or `ai_job_application_summaries` (`dup` copies attributes only, `job_application.rb:391`). It re-attaches the resume blob ONLY `if has_resume` (`:401`), then on controller `.save` (`job_applications_controller.rb:139`) the `after_commit :enqueue_new_job_application` (`:45`) fires a FRESH Flipper-gated `SubmitResumeToTextractJob` (`:167-168`). So a clone WITH a resume triggers a brand-new Textract submit; a clone WITHOUT a resume creates no TextractResult.

## Verdicts on map statements

### AGREE
- Clone action `def clone_to_job` at `job_applications_controller.rb:132-145`; route `put :clone_to_job` at `config/routes.rb:282`. CONFIRMED (controller :132-145, route :282).
- Chain: action → `clone_to_job_at_hiring_stage` (`job_application.rb:387`). CONFIRMED (:136 calls it; def at :387).
- `dup` copies attributes only (`:391`); textract_results / ai_job_application_summaries NOT cloned. CONFIRMED (:391; no association copy anywhere in method :387-412).
- `created_via = 'created_via_clone'` (`:400`); `clone_of_job_application_id` set (`:399`). CONFIRMED.
- Controller `.save` (line 139) fires `after_commit :enqueue_new_job_application`. CONFIRMED (controller :139; callback registration :45).
- enqueue_new_job_application → Flipper-gated Textract submit (`:167-168`) + status row via `find_or_create_ai_job_application_summary_status` (`:170`). CONFIRMED.
- Clone creates fresh `AiJobApplicationSummaryStatus` `'none'` via else branch `find_or_create_ai_job_application_summary_status.rb:34`. CONFIRMED — fresh clone has no `latest_ai_job_application_summary` (has_one scoped to this job_application, `job_application.rb:31`), so :27 is false → :34 `status = 'none'`.
- Auto-generation enqueued with NO requesting user (`textract_result.rb:142`: `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id) if result.success?`). CONFIRMED.
- `complete_cloning` (after_create, `:414-437`) copies only `question_responses`; channel/message cloning commented out; does not touch Textract or AI summaries. CONFIRMED (registration :47; body :414-437; :430-435 copies question_responses; :420-428 commented).
- `CloneJobApplication` (`clone_job_application.rb`) is DEAD CODE: zero callers; calls undefined `job_application.clone_to_job` and undefined local `new_job_id` at `:22`. CONFIRMED — grep finds no `def clone_to_job` model method (only policy `clone_to_job?` and the controller action) and no caller of `CloneJobApplication` outside its own file.

### DISPUTE / IMPRECISE
- Map (changelog :39): "gated SOLELY on the TARGET job's `should_auto_generate_ai_summaries?` (`textract_result.rb:137-142`)". DISPUTE on "solely" and on the line citation. The else-branch enqueue is doubly gated: `return unless job_application&.job&.should_auto_generate_ai_summaries?` (`textract_result.rb:138`) AND `... if result.success?` from `ValidateAiSummaryGeneration` (`:140-142`). The gate line is :138, not the cited :137; the validation gate is omitted from "solely". Correction: auto-gen on the clone's Textract completion requires BOTH the target job's `should_auto_generate_ai_summaries?` (:138) AND `ValidateAiSummaryGeneration` success (:140-142).
- Map (trigger section :234): "`resume.blob` re-attached (`job_application.rb:401`)" stated unconditionally. IMPRECISE — re-attach is conditional: `job_application.resume.attach(resume.blob) if has_resume` (`:401`). A clone of a resume-less original re-attaches nothing.

## Omissions (T3)

1. **No-resume clone terminal.** Map does not state that when the original has no resume, `:401` re-attaches nothing and `SubmitResumeToTextract` returns `'No resume attached'` (`submit_resume_to_textract.rb:10`) → NO TextractResult, no poll job, no AI pipeline. The status row still lands `'none'`. This is the direct answer to the slice question for the no-resume case and is absent.
2. **Candidate-already-in-target-job terminal.** `clone_to_job_at_hiring_stage` adds a `:taken` error when the candidate already exists in the target job (`job_application.rb:393`: `errors.add(:candidate, :taken, ...) if target_job.candidates.where(id: candidate_id).any?`). The controller guard `new_job_application.errors.empty? && new_job_application.save` (`job_applications_controller.rb:139`) then short-circuits — `.save` never runs, so NO `after_commit`, NO status row, NO Textract, NO new record persisted. The map's T3 section does not document this dead-end branch.
3. **`additional_files` re-attach.** `clone_to_job_at_hiring_stage` also re-attaches `additional_files` blobs (`job_application.rb:403-407`) when present. Not Textract-relevant but part of what the clone copies; map omits it (acceptable since out-of-slice, noted for completeness).
4. **Validation gate also runs in the waiting-summary `if` branch is N/A for clone** — confirming the else branch is the only reachable branch for a fresh clone (no `textract_processing` waiting summary exists because summaries aren't copied). Map implies but never states that the clone deterministically takes the `else` (auto) branch of `queue_ai_summary_job` (`textract_result.rb:137`), never the waiting-summary `if` branch (`:125`).

## Record-write sites on the T3 path
- `find_or_create_ai_job_application_summary_status.rb:37` — `@status_record.save` → creates `AiJobApplicationSummaryStatus` with `status='none'` (col: status; full save).
- `submit_resume_to_textract.rb` (downstream, shared) — builds/saves TextractResult `in_progress` only if `has_resume`. (Shared path, not clone-specific.)
- The clone record itself is saved at `job_applications_controller.rb:139` (`new_job_application.save`).

# S-E Adversarial Review (Pass 2) — Textract-processing handoff

**Slice:** S-E — the `queue_ai_summary_job` callback finds an existing `textract_processing` summary and runs it. Trace which record, what advances it, to terminal.

**Method:** Re-read code from scratch. Verified every candidate-map S-E statement against literal code.

## Chain traced

`textract_result.rb:114` `queue_ai_summary_job` →
`:115-116` guards (`textract_job_result_text.present?`, `saved_change_to_textract_job_result_text?`) →
`:121-123` `ai_summary_waiting_on_textract = job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).first` →
`:125` `if ai_summary_waiting_on_textract` →
`:126` `ValidateAiSummaryGeneration.call(...)` →
`:127-131` `if result.success?` → `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id, requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id)` →
`generate_ai_job_application_summary_job.rb:32` `textract_result.generate_ai_summary_with_credit_flow` →
`textract_result.rb:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` (NOT taken; waiting summary is `textract_processing`) →
`:70` `find_or_create_ai_job_application_summary_status` →
`:72` `set_initial_summary_pending(status_result)` (`:104-107` `update_columns(... status: 'initial_summary_pending')`) →
`:74` `generate_ai_summary` → `:111` `Orchestrate.new(textract_result_id: id).call` →
`orchestrate.rb:15-16` latest summary fetched (non-nil) →
`:22-27` `status_textract_processing?` → `run_summary` + `check_criteria_and_score` →
`summary/generate.rb:32` `existing_ai_summary.update(status: :extracting) unless existing_ai_summary.status_extracting?` →
`:64-68` `.update({status: :summarizing, structured_data:})` →
`orchestrate.rb:72` `update(status: :awaiting_job_criteria)` (RESTING if criteria not yet succeeded) →
(criteria succeeded) `score_job_application.rb:32` `update(status: :scoring)` →
`:119-124` `update({... status: :integrating})` →
`integrate_analysis.rb:49-53` `update({integrated_role_analysis:, status: :succeeded})` (TERMINAL) →
`ai_job_application_summary.rb:69` `update_summary_status_record` guard `saved_change_to_status? && status_succeeded?` → `:74-80` status row → `'current'` → `:93-97` JobChannel `ai_summary_succeeded`.
Also `generate_ai_job_application_summary_job.rb:34` `broadcast_completion(...) if requesting_organization_user_id` → `:72-76` `AI_SUMMARY_COMPLETE`.

**Record advanced:** the pre-existing `textract_processing` `AiJobApplicationSummary` (the waiting summary). Its companion `AiJobApplicationSummaryStatus` row advances `initial_summary_pending → current` on success.

## Verdicts

### Changelog S-E bullets (map lines 91-94)

1. **"S-E enqueues the job WITH `requesting_organization_user_id = ai_summary_waiting_on_textract.requested_by_organization_user_id` (`textract_result.rb:128-131`), so `AI_SUMMARY_COMPLETE` broadcasts on completion (`generate_ai_job_application_summary_job.rb:34`)."**
   AGREE. `textract_result.rb:128-131` literal matches. `generate_ai_job_application_summary_job.rb:34` `broadcast_completion(textract_result, requesting_organization_user_id) if requesting_organization_user_id`; `:72-76` action `AI_SUMMARY_COMPLETE`. Column exists (`db/schema.rb:156`).

2. **"The waiting `textract_processing` summary is transitioned `textract_processing → extracting` via `.update` in `Summary::Generate` (`generate.rb:32`), NOT `update_columns`."**
   AGREE. `generate.rb:32` `existing_ai_summary.update(status: :extracting) unless existing_ai_summary.status_extracting?`. `.update`, reuse branch (`:30-33`), reached because the existing summary is `status_textract_processing?` (`:31`).

3. **"`set_initial_summary_pending` sets the status row to `initial_summary_pending` before the pipeline runs (`textract_result.rb:98-108`)."**
   AGREE. Called at `:72` before `generate_ai_summary` at `:74`. `:104-107` `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')`, guarded `:102` on row being `none`/`initial_summary_pending`.

4. **"`BROADCAST_STATUSES` (`ai_job_application_summary.rb:23`) omits `awaiting_job_criteria` and `retrying`; the transition into `awaiting_job_criteria` emits no `ai_summary_status_change`."**
   AGREE. `:23` literal omits both. `before_update :broadcast_status_change` (`:31`) gated `:102` `BROADCAST_STATUSES.include?(status)`. The `awaiting_job_criteria` write (`orchestrate.rb:72`) therefore emits no `ai_summary_status_change`.

### Part 3 `if` branch (map line 391)

5. **"`if` waiting-summary branch (C handoff / E): validate → enqueue job WITH `requesting_organization_user_id`; on validation failure → destroy waiting summary + `AI_SUMMARY_FAILED` broadcast."**
   AGREE. `textract_result.rb:126` validate; `:127-131` success enqueue; `:132-135` else: `OrganizationUser.find_by`, `ai_summary_waiting_on_textract.destroy`, `broadcast_ai_summary_failed(...)` (`:146-160` action `AI_SUMMARY_FAILED`).

### State-table rows touched by S-E

6. **`extracting` writer `summary/generate.rb:32` (reuse) (map line 430).** AGREE.
7. **`awaiting_job_criteria` writer `orchestrate.rb:72`; also `score_job_application.rb:23,45`; RESTING, advanced only by `AiJobCriteria#resume_waiting_summaries` or later Orchestrate (map line 432).** AGREE. `score_job_application.rb:23` and `:45` both `update(status: :awaiting_job_criteria)`.
8. **`scoring` writer `score_job_application.rb:32` (map line 433).** AGREE.
9. **`succeeded` writer `integrate_analysis.rb:49-53`, terminal, fires `update_summary_status_record` (map line 435).** AGREE.
10. **`textract_processing` row "non-resting → `queue_ai_summary_job` bridge / `SubmitResumeToTextract` link" reached by "A (T9), E" (map line 429).** AGREE — this is the S-E entry record.

## Omissions

- **S-E changelog does not state the handoff's resting/terminal outcomes.** The 4 S-E bullets describe transitions and broadcasts but never state that the run advances the waiting summary `textract_processing → … → succeeded` (terminal) OR comes to rest at `awaiting_job_criteria` pending criteria. The terminal/resting facts live only in the state tables (lines 432, 435), not the S-E narrative. Minor — covered elsewhere in the doc, but the slice asked specifically to "trace to terminal" and the S-E section itself stops at transitions.
- **The S-E re-validation gate is not in the S-E changelog.** `queue_ai_summary_job` re-runs `ValidateAiSummaryGeneration` (`textract_result.rb:126`) before enqueuing on the handoff path; a validation failure here destroys the waiting summary even though it was already validated at creation. This is in Part 3 (line 391) but absent from the S-E changelog bullets. Minor.
- **The line-68 early-return interaction with the handoff is not called out for S-E.** `generate_ai_summary_with_credit_flow:68` `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` does NOT fire for the waiting `textract_processing` summary (not succeeded), so the handoff proceeds. Not an error in the map; just not noted that S-E sails past this guard. Minor.

None of these are contradictions; they are narrative gaps in the S-E-labeled section that are covered by other sections of the same document.

## clean

Every S-E statement verified AGREE. Omissions list is non-empty (narrative gaps), so clean = false.

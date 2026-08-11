# T9 — Adversarial Re-Review (Pass 2)

**Slice:** T9 — Manual generate when no TextractResult exists: `ValidateAiSummaryGeneration` kicks off Textract; trace the validate path that initiates Textract and the state the summary is left in.

**Method:** Re-read from scratch. Files opened and traced:
`app/controllers/api/v1/ai_job_application_summaries_controller.rb:1-38`
→ `app/interactors/validate_ai_summary_generation.rb:1-85`
→ `app/models/job_application.rb:685-687` (`latest_textract_result`)
→ `app/interactors/create_ai_summary_generation.rb:1-81`
→ `app/jobs/submit_resume_to_textract_job.rb:1-15`
→ `app/services/submit_resume_to_textract.rb:1-43`
→ `app/models/textract_result.rb:61-144` (`generate_ai_summary_with_credit_flow`, `set_initial_summary_pending`, `queue_ai_summary_job` bridge)

---

## Verdicts

### V1 — `has_job_description?` fail-fast guard at `:29`, def `:81-83`, error message
**Map (DIVERGENCE T9 / line 75, Trigger 9 line 228, Part 2 line 282):** guard `context.fail!(...) unless has_job_description?` at `:29`; def at `81-83`: `@job_application.job&.description.present?`; error "This job needs a description before Plato can review candidates. Add one in Job Setup."
**AGREE.** `validate_ai_summary_generation.rb:29` literal: `context.fail!(error: 'This job needs a description before Plato can review candidates. Add one in Job Setup.') unless has_job_description?`. Def `:81-83`: `def has_job_description?` / `@job_application.job&.description.present?`.

### V2 — No-TextractResult branch at `:38-42`
**Map (line 76, line 227, line 284, Trigger matrix line 500):** nil → `SubmitResumeToTextractJob.perform_later`, `context.textract_pending = true`, return; located `:38-42`.
**AGREE.** `validate_ai_summary_generation.rb:38` `unless @latest_textract_result`; `:39` `SubmitResumeToTextractJob.perform_later(@job_application.id)`; `:40` `context.textract_pending = true`; `:41` `return`; `:42` `end`.

### V3 — `context.textract_result` assigned UNCONDITIONALLY at `:31-32`
**Map (line 77, line 283):** assigned before any branch, nil on the no-TextractResult path.
**AGREE.** `:31` `@latest_textract_result = @job_application.latest_textract_result`; `:32` `context.textract_result = @latest_textract_result`. Both precede the `unless` at `:38`. On the T9 path `latest_textract_result` (`job_application.rb:686` `textract_results.order(created_at: :desc).first`) is nil, so `context.textract_result = nil`.

### V4 — Return is SUCCESS on the nil path
**Map (Trigger 9 line 228):** "returns SUCCESS."
**AGREE.** `:41` is a bare `return` inside `call`; no `context.fail!` on this branch. Interactor success is the default absent `fail!`.

### V5 — `CreateAiSummaryGeneration` builds `:textract_processing`, `textract_result: nil`, no job
**Map (line 229):** "`CreateAiSummaryGeneration` builds an `AiJobApplicationSummary` `status: :textract_processing`, `textract_result: nil` (no job enqueued)."
**AGREE.** On T9, `validation_result.textract_pending` is true and `validation_result.textract_result` is nil. `create_ai_summary_generation.rb:46` `if validation_result.textract_pending`; `:47-51` `build(textract_result: validation_result.textract_result (=nil), status: :textract_processing, requested_by_organization_user_id: context.user&.current_organization_user&.id)`; `:53` `if ai_summary.save`; `:57` `return`. No `GenerateAiJobApplicationSummaryJob` enqueued in this branch (only the `:pending` branch at `:70-74` enqueues).

### V6 — `SubmitResumeToTextract` later links `textract_result_id` onto the waiting summary
**Map (line 229, line 153):** "`SubmitResumeToTextract` later links `textract_result_id` onto this waiting summary."
**AGREE.** Ordering: controller runs Validate (enqueues `SubmitResumeToTextractJob.perform_later`, async) THEN Create (synchronously builds the `textract_processing` summary). When the async job runs, `submit_resume_to_textract.rb:18` guard `unless ...where(status: :textract_processing, stale: false).exists?` is now TRUE → the `update_all(stale: true)` at `:19` is SKIPPED, leaving the waiting summary `stale: false`. `:25` `waiting_summary = ...find_by(status: :textract_processing, stale: false, textract_result_id: nil)`; `:26` `waiting_summary&.update_columns(textract_result_id: @textract_result.id)`. Link confirmed.

### V7 — 5.2 table row: `textract_processing` writer and advancing actor
**Map (line 429):** writer `create_ai_summary_generation.rb:47-53` `build(status: :textract_processing)`; precondition "textract_pending (incl. nil TextractResult)"; reached by "A (T9), E"; non-resting → `queue_ai_summary_job` bridge / `SubmitResumeToTextract` link.
**AGREE.** Build confirmed `:47-51` (save `:53`). Bridge `textract_result.rb:121-131` selects `where(status: :textract_processing, stale: false).first` and (success) enqueues `GenerateAiJobApplicationSummaryJob(textract_result_id: id, requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id)`. Advancing actor confirmed.

### V8 — Dead end: `textract_processing` with nil `textract_result_id` after AWS-submit failure (T9)
**Map (line 441, line 422):** if AWS submit fails before `@textract_result` is built, no TextractResult, no poll job, bridge never fires; summary stuck `textract_processing`.
**AGREE.** `submit_resume_to_textract.rb:31-39` rescues use `@textract_result&.update_columns(...)`; if the AWS `send_to_textract` (`:16`) raises before `:22` build, `@textract_result` is nil, `&.` no-ops, no `GetResumeTextFromTextractJob` scheduled (`:27` is inside the `if @textract_result.save` block at `:24`). The T9 waiting summary built at `create_ai_summary_generation.rb:47-51` has nil `textract_result_id` and never gets linked → stuck `textract_processing`. No advancing actor.

### V9 — `generate_ai_summary_with_credit_flow` calls find_or_create + set_initial_summary_pending at `:70-72`; `create_status_record` REMOVED
**Map (line 78):** REMOVED `create_status_record`; NEW credit flow calls `find_or_create_ai_job_application_summary_status` + `set_initial_summary_pending` before the pipeline at `:70-72`.
**AGREE (but tangential to T9's own path).** `textract_result.rb:70` `status_result = job_application.find_or_create_ai_job_application_summary_status`; `:72` `set_initial_summary_pending(status_result) if status_result.success?`. NOTE for scope: this executes on the LATER bridge/job run, not on the T9 validate-initiates-Textract path itself (which enqueues no job). The claim is code-accurate; placing it in the T9 divergence list is a framing choice, not an error.

### V10 — Other validation branches (failed / in_progress / not_started)
**Map (Part 2 line 286):** "failed (both current+previous) → fail!; failed (only current) → resubmit + textract_pending=true; in_progress/not_started → textract_pending=true." text ready → textract_pending=false.
**AGREE.** `:44` `if textract_text_ready?` → `:45` `context.textract_pending = false` (`textract_text_ready?` `:73-75` = `textract_job_result_text.present?`). `:46` `elsif ...textract_job_status_failed?`: `:52` `if previous_textract_result&.textract_job_status_failed?` → `:53` `fail!`; else `:55-56` resubmit + `textract_pending = true`. `:58` `else` → `:59` `textract_pending = true`. These are outside the strict "no TextractResult" T9 path but are on the same file/slice and verified.

---

## Omissions (T9 scope: "the state the summary is left in")

1. **The waiting `textract_processing` summary is created carrying `requested_by_organization_user_id`** (`create_ai_summary_generation.rb:50`, sourced from `context.user&.current_organization_user&.id`; `context.user` = `current_user` passed by the controller at `:20`). This is load-bearing for T9's terminal state: when Textract later completes, the bridge threads that value into `GenerateAiJobApplicationSummaryJob(... requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id)` (`textract_result.rb:130`), which is what later produces the `AI_SUMMARY_COMPLETE` user toast. The map covers this under S-E (line 91) but the T9 section (line 229) omits that the summary is left carrying the requesting user. Relevant to "the state the summary is left in."

2. **`ValidateAiSummaryGeneration` is invoked WITHOUT a `user:` argument on the T9 manual path** (`ai_job_application_summaries_controller.rb:8-11` passes only `job_application:` and `organization:`), so `context.user` is nil inside Validate. Immaterial (Validate reads no user), but the map's Part 2 validation narrative does not note that `user` is supplied only to `CreateAiSummaryGeneration` (`:17-21`), not to Validate. Minor.

3. **Terminal-state completeness for the happy T9 path is not stated in the T9 section.** The T9 section stops at "summary left `textract_processing`, Textract kicked off." The full T9 terminal (after Textract succeeds): bridge `queue_ai_summary_job` `if` branch re-validates and enqueues the job WITH the requesting user → pipeline drives the same `textract_processing → extracting → … → succeeded` summary. This is documented in Part 3 / 5.2 generally, but not cross-linked from the T9 trigger entry. Documentation-completeness note, not a code error.

---

## Conclusion
All map statements about the T9 slice that I could check are code-accurate. No DISPUTE. Three omissions noted (one substantive: the waiting summary carries `requested_by_organization_user_id`, which determines the T9 terminal broadcast). Therefore `clean = false`.

# T9 Adversarial Review — Pass 5

**Slice:** T9 — Manual generate when no TextractResult exists: `ValidateAiSummaryGeneration` kicks off Textract. Trace the validate path that initiates Textract and the state the summary is left in.

**Candidate map:** `backend-flow-map-2026-06-17.md` lines 127-139 (Trigger 9 / Trigger A).

**Method:** Re-read all code from scratch. Files traced:
`ai_job_application_summaries_controller.rb:4-28` → `validate_ai_summary_generation.rb:1-84` → `job_application.rb:685-687 (latest_textract_result)` → `create_ai_summary_generation.rb:1-80` → `textract_result.rb:60-89,114-144 (queue_ai_summary_job / generate_ai_summary_with_credit_flow / set_initial_summary_pending)` → `submit_resume_to_textract_job.rb:1-14` → `submit_resume_to_textract.rb:1-42` → `generate_ai_job_application_summary_job.rb:1-78` → `ai_job_application_summary.rb:20-31`.

---

## Verdicts

### Map line 128 — fail-fast guard `unless has_job_description?` at `validate_ai_summary_generation.rb:29`, def `:81-83`
**AGREE.** `validate_ai_summary_generation.rb:29` `context.fail!(error: 'This job needs a description before Plato can review candidates. Add one in Job Setup.') unless has_job_description?`; def `:81-83` `@job_application.job&.description.present?`. Error string matches.

### Map line 129 — guard chain `:24-25` nil, `:26` flipper, `:27` has_resume?, `:28` credits_available?, `:29` has_job_description? precede the submit
**AGREE.** `:24` job_application nil, `:25` organization nil, `:26` `unless flipper_enabled?` (`AI_APPLICANT_SUMMARY`, def `:65-67`), `:27` `unless has_resume?` (def `:69-71`), `:28` `unless credits_available?` (def `:77-79` → `@organization.ai_credits_available?`), `:29` `unless has_job_description?`. All `context.fail!`. The no-result `SubmitResumeToTextractJob.perform_later` at `:39` is reached only after all five pass.

### Map line 130 — sibling branches off the same entry: `:38-42`, `:44-45`, `:46-57`, `:52-53`, `:58-59`
**AGREE.** After `context.textract_result` assigned (`:31-32`): `:38-42` `unless @latest_textract_result` → submit `:39` + `textract_pending=true` `:40` + return `:41`; `:44-45` `if textract_text_ready?` → `textract_pending=false`; `:46-57` `elsif @latest_textract_result.textract_job_status_failed?` with prior-not-failed → re-submit `:55` + `textract_pending=true` `:56`; `:52-53` prior-also-failed → `context.fail!` dead end; `:58-59` `else` → `textract_pending=true`. Exact.

### Map line 131 — CHANGED: no-result branch now `:38-42` (old map `:37-41`)
**AGREE.** Current no-result branch is `:38 unless @latest_textract_result` / `:39 SubmitResumeToTextractJob.perform_later(@job_application.id)` / `:40 context.textract_pending = true` / `:41 return` / `:42 end`.

### Map line 132 — `context.textract_result` assigned unconditionally at `:31-32`, nil on no-Textract path
**AGREE.** `:31 @latest_textract_result = @job_application.latest_textract_result`; `:32 context.textract_result = @latest_textract_result`. `latest_textract_result` def `job_application.rb:685-687` `textract_results.order(created_at: :desc).first` → nil when none. Assignment is before any branch.

### Map line 133 — REMOVED `create_status_record`; NEW `generate_ai_summary_with_credit_flow` calls find_or_create + set_initial_summary_pending at `textract_result.rb:70-72` (executes on job run, not T9 validate path)
**AGREE.** `ai_job_application_summary.rb:29-31` has no `create_status_record` callback. `textract_result.rb:70` `status_result = job_application.find_or_create_ai_job_application_summary_status`; `:72` `set_initial_summary_pending(status_result) if status_result.success?`; pipeline at `:74`. `generate_ai_summary_with_credit_flow` is invoked from `generate_ai_job_application_summary_job.rb:32`, not from Validate — the "later job run" qualification is correct.

### Map line 134 — T9 waiting-summary terminal: waiting `textract_processing` summary built by Create `:47-51` carries `requested_by_organization_user_id` (`:50`, sourced from controller `user: current_user` at `:20`); bridge threads it into `GenerateAiJobApplicationSummaryJob(requesting_organization_user_id:)` at `textract_result.rb:130`; bridge `if` branch re-validates (`:126`) and enqueues WITH the requesting user
**AGREE.** Create `:47-51` builds `status: :textract_processing` with `requested_by_organization_user_id: context.user&.current_organization_user&.id` (`:50`). Controller passes `user: current_user` (`ai_job_application_summaries_controller.rb:20`). Bridge `textract_result.rb:121-123` selects the waiting summary; `:126` `result = ValidateAiSummaryGeneration.call(...)`; `:128-131` enqueues `GenerateAiJobApplicationSummaryJob` with `requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id` (`:130`). `generate_ai_job_application_summary_job.rb:34` fires `broadcast_completion` → `AI_SUMMARY_COMPLETE` (`:72-76`) when the id is present. Drives `textract_processing → … → succeeded`. Note: stored value is `current_organization_user.id`, not the user object; the map's provenance phrasing is accurate.

### Map line 135 — active-summary REUSE sub-case: prior `textract_processing` summary with `textract_result_id: nil` passes the mismatch guard (`nil != nil` false), NOT staled (`:36-39`), REUSED and returned (`:41-44`), while Validate has ALREADY submitted Textract
**AGREE.** `create_ai_summary_generation.rb:30-34` selects active = `.where.not(status: :failed).where(stale: false).order(created_at: :desc).first` (a `textract_processing` summary qualifies). `:36` `active_ai_summary.textract_result_id != job_application.latest_textract_result&.id`: on the no-Textract path `latest_textract_result&.id` is nil and the reused summary's `textract_result_id` is nil → `nil != nil` is false → stale body `:37-38` skipped → `:41-44` returns the reused summary with no build, no enqueue. Validate already enqueued `SubmitResumeToTextractJob` at `validate_ai_summary_generation.rb:39` before Create runs.

### Map line 136 — active-summary FRESH-BUILD sub-case: no prior active summary → NEW `:textract_processing` summary built+saved `:47-53`, returned WITHOUT enqueuing
**AGREE.** When `active_ai_summary` nil (`:34/:41` false), `:46 if validation_result.textract_pending` is true (Validate set `textract_pending=true` at `:40`) → `:47-51` builds `status: :textract_processing`, `:53` saves, `:57` returns. No `GenerateAiJobApplicationSummaryJob` enqueue in this branch (the enqueue at `:70-74` is only in the `:pending` branch, unreachable when `textract_pending` true).

### Map line 137 — NOTE: Validate invoked WITHOUT `user:` (controller `:8-11` passes only job_application + organization), `context.user` nil in Validate (immaterial — Validate reads no user); user supplied only to Create (`:17-21`, `user: current_user` `:20`); pre-validate gates `authorize ... :create?` (`:6`) and exists-scoping (`:5`)
**AGREE.** Controller `:8-11` passes `job_application:` and `organization:` only to Validate. `validate_ai_summary_generation.rb:6-8` reads `context.job_application` and `context.organization`; no `context.user` read anywhere in the file. Create call `:17-21` with `user: current_user` (`:20`). `:6 authorize :ai_job_application_summary, :create?`; `:5 exists(current_organization.job_applications.where(id: params[:job_application_id]), ...)`.

### Map line 138 — NOTE: bridge waiting-summary query filters only `status: :textract_processing, stale: false` with no `textract_result_id` filter (`textract_result.rb:121-123`); waiting summary found independent of the relink at `submit_resume_to_textract.rb:26`
**AGREE.** `textract_result.rb:121-123` `job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).first` — no `textract_result_id` filter. `submit_resume_to_textract.rb:25-26` relinks via `find_by(status: :textract_processing, stale: false, textract_result_id: nil)` then `update_columns(textract_result_id: @textract_result.id)`; the bridge query does not depend on that column.

---

## Omissions

1. **Async ordering of the Textract submit is not stated as the enabling condition for the REUSE/FRESH-BUILD nil-match.** The map (line 135) relies on `job_application.latest_textract_result&.id` being nil while `CreateAiSummaryGeneration` runs, but does not note that `validate_ai_summary_generation.rb:39` enqueues `SubmitResumeToTextractJob.perform_later` (async) and `submit_resume_to_textract.rb:22` builds the `in_progress` TextractResult only when that job later runs. Because the submit is `perform_later`, no TextractResult exists during the synchronous `CreateAiSummaryGeneration` call in the same request, so `latest_textract_result` is nil and the `:36` mismatch guard sees `nil != nil`. If the submit were synchronous-before-Create, a TextractResult would exist and the guard would diverge. This ordering is load-bearing for the entire T9 "state the summary is left in" conclusion and is not spelled out in the T9 section.

2. **The submit-time stale guard that PRESERVES the T9 waiting summary is not traced.** When the async `SubmitResumeToTextractJob` eventually runs `SubmitResumeToTextract#submit_resume`, `submit_resume_to_textract.rb:18` `unless @job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).exists?` is TRUE for the T9 waiting summary (the one Create built/reused), so the `update_all(stale: true)` at `:19` is SKIPPED — the waiting `textract_processing` summary is NOT staled and survives. The map's T9 section documents the relink (`:25-26`, via the line-138 NOTE) but never states that the `:18` guard is what protects the just-built waiting summary from being staled before the relink. This directly bears on "the state the summary is left in": the summary stays `textract_processing, stale:false` and is the same record that later advances via the bridge.

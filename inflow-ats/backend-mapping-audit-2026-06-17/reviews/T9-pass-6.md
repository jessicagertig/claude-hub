# T9 Adversarial Review — pass 6

**Slice:** T9 — Manual generate when no TextractResult exists: `ValidateAiSummaryGeneration` kicks off Textract. Trace the validate path that initiates Textract and the state the summary is left in.

**Verdict:** clean = true (every map statement for the T9 slice verifies against current code; no omissions found).

## Files traced
- `app/controllers/api/v1/ai_job_application_summaries_controller.rb:4-28` (entry: `create`)
- `app/interactors/validate_ai_summary_generation.rb:1-84` (the validate path under audit)
- `app/interactors/create_ai_summary_generation.rb:1-80` (summary-state outcome)
- `app/services/submit_resume_to_textract.rb:1-42` (Textract kickoff + waiting-summary relink)
- `app/models/job_application.rb:685-687` (`latest_textract_result`), `:589` (`has_resume`), `:28` (`has_many :textract_results`)
- `app/models/textract_result.rb:114-144` (bridge `queue_ai_summary_job`)
- `app/models/ai_job_application_summary.rb:10-23` (status enum + `BROADCAST_STATUSES`)
- `db/schema.rb:156` (`requested_by_organization_user_id` column)
- OLD map `textract-ai-summary-map-6-6-2026-COPY.md:146-149,561` (compared)

## Statement-by-statement

### Map line 143 — `has_job_description?` fail-fast guard (NEW)
AGREE. `validate_ai_summary_generation.rb:29` `context.fail!(error: 'This job needs a description before Plato can review candidates. Add one in Job Setup.') unless has_job_description?`; def at `:81-83` `@job_application.job&.description.present?`. Error string matches exactly.

### Map line 144 — fail-fast guards precede the Textract submit
AGREE. `:24` job_application nil, `:25` organization nil, `:26` `unless flipper_enabled?` (`AI_APPLICANT_SUMMARY`, def `:65-67`), `:27` `unless has_resume?` (def `:69-71` → `@job_application.has_resume`), `:28` `unless credits_available?` (def `:77-79` → `@organization.ai_credits_available?`), `:29` `unless has_job_description?`. All `context.fail!` precede the `:38` no-result branch.

### Map line 145 — sibling branches off the same entry
AGREE. `:38-42` `unless @latest_textract_result` → `SubmitResumeToTextractJob.perform_later(@job_application.id)` (`:39`) + `context.textract_pending = true` (`:40`) + bare `return` (`:41`). `:44-45` `if textract_text_ready?` → `textract_pending = false`. `:46` `elsif @latest_textract_result.textract_job_status_failed?`; `:52-53` `if previous_textract_result&.textract_job_status_failed?` → `context.fail!` (dead end); `:54-56` else → resubmit `:55` + `textract_pending=true` `:56`. `:58-59` else → `textract_pending = true`. Line ranges exact.

### Map line 146 — old map cited `:37-41`, current is `:38-42` (CHANGED)
AGREE. OLD map `textract-ai-summary-map-6-6-2026-COPY.md:149` reads `**File:** app/interactors/validate_ai_summary_generation.rb:37-41`. Current no-result branch is `:38-42`. The `has_job_description?` guard inserted at `:29` shifted lines.

### Map line 147 — `context.textract_result` assigned unconditionally at `:31-32` (MAP-WRONG vs old)
AGREE. `:31` `@latest_textract_result = @job_application.latest_textract_result`; `:32` `context.textract_result = @latest_textract_result`. Unconditional, before any branch. `latest_textract_result` def `job_application.rb:685-687` `textract_results.order(created_at: :desc).first` (nil when none).

### Map line 149 — T9 waiting-summary terminal state (bridge threading)
AGREE. The waiting `textract_processing` summary is built by `CreateAiSummaryGeneration` (`:47-51`) carrying `requested_by_organization_user_id: context.user&.current_organization_user&.id` (`:50`). Column exists `db/schema.rb:156`. Bridge `textract_result.rb:121-123` finds it (`status: :textract_processing, stale: false`), `:126` re-runs `ValidateAiSummaryGeneration`, `:128-130` enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: id, requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id)`.

### Map line 150 — active-summary REUSE sub-case on no-Textract path
AGREE. `create_ai_summary_generation.rb:30-34` `.where.not(status: :failed).where(stale: false).order(created_at: :desc).first`. `:36` `if active_ai_summary && active_ai_summary.textract_result_id != job_application.latest_textract_result&.id`. On no-Textract path `latest_textract_result` is nil, so for a prior `textract_processing` summary with `textract_result_id: nil`, `nil != nil` is false → not staled → reused/returned `:41-44` with no build/no enqueue, while `validate_ai_summary_generation.rb:39` has already submitted Textract.

### Map line 151 — FRESH-BUILD sub-case
AGREE. When `active_ai_summary` is nil at `:34`/`:41`, with `validation_result.textract_pending` true (`:46`), builds `:textract_processing` summary (`:47-51`), saves (`:53`), `return` (`:57`), no job enqueued.

### Map line 152 — textract-READY sub-branch (pending summary, job enqueued NOW)
AGREE. When `textract_pending` false, `:46` false → `:60-64` builds `:pending` summary, `:70` save, `:71-74` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: validation_result.textract_result.id, requesting_organization_user_id: context.user.current_organization_user.id)`. (Out-of-strict-T9 ready-path, but accurate.)

### Map line 154 — asymmetric nil-safety on requesting-user arg
AGREE. `:50` and `:63` use `context.user&.current_organization_user&.id` (safe-nav). `:73` uses `context.user.current_organization_user.id` (no safe-nav).

### Map line 155 — async-ordering load-bearing for nil-match
AGREE. `validate_ai_summary_generation.rb:39` enqueues `SubmitResumeToTextractJob.perform_later` (async); `submit_resume_to_textract.rb:22` builds the `in_progress` TextractResult only when that job later runs. So during the synchronous `CreateAiSummaryGeneration` run `latest_textract_result&.id` is nil, sustaining the `nil != nil` match at `:36`.

### Map line 156 — submit-time stale guard PRESERVES the waiting summary
AGREE. `submit_resume_to_textract.rb:18` `unless @job_application.ai_job_application_summaries.where(status: :textract_processing, stale: false).exists?` is TRUE for the just-built/reused waiting summary, so `update_all(stale: true)` (`:19`) is SKIPPED. Relink at `:25-26` `find_by(status: :textract_processing, stale: false, textract_result_id: nil)` then `update_columns(textract_result_id: @textract_result.id)`.

### Map line 157 — Validate invoked WITHOUT user; controller gates
AGREE. `ai_job_application_summaries_controller.rb:8-11` passes only `job_application:` and `organization:` to Validate (no `user:`). User supplied only to `CreateAiSummaryGeneration` (`:17-21`, `user: current_user` at `:20`). Pre-validate gates: `authorize :ai_job_application_summary, :create?` (`:6`); scoping `exists(current_organization.job_applications.where(id: params[:job_application_id]), ...)` (`:5`).

### Map line 158 — bridge query independence
AGREE. `textract_result.rb:121-123` filters only `status: :textract_processing, stale: false` (no `textract_result_id` filter), so the waiting summary is found regardless of the relink at `submit_resume_to_textract.rb:26`.

### Part 1 Trigger 9 (map lines 392-398) and Part 2 §Validation/Creation (lines 446-465)
AGREE in full; same citations re-verified. No-result branch does a bare `return` (`:41`) with no `context.fail!`, so the interactor SUCCEEDS and the controller proceeds to `CreateAiSummaryGeneration` (controller `:12`/`:17`).

### Part 7 matrix row 9 (line 687)
AGREE. `ValidateAiSummaryGeneration (:38-42)`, gate `AI_APPLICANT_SUMMARY`, behavior text matches the traced branches.

## Omissions
None. Every claim the candidate map makes about the T9 validate-path-initiates-Textract slice is anchored on current code and verified. (Note for completeness: `SubmitResumeToTextract` lives at `app/services/submit_resume_to_textract.rb`, a service not an interactor; the map's T9 citations use the bare filename and assert no path, so no T9 statement is wrong on this point.)

## Record-write sites on the T9 validate path
- `validate_ai_summary_generation.rb:39` / `:55` — no record write; enqueues `SubmitResumeToTextractJob.perform_later` (Textract built later in the service).
- `submit_resume_to_textract.rb:19` — `update_all(stale: true)` on `ai_job_application_summaries` (SKIPPED on the T9 waiting-summary path per `:18` guard).
- `submit_resume_to_textract.rb:22-24` — `textract_results.build(...).save` → NEW TextractResult, `textract_job_status: 'in_progress'`, `textract_job_id` (full save, callbacks).
- `submit_resume_to_textract.rb:26` — `waiting_summary&.update_columns(textract_result_id: @textract_result.id)` (update_columns, no callbacks).
- `create_ai_summary_generation.rb:37` — `update_columns(stale: true)` on mismatched active summary (not hit on the no-Textract nil-match path).
- `create_ai_summary_generation.rb:53` — `ai_summary.save` → NEW `:textract_processing` summary, `requested_by_organization_user_id` (full save).
- `create_ai_summary_generation.rb:70` — `ai_summary.save` → NEW `:pending` summary (ready path; full save).

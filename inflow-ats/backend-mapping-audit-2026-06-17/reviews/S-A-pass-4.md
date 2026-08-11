# S-A Pass-4 Adversarial Review — Manual Single Generate

**Slice:** S-A — controller create → ValidateAiSummaryGeneration → CreateAiSummaryGeneration → GenerateAiJobApplicationSummaryJob → AiJobApplicationAction::Orchestrate.

**Method:** Re-read all S-A code from scratch; attempted to refute every map statement about S-A against literal code.

## Files traced (chain)
`app/controllers/api/v1/ai_job_application_summaries_controller.rb:4-28`
→ `app/interactors/validate_ai_summary_generation.rb:1-84`
→ `app/interactors/create_ai_summary_generation.rb:1-80`
→ `app/jobs/generate_ai_job_application_summary_job.rb:1-78`
→ `app/models/textract_result.rb:61-144`
→ `app/services/ai_job_application_action/orchestrate.rb:1-106`
→ `app/services/ai_job_application_action/summary/generate.rb:30-40`

Supporting reads: `app/models/job_application.rb:29-32,685-687`; `app/services/submit_resume_to_textract.rb:1-42`; `app/models/ai_job_application_summary.rb:1-112`; `app/policies/ai_job_application_summary_policy.rb:1-33`.

## Branch point (both S-A sub-branches)
- Determination of textract-ready vs pending: `validate_ai_summary_generation.rb:44-60`. Ready → `textract_pending = false` at `:45` (only when `textract_text_ready?` `:73-75`). Pending → `textract_pending = true` at `:40` (no TextractResult), `:56` (only-current failed, resubmit), `:59` (in_progress/not_started).
- Branch executed in CreateAiSummaryGeneration: `create_ai_summary_generation.rb:46` `if validation_result.textract_pending`.
  - (i) ready: `:60-64` build `status: :pending` summary, `:70-74` save + enqueue `GenerateAiJobApplicationSummaryJob(textract_result_id, requesting_organization_user_id)`.
  - (ii) pending: `:47-53` build `status: :textract_processing` summary, NO job, `:57` return. Later linked to a TextractResult by `submit_resume_to_textract.rb:25-26`; bridge `if` branch (`textract_result.rb:125-131`) re-validates and enqueues the job WITH the requesting user.

## Verdicts (all AGREE)

1. Controller passes only `job_application:`+`organization:` to Validate (no `user:`); `user: current_user` only to Create. AGREE — controller `:8-11`, `:17-21` (`user: current_user` `:20`).
2. Controller gate: `exists(current_organization.job_applications.where(id: ...))` `:5` + `authorize :ai_job_application_summary, :create?` `:6`; `create?` → `can_use_ai_credits?` (policy `:4-5,16-18`). AGREE.
3. `has_job_description?` fail-fast guard at `validate_ai_summary_generation.rb:29`, def `:81-83` (`@job_application.job&.description.present?`). AGREE.
4. `context.textract_result` assigned unconditionally (`:32`, nil on no-TextractResult path); `latest_textract_result` def `job_application.rb:685-687` (`textract_results.order(created_at: :desc).first`). AGREE.
5. No-TextractResult branch `:38-42`: `SubmitResumeToTextractJob.perform_later` `:39`, `textract_pending = true` `:40`, bare `return` `:41`. AGREE.
6. CreateAiSummaryGeneration active-summary reuse `:30-34`; mismatch guard `:36` `active_ai_summary.textract_result_id != job_application.latest_textract_result&.id` (nil != nil false on no-Textract path → not staled, reused `:41-44`). AGREE.
7. textract_processing arm requesting user via safe-nav `context.user&.current_organization_user&.id` `:50`; pending(ready) arm `context.user.current_organization_user.id` `:73` (NO safe-nav). AGREE.
8. `generate_ai_summary_with_credit_flow` `:67-68` early-return `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`; `:70` find_or_create status; `:72` set_initial_summary_pending; `:74` generate_ai_summary; `:77` `self.ai_job_application_summaries.order(created_at: :desc).first`; `:82` return unless succeeded; `:84` CreateAiCreditBalanceTransaction. AGREE.
9. Bridge `if` waiting-summary branch: query `:121-123` (`status: :textract_processing, stale: false`, job_application-scoped, no order); re-validate `:126`; enqueue WITH `requesting_organization_user_id: ai_summary_waiting_on_textract.requested_by_organization_user_id` `:128-131`; on fail destroy + `AI_SUMMARY_FAILED` `:132-135`. AGREE.
10. Job: `perform(textract_result_id:, requesting_organization_user_id: nil)` `:24`; `return unless textract_result` `:30`; `generate_ai_summary_with_credit_flow` `:32`; `broadcast_completion ... if requesting_organization_user_id` `:34` → `AI_SUMMARY_COMPLETE` `:74`. AGREE.
11. Orchestrate: `:6` find_by, `:12` return unless; `:15` `@job_application.ai_job_application_summaries.order(created_at: :desc).first` (JobApplication-scoped, no stale filter); `:16` return unless; textract_processing dispatches to `run_summary` (`:22-26`). AGREE.
12. Summary::Generate reuses textract_processing/pending summary via `.update(status: :extracting)` `generate.rb:31-33`. AGREE.
13. `update_summary_status_record` after_commit on:update, guard `saved_change_to_status? && status_succeeded?` `:69`; writes `status: 'current'` via `.update` `:74-80`; then `ai_summary_succeeded` JobChannel broadcast `:93-97`. AGREE.

## Omissions
None material to S-A. The map enumerates both sub-branches, the branch point, the requesting-user threading asymmetry (`:50` safe-nav vs `:73` no safe-nav), the active-summary reuse on the no-Textract path, the controller scoping/authorize gates, and the credit-charge terminal.

## Conclusion
clean = true. Every S-A map statement verified against literal code; no disputes, no omissions.

# S-A Adversarial Review — Pass 2 (Manual Single Generate)

**Slice:** S-A — controller create → ValidateAiSummaryGeneration → CreateAiSummaryGeneration → GenerateAiJobApplicationSummaryJob → generate_ai_summary_with_credit_flow → Orchestrate.
**Method:** Re-read all S-A code from scratch; attempted to refute every map statement against literal code.

Files traced:
- `app/controllers/api/v1/ai_job_application_summaries_controller.rb:4-28`
- `app/interactors/validate_ai_summary_generation.rb:1-84`
- `app/interactors/create_ai_summary_generation.rb:1-80`
- `app/jobs/generate_ai_job_application_summary_job.rb:1-78`
- `app/models/textract_result.rb:61-111`
- `app/services/ai_job_application_action/orchestrate.rb:1-106`
- `app/services/ai_job_application_action/summary/generate.rb:30-40`
- `config/routes.rb:302`

## Verdicts (AGREE unless noted)

1. **Controller chain create → ValidateAiSummaryGeneration → CreateAiSummaryGeneration.** AGREE — controller `:8` ValidateAiSummaryGeneration.call, `:17` CreateAiSummaryGeneration.call, route `config/routes.rb:302` `resources :ai_job_application_summaries, only: [:show, :create]`.

2. **NEW `has_job_description?` fail-fast guard at `validate_ai_summary_generation.rb:29`, def at `:81-83` = `@job_application.job&.description.present?`.** AGREE — literal lines confirmed; error string matches exactly.

3. **`context.textract_result` assigned UNCONDITIONALLY at `:31-32`.** AGREE — `:31` `@latest_textract_result = @job_application.latest_textract_result`; `:32` `context.textract_result = @latest_textract_result`, before any branch.

4. **No-TextractResult branch at `:38-42` → SubmitResumeToTextractJob, textract_pending=true, return.** AGREE — `:38 unless @latest_textract_result`, `:39` enqueue, `:40` textract_pending=true, `:41` return.

5. **Branch (i) Textract ready → `:pending` summary built, `GenerateAiJobApplicationSummaryJob` enqueued now.** AGREE — `create_ai_summary_generation.rb:60-64` build(status: :pending), `:70 if ai_summary.save`, `:71-74` `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id:, requesting_organization_user_id:)`.

6. **Branch (ii) Textract pending → `:textract_processing` summary, NO job.** AGREE — `:46 if validation_result.textract_pending`, `:47-53` build(status: :textract_processing), `:53-57` save / fail!, `:57 return`. No job enqueue in this branch.

7. **Branch point.** AGREE-with-omission — the actual branch point is `create_ai_summary_generation.rb:46` `if validation_result.textract_pending`. The map brackets both arms (`:46-53` and `:60-74`) but never pins the single branch-point line the slice demands. See omissions.

8. **Active-summary reuse short-circuit `:30-34` lookup, `:36-37` stale-on-mismatch.** AGREE — `:30-34` `.where.not(status: :failed).where(stale: false).order(created_at: :desc).first`; `:36` mismatch check, `:37` `update_columns(stale: true)`, `:38` nil-out; `:41-44` returns existing if still active.

9. **GenerateAiJobApplicationSummaryJob: retry_on CustomErrorAiSummary 2 min ×3; calls `generate_ai_summary_with_credit_flow` `:32`; `broadcast_completion(...) if requesting_organization_user_id` `:34`.** AGREE — `:13` retry_on, `:32`, `:34` confirmed. Retry-exhaustion block `:19` `ai_summary&.update_columns(status: :failed, ...)` and StandardError rescue `:44` confirmed.

10. **generate_ai_summary_with_credit_flow step order: `:68` return guard, `:70-72` find_or_create + set_initial_summary_pending, `generate_ai_summary` → Orchestrate, `:82` succeeded re-fetch, `:84` credit.** AGREE — `:67-68` `latest_ai_summary = ...; return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`; `:70` find_or_create; `:72` set_initial_summary_pending; `:74` generate_ai_summary; `:77` re-fetch; `:82 return unless ...status_succeeded?`; `:84` CreateAiCreditBalanceTransaction. `generate_ai_summary` def `:110-111` calls `Orchestrate.new(textract_result_id: id).call`.

11. **Orchestrate `:15` latest summary (no stale filter), `:16` return unless present.** AGREE — literal lines confirmed.

12. **Orchestrate dispatch table (pending/textract_processing/extracting/retrying→run_summary; summarizing complete/incomplete; awaiting_job_criteria; scoring with/without criteria_results; integrating; succeeded/failed→return).** AGREE — `:22-49` confirmed line-for-line.

13. **`check_criteria_and_score` `:68-83`: return if failed `:69`; return unless summary_complete? `:70`; update awaiting_job_criteria `:72`; succeeded-criteria→run_scoring+run_integration; else extract_job_criteria unless pending/in_progress; return.** AGREE — `:69-82` confirmed.

14. **Stage 1 reuse `.update(status: :extracting)` at generate.rb:32 (else create at :35-39).** AGREE — `:30-40` confirmed; `:32` has an `unless ...status_extracting?` guard on the update (map cites the update at :32; accurate).

## Omissions (S-A)

1. **Branch-point line not pinned.** The slice explicitly requires file:line for the textract-ready vs textract-pending branch. The decision is `create_ai_summary_generation.rb:46` `if validation_result.textract_pending`. The map gives the two arms' ranges but never states line 46 as the branch point. (The upstream determinant — `ValidateAiSummaryGeneration` SETTING `context.textract_pending` at `:40/45/56/59` — is also not pinned to a single line in the S-A context.)

2. **Safe-nav asymmetry on requesting user.** On the pending (textract_processing) build, `requested_by_organization_user_id: context.user&.current_organization_user&.id` (`:50`, safe-nav). On the ready (pending) job enqueue, `requesting_organization_user_id: context.user.current_organization_user.id` (`:73`, NO safe-nav). The map does not note this; the ready path raises NoMethodError if `current_user.current_organization_user` is nil, whereas the pending build tolerates nil. Minor, but it is an S-A behavior the map omits.

3. **Controller authorize + `exists` guard.** Controller `:5 exists(...)` scopes to `current_organization.job_applications`, `:6 authorize :ai_job_application_summary, :create?`. Not load-bearing to the flow map but is the actual S-A entry gate; the map's trigger matrix lists policy generically (`can_use_ai_credits?` in Part 6) without noting the controller-level `exists` 404 guard.

## Conclusion
Every concrete code claim the map makes about S-A is AGREE against literal code. There are no DISPUTEs. However the slice's explicit requirement (branch-point file:line) is not satisfied by the map, and two S-A behaviors (safe-nav asymmetry, controller exists/authorize gate) are omitted. clean = false on account of omissions.

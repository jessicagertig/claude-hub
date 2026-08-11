# S-A Adversarial Review — pass-7

Slice S-A: Manual single generate. Controller create → ValidateAiSummaryGeneration → CreateAiSummaryGeneration → GenerateAiJobApplicationSummaryJob → AiJobApplicationAction::Orchestrate. Both sub-branches (textract ready / textract pending).

Re-read from scratch against current code. Files opened and traced:
- `app/controllers/api/v1/ai_job_application_summaries_controller.rb` (create `:4-28`)
- `app/interactors/validate_ai_summary_generation.rb` (full)
- `app/interactors/create_ai_summary_generation.rb` (full)
- `app/jobs/generate_ai_job_application_summary_job.rb` (full)
- `app/models/textract_result.rb:61-144` (generate_ai_summary_with_credit_flow, set_initial_summary_pending, queue_ai_summary_job)
- `app/services/ai_job_application_action/orchestrate.rb` (full)
- `app/services/ai_job_application_action/summary/generate.rb:25-69` (reuse/create branch)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (full)
- `app/models/job_application.rb:28-47` (associations/callbacks), `:685-687` (latest_textract_result)

## Verdicts (every S-A map statement → AGREE/DISPUTE)

All AGREE. Each claim verified against the literal line cited.

1. `validate_ai_summary_generation.rb:29` `unless has_job_description?`, def `:81-83` `@job_application.job&.description.present?` — AGREE. Lines 29, 81-83 match exactly.
2. Fail-fast chain `:24-25` nil guards, `:26` flipper, `:27` has_resume, `:28` credits, `:29` job_description, all BEFORE submit `:39` — AGREE.
3. Sibling branches: `:38-42` no-result → submit+pending+return; `:44-45` ready → pending=false; `:46-57` failed-but-prior-not → resubmit `:55`+pending `:56`; `:52-53` both-failed → fail!; `:58-59` else → pending=true — AGREE. (Line 52 `if previous_textract_result&.textract_job_status_failed?`, line 53 `context.fail!`.)
4. No-result branch shifted to `:38-42` (old `:37-41`) — AGREE.
5. `context.textract_result` assigned unconditionally at `:31-32` (RHS nil on no-result path); `latest_textract_result` def `job_application.rb:685-687` `textract_results.order(created_at: :desc).first` — AGREE.
6. `generate_ai_summary_with_credit_flow` calls find_or_create + set_initial_summary_pending at `textract_result.rb:70-72` — AGREE.
7. T9 waiting-summary: built `:pending`-style `textract_processing` carries `requested_by_organization_user_id` `:50`; bridge threads it at `textract_result.rb:130`; bridge IF branch re-validates `:126`, enqueues with requesting user `:128-131` — AGREE.
8. No-Textract REUSE sub-case: `active_ai_summary` `:30-34`; mismatch `nil != nil` false → not staled `:36-39`; reused+returned `:41-44` — AGREE.
9. No-Textract FRESH-BUILD: NEW `:textract_processing` built+saved `:47-53`, returned WITHOUT enqueue `:57` — AGREE.
10. Textract-READY sub-branch: `:46` else arm, `:pending` built `:60-64`, saved `:70`, synchronous enqueue `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id:..., requesting_organization_user_id: context.user.current_organization_user.id)` `:71-74` — AGREE.
11. Active-summary lookup + mismatch-stale run BEFORE `:46`; mismatch staled via `update_columns(stale: true)` `:37` — AGREE.
12. Asymmetric nil-safety: `:73` no safe-nav; build sites `:50` and `:63` use `context.user&.current_organization_user&.id` — AGREE.
13. Async-ordering note (submit is `perform_later`, TextractResult built only when job runs `submit_resume_to_textract.rb:22`) — AGREE in mechanism (submit at `:39` is `.perform_later`).
14. Validate invoked WITHOUT `user:` (controller `:8-11` passes only job_application+organization); Create gets `user: current_user` `:20` — AGREE.
15. Pre-validate gates: `authorize :ai_job_application_summary, :create?` `:6`, scoping `exists(current_organization.job_applications.where(id: ...))` `:5` — AGREE.
16. Bridge waiting-summary query `textract_result.rb:121-123` filters only `status: :textract_processing, stale: false`, no textract_result_id filter — AGREE.
17. Part 6 gate row: controller `:5` 404 scope + `:6` authorize — AGREE.
18. Part 7 AI matrix #A: CreateAiSummaryGeneration / auto-gen No / AI_SUMMARY_COMPLETE / 1 on success — AGREE (job enqueued with requesting user → `generate_ai_job_application_summary_job.rb:34` broadcast; credit at `textract_result.rb:84`).
19. Orchestrate selects JobApplication-scoped `:15`, `return unless` `:16`, succeeded/failed return `:46-48`; pending/textract_processing/extracting/retrying → run_summary `:22-26` — AGREE.
20. Summary::Generate reuses pending/textract_processing/extracting/retrying via `.update(status: :extracting) unless status_extracting?` `:32`, else create `:35-39` — AGREE.

## Branch point (slice requirement)
- Textract-ready vs Textract-pending DECISION: `validate_ai_summary_generation.rb:38` (`unless @latest_textract_result`) and `:44` (`if textract_text_ready?`) set `context.textract_pending`.
- Pending vs ready BUILD: `create_ai_summary_generation.rb:46` (`if validation_result.textract_pending`). Pending → `:textract_processing` build, NO job (`:47-57`). Ready → `:pending` build + synchronous enqueue (`:60-74`).
Map documents both branch points (changelog lines 157, 164; Part 7 row 9). AGREE.

## Omissions
1. (Minor / borderline) The S-A textract-READY pipeline, after the synchronous enqueue, runs the SAME Orchestrate pipeline as S-E and can come to rest at `awaiting_job_criteria` (`orchestrate.rb:72,80-81`) with the status row left at `initial_summary_pending` and NO broadcast (BROADCAST_STATUSES excludes `awaiting_job_criteria` AND `retrying`, `ai_job_application_summary.rb:23`). The map documents this desync ONLY under S-E (line 211) and X3, not co-located in the S-A section. Since S-A's scope ends at "generation job → Orchestrate," the deeper rest states are owned by S-E; this is a cross-reference gap rather than a missing fact. Noted for completeness.

clean = false (one borderline omission). All verdicts AGREE; zero DISPUTEs.

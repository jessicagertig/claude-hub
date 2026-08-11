# Re-verify: Bridge-SCDE — verdict CLEAN

Topic: bridge `TextractResult#queue_ai_summary_job` (NEW ~325-336) and generation-job exhaustion (NEW ~353-356).

## Previously-flagged findings

### (1) Bridge selector read-only; advancing record re-selected by ordered query (divergence window)
RESOLVED — present and correct at NEW `backend-flow-map-2026-06-22-neutral.md:331`.
- "This selection is read only to obtain `requested_by_organization_user_id` and to choose the branch; the job receives `textract_result_id` only (`:129`), never a summary id."
- "The advancing record is re-selected independently by an ordered query (`Orchestrate#call` `orchestrate.rb:15` and `Summary::Generate` `generate.rb:30`, both `order(created_at: :desc).first`). When the latest-by-`created_at` summary is not the `textract_processing` one this selector found, the record that advances differs from the one whose `requested_by_organization_user_id` drove the branch decision."
- Code-verified: `textract_result.rb:121-123` selector (no order); `:129` `textract_result_id: id`; `:130` `requested_by_organization_user_id`; `orchestrate.rb:15` and `generate.rb:30` both `order(created_at: :desc).first`. All exact.

### (2) Generation-job retry-exhaustion ALSO broadcasts completion (:20), not just the :failed write (:19)
RESOLVED — present and correct at NEW `backend-flow-map-2026-06-22-neutral.md:356`.
- "The retry-exhaustion block writes `ai_summary&.update_columns(status: :failed, error_message:)` (`:19`) and broadcasts completion (`:20`); the `StandardError` rescue (`:44`) also writes `:failed`. This job writes `:failed` only and never `:retrying`."
- Code-verified: `generate_ai_job_application_summary_job.rb:13` retry_on; `:19` `update_columns(status: :failed, ...)`; `:20` `broadcast_completion(...)`. Exact.

## Fresh check — dropped/altered OLD facts (this topic)
None dropped. Every load-bearing OLD bridge/gen-job fact survives in NEW:
- Entry guards `:115/:116/:119` → NEW `:329`.
- Selector `:121-123` JobApplication-scoped, no `textract_result_id` filter, no order → NEW `:331`.
- if-branch: re-validate `:126`, enqueue with requesting user `:127-131`; on failure destroy `:134` + AI_SUMMARY_FAILED `:132-135` → NEW `:333`.
- else-branch: `should_auto_generate_ai_summaries?` `:138`, re-validate `:140`, enqueue no requesting user if success `:142`, no failure handler → NEW `:334`.
- Gen job: queue/retry_on `:13`, perform sig, find_by `:25`, return unless `:30` (nil-id re-enqueue), credit-flow `:32`, broadcast if requesting user `:34`, StandardError rescue `:44` writes failed, failed-only/never-retrying → NEW `:356`.

## Fresh check — framing / banned vocab (this topic)
None. Scan of NEW `:323-356` found no banned vocab (dead end, stuck, broken, no-op, silently, hazard, fails to, MAP-WRONG, gap, should, never recovers, incorrect, problem, defect, wrong, severity ALL-CAPS). The corrections use neutral phrasing: "differs from" (divergence), "has no failure handler (no destroy, no broadcast)" — descriptive, not judgmental. `cleanup_orphaned_summary` does not appear in this section (its method-name use elsewhere is allowed).

## Verdict: CLEAN

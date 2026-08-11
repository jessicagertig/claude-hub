# S-D Adversarial Review — pass 6

**Slice:** S-D — Resume-replacement re-generation (a prior summary already exists; a new resume/Textract result arrives).
**Method:** Re-read all S-D-relevant code from scratch against the candidate map `backend-flow-map-2026-06-17.md`. Default-to-skepticism.

## Files traced
- `app/services/submit_resume_to_textract.rb` (stale guard `:18`, `update_all(stale:true)` `:19`, build in_progress `:22`, relink `:25-26`)
- `app/models/textract_result.rb` (credit flow `:61-89`; `:67-68` early-return guard; `:70` find_or_create; `:72` set_initial; `:77` self.ai_job_application_summaries; `:82` succeeded guard; `:84` credit; bridge `queue_ai_summary_job` `:114-144`, waiting selection `:121-123`, else branch `:137-142`, set_initial `:98-108`)
- `app/services/ai_job_application_action/orchestrate.rb` (`:15` JobApplication-scoped newest, `:16` nil guard, `:46-48` succeeded/failed return, `:64` run_summary)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (`:12` status-row pointer read, `:14` succeeded check, `:15` regenerating flip via update_columns, `:16-20` broadcast)
- `app/models/ai_job_application_summary.rb` (`:30` after_commit on:update, `:69` guard, `:74-80` .update to current)
- `app/services/ai_job_application_action/summary/generate.rb` (`:30-40` reuse vs create; reuse does NOT re-assign textract_result, create at `:35-39` does)
- `app/interactors/create_ai_summary_generation.rb` (`:30-34` stale filter, `:36-38` mismatch-stale — manual recovery)
- `app/interactors/create_bulk_ai_summary_generation.rb` (`:34-38` identical filter — bulk recovery)
- `app/interactors/queue_bulk_ai_summary_jobs.rb` (`:36-40` drops only `:current`)
- `app/models/job_application.rb` (`:31` latest_ai_job_application_summary has_one; `:160-162` find_or_create; `:164-171` enqueue_new_job_application)
- `app/models/job.rb` (`:914-922` should_auto_generate_ai_summaries?)
- `app/interactors/validate_ai_summary_generation.rb` (`:24-29` fail conditions)
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx` (`:73-76` ai_summary_status_change list-skip; `:77-81` ai_summary_succeeded list-invalidate)

## Verdicts (all AGREE except omissions noted)

All literal-code claims in the Trigger D / S-D section, the RECONCILIATION NOTE #3, and the cross-referenced T2 auto-continuation bullet check out against current code. The scope distinction between `orchestrate.rb:15` (JobApplication-scoped, picks the old stale-succeeded summary) and `textract_result.rb:77` (`self.ai_job_application_summaries`, firing-TextractResult-scoped, empty on the new result) is the verified mechanism that makes S-D a no-op for credit while still flipping the status row to a stuck `regenerating`.

### OMISSIONS (make clean=false)

1. **Validation-failure-after-Textract sub-terminal (auto-gen ON) is undocumented for S-D.**
   On the S-D auto path the bridge else branch re-runs `ValidateAiSummaryGeneration` at `textract_result.rb:140` and enqueues `GenerateAiJobApplicationSummaryJob` ONLY `if result.success?` (`:142`). `ValidateAiSummaryGeneration` can fail on credits-exhausted (`validate_ai_summary_generation.rb:28`) or missing-job-description (`:29`) — both reachable in S-D (resume is present after replacement, but credits/description are independent). When validation FAILS at `:140`: no job is enqueued, so `find_or_create_ai_job_application_summary_status` (`textract_result.rb:70`) NEVER runs, the status row is NEVER flipped to `regenerating` and stays `current` with now-stale denormalized data, and the prior summary stays `succeeded + stale:true` with no further actor. This is a distinct S-D resting state separate from the documented auto-gen-OFF case (map line 174) and the documented auto-gen-ON STUCK-`regenerating` case (lines 175-178). The else branch has no failure handler (silent no-op, consistent with S-C line 161), so nothing surfaces this to the user. The map's S-D section documents only the validation-SUCCESS continuation.

2. **`set_initial_summary_pending` is a no-op on the S-D auto path — not stated.**
   On the S-D auto path, `find_or_create` (`textract_result.rb:70`) flips the status row to `regenerating` FIRST, then `set_initial_summary_pending` (`:72`) runs with guard `:102` `return unless status_record.status_none? || status_record.status_initial_summary_pending?`. Because the row is now `regenerating`, the guard fails and `:104-107` does NOT execute — the row keeps its OLD denormalized `ai_job_application_summary_id`/score/headline/analysis (consistent with the STUCK-`regenerating`-renders-old-data terminal). The map states the stuck-regenerating terminal and the regenerating-flip's status-only write (line 213) but does not explicitly note that `set_initial_summary_pending` no-ops here due to the `:102` guard against `regenerating`, which is the reason the `initial_summary_pending` writer does not re-point the row mid-path.

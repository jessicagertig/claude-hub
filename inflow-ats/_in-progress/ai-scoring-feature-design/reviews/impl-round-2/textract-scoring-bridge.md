# textract-scoring-bridge — Implementation Review Round 2

## Files reviewed

- `app/models/textract_result.rb` — `generate_ai_summary_with_credit_flow`, `generate_ai_summary` (now calls Orchestrate), `queue_ai_summary_job`
- `app/services/ai_job_application_action/orchestrate.rb` — replaces old `generate_ai_summary`
- `app/jobs/generate_ai_job_application_summary_job.rb` — `textract_result_id` parameter, error handling, broadcast
- `app/interactors/validate_ai_summary_generation.rb` — textract pending logic
- `app/interactors/create_ai_summary_generation.rb` — status assignment
- `app/models/ai_job_criteria.rb` — `resume_waiting_summaries` callback

## Findings

No findings.

1. **Orchestrator replaces `generate_ai_summary`:** `TextractResult#generate_ai_summary` (line 91-93) now calls `AiJobApplicationAction::Orchestrate.new(textract_result_id: id).call`. Method is private. Matches spec Section 6.
2. **`generate_ai_summary_with_credit_flow` unchanged:** Lines 61-82 are untouched. Credit consumption still gated by `status_succeeded?` at line 75. All trigger paths (auto, manual, bulk, criteria-ready) converge here correctly.
3. **`textract_result_id` parameter chain intact:** `GenerateAiJobApplicationSummaryJob.perform(textract_result_id:)` -> `TextractResult#generate_ai_summary_with_credit_flow` -> `generate_ai_summary` -> `Orchestrate.new(textract_result_id:)`. Chain unbroken.
4. **Criteria-ready resume path:** `AiJobCriteria#resume_waiting_summaries` (line 20-27) finds summaries with `status: :awaiting_job_criteria`, enqueues `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: summary.textract_result_id)`. This re-enters the same pipeline. Correct per spec Section 6.
5. **No duplicate credit consumption on resume:** When `GenerateAiJobApplicationSummaryJob` fires for a resume from `awaiting_job_criteria`, the orchestrator picks up at the criteria check, runs scoring and integration. Credit consumed only when status reaches `succeeded`. If the original run already consumed a credit (it wouldn't have — `awaiting_job_criteria` is before `succeeded`), this is safe.

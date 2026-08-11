# textract-scoring-bridge -- Round 5

## Scope
Orchestrator replaces `generate_ai_summary` inside `TextractResult#generate_ai_summary_with_credit_flow`. All trigger paths must work. `textract_result_id` parameter chain intact. Callback-based resume from `awaiting_job_criteria`.

## Files reviewed
- `app/models/textract_result.rb` (full file)
- `app/services/ai_job_application_action/orchestrate.rb` (full file)
- `app/jobs/generate_ai_job_application_summary_job.rb` (full file)
- `app/models/ai_job_criteria.rb` (full file)
- `app/interactors/create_ai_summary_generation.rb` (full file)

## Integration point verified

`generate_ai_summary` (line 91-93, now private) calls `AiJobApplicationAction::Orchestrate.new(textract_result_id: id).call`. Called from `generate_ai_summary_with_credit_flow` (line 67). All trigger paths flow through this:

1. **Auto trigger:** `TextractResult after_commit :queue_ai_summary_job` -> `GenerateAiJobApplicationSummaryJob` -> `textract_result.generate_ai_summary_with_credit_flow` -> `generate_ai_summary` -> `Orchestrate`
2. **Manual trigger:** `AiJobApplicationSummariesController#create` -> `ValidateAiSummaryGeneration` -> `CreateAiSummaryGeneration` -> `GenerateAiJobApplicationSummaryJob` -> same path
3. **Bulk trigger:** `BulkAiJobApplicationSummariesController#create` -> `QueueBulkAiSummaryJobs` -> `BulkGenerateAiSummariesJob` -> `result.textract_result.generate_ai_summary_with_credit_flow` -> same path
4. **Criteria-ready callback:** `AiJobCriteria after_commit :resume_waiting_summaries` -> `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id:)` -> same path

## `generate_ai_summary` made private

Verified at line 89 (`private` keyword) before line 91 (`def generate_ai_summary`). No external callers can bypass the orchestrator. Matches spec: "should be removed or made private."

## `textract_result_id` parameter chain

`GenerateAiJobApplicationSummaryJob` takes `textract_result_id:` (line 24). The `AiJobCriteria` callback passes `textract_result_id: ai_job_application_summary.textract_result_id` (line 24-25 of `ai_job_criteria.rb`). Orchestrator constructor takes `textract_result_id:` (line 5). Chain intact.

## Credit consumption gating

`generate_ai_summary_with_credit_flow` line 75: `return unless ai_job_application_summary&.status_succeeded?`. Since `succeeded` now means full pipeline (value 7), credits are only consumed after integration completes. Correct per spec Section 8.

## Findings

None.

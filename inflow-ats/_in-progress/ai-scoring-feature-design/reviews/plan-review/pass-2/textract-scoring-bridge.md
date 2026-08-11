# Pass 2 — textract-scoring-bridge

## Verification of Pass 1 corrections

No corrections in this angle. Pass 1 had no findings.

## Fresh-eyes re-read

Re-checked the four entry points:

1. **Auto trigger:** `TextractResult after_commit :queue_ai_summary_job` -> `GenerateAiJobApplicationSummaryJob` -> `textract_result.generate_ai_summary_with_credit_flow` -> `generate_ai_summary` (now calls orchestrator) -> `Orchestrate`. CORRECT.

2. **Manual trigger:** Controller -> interactors -> `GenerateAiJobApplicationSummaryJob` -> same flow. CORRECT.

3. **Bulk trigger:** `BulkGenerateAiSummariesJob#each_iteration` -> `result.textract_result.generate_ai_summary_with_credit_flow` -> same flow. CORRECT.

4. **Criteria-ready callback:** `AiJobCriteria after_commit` -> `GenerateAiJobApplicationSummaryJob.perform_later(textract_result_id: summary.textract_result_id)` -> same flow. CORRECT.

All four converge at `generate_ai_summary_with_credit_flow` -> `generate_ai_summary` (now orchestrator). The credit consumption, notification, and broadcast logic remain unchanged.

One observation: The `BulkGenerateAiSummariesJob` calls `generate_ai_summary_with_credit_flow` directly (not through `GenerateAiJobApplicationSummaryJob`). The plan correctly notes this in spec Section 5. This means the bulk job's error handling (its own `retry_on`, `discard_on`) operates on the entire iteration, not on a sub-job. This is unchanged from the current behavior.

## Final completeness sweep

No gaps. Bridge is fully specified.

## Findings

No findings.

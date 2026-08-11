# credit-consumption-timing -- Round 4

## Scope

Verify credit consumed only at `succeeded` (terminal state). Every reference to `status_succeeded?` and related enum methods must be identified and verified.

## Findings

### Credit consumption gate

`TextractResult#generate_ai_summary_with_credit_flow` line 75: `return unless ai_job_application_summary&.status_succeeded?`. With the redesigned enum, `succeeded` = 7 means full pipeline (summary + scoring + integration) complete. Credits are only consumed after the entire evaluation succeeds. If scoring or integration fails, the status never reaches `succeeded` and no credit is consumed. Correct per spec Section 8.

### Exhaustive status_succeeded? reference check

Grepped `status_succeeded?` across all app/ files:

1. `ai_job_application_summary.rb:53` -- `destroy_previous_textract_results`: fires after full pipeline. Correct (old textract results should only be cleaned up after the complete evaluation).
2. `ai_job_application_summary.rb:61` -- `update_summary_status_record`: updates the status read model after full pipeline. Correct.
3. `textract_result.rb:75` -- credit consumption gate. Correct.
4. `ai_job_criteria.rb:21` -- `resume_waiting_summaries`: fires on `AiJobCriteria` succeeded (different model's enum). Not related to `AiJobApplicationSummary` succeeded.
5. `generate_ai_job_application_summary_job.rb:61` -- broadcast_completion: broadcasts after full pipeline. Correct.

No references to `status: :succeeded` on `AiJobApplicationSummary` exist in any code path that should fire at the summary-only completion point. All correctly gate on full-pipeline terminal state.

### Entry type reuse

The spec says reuse `ai_summary_usage_debit: 60` in `AiCreditBalanceTransaction`. `CreateAiCreditBalanceTransaction` is called from `generate_ai_summary_with_credit_flow` and uses the existing entry type. No new entry types added. Correct.

### 1 credit per evaluation

No additional credit consumption points added anywhere in the scoring services or orchestrator. The single credit consumption in `generate_ai_summary_with_credit_flow` covers the entire evaluation. Correct per spec Section 8.

## Result: PASS -- 0 findings

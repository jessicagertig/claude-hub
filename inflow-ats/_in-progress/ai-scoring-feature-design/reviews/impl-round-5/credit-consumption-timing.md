# credit-consumption-timing -- Round 5

## Scope
Credit consumed only at `succeeded` (terminal state). Every reference to `status_succeeded?`, `status: :succeeded`, and enum-generated status methods verified.

## Files reviewed
- `app/models/textract_result.rb` line 75
- `app/models/ai_job_application_summary.rb` lines 53, 61
- `app/models/ai_job_criteria.rb` line 21
- `app/jobs/generate_ai_job_application_summary_job.rb` line 61
- `app/services/ai_job_application_action/orchestrate.rb` lines 46, 76
- `app/services/ai_job_application_action/scoring/score_job_application.rb` line 22

## Exhaustive `status_succeeded?` audit

| Location | Object | Purpose | Correct? |
|----------|--------|---------|----------|
| `textract_result.rb:75` | `AiJobApplicationSummary` | Credit consumption gate | Yes -- `succeeded` = full pipeline |
| `ai_job_application_summary.rb:53` | `AiJobApplicationSummary` | Destroy previous textract results | Yes -- cleanup after full success |
| `ai_job_application_summary.rb:61` | `AiJobApplicationSummary` | Update status record pointer | Yes -- points to latest success |
| `ai_job_criteria.rb:21` | `AiJobCriteria` | Resume waiting summaries | Yes -- different model's enum |
| `generate_ai_job_application_summary_job.rb:61` | `AiJobApplicationSummary` | Broadcast success/fail | Yes -- broadcast after full pipeline |
| `orchestrate.rb:46` | `AiJobApplicationSummary` | Terminal state guard | Yes -- skip re-processing |
| `orchestrate.rb:76` | `AiJobCriteria` | Criteria ready check | Yes -- different model's enum |
| `score_job_application.rb:22` | `AiJobCriteria` | Criteria availability check | Yes -- different model's enum |

## Credit path

1. `Orchestrate.call` runs full pipeline
2. `IntegrateAnalysis` sets `status: :succeeded` via `update` (triggers callbacks)
3. Control returns to `generate_ai_summary_with_credit_flow`
4. Line 75: `return unless ai_job_application_summary&.status_succeeded?`
5. `CreateAiCreditBalanceTransaction.call(summary: ai_job_application_summary)`

If scoring or integration fails, status is `failed` (or `retrying`), and line 75 returns early -- no credit consumed.

## Findings

None.

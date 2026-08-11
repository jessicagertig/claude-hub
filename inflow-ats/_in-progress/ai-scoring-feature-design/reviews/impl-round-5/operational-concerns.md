# operational-concerns -- Round 5

## Scope
Job retry patterns, exhaustion blocks, queue assignment, logging, monitoring.

## Files reviewed
- `app/jobs/extract_job_criteria_job.rb`
- `app/jobs/generate_ai_job_application_summary_job.rb`
- `app/services/ai_job_application_action/scoring/extract_criteria.rb`
- `app/services/ai_job_application_action/scoring/score_job_application.rb`
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb`

## Job retry patterns

### `ExtractJobCriteriaJob`
- `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3` with exhaustion block
- Exhaustion block: `ai_job_criteria&.update_columns(status: :failed, error_message: error&.message)`
- Matches `GenerateAiJobApplicationSummaryJob` exhaustion pattern (pipeline failure pattern #14)
- Queue: `:default`

### `GenerateAiJobApplicationSummaryJob`
- `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3` with exhaustion block (NEW -- added in this branch)
- Exhaustion block: finds textract_result, finds latest summary, sets `failed`, broadcasts
- Previous version had no exhaustion block -- this is a fix from pre-work findings

## Error propagation through orchestrator

When `Summary::Generate` raises `CustomErrorAiSummary`:
1. `Summary::Generate` sets status to `retrying` and re-raises
2. `Orchestrate.call` does not catch -- propagates up
3. `GenerateAiJobApplicationSummaryJob` `CustomErrorAiSummary` rescue catches, re-raises
4. ActiveJob `retry_on` fires, job retried
5. On retry, orchestrator sees `retrying` status, re-runs summary from beginning

Same propagation works for `ScoreJobApplication` and `IntegrateAnalysis` CustomErrorAiSummary.

When `JSON::ParserError` or `StandardError` occurs in sub-services:
1. Sub-service sets status to `failed`, does NOT re-raise
2. Orchestrator continues, but next step checks `status_failed?` and returns
3. Control returns to `generate_ai_summary_with_credit_flow`
4. Line 75: `return unless ai_job_application_summary&.status_succeeded?` -- returns, no credit consumed

## Logging

All services and jobs use `ap` for debug logging and `Rails.logger.error` for error logging. Consistent with existing codebase pattern.

## Findings

None.

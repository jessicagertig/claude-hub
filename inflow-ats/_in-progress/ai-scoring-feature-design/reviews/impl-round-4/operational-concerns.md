# operational-concerns -- Round 4

## Scope

Job queue behavior, retry/exhaustion patterns, error propagation, logging, monitoring.

## Findings

### ExtractJobCriteriaJob retry pattern

`retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3` with exhaustion block that sets `failed`. Matches `GenerateAiJobApplicationSummaryJob` pattern per Known Failure Pattern #14 (analog structural matching).

### GenerateAiJobApplicationSummaryJob exhaustion block

The job now has an exhaustion block (added in commit `4a7040c0b`). On exhaustion: finds the summary via `textract_result.ai_job_application_summaries.order(created_at: :desc).first`, sets `failed` with error message, broadcasts completion. This was a pre-existing gap that was fixed.

### Error propagation through orchestrator

`Summary::Generate` sets `retrying` and re-raises `CustomErrorAiSummary`. `ScoreJobApplication` and `IntegrateAnalysis` do the same for `CustomErrorAiSummary`. The orchestrator does NOT catch these -- they propagate to the job's `retry_on`. On retry, the orchestrator's resume logic picks up from the appropriate status. Correct error propagation chain.

### Non-retryable errors

`JSON::ParserError` and `StandardError` set `failed` (terminal) and do NOT re-raise. The job does not retry. Correct -- these errors are unlikely to succeed on retry.

### Queue assignment

Both `ExtractJobCriteriaJob` and `GenerateAiJobApplicationSummaryJob` use `queue_as :default`. Consistent with existing jobs.

### Logging

All services use `ap` debug logs at entry points and in error handlers. `Rails.logger.error` used for structured error logging. Matches the existing `Summary::Generate` pattern.

### Timeout configuration

`AiProviders::Openai` now has `timeout: 120` and `open_timeout: 30`. This prevents indefinite hangs on OpenAI API calls. Previously there was no explicit timeout -- Faraday's default is 60s. The increase to 120s accounts for the structured data extraction calls which can be slow for long job descriptions.

### Temperature setting

`AiProviders::Openai` now sends `temperature: 0` in all requests. This improves determinism for scoring and criteria extraction. Consistent with the scoring pipeline's need for reproducible results.

## Result: PASS -- 0 findings

# Operational Concerns -- Round 1

## Findings

No issues found.

- Logging: All services use `ap` for debug logging and `Rails.logger.error` for error logging, consistent with analog patterns.
- Error handling: Three-tier rescue pattern (`CustomErrorAiSummary` -> re-raise for retry, `JSON::ParserError` -> fail terminal, `StandardError` -> fail terminal) is consistent across all new services.
- `CustomErrorAiSummary` correctly sets `retrying` on `AiJobApplicationSummary` (not `failed`) for `ScoreJobApplication` and `IntegrateAnalysis`, allowing job retries to resume. `ExtractCriteria` correctly sets `failed` on `AiJobCriteria` (different model, different lifecycle).
- Performance: No N+1 queries introduced. `job_applications_controller.rb` correctly adds `.includes(:ai_job_application_summary_status)` for eager loading.
- `Orchestrate` uses `reload` with documented deviation from Rule 8 -- necessary and well-documented.

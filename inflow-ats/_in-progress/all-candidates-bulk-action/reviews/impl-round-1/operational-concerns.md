# Operational Concerns — Round 1

## Findings

No issues found.

Verified:
- Error logging: `Rails.logger.error(e)` and `ap e` in the rescue block (though the rescue block itself is flagged as an analog deviation in backend-contract)
- Mailer delivery: `.deliver_later` used at all call sites — no synchronous email delivery
- No N+1: `@job.job_applications.pluck(:id)` is a single query
- No performance concerns: reuses existing job iteration pattern
- Postmark templates: spec correctly documents that `user-bulk-all-stages-ai-summary-complete` and `user-bulk-all-stages-ai-summary-failed` must be created in Postmark before deployment
- WebSocket: reuses existing `AI_SUMMARY_BULK_COMPLETE` action type — no new handler code needed
- Query invalidation: `useBulkGenerateAllStagesAiSummaries` invalidates `job` key in addition to the analog's keys — correct for updated `aiJobApplicationSummariesCount`

# reinventing-the-wheel — Implementation Review Round 2

## Files reviewed

All new services and models checked against existing patterns in the codebase.

## Findings

No findings.

1. **`ExtractCriteria` follows `Summary::Generate` pattern:** Constructor takes ID, loads with `find_by`, single public method, three-tier error handling, `create_ai_api_request` private method, `update_columns` for intermediate transitions, `update` for final `succeeded` transition. Direct structural match.
2. **`ScoreJobApplication` follows same pattern:** Constructor takes objects (called from orchestrator), three-tier error handling, `create_ai_api_request` method.
3. **`IntegrateAnalysis` follows same pattern.**
4. **`ExtractJobCriteriaJob` follows `GetResumeTextFromTextractJob` pattern:** `retry_on CustomErrorAiSummary` with exhaustion block, `find_by` guard, delegates to service.
5. **`AiJobCriteria#resume_waiting_summaries` follows `TextractResult#queue_ai_summary_job` pattern:** `after_commit` on update, guards on status change + success, finds waiting records, enqueues jobs.
6. **`Job#extract_job_criteria` follows existing callback patterns:** Flipper gate, debounce via status check, `perform_later` with delay.
7. **`AiJobApplicationSummaryStatus` follows lightweight read model pattern:** Minimal model, belongs_to associations, uniqueness validation on foreign key.
8. **`create_ai_api_request` method:** Identical structure in all three scoring services and `Summary::Generate`. Same parameters, same cost calculation, same attributes. Not extracted to a shared module, but this matches the existing pattern (each service has its own private method).

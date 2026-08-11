# Backward Compatibility — Round 1

## Findings

No issues found.

Verified:
- `QueueBulkAiSummaryJobs` — existing `create` caller passes no `kind` or `rescore_requested`; interactor handles both with safe defaults (`context.kind || 'single_hiring_stage'`, falsy `context.rescore_requested` leaves filter intact)
- `BulkGenerateAiSummariesJob` — existing payloads have no `kind` key; `payload['kind'] || 'single_hiring_stage'` preserves existing behavior
- `bulk_ai_job_application_summary_params` — adding `:rescore_requested` to permit list is additive; existing `create` requests that don't include it get nil, which is fine
- `Api::V1::JobSerializer` — two new attributes are additive; no existing frontend code destructures or breaks on extra keys
- Existing `BulkJobApplicationAiSummaryResultMailer` is unchanged
- Existing `AI_SUMMARY_BULK_COMPLETE` broadcast action type unchanged; `hiringStageLink` field name unchanged

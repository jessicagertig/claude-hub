# Backward Compatibility — Round 1

## Findings

- Verified: `QueueBulkAiSummaryJobs` — existing caller (`create` action) does not pass `kind` or `rescore_requested`. The interactor reads them from context, which returns nil when not set. The spec says `kind` defaults to `"single_hiring_stage"` in the payload — the interactor must handle nil `context.kind` gracefully. Correctly addressed.

- Verified: `BulkGenerateAiSummariesJob` — existing payloads have no `kind` key. The spec says "When `kind` is `'single_hiring_stage'` or absent" for both `notify_complete` and `notify_failure`. Correctly handles backward compatibility.

- Verified: `bulk_ai_job_application_summary_params` — adding `rescore_requested` to the permit list is purely additive. Existing `create` requests don't include it; it will be nil, which is falsy. No breakage.

- Verified: `Api::V1::JobSerializer` — adding attributes is additive. No breakage.

No issues found.

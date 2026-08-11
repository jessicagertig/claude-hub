# serializer-contract

## Checked

1. `JobApplicationSerializer` -- removed `has_one :ai_job_application_summary` + method override, added `has_one :ai_job_application_summary_status`. Matches `ShallowJobApplicationSerializer` pattern.
2. `AiJobApplicationSummaryStatusSerializer` -- added `:updated_at` to attributes. Correct.
3. `AiJobApplicationSummaryStatus.update_columns` in model -- now includes `updated_at: Time.current`. Correct.
4. `jobApplication.ts` -- removed `aiJobApplicationSummary`, added `aiJobApplicationSummaryStatus` with correct fields matching serializer output (camelCase per rule 7).
5. `aiJobApplicationSummary.ts` -- status enum updated to match Ruby model enum. Correct.
6. No remaining `jobApplication.aiJobApplicationSummary` property access in frontend (verified via grep).
7. `useAiJobApplicationSummary` query key `["aiJobApplicationSummary", aiJobApplicationSummaryId]` matches invalidation keys in both `WebsocketJobChannelHandler` and `WebsocketGlobalChannelHandler`.

## Findings

None.

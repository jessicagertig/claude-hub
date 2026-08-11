# query-invalidation-coherence -- Round 1

## Fact Check

### Query keys in hooks
- `useAiJobApplicationSummary`: `["aiJobApplicationSummary", aiJobApplicationSummaryId]` -- CONFIRMED
- `useJobApplication`: `["jobApplication", jobApplicationId]` (inferred from `queryClient.setQueryData(["jobApplication", data.id], ...)`) -- CONFIRMED

### New invalidation (JobChannel)
- Plan C.1.1: `queryClient.invalidateQueries(["jobApplication"])` and `queryClient.invalidateQueries(["aiJobApplicationSummary"])`
- Prefix-based (no specific ID). Matches existing pattern in `WebsocketGlobalChannelHandler`. Broader than necessary but consistent.

### Existing invalidation (GlobalChannel)
- `AI_SUMMARY_COMPLETE` (lines 225-227): invalidates `["jobApplication"]`, `["aiJobApplicationSummary"]`, `["organizationAiCreditBalance"]` -- CONFIRMED
- `AI_SUMMARY_FAILED` (lines 239-240): invalidates `["jobApplication"]`, `["organizationAiCreditBalance"]`. Note: does NOT invalidate `["aiJobApplicationSummary"]` -- CONFIRMED

### Generate mutation invalidation
- `useGenerateAiSummary` onSuccess (useAiJobApplicationSummary.ts): invalidates `["jobApplication", variables.jobApplicationId]`, `["organizationAiCreditBalance"]` -- CONFIRMED. Does NOT invalidate `["aiJobApplicationSummary"]` directly.
- `useUpdateJobApplication` onSuccess (useJobApplication.ts:224): invalidates `["aiJobApplicationSummary"]` -- CONFIRMED. This is the update mutation, not a generate mutation. Still correct after rework.

### Double invalidation on `succeeded`
- `before_update :broadcast_status_change` fires -> JobChannel -> invalidates `["jobApplication"]` + `["aiJobApplicationSummary"]`
- `after_commit :update_summary_status_record` fires -> denormalizes to status record
- `GenerateAiJobApplicationSummaryJob` (or `TextractResult`) fires GlobalChannel -> invalidates `["jobApplication"]` + `["aiJobApplicationSummary"]` + `["organizationAiCreditBalance"]`
- Different timing (before_update vs after job completes). Both cause refetches. React Query deduplicates within the same tick but these are separate ticks. Two quick refetches, no UI flicker expected. Acceptable.

### Timing concern (optimistic broadcast)
- `before_update` broadcast fires BEFORE DB write. Frontend may refetch stale data if the request hits the server before the transaction commits. GlobalChannel broadcast (after commit) corrects this. Documented in Risk #4. Acceptable for intermediate statuses.

## Completeness

| Spec requirement | Plan step | Status |
|---|---|---|
| New event invalidation | C.1.1 | Covered |
| Invalidates `["jobApplication"]` | C.1.1 | Covered |
| Invalidates `["aiJobApplicationSummary"]` | C.1.1 | Covered |
| No conflict with GlobalChannel | C.1.1 note, P4 | Documented |
| Generate mutation invalidation correct | Not in plan | Verified (no change needed) |

## Findings

No issues found.

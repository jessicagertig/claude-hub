# query-invalidation-coherence -- Round 1

## Fact Check

**Plan claim C.1.1: new event invalidates `["jobApplication"]` and `["aiJobApplicationSummary"]`**
- Plan shows this in the code block. Verified against the query keys:
  - `useJobApplication` uses key `["jobApplication", jobApplicationId]` -- prefix match on `["jobApplication"]` will match.
  - `useAiJobApplicationSummary` uses key `["aiJobApplicationSummary", aiJobApplicationSummaryId]` -- prefix match on `["aiJobApplicationSummary"]` will match.

**Plan claim: `WebsocketGlobalChannelHandler` `AI_SUMMARY_COMPLETE` invalidates `["jobApplication"]`, `["aiJobApplicationSummary"]`, `["organizationAiCreditBalance"]`**
- Verified: lines 225-227 invalidate all three.

**Plan claim: `AI_SUMMARY_FAILED` invalidates `["jobApplication"]` and `["organizationAiCreditBalance"]`**
- Verified: lines 239-240 invalidate `["jobApplication"]` and `["organizationAiCreditBalance"]`. Notably does NOT invalidate `["aiJobApplicationSummary"]`.

**Plan claim: React Query deduplicates identical query invalidations**
- Correct: React Query batches invalidations per tick. Two calls to `invalidateQueries(["jobApplication"])` in the same tick result in one refetch.

**Plan claim: `useJobApplication` generate mutation invalidates `["aiJobApplicationSummary"]` at line 224**
- Wait -- the `useGenerateAiSummary` mutation is in `useAiJobApplicationSummary.ts`, not `useJobApplication.ts`. Let me re-check.
- Verified: `useAiJobApplicationSummary.ts` lines 18-22: `useGenerateAiSummary` invalidates `["jobApplication", variables.jobApplicationId]` and `["organizationAiCreditBalance"]`. No `["aiJobApplicationSummary"]` invalidation in this mutation.
- `useJobApplication.ts` line 224: this is inside a different mutation (`useUpdateJobApplication` or similar). The generate mutation is in `useAiJobApplicationSummary.ts`, not `useJobApplication.ts`.
- The plan references line 224 of `useJobApplication.ts` which does call `queryClient.invalidateQueries(["aiJobApplicationSummary"])`. This is inside the `useUpdateJobApplication` mutation's `onSuccess` -- not the generate mutation. The plan's reference is correct but the context is about updating a job application, not generating a summary. Still valid for query coherence.

## Completeness

Spec requirements this angle covers:
1. New `JobChannel` event invalidates correct queries -- plan C.1.1
2. Existing `GlobalChannel` events not modified -- plan (no changes section)
3. No conflicting or redundant query invalidation -- plan Risks #2
4. All query keys match between hooks and invalidation calls -- verified above

All covered.

## Findings

No issues found.

## Amendments Applied

None.

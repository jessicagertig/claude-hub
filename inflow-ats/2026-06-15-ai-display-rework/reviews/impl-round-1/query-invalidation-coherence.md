# query-invalidation-coherence

## Checked

1. New `JobChannel` broadcast (`ai_summary_status_change`) invalidates:
   - `["jobApplication"]` -- prefix match, refreshes all job application queries including the status record
   - `["aiJobApplicationSummary"]` -- prefix match, refreshes the full summary query

2. Existing `GlobalChannel` broadcast (`AI_SUMMARY_COMPLETE`) invalidates:
   - `["jobApplication"]`
   - `["aiJobApplicationSummary"]`
   - `["organizationAiCreditBalance"]`

3. Both can fire for `succeeded` status. React Query deduplicates invalidations within the same tick. No UI flicker expected.

4. The new broadcast also fires for intermediate statuses (`extracting`, `summarizing`, `scoring`, `integrating`, `textract_processing`, `failed`) which the GlobalChannel broadcast does NOT cover. This enables the PlatoLoadingState checklist to advance in real time.

5. Query keys match:
   - `useAiJobApplicationSummary` key: `["aiJobApplicationSummary", aiJobApplicationSummaryId]` -- prefix-matched by `["aiJobApplicationSummary"]`
   - `useJobApplication` key: `["jobApplication", jobApplicationId]` -- prefix-matched by `["jobApplication"]`

6. `useGenerateAiSummary` mutation onSuccess: invalidates `["jobApplication", variables.jobApplicationId]` and `["organizationAiCreditBalance"]`. Still correct after rework.

## Findings

None.

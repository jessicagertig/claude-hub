# query-invalidation-coherence (Round 2)

## Re-verified

1. Query key matching: `["aiJobApplicationSummary"]` prefix-matches `["aiJobApplicationSummary", aiJobApplicationSummaryId]`. `["jobApplication"]` prefix-matches `["jobApplication", jobApplicationId]`. Both invalidation calls in `WebsocketJobChannelHandler` correctly target the right queries.
2. `useGenerateAiSummary` mutation onSuccess invalidates `["jobApplication", variables.jobApplicationId]` and `["organizationAiCreditBalance"]`. This still fires correctly after the rework.
3. Double invalidation on `succeeded` (JobChannel + GlobalChannel) is harmless -- React Query deduplicates within the same tick.
4. Intermediate statuses (extracting, summarizing, scoring, integrating, textract_processing) only fire from the new JobChannel broadcast. The GlobalChannel only fires for succeeded/failed. Correct separation.
5. The `queryClient` is already in the `handleJobMessage` dependency array (line 82: `[refetchJob, queryClient, jobId]`). No stale closure risk.

## Findings

None.

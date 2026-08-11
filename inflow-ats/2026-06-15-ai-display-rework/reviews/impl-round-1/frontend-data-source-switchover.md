# frontend-data-source-switchover

## Checked

1. `PlatoTab.tsx` -- switched from `jobApplication.aiJobApplicationSummary` to `jobApplication.aiJobApplicationSummaryStatus`. Uses `summaryStatus?.aiJobApplicationSummaryId` for the `useAiJobApplicationSummary` hook. Correct.
2. `JobApplicationActivity.tsx` -- switched from `aiJobApplicationSummary?.status === "succeeded"` to `aiJobApplicationSummaryStatus?.status === "current" || ... === "regenerating"`. Props read from status record. Correct.
3. `PlatoOverviewCallout.tsx` -- receives `summaryStatusValue` instead of `summaryStatus`. Four-state derivation from status record. Correct.
4. `PlatoGeneratedReviewCallout.tsx` -- receives props from parent; component itself not modified (parent passes data from status record). Correct.
5. `JobApplicationListContainer.tsx` -- already uses `aiJobApplicationSummaryStatus` (pre-existing on branch). No changes needed. Correct.
6. `AiJobApplicationSummaryFeedItem.tsx` -- deleted. Was dead code (not imported anywhere). Correct.
7. `generatedAgo` -- now uses `distanceInWords(summaryStatus?.updatedAt)` instead of `distanceInWords(aiJobApplicationSummary.createdAt)`. The status record's `updated_at` reflects when the latest successful summary landed (via `update_summary_status_record` callback). Correct.
8. `stale` -- read from `fullSummary?.stale` instead of `aiSummary.stale`. Correct (stale is on the full summary record, not the status record).
9. No remaining `jobApplication.aiJobApplicationSummary` property access in frontend (verified via grep).

## Findings

None.

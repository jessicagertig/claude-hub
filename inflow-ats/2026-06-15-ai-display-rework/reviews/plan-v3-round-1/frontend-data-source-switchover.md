# frontend-data-source-switchover -- Round 1

## Fact Check

### PlatoTab.tsx
- Line 37: `const aiSummary = jobApplication.aiJobApplicationSummary;` -- CONFIRMED
- Line 43: `aiJobApplicationSummaryId: aiSummary?.id` -- CONFIRMED
- Line 91: `distanceInWords(aiSummary.createdAt)` for generatedAgo -- CONFIRMED
- Line 100: `aiSummary.stale` for stale check -- CONFIRMED

### JobApplicationActivity.tsx
- Line 399: `jobApplication.aiJobApplicationSummary?.status === "succeeded"` -- CONFIRMED
- Lines 401-404: reads `headline`, `integratedRoleAnalysis || summaryText`, `scorePercentage`, `createdAt` from `jobApplication.aiJobApplicationSummary` -- CONFIRMED

### PlatoGeneratedReviewCallout.tsx
- Props: `headline: string`, `roleFit: string`, `scorePct: number`, `generatedAgo: string`, `onClick?: () => void` at lines 11-17 -- CONFIRMED
- Component is props-only (no data fetching). Parent passes values. No component-level change needed. CONFIRMED.

### PlatoOverviewCallout.tsx
- Current props: `summaryStatus?: string | null`, `hasResume?: boolean`, `variant?`, `onClick?`, `linkHref?` at lines 12-18 -- CONFIRMED

### useAiJobApplicationSummary
- Query key: `["aiJobApplicationSummary", aiJobApplicationSummaryId]` -- CONFIRMED
- `enabled: aiJobApplicationSummaryId != undefined` -- CONFIRMED. When switching to `summaryStatus?.aiJobApplicationSummaryId`, this will be `undefined` when no linked summary exists, correctly disabling the query.

### useJobApplication
- `useUpdateJobApplication` mutation at line 224 invalidates `["aiJobApplicationSummary"]` -- CONFIRMED. This is not a generate mutation; it is the update mutation. Still correct after rework.
- `useGenerateAiSummary` mutation (in `useAiJobApplicationSummary.ts`) invalidates `["jobApplication", variables.jobApplicationId]` and `["organizationAiCreditBalance"]` on success -- CONFIRMED. Does NOT invalidate `["aiJobApplicationSummary"]` directly; the websocket broadcast handles that.

### All frontend `aiJobApplicationSummary` references
- Grep found references in: `jobApplication.ts` (type -- removed by B.1), `PlatoTab.tsx` (switched by C.3), `JobApplicationActivity.tsx` (switched by C.4), `WebsocketGlobalChannelHandler.tsx` (invalidation key -- stays), `useJobApplication.ts` (invalidation key -- stays), `useAiJobApplicationSummary.ts` (hook return type -- stays).
- No orphaned references after plan changes. CONFIRMED.

### AiJobApplicationSummaryFeedItem.tsx
- Not imported anywhere (grep zero results outside the file). Plan D.1.1 deletes it. CONFIRMED safe.

## Completeness

| Spec requirement | Plan step | Status |
|---|---|---|
| PlatoTab reads from `aiJobApplicationSummaryStatus` | C.3.1 | Covered |
| PlatoTab uses `summaryStatus?.aiJobApplicationSummaryId` | C.3.2 | Covered |
| PlatoTab status checks updated | C.3.3 | Covered |
| PlatoTab shimmer replaced with PlatoLoadingState | C.3.4 | Covered |
| PlatoTab generatedAgo uses `summaryStatus?.updatedAt` | C.3.5 | Covered |
| JobApplicationActivity switches data source | C.4.1 | Covered |
| JobApplicationActivity updates callout props | C.4.2 | Covered |
| PlatoGeneratedReviewCallout reads from status (via parent) | C.6.1 | Covered |
| Remove `aiJobApplicationSummary` from type | B.1.1, B.1.2 | Covered |
| AiJobApplicationSummaryFeedItem deletion | D.1.1 | Covered |

## Findings

No issues found.

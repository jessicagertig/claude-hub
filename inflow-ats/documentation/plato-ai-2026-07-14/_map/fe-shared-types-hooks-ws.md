# Slice map: FE shared types, query hooks, websocket handlers, lookups

Scope: TS data contracts, React Query hooks, ActionCable websocket handlers, and lookup/helper libs for Plato AI (summaries + scoring + AI-credits billing). Mostly NEW files; the risk lives in the handful of EDITS to shared/cross-feature files.

## New TS type contracts (data shapes only — no runtime behavior)
- `shared/types/aiJobApplicationSummary.ts` — `AiJobApplicationSummary` (status enum: pending → textract_processing → extracting → summarizing → awaiting_job_criteria → scoring → integrating → succeeded | retrying | failed; headline, summaryText, stale, scorePercentage, integratedRoleAnalysis) + `AiJobApplicationSummaryFull` (adds structuredData, criteriaResults, jobApplicationId). `CriteriaResult` tiers tier_1/2/3, scores full_match/partial_match/not_found. `AiResumeStructuredData`, `AiAssessment` (domains, keySkills, standoutAccomplishments), work/education shapes.
- `shared/types/aiSummaryWebsocketPayloads.ts` — payload shapes consumed by the global websocket handler (see below).
- `shared/types/organizationAiCreditBalance.ts` — balance buckets: daily/monthly/addonSubscription/addon/total remaining, monthly allocation, period end dates.
- `shared/types/organizationAiCreditPurchase.ts` — subscription purchase record; status enum active/past_due/canceled/paused.

## SHARED types EDITED (regression surface — non-AI code reads these)
- `shared/types/jobApplication.ts` — adds `aiJobApplicationSummaryStatus` (enum none/initial_summary_pending/current/regenerating + denormalized scorePercentage/headline/integratedRoleAnalysis) and `bulkAiSummaryProcessing: boolean` to the base `JobApplication` interface. Every JobApplication consumer now expects these; if the serializer omits them they are undefined. Non-AI regression: any strict use of JobApplication shape.
- `shared/types/organization.ts` — `OrganizationSettings` gains typed AI keys (autoGenerateAiSummariesEnabled, hiringTeamAiCreditsControlEnabled, lowAiCreditNotificationsEnabled, lowAiCreditNotificationThreshold, zeroAiCreditNotificationsEnabled); `[key: string]: any` index kept so nothing else breaks. `PlanFeatures` enum gains `AI_APPLICANT_SUMMARY = "ai_applicant_summary"` — gates AI UI on plan feature.

## Query hooks — NEW
- `useAiJobApplicationSummary.ts` — `useGenerateAiSummary` (POST /job_applications/:id/ai_job_application_summaries; on success invalidates jobApplication+aiJobApplicationSummary+organizationAiCreditBalance) and `useAiJobApplicationSummary` GET (enabled only when summary id defined — avoids the `|| 0` 404 anti-pattern).
- `useBulkGenerateAiSummaries.ts` — `useBulkGenerateAiSummaries` (POST /bulk_ai_job_application_summaries with jobId+hiringStageId+included/excludedJobApplicationIds+roleFit → returns queuedCount/skippedCount/anyTextractPending) and `useBulkGenerateAllStagesAiSummaries` (POST .../all_stages with rescoreRequested). Both invalidate stage list, jobApplication, credit balance (+job for all-stages). Server-side selection resolution (matches bulk-move/bulk-message analog).
- `useOrganizationAiCreditBalance.ts` — GET /ai_credits.
- `useOrganizationAiCreditPurchase.ts` (274 lines) — full AI-credit billing surface: get purchase, checkout top-up, preview/commit subscription change, preview/purchase top-up, purchase-top-up checkout session (flat unwrapped params, mirrors WWR checkout), cancel/revert subscription, prices, customer subscription, cancel/get scheduled change. Invalidations cascade across organizationAiCreditPurchase / organizationAiCreditBalance / aiCreditCustomerSubscription / aiCreditSubscriptionSchedule.

## Query hooks — EDITED (SHARED / regression surface)
- `useJobApplication.ts` —
  - `getInfiniteJobApplications` now sends `role_fit` array param (arrayFormat: "bracket", skipNull) on the stage list request; `useInfiniteJobApplicationsForStage` adds `roleFit` and PUTS IT IN THE QUERY KEY `["jobApplicationsForStage", stageId, roleFit]`. Regression risk: any caller that renders stage lists — a new roleFit filter dimension now partitions the cache; callers not passing roleFit get key `[...,undefined]`.
  - `bulkMoveJobApplicationsToStage` now sends `roleFit` (default []). SHARED non-AI bulk-move flow gets a new param.
  - `useUpdateJobApplication` onSuccess now also invalidates `["aiJobApplicationSummary"]`. Every job-application update (stage move, edit — non-AI actions) now refetches AI summaries.
- `useBulkMessage.ts` — `createBulkMessage` adds `roleFit` (default []) to payload. SHARED non-AI bulk-messaging flow now carries a roleFit filter param.

## Websocket handlers — EDITED
- `WebsocketGlobalChannelHandler.tsx` — new cases: `AI_CREDIT_TOP_UP_COMPLETE` (invalidate balance); `AI_SUMMARY_COMPLETE` (toast success/warning by status, 10s, link to job application; invalidate jobApplication/aiJobApplicationSummary/stage list/balance); `AI_SUMMARY_FAILED` (warning toast, invalidations); `AI_SUMMARY_BULK_FAILED` (warning toast 20s from message); `AI_SUMMARY_BULK_COMPLETE` (composed toast "N Plato reviews generated, M failed, K skipped"; kind warning if failures, info if 0 succeeded, else success; link to hiring stage; invalidations). USER-VISIBLE: realtime toasts + auto-refresh when AI summaries finish/fail. Shared handler — a malformed/unknown payload falls through default (no regression to existing cases).
- `WebsocketJobChannelHandler.tsx` — new `ai_summary_status_change` case invalidates `["aiJobApplicationSummary", id]`, `["jobApplication", jobApplicationId]`, `["jobApplicationsForStage", hiringStageId]`. Drives live status pill / score updates on the job board while a review is generating. Note: stage-list key here is `[..., hiringStageId]` (no roleFit third element) — relies on react-query prefix matching to invalidate the roleFit-partitioned keys.

## Lookups & helper libs
- `ats/src/lib/newLookups.ts` — adds `AutoGenerateAiSummaries` type + `jobAutoGenerateAiSummariesOptions` (default / enabled / disabled) for the Job-level AI auto-generate setting dropdown.
- `shared/lib/bulkAiSummaryCount.ts` (NEW) — `bulkSummaryProcessableCount`: estimates how many candidates a bulk run will actually process by subtracting loaded selected candidates whose `aiJobApplicationSummaryStatus.status === "current"` (already succeeded, non-stale). Returns `{count, isExact}`; isExact false = upper bound when not all rows loaded. Drives the "will process N" count in the bulk-generate confirm UI.
- `shared/lib/planHelpers.ts` — adds AI credit allocation map from `window.AI_CREDIT_ALLOCATIONS` (JSON) with hardcoded fallback (prod `plato_ai_credit_*` + dev `ai_credit_pack_*` keys), display-name map, and `aiCreditPrices(stripePrices)` builder (kind subscription/one_off, credits, priceDollars = unitAmount/100). Feeds the AI-credit purchase/pricing UI. SHARED file (existing plan helpers unchanged).
- `shared/lib/validateWithYup.ts` — adds `validateOrganizationAiSettings` (low-credit threshold ≥1 required when notifications enabled) and `validateBulkGenerateAiSummaries` (availableCredits ≥1 or "no credits available" error). SHARED validation module (existing validators untouched).

## Regression callouts (name + how)
1. `JobApplication` interface widened — consumers across the whole app now type-expect aiJobApplicationSummaryStatus + bulkAiSummaryProcessing.
2. `useInfiniteJobApplicationsForStage` cache key now includes roleFit — cache partitioning change affecting all stage-list rendering, not just AI.
3. `useUpdateJobApplication` invalidates aiJobApplicationSummary on EVERY update — extra refetch on all non-AI job-application mutations.
4. `bulkMoveJobApplicationsToStage` / `createBulkMessage` send new `roleFit` param — non-AI bulk move + bulk message flows.
5. Global + Job websocket handlers extended — new cases only; unknown payloads fall through, existing cases untouched.

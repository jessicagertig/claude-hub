# F1 — Frontend status consumers of AiJobApplicationSummaryStatus — Pass 1

**Angle:** F1
**Date traced:** 2026-06-22
**Repo:** /Users/jessica/wrk/wrk-corp/inflow-ats

## Files traced (chain)

Backend exposure:
- `app/controllers/api/v1/job_applications_controller.rb:27,28,38,39` (index, infinite list) → `app/serializers/api/v1/shallow_job_application_serializer.rb:23-24` → `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb`
- `app/controllers/api/v1/job_applications_controller.rb:56,60` (show) → `app/serializers/api/v1/job_application_serializer.rb:40-41` → same status serializer
- `app/models/ai_job_application_summary_status.rb` (enum {none,initial_summary_pending,current,regenerating} _prefix:true)
- Status writers: `app/models/ai_job_application_summary.rb:57-98` (update_summary_status_record → 'current' + ai_summary_succeeded broadcast; broadcast_status_change → ai_summary_status_change), `app/models/textract_result.rb:98-108` (set_initial_summary_pending), `app/interactors/find_or_create_ai_job_application_summary_status.rb:14-20,27-34` ('regenerating' + ai_summary_status_change broadcast / 'current' / 'none')

Frontend:
- `app/javascript/shared/types/jobApplication.ts:1-9,21` (AiJobApplicationSummaryStatus TS interface)
- `app/javascript/ats/src/views/jobApplications/JobApplicationListContainer.tsx:50-58,235-236` (infinite list reader) → `app/javascript/ats/src/views/jobApplications/JobApplicationNavItem.tsx:21-44` → `app/javascript/ats/src/views/jobApplications/Plato/FitIndicator.tsx:19-21,87-116` (fitBand/FitHarvey)
- `app/javascript/shared/queryHooks/useJobApplication.ts:153-162,164-208,351-368` (query keys jobApplications / jobApplicationsForStage / jobApplication)
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx:73-81` (ai_summary_status_change + ai_summary_succeeded handlers)
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx` (detail pane) → `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts` (useGenerateAiSummary, useAiJobApplicationSummary)
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx:79-94` (activity feed reader)
- `app/javascript/shared/lib/bulkAiSummaryCount.ts` (bulkSummaryProcessableCount)

## Serializer exposure

`Api::V1::AiJobApplicationSummaryStatusSerializer` exposes: `id, ai_job_application_summary_id, status, score_percentage, headline, integrated_role_analysis, updated_at, published_at_timestamp` (published_at_timestamp = `object.updated_at.to_i`). It does NOT expose `regenerating` (no such column — regenerating is an enum VALUE of `status`, not a boolean). The map (lines 513,520,640) describes a boolean `regenerating` column "never set to true"; that column no longer exists — MAP-WRONG.

Both `ShallowJobApplicationSerializer` (infinite list) and `JobApplicationSerializer` (show) expose `has_one :ai_job_application_summary_status` with this serializer. Index preloads `.includes(:ai_job_application_summary_status)`.

## TS interface

`jobApplication.ts:1-9` — `status: "none" | "initial_summary_pending" | "current" | "regenerating"`. Matches the backend enum exactly. Declares `scorePercentage`, `headline`, `integratedRoleAnalysis`, `aiJobApplicationSummaryId`, `updatedAt`. Does NOT declare `publishedAtTimestamp`, though the serializer sends it AND `JobApplicationActivity.tsx:87` reads `summaryStatus.publishedAtTimestamp` (untyped access — works at runtime, missing from interface).

## Readers (every file:line)

1. `JobApplicationListContainer.tsx:235` — `summaryStatus={jobApplication.aiJobApplicationSummaryStatus?.status}`
2. `JobApplicationListContainer.tsx:236` — `summaryScorePercentage={jobApplication.aiJobApplicationSummaryStatus?.scorePercentage}`
3. `JobApplicationNavItem.tsx:26-29` — Harvey ball shown only when `status === "current" || status === "regenerating"` AND `scorePercentage != null`. `none`/`initial_summary_pending` render NOTHING in the list.
4. `bulkAiSummaryCount.ts:~42` — `aiJobApplicationSummaryStatus?.status === "current"` excludes already-current rows from bulk count estimate.
5. `PlatoTab.tsx:41-42` — reads `summaryStatus` and `statusValue`.
6. `PlatoTab.tsx:46` — passes `summaryStatus?.aiJobApplicationSummaryId` to `useAiJobApplicationSummary` (keys the heavy fetch).
7. `PlatoTab.tsx:50,52,151,154,210,218` — `regenerationSettled`, `hasContent`, render branches keyed on `statusValue` (`current`/`regenerating`).
8. `PlatoTab.tsx:127,129,130` — denormalized `headline`, `scorePercentage`, `updatedAt` rendered.
9. `JobApplicationActivity.tsx:79-91` — `status === "current" || "regenerating"` → builds a platoReview feed entry from `publishedAtTimestamp, headline, integratedRoleAnalysis, scorePercentage, updatedAt`.

## Websocket handler — ai_summary_status_change

`WebsocketJobChannelHandler.tsx:73-76`:
```
case "ai_summary_status_change":
  queryClient.invalidateQueries(["aiJobApplicationSummary", data.payload.aiJobApplicationSummaryId]);
  queryClient.invalidateQueries(["jobApplication", data.payload.jobApplicationId]);
```
Invalidates the heavy single-summary fetch and the single job_application show query. Does NOT invalidate `["jobApplicationsForStage", ...]` (the infinite list key, useJobApplication.ts:185).

Separate event `ai_summary_succeeded` (`WebsocketJobChannelHandler.tsx:77-81`) invalidates `["jobApplicationsForStage", data.payload.hiringStageId]` — THIS is what refreshes the infinite list so the Harvey ball appears. Broadcast from `ai_job_application_summary.rb:93-97` (after_commit, after the status row is set to 'current').

`ai_summary_status_change` is broadcast from TWO sites:
- `ai_job_application_summary.rb:107` (before_update broadcast_status_change, gated by `BROADCAST_STATUSES` which excludes `awaiting_job_criteria` and `retrying`) — payload `{jobApplicationId, aiJobApplicationSummaryId}`.
- `find_or_create_ai_job_application_summary_status.rb:16-20` (when an existing succeeded summary is flipped to 'regenerating') — same payload.

## Desync windows (FE display vs DB row)

1. **Infinite list does not react to ai_summary_status_change.** The list query is `["jobApplicationsForStage", stageId, roleFit]` (useJobApplication.ts:185). `ai_summary_status_change` invalidates only `["aiJobApplicationSummary", id]` and `["jobApplication", id]` (singular). So while a summary moves through pending→extracting→...→integrating, the list row shows whatever its last fetch had (typically prior `current` Harvey ball, or nothing for a first-time `none`). Only `ai_summary_succeeded` refreshes the list. Display-only desync resolved on success.

2. **Regeneration not reflected in the list.** When regeneration starts, `find_or_create_ai_job_application_summary_status.rb:15` sets status `regenerating` and broadcasts `ai_summary_status_change`. That refetches the SHOW record (detail pane shows the "Regenerating" chip, PlatoTab.tsx:210-216) but NOT the list. List NavItem still renders a Harvey ball because line 27 treats `regenerating` like `current` — value stays the old score until `ai_summary_succeeded` lands. Display-only desync; cosmetically consistent (old score shown while regenerating).

3. **PlatoTab local optimistic loading (`showPlatoLoading`).** PlatoTab.tsx:30,62 — on generate mutation success, local React state `showPlatoLoading=true` forces the loading state (renderBody.tsx:158) independent of any DB row. Cleared (line 51) when `regenerationSettled` = `statusValue === "regenerating" || fullSummaryStatus === "failed"`. Pure display-only state; can show "loading" before the DB status row reflects the new generation. Not a true desync (no stale data shown), but a display state with no backing DB row.

4. **useGenerateAiSummary invalidations omit the list.** useAiJobApplicationSummary.ts:18-22 invalidates `["jobApplication", id]`, `["aiJobApplicationSummary"]`, `["organizationAiCreditBalance"]` — never `["jobApplicationsForStage"]`. So a user clicking Generate/Regenerate updates the detail pane but not the list row until the websocket `ai_summary_succeeded` arrives.

No optimistic `setQueryData` writes the status row itself; all FE status display is read-through from the last server fetch. There is no path that fabricates a status VALUE the DB never held — the only display-only states are PlatoTab's `showPlatoLoading` (a loading spinner) and the stale-cache windows above.

## Terminal display states / dead ends

- `none` and `initial_summary_pending` → list renders no Harvey ball (NavItem.tsx:26-29). PlatoTab `none` + no resume → noResume empty state; else ready/noCredits empty state (PlatoTab.tsx:187-206).
- `current` / `regenerating` with `scorePercentage != null` → Harvey ball in list; full summary rendered in PlatoTab when `fullSummary` loaded.
- If the status row is `current` but `aiJobApplicationSummaryId` points at a summary whose detail fetch returns non-succeeded/empty `structuredData`, PlatoTab shows the loading state (line 167) — list still shows the Harvey ball. Minor list/detail disagreement window.

## Map verdict summary

The old map has NO frontend-consumer section. Its only FE coverage is Part 8 (WebSocket Actions table, lines 707-714) which lists `AI_SUMMARY_COMPLETE/FAILED/BULK_*` GlobalChannel events — it does NOT mention `ai_summary_status_change` or `ai_summary_succeeded` (the JobChannel events that actually drive the status-table UI). The map's AiJobApplicationSummaryStatus data-model section (lines 504-520) describes a stale schema: a 10-value status enum (should be 4-value none/initial_summary_pending/current/regenerating) and a boolean `regenerating` column that no longer exists.

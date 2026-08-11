# F1 Adversarial Review — Pass 2 (Frontend status consumers)

Re-audited from scratch against current code at `/Users/jessica/wrk/wrk-corp/inflow-ats`.

## Files traced
- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb`
- `app/serializers/api/v1/shallow_job_application_serializer.rb`
- `app/serializers/api/v1/job_application_serializer.rb`
- `app/controllers/api/v1/job_applications_controller.rb` (list/show queries)
- `app/javascript/ats/src/views/jobApplications/JobApplicationNavItem.tsx`
- `app/javascript/ats/src/views/jobApplications/JobApplicationListContainer.tsx`
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx`
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx`
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx`
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx`
- `app/javascript/shared/queryHooks/useJobApplication.ts` (list query key)
- `app/javascript/shared/lib/bulkAiSummaryCount.ts`
- `app/javascript/shared/types/jobApplication.ts`

## Verdicts

### AGREE
- **Serializer fields** — `AiJobApplicationSummaryStatusSerializer` exposes `id, ai_job_application_summary_id, status, score_percentage, headline, integrated_role_analysis, updated_at, published_at_timestamp`; `published_at_timestamp = object.updated_at.to_i`. (`ai_job_application_summary_status_serializer.rb:4-10`)
- **Embedded via has_one in both serializers** — `ShallowJobApplicationSerializer:23-24` (`has_one :ai_job_application_summary_status`), `JobApplicationSerializer:40-41`.
- **`.includes` preload on the infinite list** — `job_applications_controller.rb:27,38` (`.includes(:ai_job_application_summary_status)`), rendered with `ShallowJobApplicationSerializer` (`:28,39`).
- **Harvey-ball gate** — renders only when status `current`/`regenerating` AND `scorePercentage != null`. (`JobApplicationNavItem.tsx:26-29`)
- **List container reads** — `JobApplicationListContainer.tsx:235-236` reads `aiJobApplicationSummaryStatus?.status` / `?.scorePercentage`.
- **`ai_summary_status_change` does NOT invalidate the list** — invalidates only `['aiJobApplicationSummary', id]` + `['jobApplication', id]`. (`WebsocketJobChannelHandler.tsx:73-76`)
- **`ai_summary_succeeded` (JobChannel) invalidates `['jobApplicationsForStage', hiringStageId]`** — `WebsocketJobChannelHandler.tsx:77-81`.
- **bulkAiSummaryCount excludes `'current'`** — `bulkAiSummaryCount.ts:37-41`.
- **TS interface** — 4-value status union; `publishedAtTimestamp` NOT declared (interface has id/aiJobApplicationSummaryId/status/scorePercentage/headline/integratedRoleAnalysis/updatedAt) yet serializer sends it (`serializer:6`) and `JobApplicationActivity.tsx:87` reads it. (`jobApplication.ts:1-9`)
- **PlatoTab keys heavy fetch off status row id** — `PlatoTab.tsx:46` (`aiJobApplicationSummaryId: summaryStatus?.aiJobApplicationSummaryId`).
- **JobApplicationActivity platoReview entry** — built from `publishedAtTimestamp`/`headline`/`integratedRoleAnalysis`/`scorePercentage` when status `current`/`regenerating`. (`JobApplicationActivity.tsx:79-94`)

### DISPUTE
- **MAP CLAIM (F1 line 114; Part 8 line 521):** "JobChannel `ai_summary_succeeded` is the **only** event that invalidates `['jobApplicationsForStage', hiringStageId]`" / "(only list-refreshing event)".
  - **CONTRADICTING CODE:** `WebsocketGlobalChannelHandler.tsx` invalidates `jobApplicationsForStage` on FOUR additional AI events:
    - `AI_SUMMARY_COMPLETE` → `queryCache.invalidateQueries(["jobApplicationsForStage"])` (`:227`)
    - `AI_SUMMARY_FAILED` → `:241`
    - `AI_SUMMARY_BULK_FAILED` → `:253`
    - `AI_SUMMARY_BULK_COMPLETE` → `queryCache.invalidateQueries("jobApplicationsForStage")` (`:281`)
  - The list query key is `["jobApplicationsForStage", Number(stageId), roleFit]` (`useJobApplication.ts:185`). React-query partial matching means a prefix invalidation (`"jobApplicationsForStage"` or `["jobApplicationsForStage"]`) invalidates EVERY stage-keyed list query, including the active stage. So the infinite list IS refreshed by these GlobalChannel AI events. The word "only" is wrong.
  - **CORRECTION:** `ai_summary_succeeded` is the only *JobChannel* event that targets the *stage-keyed* form, but it is NOT the only event that refreshes the list. `AI_SUMMARY_COMPLETE`, `AI_SUMMARY_FAILED`, `AI_SUMMARY_BULK_FAILED`, and `AI_SUMMARY_BULK_COMPLETE` (all GlobalChannel) also invalidate `jobApplicationsForStage` and thus refresh the list.

- **MAP CLAIM (Part 9 desync window #5, line 578):** "the infinite list reacts **only** to `ai_summary_succeeded`, not `ai_summary_status_change`; intermediate pipeline statuses never reach the list."
  - **CONTRADICTING CODE:** same as above — `WebsocketGlobalChannelHandler.tsx:227,241,253,281`. The "reacts only to ai_summary_succeeded" half is false. On the manual single path, `AI_SUMMARY_COMPLETE` (which fires whenever `requesting_organization_user_id` is present, regardless of succeeded vs failed status — see the handler title branch `:215-218`) also refreshes the list. On the bulk path, `AI_SUMMARY_BULK_COMPLETE`/`_FAILED` refresh it.
  - **CORRECTION:** The list ignores `ai_summary_status_change` (true), but it IS refreshed by `ai_summary_succeeded` AND by the GlobalChannel events `AI_SUMMARY_COMPLETE`/`AI_SUMMARY_FAILED`/`AI_SUMMARY_BULK_COMPLETE`/`AI_SUMMARY_BULK_FAILED`. The narrower true statement: no *intermediate per-status* (`ai_summary_status_change`) event reaches the list; only terminal/completion events do.

## Omissions (for F1 slice)

1. **GlobalChannel AI events refreshing the list are entirely absent from the F1 section.** The F1 bullets (lines 111-116) and Part 9 "Websocket" reader (line 571) cover only the JobChannel handler. `WebsocketGlobalChannelHandler.tsx` cases `AI_SUMMARY_COMPLETE:227`, `AI_SUMMARY_FAILED:241`, `AI_SUMMARY_BULK_FAILED:253`, `AI_SUMMARY_BULK_COMPLETE:281` all invalidate `jobApplicationsForStage` and are list consumers that the F1 slice should enumerate.

2. **No statement that there is NO optimistic-UI / cache-write path for the status row.** The slice scope asks F1 to identify display-only desync from optimistic UI. Verified: no query hook writes `aiJobApplicationSummaryStatus` via `setQueryData`/`onMutate` (grep of `app/javascript/shared/queryHooks/` returns no status-row optimistic writes). The map should record this absence explicitly; all FE status display is server-truth via query invalidation, so there is no optimistic display-only desync surface. (Map neither claims nor denies this.)

3. **PlatoTab display-field fallbacks `|| 0` / `|| ""`** at `PlatoTab.tsx:127,129` (`summaryStatus?.headline || ""`, `summaryStatus?.scorePercentage || 0`) — display-only fabrication of `0`/`""` for absent denormalized data on the detail Plato card. Not a DB desync, but a FE-display divergence from the null DB value the serializer sends. Worth noting under F1's "display value vs DB" mandate (the fetch key at `:46` correctly does NOT use a fallback).

clean = false

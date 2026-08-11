# F1 — Frontend status consumers — Pass-3 adversarial review

Reviewed against candidate map `backend-flow-map-2026-06-17.md` lines 148-156 (F1 section) plus cross-referenced claims 71, 152.

## Trace chains followed (re-read from scratch)
- `app/controllers/api/v1/job_applications_controller.rb:27,38` → `app/serializers/api/v1/shallow_job_application_serializer.rb:23` → `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb:4-10`
- `app/javascript/ats/src/views/jobApplications/JobApplicationNavItem.tsx:26-29`
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx:73-81`
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:227,241,253,281` → `app/javascript/shared/queryHooks/useJobApplication.ts:185`
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx:42,46,127,129,130` → `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts:43-45`
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx:79-91`
- `app/javascript/shared/types/jobApplication.ts:1-9`
- `app/javascript/shared/lib/bulkAiSummaryCount.ts:37-41`
- `app/javascript/shared/queryHooks/useJobApplication.ts:229` (setQueryData)

## Verdicts

### Claim (149) serializer exposure + preload — AGREE
`shallow_job_application_serializer.rb:23` `has_one :ai_job_application_summary_status, serializer: Api::V1::AiJobApplicationSummaryStatusSerializer`. Serializer attributes at `ai_job_application_summary_status_serializer.rb:4-6` = `id, ai_job_application_summary_id, status, score_percentage, headline, integrated_role_analysis, updated_at, published_at_timestamp` (exact match). Preload `.includes(:ai_job_application_summary_status)` at `job_applications_controller.rb:27` and `:38`, rendered via `ShallowJobApplicationSerializer` at `:28,:39`. `published_at_timestamp` is a computed method = `object.updated_at.to_i` (`:8-10`).

### Claim (150) NavItem Harvey-ball gate — AGREE
`JobApplicationNavItem.tsx:26-29`: `const harveyValue = (summaryStatus === "current" || summaryStatus === "regenerating") && summaryScorePercentage != null ? fitBand(summaryScorePercentage).fill : null`. Exact.

### Claim (151) JobChannel events — AGREE
`WebsocketJobChannelHandler.tsx:73-76` `ai_summary_status_change` invalidates `["aiJobApplicationSummary", ...]` (`:74`) and `["jobApplication", ...]` (`:75`) — NOT the infinite list. `:77-81` `ai_summary_succeeded` invalidates `["jobApplicationsForStage", data.payload.hiringStageId]` (`:80`).

### Claim (152) GlobalChannel completion events refresh the list; list key — AGREE
`ats/src/websockets/WebsocketGlobalChannelHandler.tsx`: AI_SUMMARY_COMPLETE `:227`, AI_SUMMARY_FAILED `:241`, AI_SUMMARY_BULK_FAILED `:253`, AI_SUMMARY_BULK_COMPLETE `:281` each call `invalidateQueries("jobApplicationsForStage")` (`:227,:253` array form `["jobApplicationsForStage"]`; `:281` string form). List key `["jobApplicationsForStage", Number(stageId), roleFit]` at `useJobApplication.ts:185`. react-query prefix matching invalidates the keyed query. Confirmed.

### Claim (153) bulkAiSummaryCount excludes current — AGREE
`bulkAiSummaryCount.ts:37-41` filters `isSelected(...) && jobApplication.aiJobApplicationSummaryStatus?.status === "current"` into `loadedCurrentSelected`, subtracted at `:46`.

### Claim (154) TS interface 4-value union + publishedAtTimestamp untyped — AGREE
`jobApplication.ts:4` `status: "none" | "initial_summary_pending" | "current" | "regenerating"`. Interface fields `:1-9` include `updatedAt` (`:8`) but NOT `publishedAtTimestamp`. `JobApplicationActivity.tsx:87` reads `summaryStatus.publishedAtTimestamp` — untyped runtime access. Confirmed.

### Claim (155) no optimistic-UI desync — AGREE
No `setQueryData`/`onMutate` in `app/javascript/shared/queryHooks/` references `aiJobApplicationSummaryStatus`/`summaryStatus`. The one `setQueryData` touching jobApplication (`useJobApplication.ts:229`) runs in `onSuccess` (server-truth `data`), spreading the full mutation response — not an `onMutate` optimistic pre-write of the status field. No display-only desync surface for the status row from cache writes. Confirmed.

### Claim (156) PlatoTab display-only fallbacks — AGREE
`PlatoTab.tsx:127` `headline: summaryStatus?.headline || ""`; `:129` `scorePct: summaryStatus?.scorePercentage || 0`. Fetch key `:46` `aiJobApplicationSummaryId: summaryStatus?.aiJobApplicationSummaryId` (no `|| 0`). The downstream hook gates `enabled: aiJobApplicationSummaryId != undefined` (`useAiJobApplicationSummary.ts:45`), so no spurious GET fires. Confirmed.

## Omissions

1. **PlatoTab.tsx is the primary detail-view status consumer; map only cites its two fallback lines.** The map (156) cites only `:127,129`. PlatoTab branches the entire Plato card on `summaryStatus?.status` (read at `:42`, used at `:50,:52,:151,:154,:210,:218`), reads `summaryStatus?.aiJobApplicationSummaryId` (`:46`) to drive the full-summary fetch, and reads `summaryStatus?.updatedAt` (`:130`). It is the main reader of the status table on the candidate detail view — the F1 prose lists NavItem and bulkAiSummaryCount as readers but never names PlatoTab as a status reader (only as a source of two fallbacks).

2. **JobApplicationActivity.tsx is a full status reader, omitted from the reader list.** `:79-91`: gates a `platoReview` activity-feed entry on `summaryStatus?.status === "current" || "regenerating"` (`:80-83`) and reads `headline` (`:88`), `integratedRoleAnalysis` (`:89`), `scorePercentage` (`:90`), `updatedAt` (`:91`), and `publishedAtTimestamp` (`:87`). The map mentions only `:87` in the typing-gap note (154); it never documents this component as a status-table consumer that renders the denormalized columns into the activity feed.

## clean
false — all verdicts AGREE, but two reader omissions (PlatoTab as primary consumer; JobApplicationActivity as full reader).

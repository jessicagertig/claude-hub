# F1 Adversarial Review — Pass 4

Slice F1 — Frontend status consumers of `AiJobApplicationSummaryStatus`. Re-audited from scratch against current code. Candidate map section: lines 174-184 of `backend-flow-map-2026-06-17.md`, plus F1 cross-refs at changelog lines 135.

## Verdicts (all AGREE)

1. **Serializer + preload.** Map: "Infinite job-applications list serializes the status row via `ShallowJobApplicationSerializer` (`has_one :ai_job_application_summary_status`, `:23-24`), preloaded with `.includes(:ai_job_application_summary_status)` (`job_applications_controller.rb:27,38`). `AiJobApplicationSummaryStatusSerializer` exposes `id, ai_job_application_summary_id, status, score_percentage, headline, integrated_role_analysis, updated_at, published_at_timestamp` (`:4-10`, `published_at_timestamp = object.updated_at.to_i` at `:8-10`)."
   - AGREE. `app/serializers/api/v1/shallow_job_application_serializer.rb:23-24` `has_one :ai_job_application_summary_status, serializer: Api::V1::AiJobApplicationSummaryStatusSerializer`. Controller `index` preloads at `job_applications_controller.rb:27` and `:38` (`.includes(:ai_job_application_summary_status)`). Serializer attributes at `ai_job_application_summary_status_serializer.rb:4-6`, `published_at_timestamp` body `:8-10` `object.updated_at.to_i`.

2. **List fit indicator gate.** Map: "List Harvey-ball fit indicator renders ONLY when status is `current` or `regenerating` AND `scorePercentage != null` (`JobApplicationNavItem.tsx:26-29`)."
   - AGREE. `JobApplicationNavItem.tsx:26-29` `(summaryStatus === "current" || summaryStatus === "regenerating") && summaryScorePercentage != null ? fitBand(...).fill : null`.

3. **JobChannel ai_summary_status_change.** Map: "invalidates the single-summary + single-job-application queries, NOT the infinite list (`WebsocketJobChannelHandler.tsx:73-76`)."
   - AGREE. `WebsocketJobChannelHandler.tsx:73-76` invalidates `["aiJobApplicationSummary", data.payload.aiJobApplicationSummaryId]` and `["jobApplication", data.payload.jobApplicationId]`; no list invalidation. Backend payload matches: `ai_job_application_summary.rb:107` and `find_or_create_ai_job_application_summary_status.rb:19` send `jobApplicationId` + `aiJobApplicationSummaryId`.

4. **JobChannel ai_summary_succeeded.** Map: "the only JobChannel event that invalidates `['jobApplicationsForStage', hiringStageId]` (`WebsocketJobChannelHandler.tsx:77-81`)."
   - AGREE. `:77-81` invalidates `["jobApplicationsForStage", data.payload.hiringStageId]`. Backend payload `ai_job_application_summary.rb:96` sends `hiringStageId`. It is the only JobChannel case touching `jobApplicationsForStage`.

5. **GlobalChannel terminal events also refresh the list.** Map: "GlobalChannel `AI_SUMMARY_COMPLETE` (`:227`), `AI_SUMMARY_FAILED` (`:241`), `AI_SUMMARY_BULK_FAILED` (`:253`), and `AI_SUMMARY_BULK_COMPLETE` (`:281`) all call `invalidateQueries("jobApplicationsForStage")`; react-query prefix matching invalidates the stage-keyed list query (`['jobApplicationsForStage', stageId, roleFit]`, list key `useJobApplication.ts:185`)."
   - AGREE. `ats/src/websockets/WebsocketGlobalChannelHandler.tsx:227,241,253,281` each invalidate `jobApplicationsForStage`. List key `useJobApplication.ts:185` `["jobApplicationsForStage", Number(stageId), roleFit]`. Prefix match holds. Line numbers are unambiguous: the `shared/websockets/WebsocketGlobalChannelHandler.tsx` has NO AI_SUMMARY cases; AI handling lives only in the ats handler, which is mounted via `ats/src/websockets/WebsocketContext.tsx:3`.

6. **bulkAiSummaryCount excludes current.** Map: "`bulkAiSummaryCount.ts` excludes rows whose status is `'current'` from the bulk-run estimate (`:37-41`, subtracted at `:46`)."
   - AGREE. `bulkAiSummaryCount.ts:37-41` filters `aiJobApplicationSummaryStatus?.status === "current"` → `loadedCurrentSelected`; `:46` `count: Math.max(0, selectionCount - loadedCurrentSelected)`.

7. **TS interface + untyped publishedAtTimestamp.** Map: "TS interface `AiJobApplicationSummaryStatus.status` union is the 4-value set (`jobApplication.ts:4`); `publishedAtTimestamp` is sent by the serializer (`:6`) and read by `JobApplicationActivity.tsx:87` but is NOT declared on the TS interface (`jobApplication.ts:1-9`) — untyped runtime access."
   - AGREE. `shared/types/jobApplication.ts:4` status union is `"none"|"initial_summary_pending"|"current"|"regenerating"`. Interface `:1-9` lacks `publishedAtTimestamp`. Serializer sends it (`ai_job_application_summary_status_serializer.rb:6`). Read at `JobApplicationActivity.tsx:87`.

8. **No optimistic-UI desync.** Map: "no query hook in `app/javascript/shared/queryHooks/` writes `aiJobApplicationSummaryStatus` via `setQueryData`/`onMutate`. `useJobApplication.ts:229` `setQueryData` runs in `onSuccess` with full server data, not `onMutate` optimistic. All FE status display is server-truth via query invalidation; there is no optimistic display-only desync surface for the status row."
   - AGREE. Grep of `shared/queryHooks/` for `aiJobApplicationSummaryStatus`/`summaryStatus` → zero hits. The three `onMutate` hooks are `useQuestion.ts:98`, `useJob.ts:162`, `useWebflow.ts:218` — none touch the status row. `useJobApplication.ts:229` `setQueryData(["jobApplication", data.id], {...data})` is inside `onSuccess` (`:220`), not `onMutate`.

9. **PlatoTab display-only fallbacks.** Map: "`PlatoTab.tsx:127,129` use `summaryStatus?.headline || ''` and `summaryStatus?.scorePercentage || 0`... The fetch key at `PlatoTab.tsx:46` correctly omits a fallback (downstream gate `useAiJobApplicationSummary.ts:45` `enabled: aiJobApplicationSummaryId != undefined`)."
   - AGREE. `PlatoTab.tsx:127` `headline: summaryStatus?.headline || ""`; `:129` `scorePct: summaryStatus?.scorePercentage || 0`; `:46` `aiJobApplicationSummaryId: summaryStatus?.aiJobApplicationSummaryId` (no fallback). Gate `useAiJobApplicationSummary.ts:45` `{ enabled: aiJobApplicationSummaryId != undefined }`.

10. **PlatoTab is a full status reader.** Map: "branches the entire Plato card on `summaryStatus?.status` (read at `:42`; used at `:50,:52,:151,:154,:210,:218`), reads `summaryStatus?.aiJobApplicationSummaryId` (`:46`), reads `summaryStatus?.updatedAt` (`:130`)."
    - AGREE. `:42` `statusValue = summaryStatus?.status`; used `:50,:52,:151,:154,:210,:218` (also `:187` but the cited set is representative); `:46` and `:130` confirmed.

11. **JobApplicationActivity is a full status-table reader.** Map: "`JobApplicationActivity.tsx:79-91` gates a `platoReview` activity-feed entry on `summaryStatus?.status === 'current' || 'regenerating'` (`:80-83`) and renders `headline` (`:88`), `integratedRoleAnalysis` (`:89`), `scorePercentage` (`:90`), `updatedAt` (`:91`), `publishedAtTimestamp` (`:87`)."
    - AGREE. `:79` `summaryStatus = jobApplication.aiJobApplicationSummaryStatus`; `:80-83` gate; `:87` publishedAtTimestamp, `:88` headline, `:89` integratedRoleAnalysis (as `roleFit`), `:90` scorePercentage, `:91` updatedAt.

## Omissions

- **The list-row column-read site (`JobApplicationListContainer.tsx`) is uncited.** The map describes the fit indicator at `JobApplicationNavItem.tsx:26-29`, but NavItem only receives `summaryStatus: string|null` and `summaryScorePercentage: number|null` as scalar props (`JobApplicationNavItem.tsx:17-18`). The actual denormalized-column read off each infinite-list row happens in `JobApplicationListContainer.tsx`: `jobApplicationsForStage.map(...)` at `:220`, rendering `JobApplicationNavItem` at `:226` with `summaryStatus={jobApplication.aiJobApplicationSummaryStatus?.status}` (`:235`) and `summaryScorePercentage={jobApplication.aiJobApplicationSummaryStatus?.scorePercentage}` (`:236`). This is the list consumer that reads the status row's `status` and denormalized `score_percentage` columns; it should be cited as the F1 list reader alongside NavItem.

clean = false (one omission; all verdicts AGREE).

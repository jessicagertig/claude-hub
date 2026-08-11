# F1 — Frontend status consumers — Adversarial review (pass-5)

Slice F1: frontend consumers of `AiJobApplicationSummaryStatus`. Re-verified every candidate-map F1 statement against current code from scratch.

Candidate map: `/Users/jessica/claude-hub/inflow-ats/backend-mapping-audit-2026-06-17/backend-flow-map-2026-06-17.md`
Repo: `/Users/jessica/wrk/wrk-corp/inflow-ats`

## Files opened and traced

- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb`
- `app/serializers/api/v1/shallow_job_application_serializer.rb`
- `app/serializers/api/v1/job_application_serializer.rb`
- `app/controllers/api/v1/job_applications_controller.rb`
- `app/javascript/ats/src/views/jobApplications/JobApplicationListContainer.tsx`
- `app/javascript/ats/src/views/jobApplications/JobApplicationNavItem.tsx`
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx`
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx`
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx`
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx`
- `app/javascript/shared/lib/bulkAiSummaryCount.ts`
- `app/javascript/shared/queryHooks/useJobApplication.ts`
- `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts`
- `app/javascript/shared/types/jobApplication.ts`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- `app/models/ai_job_application_summary.rb`

## Verdicts (all AGREE)

1. **Serializer exposure (map line 206).** AGREE. `ai_job_application_summary_status_serializer.rb:4-6` attributes `id, ai_job_application_summary_id, status, score_percentage, headline, integrated_role_analysis, updated_at, published_at_timestamp`; `published_at_timestamp` method `object.updated_at.to_i` at `:8-10`. `shallow_job_application_serializer.rb:23-24` `has_one :ai_job_application_summary_status`. Preload `.includes(:ai_job_application_summary_status)` at `job_applications_controller.rb:27` and `:38`.

2. **List-row column-read site (map line 207).** AGREE. `JobApplicationListContainer.tsx:220` `jobApplicationsForStage.map(...)`; `:226` `<JobApplicationNavItem`; `:235` `summaryStatus={jobApplication.aiJobApplicationSummaryStatus?.status}`; `:236` `summaryScorePercentage={jobApplication.aiJobApplicationSummaryStatus?.scorePercentage}`. NavItem scalar props `summaryStatus?: string | null` / `summaryScorePercentage?: number | null` at `JobApplicationNavItem.tsx:17-18`.

3. **Harvey-ball render gate (map line 208).** AGREE. `JobApplicationNavItem.tsx:26-29`: `(summaryStatus === "current" || summaryStatus === "regenerating") && summaryScorePercentage != null ? fitBand(...).fill : null`.

4. **JobChannel handler (map line 209).** AGREE. `WebsocketJobChannelHandler.tsx:73-76` `ai_summary_status_change` → invalidates `["aiJobApplicationSummary", aiJobApplicationSummaryId]` (`:74`) + `["jobApplication", jobApplicationId]` (`:75`), NOT the list. `:77-81` `ai_summary_succeeded` → invalidates `["jobApplicationsForStage", hiringStageId]` (`:80`).

5. **GlobalChannel completion events refresh the list (map line 210).** AGREE. `WebsocketGlobalChannelHandler.tsx` (the `ats/src/websockets/` file): `AI_SUMMARY_COMPLETE` invalidate at `:227`, `AI_SUMMARY_FAILED` at `:241`, `AI_SUMMARY_BULK_FAILED` at `:253`, `AI_SUMMARY_BULK_COMPLETE` at `:281`, all `jobApplicationsForStage`. List key `["jobApplicationsForStage", Number(stageId), roleFit]` at `useJobApplication.ts:185` — prefix-matchable.

6. **bulkAiSummaryCount excludes `current` (map line 211).** AGREE. `bulkAiSummaryCount.ts:37-41` filters `aiJobApplicationSummaryStatus?.status === "current"`; subtracted at `:46` `selectionCount - loadedCurrentSelected`.

7. **TS interface 4-value union + untyped publishedAtTimestamp (map line 212).** AGREE. `jobApplication.ts:4` 4-value union; interface `:1-9` does NOT declare `publishedAtTimestamp`; `JobApplicationActivity.tsx:87` reads `summaryStatus.publishedAtTimestamp` (untyped runtime access).

8. **No optimistic-UI desync (map line 213).** AGREE. No `aiJobApplicationSummaryStatus` write via `setQueryData` anywhere in `app/javascript/shared/queryHooks/` (grep empty). `useJobApplication.ts:229` `setQueryData(["jobApplication", data.id], {...data})` runs in `onSuccess` (`:220`), full server data, not `onMutate`. The only three `onMutate` hooks are `useQuestion.ts:98`, `useJob.ts:162`, `useWebflow.ts:218` — none touch the status row.

9. **PlatoTab display fallbacks + no-fallback fetch key (map line 214).** AGREE. `PlatoTab.tsx:127` `summaryStatus?.headline || ""`; `:129` `summaryStatus?.scorePercentage || 0`. Fetch key `:46` `aiJobApplicationSummaryId: summaryStatus?.aiJobApplicationSummaryId` (no fallback); downstream gate `useAiJobApplicationSummary.ts:45` `enabled: aiJobApplicationSummaryId != undefined`.

10. **PlatoTab full status reader (map line 215).** AGREE on cited lines. `statusValue = summaryStatus?.status` at `:42`; used at `:50,:52,:151,:154,:210,:218`; `aiJobApplicationSummaryId` read at `:46`; `updatedAt` at `:130`. (See omission below — `:187` is an additional usage the enumeration misses.)

11. **JobApplicationActivity full reader (map line 216).** AGREE. `JobApplicationActivity.tsx:80-83` gates `platoReview` on status `current`/`regenerating`; `:87` `publishedAtTimestamp`, `:88` `headline`, `:89` `integratedRoleAnalysis` (→`roleFit`), `:90` `scorePercentage` (→`scorePct`), `:91` `updatedAt`.

12. **Part 9 §737 detail serializer has_one (map line 737).** AGREE. `job_application_serializer.rb:40-41` `has_one :ai_job_application_summary_status`. Show preload `job_applications_controller.rb:56`.

13. **regenerating broadcast desync note (map line 159).** AGREE. `find_or_create_ai_job_application_summary_status.rb:15` `update_columns(status: 'regenerating')`, `:16-20` broadcasts `ai_summary_status_change` with `{ jobApplicationId, aiJobApplicationSummaryId }`. FE handler `WebsocketJobChannelHandler.tsx:74-75` reads exactly those payload keys and invalidates only summary + job-application queries (NOT the list). Confirmed desync surface: NavItem renders the Harvey ball for `regenerating` + non-null score (`:26-29`), so a row flipped to `regenerating` with OLD denormalized score keeps rendering the stale score on the list until a list-refreshing event arrives. `BROADCAST_STATUSES` at `ai_job_application_summary.rb:23` omits `awaiting_job_criteria` + `retrying`; second `ai_summary_status_change` emitter `ai_job_application_summary.rb:107` (before_update, guarded `:102`).

## Display-only vs true desync (slice question)

- **No true FE-vs-DB desync from optimistic UI.** All status display is server-truth via query invalidation; no optimistic `setQueryData`/`onMutate` writes the status row (verdict 8).
- **Display-only desync surfaces (FE shows a value while DB differs until next refresh):**
  - **Stale list score during regenerate:** `ai_summary_status_change` (the `regenerating` flip) never invalidates `jobApplicationsForStage`; the list keeps the prior `score_percentage`/`status:current` render until a completion event (`ai_summary_succeeded` / GlobalChannel `AI_SUMMARY_*`) lands. (map line 159 — AGREE.)
  - **Fabricated `''`/`0` in PlatoTab detail card:** `PlatoTab.tsx:127,129` substitute `''`/`0` for null denormalized data (display-only fabrication, not a cache desync). (map line 214 — AGREE.)

## Omissions

- **PlatoTab `statusValue` usage at `:187` is omitted from the map line-215 enumeration.** `PlatoTab.tsx:187` `if ((!statusValue || statusValue === "none") && !jobApplication.hasResume)` reads `statusValue` (the status-row `status`) to branch the no-resume empty state. The map enumerates `statusValue` usages as "`:50,:52,:151,:154,:210,:218`" and `grep -n statusValue PlatoTab.tsx` returns `:42,:50,:52,:151,:154,:187,:210,:218` — `:187` is a genuine status-table read missing from the list.

## Conclusion

Every substantive F1 claim verifies against current code (13/13 AGREE). One enumeration omission (`PlatoTab.tsx:187`). clean = false solely due to that omission.

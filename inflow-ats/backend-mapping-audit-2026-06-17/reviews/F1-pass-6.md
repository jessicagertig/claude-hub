# F1 — Frontend status consumers — Adversarial Review (pass-6)

Slice: F1. Method: re-read candidate map's F1 statements, re-traced current code from scratch. Repo: `/Users/jessica/wrk/wrk-corp/inflow-ats`.

## Files opened and traced
- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb`
- `app/serializers/api/v1/shallow_job_application_serializer.rb`
- `app/serializers/api/v1/job_application_serializer.rb`
- `app/controllers/api/v1/job_applications_controller.rb` (preloads :27,:38,:56)
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx`
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx`
- `app/javascript/shared/websockets/WebsocketGlobalChannelHandler.tsx` (no AI handling — confirms ats version is correct)
- `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts`
- `app/javascript/shared/queryHooks/useJobApplication.ts`
- `app/javascript/shared/types/jobApplication.ts`
- `app/javascript/shared/lib/bulkAiSummaryCount.ts`
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx`
- `app/javascript/ats/src/views/jobApplications/JobApplicationListContainer.tsx`
- `app/javascript/ats/src/views/jobApplications/JobApplicationNavItem.tsx`
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx`
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoOverviewCallout.tsx` (OMITTED reader)
- `app/models/ai_job_application_summary.rb` (broadcast payloads, update_summary_status_record)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (regenerating broadcast)

## Verdicts — all AGREE

Every F1 statement in the candidate map verified against literal code. No DISPUTE.

- Serializer `AiJobApplicationSummaryStatusSerializer` attributes `:4-6`, `published_at_timestamp = object.updated_at.to_i` `:8-10`. AGREE.
- `has_one :ai_job_application_summary_status` in ShallowJobApplicationSerializer `:23-24`, JobApplicationSerializer `:40-41`. AGREE.
- Controller `.includes(:ai_job_application_summary_status)` at `job_applications_controller.rb:27,:38` (list) and `:56` (show). AGREE.
- `WebsocketJobChannelHandler.tsx`: `ai_summary_status_change` `:73-76` invalidates `aiJobApplicationSummary` (`:74`)+`jobApplication` (`:75`), NOT list; `ai_summary_succeeded` `:77-81` invalidates `['jobApplicationsForStage', hiringStageId]` (`:80`). AGREE. Broadcast payloads confirmed: `ai_job_application_summary.rb:96` `{ jobApplicationId, hiringStageId }`, `:107` `{ jobApplicationId, aiJobApplicationSummaryId: id }`.
- `WebsocketGlobalChannelHandler.tsx` (ats): `AI_SUMMARY_COMPLETE` `:227`, `AI_SUMMARY_FAILED` `:241`, `AI_SUMMARY_BULK_FAILED` `:253`, `AI_SUMMARY_BULK_COMPLETE` `:281` all invalidate `jobApplicationsForStage`. AGREE. List key `["jobApplicationsForStage", Number(stageId), roleFit]` `useJobApplication.ts:185` → prefix-matched by both the 2-element JobChannel key and the bare-string GlobalChannel invalidations. AGREE.
- `JobApplicationListContainer.tsx:220` map, `:226` NavItem, `:235` summaryStatus, `:236` summaryScorePercentage. AGREE.
- `JobApplicationNavItem.tsx:17-18` scalar props; Harvey ball `:26-29` gated on `(current||regenerating) && scorePercentage != null`. AGREE.
- `PlatoTab.tsx`: `statusValue` read `:42`; `grep -n statusValue` returns EXACTLY `:42,:50,:52,:151,:154,:187,:210,:218` (map's list verified); fetch key `:46` `summaryStatus?.aiJobApplicationSummaryId` (no fallback); display fallbacks `:127` `headline || ""`, `:129` `scorePercentage || 0`; `:130` `updatedAt`; `:187` no-resume gate. AGREE.
- `useAiJobApplicationSummary.ts:45` `enabled: aiJobApplicationSummaryId != undefined`. AGREE.
- `JobApplicationActivity.tsx`: status `:79`, gate current/regenerating `:80-83`, publishedAtTimestamp `:87`, headline `:88`, integratedRoleAnalysis `:89`, scorePercentage `:90`, updatedAt `:91`. AGREE.
- `jobApplication.ts:4` 4-value status union; `publishedAtTimestamp` NOT on the interface `:1-9` → untyped read at Activity `:87`. AGREE.
- `bulkAiSummaryCount.ts:37-41` filters `status === "current"`, subtracts at `:46`. AGREE.
- No optimistic-UI desync: only `onMutate` hooks are useQuestion/useJob/useWebflow (none touch the status table); `useJobApplication.ts:229` `setQueryData` runs in `onSuccess` (`:220`) with full server `data`. AGREE.
- `find_or_create_ai_job_application_summary_status.rb:16-20` `regenerating` broadcasts `ai_summary_status_change` (list-ignored) → list keeps showing stale denormalized score. AGREE.
- `update_summary_status_record` `ai_job_application_summary.rb:69` guard (no stale guard), `:74-80` writes current+denormalized cols, `:93-97` broadcasts `ai_summary_succeeded`. AGREE (desync #7 valid).

## Omissions

### O1 (real omission) — `PlatoOverviewCallout.tsx` is a status-table reader the map's "Every reader" list omits
`app/javascript/ats/src/views/jobApplications/Plato/PlatoOverviewCallout.tsx` consumes the status enum: prop `summaryStatusValue?: "none" | "initial_summary_pending" | "current" | "regenerating" | null` (`:13`), and `deriveCalloutStatus` (`:40-47`) branches on `current`/`regenerating` (`:41-42` → null/hidden), `initial_summary_pending` (`:43` → "generating"), `none`/null (`:44-45` → "ask"/"noResume" by `hasResume`). The map's Part 9 "Every reader" (lines 769-772) and the F1 changelog (lines 234-243) list only JobApplicationListContainer, PlatoTab, JobApplicationActivity, bulkAiSummaryCount — `PlatoOverviewCallout` is absent.

IMPORTANT QUALIFIER: `PlatoOverviewCallout` has ZERO importers/callers (`grep -rn "PlatoOverviewCallout" app/javascript/` returns only its own definition file; `grep -rn "summaryStatusValue"` outside the file returns nothing). It is a defined+exported but currently-UNWIRED component — it reads the status enum by interface but does not render anywhere today, so it produces no live display and no desync. The map elsewhere documents dead code explicitly (e.g. `CloneJobApplication` "DEAD CODE: zero callers"); by that standard this status-shaped-but-dead reader should be listed as "present but unwired (zero callers)" rather than silently omitted.

Suggested map text: "**Frontend (detail — PlatoOverviewCallout, UNWIRED):** `PlatoOverviewCallout.tsx` types its prop `summaryStatusValue` as the 4-value status union (`:13`) and `deriveCalloutStatus` (`:40-47`) branches the callout on `current`/`regenerating`/`initial_summary_pending`/`none`. It is a status-enum reader by interface but has ZERO callers (`grep -rn PlatoOverviewCallout` returns only its own file) — defined+exported, not rendered anywhere, no live display, no desync. Listed for completeness as a dead status reader."

## clean
false (one omission: O1). All explicit map statements about F1 are AGREE; the single defect is an omitted (dead) status-enum reader.

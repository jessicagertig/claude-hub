# F1 Adversarial Review — Pass 7 (Frontend status consumers)

Re-audited the candidate map (`backend-flow-map-2026-06-17.md`) F1 statements against current code from scratch. Files opened and traced:

- `app/serializers/api/v1/shallow_job_application_serializer.rb`
- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb`
- `app/controllers/api/v1/job_applications_controller.rb:20-64`
- `app/javascript/ats/src/views/jobApplications/JobApplicationListContainer.tsx:215-244`
- `app/javascript/ats/src/views/jobApplications/JobApplicationNavItem.tsx:1-45`
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx:60-89`
- `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:205-294`
- `app/javascript/shared/queryHooks/useJobApplication.ts:175-237`
- `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts`
- `app/javascript/shared/lib/bulkAiSummaryCount.ts`
- `app/javascript/shared/types/jobApplication.ts`
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx:75-99`
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx:38-231`
- `app/javascript/ats/src/views/jobApplications/Plato/PlatoOverviewCallout.tsx`
- `app/javascript/ats/src/views/jobApplications/PlatoOverviewCallout.tsx` (0 bytes — empty)
- `app/models/ai_job_application_summary.rb:60-109`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb`

## Verdicts

All F1 map statements AGREE. Every claim verified against the literal line cited.

1. (map L256) ShallowJobApplicationSerializer has_one + serializer attributes — AGREE. `shallow_job_application_serializer.rb:23-24`; `ai_job_application_summary_status_serializer.rb:4-6` (attrs), `:8-10` (`published_at_timestamp = object.updated_at.to_i`); `.includes` at controller `:27,:38`. (Minor imprecision: map writes attribute span as `:4-10`; actual attributes `:4-6`, method `:8-10`. Not load-bearing — every named attribute present.)
2. (L257) List-row column read — AGREE. `JobApplicationListContainer.tsx:220,226,235,236`; NavItem scalar props `:17-18`.
3. (L258) Harvey ball only for current/regenerating + scorePercentage != null — AGREE. `JobApplicationNavItem.tsx:26-29`.
4. (L259) JobChannel events — AGREE. `WebsocketJobChannelHandler.tsx:73-76` (status_change → summary + jobApplication, not list); `:77-81` (succeeded → jobApplicationsForStage).
5. (L260) GlobalChannel completion events refresh list — AGREE. `WebsocketGlobalChannelHandler.tsx:227,241,253,281` (case labels at `:212,:232,:246,:259`).
6. (L260 / list key) — AGREE. `useJobApplication.ts:185` `["jobApplicationsForStage", Number(stageId), roleFit]`.
7. (L261) bulkAiSummaryCount excludes current — AGREE. `bulkAiSummaryCount.ts:37-41`, subtracted `:46`.
8. (L262) TS union 4-value; publishedAtTimestamp serialized but not on TS interface — AGREE. `jobApplication.ts:4` (union), `:1-9` (no publishedAtTimestamp); serializer `:6`; read at `JobApplicationActivity.tsx:87`.
9. (L263) No optimistic-UI desync in `shared/queryHooks/` — AGREE. grep of `shared/queryHooks/`: the only `onMutate` optimistic hooks are useQuestion/useJob/useWebflow (none touch aiJobApplicationSummaryStatus); `useJobApplication.ts:229` setQueryData is inside `onSuccess` with server data; `useAiJobApplicationSummary.ts` generate mutation only invalidates `:18-22`.
10. (L264) Display-only fallbacks — AGREE. `PlatoTab.tsx:127` `headline || ""`, `:129` `scorePercentage || 0`; fetch key `:46` no fallback; `useAiJobApplicationSummary.ts:45` `enabled: aiJobApplicationSummaryId != undefined`.
11. (Part 9 L793) NavItem render gate — AGREE. as #2/#3.
12. (Part 9 L794) PlatoTab status reads — AGREE. `PlatoTab.tsx:42` (statusValue), `:46` (fetch key), `:50,:52,:151,:154,:187,:210,:218`, `:127,:129,:130`.
13. (Part 9 L795) JobApplicationActivity denormalized consumer — AGREE. `JobApplicationActivity.tsx:80-83,87,88,89,90,91`.
14. (Part 9 L796) PlatoOverviewCallout UNWIRED — AGREE. `Plato/PlatoOverviewCallout.tsx:13,40-47`; grep shows ZERO external callers (only self-references). Top-level `PlatoOverviewCallout.tsx` is a 0-byte empty file.
15. (Part 9 L797/L261) bulk exclusion — AGREE.
16. (Part 9 L798/L799) Websocket invalidation map — AGREE. Backend broadcasts confirmed: `ai_job_application_summary.rb:93-97` (ai_summary_succeeded payload jobApplicationId+hiringStageId), `:107` (ai_summary_status_change payload jobApplicationId+aiJobApplicationSummaryId), `find_or_create_ai_job_application_summary_status.rb:16-20` (regenerating → ai_summary_status_change). These match FE handler payload reads.

## True F1 data-desync surface (captured by map; corroborated)

The genuine FE-vs-DB divergence for F1 is a DATA desync, not optimistic-UI:
- `regenerating` flip (`find_or_create_ai_job_application_summary_status.rb:15` `update_columns(status:'regenerating')`, denormalized columns NOT cleared) broadcasts `ai_summary_status_change` (`:16-20`).
- FE handler for `ai_summary_status_change` (`WebsocketJobChannelHandler.tsx:73-76`) invalidates only `aiJobApplicationSummary` + `jobApplication`, NOT `jobApplicationsForStage`.
- Therefore the infinite list keeps rendering the STALE denormalized `score_percentage` and old `status` until a later `ai_summary_succeeded` (`ai_job_application_summary.rb:93-97`) or a GlobalChannel AI completion event invalidates the list.
- Map captures this at L193, L259, L807, L783. AGREE.

The map's L263 "no optimistic display-only desync" is a correct, narrower claim about `setQueryData`/`onMutate` and is not contradicted by the data-desync above.

## Omissions

None material to F1. (Two cosmetic notes, not omissions requiring map change: the serializer attribute span is `:4-6` not `:4-10`; the empty 0-byte top-level `PlatoOverviewCallout.tsx` duplicate exists alongside the real `Plato/` one — the map already names the correct `Plato/` path.)

## clean = false

Because verdict #1 carries a minor `file:line` range imprecision (`:4-10` vs `:4-6`). All substantive claims AGREE.

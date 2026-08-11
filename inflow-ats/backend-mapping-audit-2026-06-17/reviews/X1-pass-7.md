# X1 Adversarial Review — AiJobApplicationSummaryStatus (pass-7)

Re-traced from scratch against current code. Slice X1 = AiJobApplicationSummaryStatus table, whole codebase: every read, every write, full state-transition table, desync windows.

## Method
Read the model, all three writers, the wrapper, schema, all serializers, controller preloads, bulk reader, recurring rake reader, and all 8 frontend consumers. Census of every class-level and association-level reference in app/ + lib/.

## WRITE-SITE CENSUS (exhaustive — only 3 writers exist)
- `find_or_create_ai_job_application_summary_status.rb:15` — `update_columns(status: 'regenerating')` (status only; denormalized cols NOT cleared)
- `find_or_create_ai_job_application_summary_status.rb:25-37` — `build_ai_job_application_summary_status` then `:29` status='current' (+ denormalized copy `:30-32`, stale-guarded `:27`) OR `:34` status='none'; `:37` save / `:38` fail
- `textract_result.rb:104-107` — `update_columns(ai_job_application_summary_id:, status: 'initial_summary_pending')` (guard `:101-102`: row+latest exist, only from none/initial_summary_pending)
- `ai_job_application_summary.rb:74-80` — `.update(ai_job_application_summary_id:, status:'current', score_percentage:, headline:, integrated_role_analysis:)` (guard `:69` saved_change_to_status? && status_succeeded?)

Verified by `grep` for `build_/update/update_columns/save/create/destroy` on the model and association across app/ + lib/. No other writer exists. The map's X0 census line (`:820`) names exactly these three. AGREE.

## READ-SITE CENSUS
- Serializer `Api::V1::AiJobApplicationSummaryStatusSerializer:4-10` (id, ai_job_application_summary_id, status, score_percentage, headline, integrated_role_analysis, updated_at, published_at_timestamp=updated_at.to_i)
- Embedded `has_one` in `ShallowJobApplicationSerializer:23-24` and `JobApplicationSerializer:40-41`
- Controller preloads `job_applications_controller.rb:27,38` (index/list) and `:56` (show)
- Bulk: `queue_bulk_ai_summary_jobs.rb:36-40` (status: :current drop)
- counter_culture proc `ai_job_application_summary_status.rb:7` (rolls current+regenerating into jobs.ai_job_application_summaries_count)
- Maintenance: `recurring_tasks.rake:79` counter_culture_fix_counts
- Scopes: `job_application.rb:106-108` fit_bands, `:110-112` unscored
- FE list: `JobApplicationListContainer.tsx:221-236`, `JobApplicationNavItem.tsx:17-18,26-29`
- FE detail: `PlatoTab.tsx:41-42,46,127,129-130,50,52,151,154,187,210,218`
- FE activity: `JobApplicationActivity.tsx:79-91`
- FE unwired: `PlatoOverviewCallout.tsx:13,40-47` (ZERO importers — confirmed by grep)
- FE bulk: `bulkAiSummaryCount.ts:37-41`
- WS JobChannel: `WebsocketJobChannelHandler.tsx:73-75` (ai_summary_status_change → aiJobApplicationSummary + jobApplication, NOT list), `:77-80` (ai_summary_succeeded → jobApplicationsForStage)
- No optimistic desync: `useJobApplication.ts:219/229` setQueryData in onSuccess (not onMutate); `useAiJobApplicationSummary.ts:45` enabled gate

All map read-site claims verified accurate at the cited lines.

## STATE-TRANSITION TABLE (verified)
| To | Writer | Precondition | Resting? | Advancer out |
|---|---|---|---|---|
| none (create) | find_or_create:34,37 | no current non-stale succeeded summary at create | yes | set_initial_summary_pending / FindOrCreate-regenerating |
| current (create) | find_or_create:29 | latest summary succeeded && !stale at create (`:27`) | yes | FindOrCreate→regenerating on new gen |
| none→initial_summary_pending | textract_result.rb:104 | status_result+latest exist (`:101`); only from none/initial (`:102`) | no | update_summary_status_record→current |
| (succeeded-pointer)→regenerating | find_or_create:15 | row's denormalized summary `status_succeeded?` (`:14`) | no (unless stuck) | update_summary_status_record→current |
| initial/regenerating→current | ai_job_application_summary.rb:74 | summary saved_change_to_status? && status_succeeded? (`:69`) | yes | new gen→regenerating |

No `failed` enum value exists → failed/retrying summary leaves row stuck. CONFIRMED.

## DESYNC WINDOWS (all 8 verified)
1. Pipeline in-flight (initial_summary_pending) vs live summary — CONFIRMED
2. failed/retrying summary leaves row stuck (`:69` returns, no failed value) — CONFIRMED
3. regenerating keeps OLD denormalized data (`:15` status-only) — CONFIRMED
4. T2/D stuck regenerating (Orchestrate `:15-16,:46-48` reuses stale-succeeded, never re-succeeds); no credit (`textract_result.rb:77/82` self.ai_job_application_summaries empty) — CONFIRMED
5. list ignores ai_summary_status_change, refreshed only by terminal events — CONFIRMED
6. no row at all → serializer null — CONFIRMED
7. current pointing at stale summary (`:74` no stale guard, unlike create-path `:27`) — CONFIRMED
8. counter_culture bypass on update_columns writers; backing column present (schema:907) — CONFIRMED

## DISPUTES
None of substance. All map statements verified against literal code.

## OMISSIONS
1. `AiJobApplicationSummary` declares `has_one :ai_job_application_summary_status` (`ai_job_application_summary.rb:8`). The Part 9 data-model/association section lists JobApplication's `has_one` and the row's two `belongs_to`, but omits the reverse `has_one` on the summary model. Not load-bearing (the model reaches the row via `job_application.ai_job_application_summary_status` at `:71`, never via `self`), but it is an existing association on the slice's record graph and absent from the map's association list.

## clean = false (one omission)

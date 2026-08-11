# X1 — AiJobApplicationSummaryStatus table, whole-codebase

**Pass 1 — 2026-06-22**

## Files traced (chain)

Backend:
- `app/models/ai_job_application_summary_status.rb` (model, enum, counter_culture, scopes, validation)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (creates row; sets `current`/`none`; flips to `regenerating`)
- `db/migrate/20260611120001_create_ai_job_application_summary_statuses.rb` (table/columns/indexes)
- `app/models/ai_job_application_summary.rb:57-98` (`update_summary_status_record` → writes `status:'current'` + denorm cols)
- `app/models/textract_result.rb:61-108` (`generate_ai_summary_with_credit_flow` → `find_or_create...` + `set_initial_summary_pending`)
- `app/models/job_application.rb:32,107-112,160-162,170` (assoc, scopes `fit_bands`/`unscored`, `find_or_create...`)
- `app/serializers/api/v1/ai_job_application_summary_status_serializer.rb`
- `app/serializers/api/v1/shallow_job_application_serializer.rb:23-24`
- `app/serializers/api/v1/job_application_serializer.rb:40-41`
- `app/controllers/api/v1/job_applications_controller.rb:27,38,56` (eager-load `.includes(:ai_job_application_summary_status)`)
- `app/interactors/queue_bulk_ai_summary_jobs.rb:36-40` (reads `status: :current` to drop already-summarized)
- `db/data/20260622182505_add_counter_culture_fix_for_ai_job_application_summaries.rb`
- `db/schema.rb:903` (`jobs.ai_job_application_summaries_count` counter cache target)

Frontend (infinite-loaded list + detail consumers):
- `app/javascript/shared/types/jobApplication.ts:1-22` (TS interface)
- `app/javascript/shared/lib/bulkAiSummaryCount.ts:40` (reads `status === "current"`)
- `app/javascript/ats/src/views/jobApplications/JobApplicationListContainer.tsx:235-236` (reads `status`, `scorePercentage`)
- `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx:41-53` (reads `status`, `aiJobApplicationSummaryId`)
- `app/javascript/ats/src/views/jobApplications/JobApplicationActivity.tsx:79-89` (reads `status`, `publishedAtTimestamp`, `headline`, `integratedRoleAnalysis`)
- `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx:73-81` (handles `ai_summary_status_change`, `ai_summary_succeeded` → invalidate queries)

---

## HEADLINE: the map's entire AiJobApplicationSummaryStatus section is WRONG

The map (lines 504-521, 605, 638-651, Gap 7) describes a **completely different schema and behavior** than the current code:

| Map says | Code says |
|---|---|
| enum `{pending..failed}` (10 values mirroring summary) | enum `{none:0, initial_summary_pending:1, current:2, regenerating:3}` |
| boolean column `regenerating` (default false, not null) | **No such column.** `regenerating` is an ENUM VALUE of `status`. |
| `regenerating` "never set to true (broken)" | `status:'regenerating'` IS set, in `FindOrCreateAiJobApplicationSummaryStatus:15` |
| created via `AiJobApplicationSummary after_commit :create_status_record` | That callback **does not exist**. Row created by `FindOrCreateAiJobApplicationSummaryStatus` interactor. |
| `update_summary_status_record` uses `update_columns`, sets `status: integer 7`, `regenerating: false` | uses `.update` (not update_columns), sets `status:'current'`, no `regenerating` field |
| status enum values = summary's pipeline statuses | status = display-lifecycle states (none → pending → current ⇄ regenerating) |

The status-record refactor described in Gap 7 ("create_status_record callback is misplaced... should be refactored") **has already happened.** The map is pre-refactor.

---

## Schema (current, verified)

`db/migrate/20260611120001_create_ai_job_application_summary_statuses.rb` +
`app/models/ai_job_application_summary_status.rb`:

Columns: `job_application_id` (not null, FK, unique idx `idx_ai_summary_statuses_on_job_application_id`), `ai_job_application_summary_id` (nullable, FK, `optional: true`), `status` (integer, not null, default 0), `score_percentage` (decimal), `headline` (string), `integrated_role_analysis` (text), timestamps.

Enum (`_prefix: true`): `none:0, initial_summary_pending:1, current:2, regenerating:3`. Methods: `status_none?`, `status_initial_summary_pending?`, `status_current?`, `status_regenerating?`.

Validation: `validates :job_application_id, uniqueness: true` (line 16).

counter_culture (line 7): rolls a count up the `[:job_application, :job]` path into `jobs.ai_job_application_summaries_count` (schema.rb:903), counting status rows where status IN (2,3) i.e. `current` or `regenerating`.

Scopes (lines 20-24): `poor / weak / mixed / good / excellent` by `score_percentage` band (mirror frontend FIT_BANDS). Used by `JobApplication.fit_bands` (job_application.rb:106-109).

---

## COMPLETE STATE-TRANSITION TABLE for `status`

### Value: `none` (0) — resting; advanced out by the AI pipeline entry

WRITE A (create-as-none): `FindOrCreateAiJobApplicationSummaryStatus:34`
`@status_record.status = 'none'` then `:37 @status_record.save`.
Precondition: no status row exists yet AND latest summary is NOT (succeeded && non-stale) — i.e. line 27 false.
Reached by any caller of `JobApplication#find_or_create_ai_job_application_summary_status` (job_application.rb:160-161): `enqueue_new_job_application` (job_application.rb:170, on every new job_application create) and `generate_ai_summary_with_credit_flow` (textract_result.rb:70).
Advances out → `initial_summary_pending` (set_initial_summary_pending) when a pipeline run begins; or directly → `current` (update_summary_status_record) if a summary succeeds while still `none`.

### Value: `initial_summary_pending` (1) — transient; advanced out by summary success

WRITE B: `TextractResult#set_initial_summary_pending` (textract_result.rb:104-107)
```
status_record.update_columns(
  ai_job_application_summary_id: latest_summary.id,
  status: 'initial_summary_pending'
)
```
Precondition (textract_result.rb:101-102): `status_record && latest_summary` present AND `status_record.status_none? || status_record.status_initial_summary_pending?`. Called from `generate_ai_summary_with_credit_flow:72` only when `status_result.success?`. Guarded upstream by `:68 return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`.
This is the "first review being generated" state (no prior succeeded review, or prior is stale).
Advances out → `current` via update_summary_status_record on summary success. NOT a dead end during normal flow, but see DESYNC: if the summary fails, nothing writes the status row back; it sits at `initial_summary_pending` indefinitely.

### Value: `current` (2) — resting; the displayable "has a finished review" state

WRITE C (create-as-current): `FindOrCreateAiJobApplicationSummaryStatus:28-32`
```
@status_record.ai_job_application_summary = latest_ai_job_application_summary
@status_record.status = 'current'
@status_record.score_percentage = latest.score_percentage
@status_record.headline = latest.headline
@status_record.integrated_role_analysis = latest.integrated_role_analysis
```
Precondition (line 27): row does NOT yet exist AND `latest_ai_job_application_summary&.status_succeeded? && !latest.stale?`. (Back-fill case: status row created for a job_application that already has a finished review.)

WRITE D (transition-to-current on success): `AiJobApplicationSummary#update_summary_status_record` (ai_job_application_summary.rb:74-80)
```
ai_job_application_summary_status.update(
  ai_job_application_summary_id: id,
  status: 'current',
  score_percentage: score_percentage,
  headline: headline,
  integrated_role_analysis: integrated_role_analysis
)
```
Precondition (line 69): `saved_change_to_status? && status_succeeded?` — i.e. THIS summary just transitioned to `succeeded` on `:update`. Guard line 72: `return unless ai_job_application_summary_status` (silently no-ops if no row). Uses `.update` (runs validations/callbacks), NOT update_columns. Fires `JobChannel ai_summary_succeeded` broadcast (ai_job_application_summary.rb:93-97) → frontend invalidates `jobApplicationsForStage`.
Reachable from any path where a summary reaches `succeeded` (manual/auto/bulk; the `succeeded` transition happens in `IntegrateAnalysis#integrate` per X-other-slices).
`current` is resting. Advances out → `regenerating` only via WRITE E.

### Value: `regenerating` (3) — resting-with-old-review-visible; advanced out by new summary success

WRITE E: `FindOrCreateAiJobApplicationSummaryStatus:15`
`@status_record.update_columns(status: 'regenerating')`
Precondition (lines 11-14): status row EXISTS AND its associated `ai_job_application_summary&.status_succeeded?` (the row points at a succeeded summary). Then also broadcasts `JobChannel ai_summary_status_change` (lines 16-20).
This is the "a finished review exists and we're generating a replacement" state — i.e. THE map's Gap 7 `regenerating:true` intent, IMPLEMENTED, just as a status enum value rather than a boolean.
Note: denormalized cols (`score_percentage`, `headline`, `integrated_role_analysis`, `ai_job_application_summary_id`) are NOT cleared — old review data stays visible while regenerating (frontend `hasContent = status==='current' || status==='regenerating'`, PlatoTab.tsx:52; JobApplicationActivity.tsx:81-83 treats both as "reviewed").
Advances out → `current` via WRITE D when the new summary succeeds.

### Transition graph
```
(no row) ──FindOrCreate──> none           [latest summary not succeeded/non-stale]
(no row) ──FindOrCreate──> current         [latest summary succeeded & non-stale]  (WRITE C)
none ──set_initial_summary_pending──> initial_summary_pending  (WRITE B)
initial_summary_pending ──(self, re-entrant)──> initial_summary_pending (WRITE B guard allows)
none / initial_summary_pending ──summary succeeds──> current  (WRITE D)
current ──FindOrCreate (row exists, summary succeeded)──> regenerating  (WRITE E)
regenerating ──new summary succeeds──> current  (WRITE D)
```

There is NO writer that sets the row back to `none` or to `failed` after a pipeline failure. (No `failed` value exists in this enum at all.)

---

## DESYNC WINDOWS (row disagrees with latest non-stale AiJobApplicationSummary)

1. **Summary fails after `initial_summary_pending`/`regenerating`** — no writer moves the status row off `initial_summary_pending` or `regenerating` on failure. Only `update_summary_status_record` writes the row, and it fires ONLY on `status_succeeded?` (ai_job_application_summary.rb:69). A failed summary leaves the row stuck pointing at a non-succeeded `ai_job_application_summary_id`. Frontend keeps showing "regenerating"/loading (PlatoTab.tsx:50-52 relies on `fullSummaryStatus === "failed"` from the SEPARATE full-summary fetch to settle, not on the status row). Status row is now out of sync with reality (no current review, but row says current/regenerating with old denorm data).

2. **`regenerating` keeps stale denorm columns** — `score_percentage/headline/integrated_role_analysis/ai_job_application_summary_id` are NOT cleared on WRITE E. During regeneration the list/activity show the OLD review's score & headline (by design, but the row disagrees with "latest summary is mid-pipeline").

3. **`update_summary_status_record` uses `.update` and can fail silently** — if validation/save fails it only logs (ai_job_application_summary.rb:82-85) and returns; the row stays in its prior state (e.g. `regenerating`) while a newer succeeded summary exists. Desync until the next successful write.

4. **Denorm vs. `latest_ai_job_application_summary` ordering mismatch** — `update_summary_status_record` writes `ai_job_application_summary_id: id` (the summary that just succeeded), but `latest_ai_job_application_summary` is `order(created_at: :desc).first` (job_application.rb:31). If a NEWER summary row exists (created later) but an OLDER one reaches `succeeded` last, the status row points at the older one — disagreeing with `latest_*`.

5. **No status row at all** — `update_summary_status_record` guards `return unless ai_job_application_summary_status` (ai_job_application_summary.rb:72). If a summary succeeds on a job_application whose status row was never created (e.g. flows that never call `find_or_create...`), the denorm row is simply absent; serializer emits `null` and the list shows no fit indicator despite a real succeeded summary.

---

## DELETE / LIFECYCLE

No explicit destroy of `AiJobApplicationSummaryStatus` anywhere. It is destroyed only via `dependent: :destroy`? — checked: `job_application.rb:32 has_one :ai_job_application_summary_status` has NO `dependent:` option, so it is NOT auto-destroyed with the job_application (likely relies on FK). `ai_job_application_summary` association is `optional: true` and not dependent. The row persists across summary create/destroy churn — consistent with "one row per job_application, summaries come and go."

---

## READ SITES (full)

Backend:
- `job_application.rb:107-109` `fit_bands` scope — `left_joins` + merges band scopes (reads `score_percentage`).
- `job_application.rb:111-112` `unscored` scope — `where(ai_job_application_summary_statuses: {score_percentage: nil})`.
- `queue_bulk_ai_summary_jobs.rb:36-38` — `.where(status: :current).pluck(:job_application_id)` to drop already-summarized candidates from bulk run.
- `textract_result.rb:99-102` reads `status_result.ai_job_application_summary_status` then `.status_none?/.status_initial_summary_pending?`.
- `find_or_create...:9,12,14,23,27` reads existing row + associated summary status.
- counter_culture proc (model:7) reads `status_current?/status_regenerating?`.

Serializers (all via `AiJobApplicationSummaryStatusSerializer`): `id, ai_job_application_summary_id, status, score_percentage, headline, integrated_role_analysis, updated_at, published_at_timestamp(=updated_at.to_i)`. Embedded by `ShallowJobApplicationSerializer:23` (the infinite list) and `JobApplicationSerializer:40` (detail). Controller eager-loads at `job_applications_controller.rb:27,38,56`.

Frontend (what the infinite list reads): `JobApplicationListContainer.tsx:235-236` reads `.status` + `.scorePercentage`; `bulkAiSummaryCount.ts:40` reads `.status==="current"`; `PlatoTab.tsx:41-53` reads `.status` + `.aiJobApplicationSummaryId`; `JobApplicationActivity.tsx:79-89` reads `.status/.publishedAtTimestamp/.headline/.integratedRoleAnalysis`. WS handler invalidates list/summary queries on `ai_summary_status_change` and `ai_summary_succeeded`.

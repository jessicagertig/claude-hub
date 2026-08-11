# Slice X2 — Setter/Clearer Focus for AiJobApplicationSummaryStatus

**Angle:** X2 — every writer of the `AiJobApplicationSummaryStatus` row, every caller, the exact precondition each fires under, and `.update` vs `update_columns` callback implications.

## Files traced (chain)

- `app/models/ai_job_application_summary.rb:8,29,30,57-98` (status model assoc + `update_summary_status_record`)
- `app/models/ai_job_application_summary_status.rb:1-30` (enum, counter_culture, validation)
- `app/interactors/find_or_create_ai_job_application_summary_status.rb:1-47`
- `app/models/job_application.rb:31,32,45,160-171` (`enqueue_new_job_application` -> `find_or_create_ai_job_application_summary_status`; `latest_ai_job_application_summary`; `ai_job_application_summary_status` assoc)
- `app/models/textract_result.rb:61-89,98-108` (`generate_ai_summary_with_credit_flow` -> `find_or_create_...` + `set_initial_summary_pending`)
- `db/schema.rb:169-180` (table columns + unique index)
- `app/interactors/queue_bulk_ai_summary_jobs.rb:32-37` (reads `status: :current`)
- `app/controllers/api_public/v1/hire/job_resume_exports_controller.rb:42` (unrelated `status:'none'` JSON field — NOT a status-row write)

## The status record's enum/columns are NOT what the map says

`AiJobApplicationSummaryStatus` enum (`ai_job_application_summary_status.rb:9-14`):
```ruby
enum status: { none: 0, initial_summary_pending: 1, current: 2, regenerating: 3 }, _prefix: true
```
Map lines 509-512 claim the enum is `pending(0)...failed(9)` (a copy of the summary enum) and line 513 claims a boolean column `regenerating (default false, not null)`. **MAP-WRONG.** Schema (`db/schema.rb:169-180`) has NO `regenerating` boolean column. `regenerating` is now an ENUM VALUE (status=3), not a column. Columns are: `job_application_id`, `ai_job_application_summary_id`, `status (int default 0)`, `score_percentage`, `headline`, `integrated_role_analysis`, timestamps. Unique index on `job_application_id`.

There is also a `counter_culture [:job_application, :job]` (`ai_job_application_summary_status.rb:7`) that increments `job.ai_job_application_summaries_count` only when status is `current(2)` or `regenerating(3)`. ABSENT from map — NEW.

## The four real writers

### Writer 1 — FindOrCreateAiJobApplicationSummaryStatus (create/regenerating branch)
`find_or_create_ai_job_application_summary_status.rb:11-40`. Single caller: `JobApplication#find_or_create_ai_job_application_summary_status` (`job_application.rb:160-162`), itself called from two sites:
- `enqueue_new_job_application` (`job_application.rb:170`), fired by `after_commit :enqueue_new_job_application, on: [:create]` (`job_application.rb:45`) — every new job_application.
- `TextractResult#generate_ai_summary_with_credit_flow` (`textract_result.rb:70`) — every pipeline run that reaches that line.

Branches inside the interactor:
- **Record already exists** (`:11`): if its associated summary `status_succeeded?` (`:14`), do `@status_record.update_columns(status: 'regenerating')` (`:15`) then `JobChannel.broadcast_to(... event:'ai_summary_status_change' ...)` (`:16-20`). If the summary is not succeeded (or nil), the existing row is left untouched. **`update_columns` -> skips validations, model callbacks AND counter_culture.** Since `current(2)`->`regenerating(3)` are both counted buckets, the counter stays correct here by coincidence (both counted), but the skip is real.
- **No record exists** (`:22`): `build_ai_job_application_summary_status` (`:25`). If `latest_ai_job_application_summary&.status_succeeded? && !stale?` (`:27`) -> seed row with `status='current'` + denormalized `ai_job_application_summary_id/score_percentage/headline/integrated_role_analysis` from that summary (`:28-32`). Else `status='none'` (`:34`). Then `@status_record.save` (`:37`); on failure `context.fail!`. **`.save` -> FIRES counter_culture** (and any model callbacks; the model has none beyond counter_culture). Creating directly as `current` increments the job counter.
- `rescue ActiveRecord::RecordNotUnique` (`:43-44`) reloads and returns the existing row (race on the unique index).

ABSENT from map entirely (interactor did not exist when map written). VERDICT: NEW.

### Writer 2 — TextractResult#set_initial_summary_pending
`textract_result.rb:98-108`. Sole caller: `generate_ai_summary_with_credit_flow` (`textract_result.rb:72`) — `set_initial_summary_pending(status_result) if status_result.success?`, i.e. only after Writer 1 ran successfully on this same call.
Preconditions (`:101-102`): `status_record && latest_summary` present AND status is `none` OR `initial_summary_pending`. If the row is already `current` or `regenerating`, this is a no-op (the guard at `:102` blocks it).
Write (`:104-107`): `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')`. **`update_columns` -> skips validations/callbacks/counter_culture.** `none(0)`->`initial_summary_pending(1)` are both uncounted buckets, so the counter is unaffected and stays correct. ABSENT from map — NEW.

### Writer 3 — AiJobApplicationSummary#update_summary_status_record
`ai_job_application_summary.rb:57-98`, fired by `after_commit :update_summary_status_record, on: :update` (`:30`). Precondition `:69`: `return unless saved_change_to_status? && status_succeeded?` — only when a summary's own status transitions TO `succeeded` on an update. Then loads `job_application.ai_job_application_summary_status` (`:71`) and `return unless` present (`:72`) — silent no-op if no status row exists.
Write (`:74-80`):
```ruby
ai_job_application_summary_status.update(
  ai_job_application_summary_id: id,
  status: 'current',
  score_percentage: score_percentage,
  headline: headline,
  integrated_role_analysis: integrated_role_analysis)
```
**Uses `.update` (NOT `update_columns`) -> FIRES validations, model callbacks AND counter_culture.** Followed by `JobChannel.broadcast_to(... event:'ai_summary_succeeded' ...)` (`:93-97`).

Map (lines 502, 605) says this writer (a) uses `update_columns`, (b) sets `regenerating: false`, (c) sets `status` to the integer `succeeded` (7). **MAP-WRONG on all three:** current code uses `.update`, does NOT touch `regenerating` (no such column), and sets `status: 'current'` (enum 2). It DOES set `ai_job_application_summary_id`, `score_percentage`, `headline`, `integrated_role_analysis` (those match the map). The `ai_summary_succeeded` JobChannel broadcast at `:93-97` is NEW (ABSENT from map). VERDICT: CHANGED.

Note: method body `:58-67` contains `ap` debug logging (left in deliberately per the model comment style) — no behavior, but present.

### Writer 4 — create_status_record (REMOVED)
Map line 500-502 lists `after_commit :create_status_record, on: :create` on `AiJobApplicationSummary` doing `AiJobApplicationSummaryStatus.find_or_create_by(...)`. **No such callback exists** in `ai_job_application_summary.rb` today (callbacks are only `destroy_previous_textract_results`, `update_summary_status_record`, `broadcast_status_change`). Creation moved to the `FindOrCreateAiJobApplicationSummaryStatus` interactor (Writer 1), owned by `job_application`, not by the summary. This matches CLAUDE.md failure pattern #16. VERDICT: REMOVED.

## .update vs update_columns summary (callback implications)

| Writer | Site | Method | Fires callbacks/counter_culture? |
|---|---|---|---|
| 1 (regenerating branch) | find_or_create:15 | `update_columns` | NO (skips) — counter unaffected (2->3 both counted) |
| 1 (create branch) | find_or_create:37 | `save` (after build) | YES — counter increments if created as `current` |
| 2 | textract_result:104 | `update_columns` | NO (skips) — counter unaffected (0->1 both uncounted) |
| 3 | ai_job_application_summary:74 | `update` | YES — counter increments on ->`current`; also `ai_summary_succeeded` broadcast at :93 |

## Desync windows (denormalized row disagreeing with the real latest non-stale summary)

1. **Writer 3 has no `stale` guard.** It fires on ANY summary's transition to `succeeded`, copying that summary's denormalized fields onto the row even if that summary is itself stale relative to a newer textract result. No check of `stale` at `ai_job_application_summary.rb:69` or `:74`. The status row can be set `current` pointing at a stale summary.
2. **Writer 1 regenerating branch only flips status, never refreshes denormalized data.** `update_columns(status:'regenerating')` (`:15`) leaves `score_percentage/headline/integrated_role_analysis/ai_job_application_summary_id` pointing at the OLD succeeded summary while a replacement generates. The row shows old fit data under a `regenerating` status until Writer 3 fires on the new summary's success.
3. **Writer 2 update_columns skips counter_culture** — harmless here only because `none`/`initial_summary_pending` are both uncounted. If a future state machine routed through Writer 2 from a counted state, the job counter would drift. Flagged as a latent skip.
4. **Writer 1 create branch reads `latest_ai_job_application_summary` (no stale filter on the success seed?)** — it DOES check `!stale?` at `:27`, so the create branch is guarded. But Writer 3 (the recurring path) is NOT — asymmetry between create-seed (stale-guarded) and update-refresh (not stale-guarded).
5. **No writer ever sets the row back to `none`/clears denormalized columns when the latest summary is destroyed or disassociated.** `destroy_previous_textract_results` (`:47-55`) can destroy TextractResults and cascade-destroy their summaries, but nothing nulls the status row's `ai_job_application_summary_id`/score/headline if the pointed-at summary disappears. Potential dangling pointer + phantom denormalized values (relates to CLAUDE.md failure #18).

## Terminal states / dead ends for the status row

- Normal happy path: created `none` or `current` (Writer 1) -> `initial_summary_pending` (Writer 2, if it was none) -> back to `current` (Writer 3 on summary success). Resting state `current`.
- Regeneration: `current` -> `regenerating` (Writer 1) -> `current` (Writer 3 when the new summary succeeds).
- **Dead end:** if a generation that set the row to `initial_summary_pending` or `regenerating` never reaches a summary `succeeded` (pipeline fails — summary goes `failed`), Writer 3's `status_succeeded?` guard (`:69`) is never satisfied, so the row is NEVER advanced out of `initial_summary_pending`/`regenerating`. No failure-path writer touches the status row. The row rests in a non-terminal status with no actor to clear it. This is a genuine no-clearing-actor dead end on every failed/exhausted generation.

## Record-write sites (this slice)

1. `app/interactors/find_or_create_ai_job_application_summary_status.rb:15` — `@status_record.update_columns(status: 'regenerating')` — col: status — update_columns
2. `app/interactors/find_or_create_ai_job_application_summary_status.rb:29-37` — `build_...` then `@status_record.save` with status `current`/`none` (+ denormalized fields on current branch) — cols: status, ai_job_application_summary_id, score_percentage, headline, integrated_role_analysis — save (insert)
3. `app/models/textract_result.rb:104-107` — `status_record.update_columns(ai_job_application_summary_id:, status:'initial_summary_pending')` — cols: ai_job_application_summary_id, status — update_columns
4. `app/models/ai_job_application_summary.rb:74-80` — `ai_job_application_summary_status.update(ai_job_application_summary_id:, status:'current', score_percentage:, headline:, integrated_role_analysis:)` — cols: ai_job_application_summary_id, status, score_percentage, headline, integrated_role_analysis — update

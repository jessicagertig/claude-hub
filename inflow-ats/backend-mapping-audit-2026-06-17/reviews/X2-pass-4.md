# Slice X2 — Adversarial Review, Pass 4

**Angle:** X2 (Setter/clearer focus — `find_or_create_ai_job_application_summary_status`, `AiJobApplicationSummary#update_summary_status_record`, and every other writer of `AiJobApplicationSummaryStatus`)

**Method:** Re-read current code from scratch. Repo: `/Users/jessica/wrk/wrk-corp/inflow-ats`. Candidate map: `backend-flow-map-2026-06-17.md` (header now says Last updated 2026-06-22).

## Files traced

- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (full)
- `app/models/ai_job_application_summary.rb:29-98` (`update_summary_status_record`, callbacks)
- `app/models/ai_job_application_summary_status.rb` (full — enum, counter_culture, scopes)
- `app/models/textract_result.rb:60-144` (`generate_ai_summary_with_credit_flow`, `set_initial_summary_pending`, `queue_ai_summary_job`)
- `app/models/job_application.rb:31,32,107,111,160-171` (associations + callers)
- `db/schema.rb:13,168-179,880-914` (schema version, status table, jobs counter column)

## The three writers of AiJobApplicationSummaryStatus (X2 census)

1. **`FindOrCreateAiJobApplicationSummaryStatus#call`** — `find_or_create_ai_job_application_summary_status.rb`
   - `:15` `@status_record.update_columns(status: 'regenerating')` — **update_columns** (no callbacks). Fires ONLY when row exists AND `@status_record.ai_job_application_summary&.status_succeeded?` (`:11-14`, keyed off the status row's OWN denormalized `ai_job_application_summary` pointer at `:12`). Writes `status` column only.
   - `:37` `@status_record.save` (else/create branch). **save** (fires counter_culture + validations). Writes `status` = `'current'` + denormalized `score_percentage`/`headline`/`integrated_role_analysis` (`:28-32`) when `latest_ai_job_application_summary&.status_succeeded? && !.stale?` (`:27`), else `status='none'` (`:34`).
   - Callers: `JobApplication#find_or_create_ai_job_application_summary_status` (`job_application.rb:160-161`), reached from (a) `enqueue_new_job_application` (`job_application.rb:170`, after_commit on:create, EVERY created job_application) and (b) `generate_ai_summary_with_credit_flow` (`textract_result.rb:70`).

2. **`AiJobApplicationSummary#update_summary_status_record`** — `ai_job_application_summary.rb:57-98`
   - `:74` `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)` — **.update** (fires callbacks/counter_culture). Writes 5 columns.
   - Fires from after_commit `on: :update` (`:30`), guarded `:69` `return unless saved_change_to_status? && status_succeeded?`, and `:72` `return unless ai_job_application_summary_status`.

3. **`TextractResult#set_initial_summary_pending`** — `textract_result.rb:98-108`
   - `:104` `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')` — **update_columns** (no callbacks). Guarded `:101` `status_record && latest_summary` and `:102` `status_none? || status_initial_summary_pending?`.
   - Caller: `generate_ai_summary_with_credit_flow` `textract_result.rb:72`, only when `status_result.success?`.

## Verdicts on map statements (X2-relevant)

### AGREE

- Map L33 — `update_summary_status_record` sets `status:'current'` via `.update`, NOT update_columns, writes no `regenerating` column (`ai_job_application_summary.rb:74-81`). AGREE.
- Map L29/L134 — `regenerating` set at `find_or_create_ai_job_application_summary_status.rb:14-15` via `update_columns`, guarded on the STATUS ROW's own `ai_job_application_summary.status_succeeded?` (`:12,:14`). AGREE.
- Map L143/L157 — `set_initial_summary_pending` writes via `update_columns` (`:104-107`), guarded `:101-102`; FindOrCreate create-path → `'current'` (stale-guarded copy) or `'none'`. AGREE (`:27-35`).
- Map L159 — Row-exists + summary NOT succeeded = complete NO-OP, only sets `context.ai_job_application_summary_status = @status_record` (`:42`). AGREE (`:14` false → falls through to `:42`).
- Map L160 — `rescue ActiveRecord::RecordNotUnique` (`:43-44`) reloads + returns. AGREE.
- Map L161 — create-path `context.fail!` when `@status_record.save` false (`:37-38`); caller `textract_result.rb:72` skips `set_initial_summary_pending` (guarded on `status_result.success?`). AGREE.
- Map L162 — No writer moves the row off `initial_summary_pending`/`regenerating` on summary FAILURE; `update_summary_status_record` fires only on `status_succeeded?` (`ai_job_application_summary.rb:69`); no `failed` enum value. AGREE (status enum `ai_job_application_summary_status.rb:9-14`).
- Map L31/L153 — `create_status_record` after_commit gone from `AiJobApplicationSummary` (`ai_job_application_summary.rb:29-31` are `destroy_previous_textract_results`, `update_summary_status_record`, `broadcast_status_change`). AGREE.
- Map L151/L152 (enum + columns) — enum `{none:0, initial_summary_pending:1, current:2, regenerating:3}` _prefix:true (`ai_job_application_summary_status.rb:9-14`); columns match schema (`db/schema.rb:168-178`). AGREE.
- Map L158 — Unique index `idx_ai_summary_statuses_on_job_application_id` + `idx_ai_summary_statuses_on_summary_id` (`db/schema.rb:177-178`). AGREE.
- Map L146 (S-E) — status row reaches `'current'` on handoff success via `update_summary_status_record`, after_commit on:update, guarded `saved_change_to_status? && status_succeeded?`. AGREE.

### DISPUTE

- **Map L154** — Claims `jobs.ai_job_application_summaries_count` is "NOT present in the committed db/schema.rb (schema version 2026_06_11_120001)" and is added only by a later, undumped migration, so "a write toggling current/regenerating would raise on the missing column." **DISPUTE.** Current `db/schema.rb:13` is `version: 2026_06_22_182504`; `db/schema.rb:907` has `t.integer "ai_job_application_summaries_count", default: 0, null: false` on the jobs table, plus `ai_job_criteria_generations_count` (`:908`) and `internal_job_criteria` (`:909`). The migration `20260622182504_add_ai_summary_and_criteria_columns_to_jobs.rb` is now applied and reflected in schema.rb. The "would raise on the missing column" hazard no longer exists against current code. Correction: the counter_culture target column IS present in the committed schema; remove the schema-version-2026_06_11_120001 / missing-column caveat.

## Omissions (X2 things the map does not state)

1. **counter_culture is the callback-firing consequence the map's ".update vs update_columns" framing leaves implicit.** `AiJobApplicationSummaryStatus` has NO `after_*`/`before_*` callbacks of its own; its only callback-bearing behavior is `counter_culture [:job_application, :job]` (`ai_job_application_summary_status.rb:7`). So the practical meaning of the three write mechanisms is: `update_summary_status_record`'s `.update` (`ai_job_application_summary.rb:74`) and FindOrCreate's create-path `save` (`:37`) DO refresh `jobs.ai_job_application_summaries_count`; the two `update_columns` writes (`find_or_create…:15` regenerating-flip, `textract_result.rb:104` initial_summary_pending) BYPASS counter_culture. Notably the `none→regenerating`/`current→regenerating` flip at `find_or_create…:15` uses `update_columns`, so the counter is NOT decremented/recomputed when leaving `current` via that flip — a counter-staleness window the map does not mention (counter counts `status IN (2,3)`, so `current`→`regenerating` is count-neutral, but a `current`→`regenerating` that the writer reached only because the status-row summary was succeeded leaves the count correct; however the `update_columns` path means counter_culture's own `after_update` recompute never runs, so any divergence is never self-healed by that write).

2. **The regenerating-flip (`:15`) and the create-path are mutually exclusive branches keyed on row existence**, and the map never states that `update_summary_status_record` (`ai_job_application_summary.rb:74`) is the ONLY writer that sets `score_percentage`/`headline`/`integrated_role_analysis` to FRESH values after the row already exists. The FindOrCreate regenerating branch (`:15`) writes ONLY `status`, leaving the OLD denormalized columns in place — confirming the "STUCK regenerating with stale denormalized data" terminal (map L34/L134) but the map does not explicitly attribute the stale-data persistence to the `:15` update_columns writing status-only.

3. **`update_summary_status_record` writes `ai_job_application_summary_id: id` unconditionally to the CURRENT succeeding summary** (`ai_job_application_summary.rb:75`), regardless of whether `job_application.ai_job_application_summary_status` (`:71`) is the same summary the status row previously pointed at. The map does not note that this is the sole re-pointing writer; on success it always re-links the status row to whichever summary just reached `succeeded`, which is what reconciles a previously-`regenerating` (stale-pointer) row back to `current` on the NEXT successful generation.

## clean

clean = false (one DISPUTE on L154 + omissions present).

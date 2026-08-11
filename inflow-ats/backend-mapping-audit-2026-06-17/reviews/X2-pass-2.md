# Adversarial Review — Slice X2 (Setter/clearer focus) — Pass 2

**Target map:** `backend-flow-map-2026-06-17.md`
**Slice:** X2 — trace `find_or_create_ai_job_application_summary_status`, `AiJobApplicationSummary#update_summary_status_record`, and every other writer of `AiJobApplicationSummaryStatus`; enumerate callers, preconditions, `.update` vs `update_columns`, callback-firing implications.

## Files read from scratch
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (full)
- `app/models/ai_job_application_summary.rb` (full)
- `app/models/ai_job_application_summary_status.rb` (full)
- `app/models/textract_result.rb:60-112` (`generate_ai_summary_with_credit_flow`, `set_initial_summary_pending`)
- `app/models/job_application.rb:158-172` (wrapper + `enqueue_new_job_application`)
- grep census of every caller of the four writers

## The three writers of AiJobApplicationSummaryStatus (ground truth)

1. **`FindOrCreateAiJobApplicationSummaryStatus#call`** (`find_or_create_ai_job_application_summary_status.rb`)
   - **Caller 1:** `JobApplication#enqueue_new_job_application` (`job_application.rb:170`) via wrapper `find_or_create_ai_job_application_summary_status` (`job_application.rb:160-162`). Precondition: any `after_commit on: [:create]` of a JobApplication (`job_application.rb:45`). Unconditional, not Flipper-gated.
   - **Caller 2:** `TextractResult#generate_ai_summary_with_credit_flow` (`textract_result.rb:70`) via the same wrapper. Precondition: a generation pass runs and `latest_ai_summary` is NOT (succeeded && !stale) — i.e. it gets past the `return` at `textract_result.rb:68`.
   - **Branch A — row EXISTS, `@status_record.ai_job_application_summary&.status_succeeded?` true** (`:14`): `@status_record.update_columns(status: 'regenerating')` (`:15`) → **update_columns, NO callbacks/counter_culture/validations**; then `JobChannel.broadcast_to(... 'ai_summary_status_change' ...)` (`:16-20`). Denormalized columns (`score_percentage`, `headline`, `integrated_role_analysis`, `ai_job_application_summary_id`) NOT cleared.
   - **Branch B — row EXISTS, associated summary NOT succeeded** (`:14` false): **NO WRITE AT ALL.** Only `context.ai_job_application_summary_status = @status_record` (`:42`). This branch is unrepresented in the map.
   - **Branch C — NO row, `latest_ai_job_application_summary&.status_succeeded? && !stale?`** (`:27`): build, assign `ai_job_application_summary`, `status='current'`, copy `score_percentage`/`headline`/`integrated_role_analysis` (`:28-32`), then `@status_record.save` (`:37`) → **`.save` fires validations + counter_culture + any callbacks.**
   - **Branch D — NO row, else** (`:34`): `status='none'`, `.save` (`:37`).
   - **`context.fail!`** on save failure (`:38`) — relevant because caller 2 gates `set_initial_summary_pending` on `status_result.success?` (`textract_result.rb:72`).
   - **`rescue ActiveRecord::RecordNotUnique`** (`:43-44`): `context.ai_job_application_summary_status = job_application.reload.ai_job_application_summary_status`. Concurrency fallback — unrepresented in the map.

2. **`TextractResult#set_initial_summary_pending`** (`textract_result.rb:98-108`)
   - **Caller:** `generate_ai_summary_with_credit_flow` (`textract_result.rb:72`), only `if status_result.success?`.
   - Guard (`:101-102`): `return unless status_record && latest_summary`; `return unless status_record.status_none? || status_record.status_initial_summary_pending?`.
   - Write (`:104-107`): `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')` → **update_columns, NO callbacks.**

3. **`AiJobApplicationSummary#update_summary_status_record`** (`ai_job_application_summary.rb:57-98`)
   - Registered `after_commit :update_summary_status_record, on: :update` (`:30`).
   - Guard (`:69`): `return unless saved_change_to_status? && status_succeeded?`.
   - Early-return if no row (`:71-72`).
   - Write (`:74-80`): `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)` → **`.update`, fires validations/callbacks/counter_culture.**
   - Then `JobChannel.broadcast_to(... 'ai_summary_succeeded' ...)` (`:93-97`).

## Verdicts on map claims

All map statements about the three writers, their callers, preconditions, and `.update` vs `update_columns` choice are AGREE (cited in the structured output). The disputes are OMISSIONS, not contradictions: the map never documents Branch B (row exists / summary not succeeded → no-op) or the `rescue RecordNotUnique` reload fallback, both of which are real code paths through the primary writer this slice is responsible for.

## counter_culture detail confirmed
`ai_job_application_summary_status.rb:7`: counted when `status_current? || status_regenerating?` (statuses 2,3). The `regenerating` write (Branch A) uses `update_columns`, which skips counter_culture — but within `current`↔`regenerating` both are counted, so no drift. Map desync #8 (line 581) states this correctly. AGREE.

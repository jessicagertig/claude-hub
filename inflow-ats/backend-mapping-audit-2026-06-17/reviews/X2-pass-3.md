# Slice X2 — Adversarial Review (pass 3)

Angle: X2 — Setter/clearer focus on the AiJobApplicationSummaryStatus writers.

## Writers in scope (verified from code)

Three (and only three) code paths mutate `ai_job_application_summary_statuses` columns:

1. `FindOrCreateAiJobApplicationSummaryStatus#call`
   - `find_or_create_ai_job_application_summary_status.rb:15` `@status_record.update_columns(status: 'regenerating')` (existing-row, succeeded-summary branch) — `update_columns`, no callbacks, no denormalized clear.
   - `find_or_create_ai_job_application_summary_status.rb:25-39` create-path `build_ai_job_application_summary_status` then `@status_record.save` (`:37`) — `'current'` copy (`:28-32`) when latest summary succeeded & `!stale?`, else `'none'` (`:34`). `.save` fires callbacks.
2. `TextractResult#set_initial_summary_pending` — `textract_result.rb:104-107` `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')` — `update_columns`, no callbacks.
3. `AiJobApplicationSummary#update_summary_status_record` (after_commit on:update) — `ai_job_application_summary.rb:74-80` `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)` — `.update`, fires validations/callbacks/counter_culture.

Confirmed by grep: no other writer (`app/models/ai_job_application_summary.rb:71-74`, `app/models/textract_result.rb:99-107`, `app/interactors/find_or_create_ai_job_application_summary_status.rb` are the only mutators).

## Callers / preconditions (verified)

- `find_or_create_ai_job_application_summary_status` (model wrapper `job_application.rb:160-162`) is called from exactly two sites:
  - `job_application.rb:170` (inside `enqueue_new_job_application`, after_commit on:create `:45`) — UNCONDITIONAL, outside the Flipper block (`:167-169`). Fires on every job_application create (T1/T3 clone/T4/T5/T6).
  - `textract_result.rb:70` (inside `generate_ai_summary_with_credit_flow`) — runs only after the `:68` early return `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` does NOT fire. So for a succeeded-non-stale latest summary, find_or_create is NOT called.
- `set_initial_summary_pending` called only at `textract_result.rb:72`, guarded `if status_result.success?`. Internal guards `:101` (`status_record && latest_summary`) and `:102` (`status_none? || status_initial_summary_pending?`).
- `update_summary_status_record` after_commit on:update (`ai_job_application_summary.rb:30`), guard `:69` `saved_change_to_status? && status_succeeded?`; early return `:72` if no status row.

## .update vs update_columns — verified

- `regenerating` write: `update_columns` (`:15`) → no callbacks. AGREE with map.
- `initial_summary_pending` write: `update_columns` (`:104-107`) → no callbacks. AGREE.
- create-path: `.save` (`:37`). AGREE.
- success-path `current`: `.update` (`:74`) → fires counter_culture. AGREE with map's `.update` claim (5.3 line 511, divergence line 33, Part 9 line 623/633).

## Verdicts

All map statements about the X2 writers, their callers, preconditions, and `.update`/`update_columns` usage match the code. No disputes found.

## Omissions

None material. The map documents: both find_or_create callers with preconditions (lines 621, 70/170), the `:68` early-return gating (lines 30/115/125/363), the `update_columns`-skips-callback mechanics for `regenerating`/`initial_summary_pending` (lines 510/509/656/Part9), the `.update` current write firing counter_culture (lines 33/511/623), the no-op pass-through when the existing row's summary isn't succeeded (lines 136/513/634), the save-failure→skip-set_initial cascade (lines 138/621), the RecordNotUnique reload fallback (lines 137/621), and all desync windows (Part 9 648-656).

clean = true

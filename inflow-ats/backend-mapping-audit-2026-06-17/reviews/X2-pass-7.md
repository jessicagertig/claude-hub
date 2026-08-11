# X2 Adversarial Review — Pass 7 (Setter/clearer focus)

Slice X2: trace `find_or_create_ai_job_application_summary_status` and
`AiJobApplicationSummary#update_summary_status_record` (and any other writer)
in full. Enumerate every caller + exact precondition; confirm `.update` vs
`update_columns` and callback-firing implications.

## Code re-read from scratch (files opened)

- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (full, 1-47)
- `app/models/ai_job_application_summary.rb` (full, 1-112)
- `app/models/textract_result.rb:55-144` (generate_ai_summary_with_credit_flow + set_initial_summary_pending + queue_ai_summary_job)
- `app/models/job_application.rb:44-46, 158-172` (callback registration + wrapper + enqueue_new_job_application)
- `app/models/ai_job_application_summary_status.rb` (full, 1-26)
- grep census of every write/caller site across app/ + lib/ (excluding specs)

## The complete X2 writer/caller census (ground truth)

### Writers of AiJobApplicationSummaryStatus (EXHAUSTIVE — 4 sites)
1. `find_or_create_ai_job_application_summary_status.rb:15` — `@status_record.update_columns(status: 'regenerating')` — status-only; guard `:14` `if summary&.status_succeeded?` where `summary = @status_record.ai_job_application_summary` (`:12`, the row's OWN denormalized pointer). BYPASSES counter_culture (update_columns).
2. `find_or_create_ai_job_application_summary_status.rb:28-32, 34, 37` — create-path. `build` `:25`; `:28-32` assigns `ai_job_application_summary` + `status='current'` + score/headline/integrated_role_analysis when `latest_ai_job_application_summary&.status_succeeded? && !...stale?` (`:27`); else `:34` `status='none'`; `:37` `@status_record.save` (`context.fail!` `:38` on save=false). FIRES counter_culture (save).
3. `textract_result.rb:104-107` — `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')`; guards `:101` (`status_record && latest_summary`) + `:102` (`status_none? || status_initial_summary_pending?`). BYPASSES counter_culture.
4. `ai_job_application_summary.rb:74-80` — `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)`; registered `after_commit :update_summary_status_record, on: :update` (`:30`); guard `:69` `saved_change_to_status? && status_succeeded?`; row-existence guard `:72`. FIRES counter_culture (.update). Then broadcasts JobChannel `ai_summary_succeeded` `:93-97`.

grep confirms NO other write site touches the association (only `.update` `:74`, error log `:83`, the wrapper `:160`, and read-only `.includes` in the controller).

### Callers of find_or_create_ai_job_application_summary_status (EXHAUSTIVE — 2)
- `job_application.rb:170` inside `enqueue_new_job_application` (registered `after_commit ... on: [:create]`, `:45`). UNCONDITIONAL within the callback (NOT inside the `:167-169` Flipper guard). Fires on every job_application create.
- `textract_result.rb:70` inside `generate_ai_summary_with_credit_flow`. Reached ONLY when the `:68` early-return does NOT fire (`return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`). When a succeeded non-stale summary exists, `:70` is NEVER reached.

All `.call` invocations route through the wrapper `job_application.rb:160-161`; no direct `FindOrCreateAiJobApplicationSummaryStatus.call` elsewhere.

### Caller of set_initial_summary_pending (EXHAUSTIVE — 1)
- `textract_result.rb:72` `set_initial_summary_pending(status_result) if status_result.success?`.

## Verdicts on the map's X2 statements

AGREE (verified against code):
- Status enum `{none:0, initial_summary_pending:1, current:2, regenerating:3}` _prefix:true (`:9-14`).
- No `regenerating` boolean column; `regenerating` is status value 3.
- `update_summary_status_record` registered `on: :update` `:30`; guard `:69`; row guard `:72`; `.update` `:74-80` writes 5 cols; broadcasts `ai_summary_succeeded` `:93-97`.
- regenerating-flip `:15` is status-only `update_columns` (denormalized cols NOT cleared); guard `:14` reads the row's OWN denormalized pointer `:12`.
- create-path `:28-32/:34/:37`; guard `:27`; `context.fail!` `:38`.
- `set_initial_summary_pending` `:104-107` update_columns; guards `:101`,`:102`; caller `:72` guarded on `status_result.success?`.
- RecordNotUnique rescue `:43-44`; no-op pass-through writes nothing only `:42`.
- counter_culture literal `:7` two-part (column_name proc + column_names IN(2,3)); `.update`/save fire it, the two `update_columns` writers bypass it; nothing else on the model fires callbacks.
- `update_summary_status_record` re-points `ai_job_application_summary_id: id` UNCONDITIONALLY (`:75`) — sole recovery writer for a stuck regenerating row.
- Desync windows 1-8 (Part 9) all check out against the guards.

DISPUTE / imprecision:
1. Line 772: "called from ... `TextractResult#generate_ai_summary_with_credit_flow` (`:70`, every generation)". Overstated. `:70` is reached only when the `:68` early-return does not fire; when `latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?`, the method returns at `:68` and NEVER calls `find_or_create` at `:70`. Correction: "(`:70`, every generation EXCEPT when a succeeded non-stale latest summary exists — those return at `textract_result.rb:68` before reaching `:70`)". (The `:68` guard IS documented at line 504; only the Part-9 caller-precondition phrasing omits it.)

## Omissions
- The `:68` early-return precondition is not attached to the `:70` caller in the Part 9 "Lifecycle ownership" caller list (only in Part 2 §502-505). For an "exact precondition per caller" census this should be co-located.
- ap-range nit: several places say "ap debug lines `:57-67`", but `:57` is the `def` line; the `ap` calls run `:58-67`. Pass-5 already clarifies the def is at `:57`; the ap-range start is off by one. Cosmetic.

## clean = false (one DISPUTE + two omissions)

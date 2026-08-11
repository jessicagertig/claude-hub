# Adversarial Review — Slice X2 (Setter/clearer focus) — pass-6

**Scope:** Trace `find_or_create_ai_job_application_summary_status` and `AiJobApplicationSummary#update_summary_status_record` (and any other writer of `AiJobApplicationSummaryStatus`) in full. Enumerate every caller and the exact precondition under which each fires. Confirm `.update` vs `update_columns` at each write and callback-firing implications.

**Method:** Re-read from scratch. Files opened and traced:
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` (full)
- `app/models/ai_job_application_summary.rb:25-112` (`update_summary_status_record`, callback registration, `broadcast_status_change`)
- `app/models/textract_result.rb:60-161` (`generate_ai_summary_with_credit_flow`, `set_initial_summary_pending`, `queue_ai_summary_job`)
- `app/models/job_application.rb:29-48, 155-172` (associations, wrapper, `enqueue_new_job_application`, callback `:45`)
- `app/models/ai_job_application_summary_status.rb` (full — enum, counter_culture, validation, scopes)
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb:40-69` (succeeded `.update` that fires the success-path writer)
- `db/schema.rb:13, 168-179, 907-909`
- Codebase-wide grep for every reference to the status record / writers (app/, lib/) — confirms writer set is exhaustive.

## Writer census (exhaustive — 3 writers, 0 omitted)

Grep across `app/`/`lib/` for `ai_job_application_summary_status`, `build_ai_job_application_summary_status`, `update_summary_status_record`, `set_initial_summary_pending`, `FindOrCreateAiJobApplicationSummaryStatus` returns exactly three MUTATING sites:
1. `find_or_create_ai_job_application_summary_status.rb:15` `update_columns(status: 'regenerating')` (regenerating-flip) and `:25-37` `build_…`/assigns/`save` (create-path: `current` or `none`).
2. `textract_result.rb:104-107` `set_initial_summary_pending` → `status_record.update_columns(ai_job_application_summary_id:, status: 'initial_summary_pending')`.
3. `ai_job_application_summary.rb:74-80` `update_summary_status_record` → `ai_job_application_summary_status.update(...)` (success-path `current`).
All other references are READS (`queue_bulk_ai_summary_jobs.rb:36`, controller `.includes`, `job_application.rb:107/108/111` fit_bands/unscored). The map's writer set matches exactly.

## Caller census

- Wrapper `JobApplication#find_or_create_ai_job_application_summary_status` (`job_application.rb:160-162`) → `FindOrCreateAiJobApplicationSummaryStatus.call(job_application: self)`. Exactly TWO callers of the wrapper:
  1. `enqueue_new_job_application` (`job_application.rb:170`) — unconditional, fires from `after_commit :enqueue_new_job_application, on: [:create]` (`:45`). Every create (T1/T3-clone/T4/T5/T6).
  2. `generate_ai_summary_with_credit_flow` (`textract_result.rb:70`) — every generation that passes the `:68` early-return guard.
- No direct callers of `FindOrCreateAiJobApplicationSummaryStatus.call` bypassing the wrapper (grep confirms only `:161`).
- `set_initial_summary_pending` called only from `textract_result.rb:72`, guarded `if status_result.success?`.
- `update_summary_status_record` fired only via `after_commit … on: :update` (`ai_job_application_summary.rb:30`); the success-producing `.update` is `integrate_analysis.rb:53` (`status: :succeeded` at :51), an update on an existing record so `on: :update` fires.

## .update vs update_columns at each write — all confirmed

| Write | Mechanism | counter_culture | Map claim |
|---|---|---|---|
| `find_or_create…:15` regenerating | `update_columns` | bypassed | AGREE |
| `find_or_create…:37` create-path (none/current) | `save` (on built record) | fires | AGREE |
| `textract_result.rb:104` initial_summary_pending | `update_columns` | bypassed | AGREE |
| `ai_job_application_summary.rb:74` success-path current | `.update` | fires | AGREE |

## Verdicts — every X2 map statement AGREE

No DISPUTE. All preconditions, line numbers, mechanisms, broadcast events, and schema facts verified against current code. See structured output for the itemized AGREE list.

## Omissions

None material. The map's Part 9, table 5.3, the X1/X2 changelog block (lines 200-218), and the Part 10 census (line 795) cover every writer, caller, precondition, mechanism, and desync window I found. One minor cosmetic note (non-blocking, does not flip clean): the map cites `integrate_analysis.rb:53` with a bare filename; the actual path is `app/services/ai_job_application_action/scoring/integrate_analysis.rb` (not `app/interactors/`). The map uses bare filenames throughout by convention, and the line number (:53 for the `.update`) is correct, so this is not an X2-writer error.

**clean = true** — every X2 verdict AGREE and no material omission.

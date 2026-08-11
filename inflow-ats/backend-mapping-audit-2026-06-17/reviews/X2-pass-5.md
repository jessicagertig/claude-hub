# Slice X2 — Adversarial Review (pass 5)

**Angle:** X2 — Setter/clearer focus. `find_or_create_ai_job_application_summary_status`, `AiJobApplicationSummary#update_summary_status_record`, `TextractResult#set_initial_summary_pending`, and every other writer of `AiJobApplicationSummaryStatus`. Caller enumeration, preconditions, `.update` vs `update_columns`, callback implications.

Re-read from scratch against current code. Files opened and traced:
`find_or_create_ai_job_application_summary_status.rb` → `ai_job_application_summary.rb` → `job_application.rb` → `textract_result.rb` → `ai_job_application_summary_status.rb` → `db/schema.rb` → `db/migrate/20260611120001_create_ai_job_application_summary_statuses.rb`

## Complete writer census for AiJobApplicationSummaryStatus (verified)

1. `ai_job_application_summary.rb:74` — `ai_job_application_summary_status.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)` — **`.update`** (fires counter_culture). In `update_summary_status_record` (`def` at `:57`, after_commit `on: :update` registered `:30`, guard `:69` `return unless saved_change_to_status? && status_succeeded?`, no-row return `:72`).
2. `find_or_create_ai_job_application_summary_status.rb:15` — `@status_record.update_columns(status: 'regenerating')` — **`update_columns`** (bypasses counter_culture). Guard `:14` `if summary&.status_succeeded?`, summary = `@status_record.ai_job_application_summary` (`:12`, the ROW's own pointer). Broadcast `:16-20`.
3. `find_or_create_ai_job_application_summary_status.rb:37` — `@status_record.save` — **`save`** (fires counter_culture). Build `:25`; current-copy assign `:27-32` (precondition `:27` `latest_ai_job_application_summary&.status_succeeded? && !stale?`, `latest_ai_job_application_summary` read at `:23`); else `status='none'` `:34`. `context.fail!` on save-false `:37-38`. Rescue `RecordNotUnique` `:43-44`.
4. `textract_result.rb:104-107` — `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')` — **`update_columns`** (bypasses counter_culture). In `set_initial_summary_pending` (`def :98`), guards `:101` `return unless status_record && latest_summary`, `:102` `return unless status_none? || status_initial_summary_pending?`.

Grep confirms NO other write site. No own before/after callbacks on the model (`ai_job_application_summary_status.rb` has only `counter_culture` `:7`).

## Caller census (verified)

- `find_or_create_ai_job_application_summary_status` (wrapper `job_application.rb:160-162`): exactly 2 callers — `job_application.rb:170` (in `enqueue_new_job_application`, every create, NOT Flipper-gated) and `textract_result.rb:70` (in `generate_ai_summary_with_credit_flow`, every generation). ✓ matches map.
- `update_summary_status_record`: sole trigger is `after_commit on: :update` (`:30`). ✓
- `set_initial_summary_pending`: sole caller `textract_result.rb:72`, gated `if status_result.success?`. ✓

## Verdicts

Every substantive map claim about X2 AGREES with code. One minor citation-range dispute:

- DISPUTE — map line 723 cites `AiJobApplicationSummary#update_summary_status_record` as `(:69-98, on summary success)`. The method `def update_summary_status_record` begins at `ai_job_application_summary.rb:57`, not `:69`. `:69` is the guard line; `:57-67` are the method's `ap` debug lines. The range `:69-98` undercounts the method by excluding lines `:57-68`. (Functional body — guard through broadcast — is `:69-98`, so the cite is defensible as "the effective body," but as a method-definition range it is wrong. Flagging per default-skepticism.) Every other cite of this writer in the map (`:30` reg, `:69` guard, `:72` no-row, `:74-80` update, `:93-97` broadcast) is correct.

All other X2 claims verified AGREE — enum (`:9-14`), no `regenerating` column, counter_culture `status IN (2,3)` (`:7`) + backing column (`db/schema.rb:907`), indexes (`:177/:178`), uniqueness (`:16`), migration columns (`:5-16`), the 5.3 transition table writers/preconditions, the no-op pass-through (`:14` false → only `:42`), save-failure `context.fail!` (`:37-38`) skipping `set_initial_summary_pending`, the regenerating-flip-keeps-stale-data (`:15` status-only), the re-pointing recovery writer (`ai_job_application_summary.rb:75` unconditional), and all three dead-ends (stuck `initial_summary_pending`, stuck `regenerating`, no-row).

## Omissions

None material. (Part 9 prose at line 731 abbreviates `set_initial_summary_pending` as a status-only write, but the 5.3 table line 605 correctly shows it also writes `ai_job_application_summary_id: latest_summary.id`, and line 167 cites `:104-107` — so the `ai_job_application_summary_id` write is documented elsewhere, not omitted globally.)

## clean

false — one DISPUTE (line 723 method-range cite).

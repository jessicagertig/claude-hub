# X1 Pass-4 Adversarial Review — AiJobApplicationSummaryStatus (whole-codebase)

Re-read from scratch. Target table: `ai_job_application_summary_statuses`.

## Verdict summary

Almost every map claim AGREES with current code. One material **DISPUTE**: the
counter_culture PROVENANCE FLAG is now stale — `db/schema.rb` has been re-dumped at
version `2026_06_22_182504` and the target column `jobs.ai_job_application_summaries_count`
IS present (`db/schema.rb:907`). The map repeatedly asserts the committed schema is
`2026_06_11_120001` and that the column is missing, which would make a `current`/`regenerating`
write "raise on the missing column." That is false against current code.

## Writers (complete, verified)
1. `find_or_create_ai_job_application_summary_status.rb:15` `@status_record.update_columns(status: 'regenerating')` — precondition: existing row AND `@status_record.ai_job_application_summary&.status_succeeded?` (`:12,:14`). update_columns (skips counter_culture). Broadcasts `ai_summary_status_change` (`:16-20`).
2. `find_or_create_ai_job_application_summary_status.rb:25-37` create-path. `:27` guard `latest_ai_job_application_summary&.status_succeeded? && !stale?` → `'current'` w/ denorm copy (`:28-32`), else `'none'` (`:34`). `.save` (`:37`) fires counter_culture. `context.fail!` on save false (`:38`).
3. `textract_result.rb:104-107` `set_initial_summary_pending` `update_columns(ai_job_application_summary_id:, status: 'initial_summary_pending')` — guards `:101` (record+latest summary), `:102` (status_none?||status_initial_summary_pending?).
4. `ai_job_application_summary.rb:74-80` `update_summary_status_record` `.update(ai_job_application_summary_id:, status:'current', score_percentage:, headline:, integrated_role_analysis:)` — `after_commit on: :update` (`:30`), guard `:69` `saved_change_to_status? && status_succeeded?`, early-return no row `:72`. Fires counter_culture. Then `ai_summary_succeeded` broadcast (`:93-97`).

No bang-method writers, no `delete_all`/`destroy` sites. `lib/` has zero references.

## Readers (complete, verified)
- Serializer `Api::V1::AiJobApplicationSummaryStatusSerializer:4-10` (`published_at_timestamp = updated_at.to_i :8-10`).
- `ShallowJobApplicationSerializer:23-24` has_one; `JobApplicationSerializer:40-41` has_one.
- Controller preloads `job_applications_controller.rb:27,38,56` `.includes(:ai_job_application_summary_status)`.
- `queue_bulk_ai_summary_jobs.rb:36-40` reads `status: :current`.
- `job_application.rb:106-113` `fit_bands` + `unscored` scopes.
- counter_culture rollup `ai_job_application_summary_status.rb:7`.
- FE: `jobApplication.ts:1-9` (interface, 4-value union `:4`, no publishedAtTimestamp), `bulkAiSummaryCount.ts:40,46`, `WebsocketJobChannelHandler.tsx:73-81`, `PlatoTab.tsx:41-52,127-130,151-218`, `JobApplicationListContainer.tsx:235-236`, `JobApplicationActivity.tsx:79-92`.
- GlobalChannel: `WebsocketGlobalChannelHandler.tsx:227,241,253,281` all invalidate `jobApplicationsForStage`.

## DISPUTE — counter_culture provenance flag (map lines 154, 641, 646-659, 688, 706)
- Map: committed schema version `2026_06_11_120001`; `jobs.ai_job_application_summaries_count` NOT in schema; write would raise.
- Code: `db/schema.rb:13` `ActiveRecord::Schema.define(version: 2026_06_22_182504)`; `db/schema.rb:907` `t.integer "ai_job_application_summaries_count", default: 0, null: false` (also `:908` ai_job_criteria_generations_count, `:909` internal_job_criteria). Migration `20260622182504` IS dumped. The "would raise on missing column" hypothetical is moot. Correction: column is present in committed schema; counter_culture target exists; no raise.

## Minor note (not a dispute)
- schema `create_table` block is `db/schema.rb:168-179` (map says 168-178; closing `end` at 179). Columns/indexes all match.

## Omissions
- None of substance. All Ruby + FE readers/writers are covered. (Band-scope boundaries at `:20-24` are summarized but not enumerated; acceptable.)

clean = false (one DISPUTE).

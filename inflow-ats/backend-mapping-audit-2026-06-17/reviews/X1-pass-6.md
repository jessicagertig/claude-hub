# X1 Adversarial Review — Pass 6

**Slice:** X1 — `AiJobApplicationSummaryStatus` table, whole-codebase reads & writes, state-transition table, desync windows.
**Method:** Re-read all code from scratch; attempted to refute every map statement about the slice against literal `file:line`.

## Verdict summary
Every substantive map claim about the X1 slice AGREES with current code. One OMISSION found: a maintenance reader site (`recurring_tasks.rake:79`) absent from the map's reader list and Part 10 census. Therefore `clean = false`.

---

## Writers (complete set — verified by grep of `app/` + `lib/` for `.update|.create|.save|build_|update_columns` on the record)

1. `find_or_create_ai_job_application_summary_status.rb:15` — `@status_record.update_columns(status: 'regenerating')` (status-only, bypasses counter_culture; broadcasts `ai_summary_status_change` `:16-20`). Fires when `@status_record` exists AND its `ai_job_application_summary` (denormalized pointer, `:12`) is `status_succeeded?` (`:14`).
2. `find_or_create_ai_job_application_summary_status.rb:25` build + `:37` `save` — create-path. `:27` `latest_ai_job_application_summary&.status_succeeded? && !latest...stale?` → `'current'` with denormalized copy (`:28-32`); else `'none'` (`:34`). `:37-38` `context.fail!` on save failure.
3. `textract_result.rb:104-107` — `status_record.update_columns(ai_job_application_summary_id: latest_summary.id, status: 'initial_summary_pending')`. Guards `:101` (status_record && latest_summary), `:102` (`status_none? || status_initial_summary_pending?`). Bypasses counter_culture.
4. `ai_job_application_summary.rb:74-80` — `.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)`. `after_commit on: :update` (`:30`), guard `:69` `saved_change_to_status? && status_succeeded?`, early-return no row `:72`. Fires counter_culture. Broadcasts `ai_summary_succeeded` `:93-97`.

All four are in the map's census (line 795) and Part 9 §"Every transition". CONFIRMED.

## Readers (complete set)
- Serializer `Api::V1::AiJobApplicationSummaryStatusSerializer:4-10`; embedded `has_one` in `shallow_job_application_serializer.rb:23-24` + `job_application_serializer.rb:40-41`; controller preloads `job_applications_controller.rb:27,38,56`.
- `queue_bulk_ai_summary_jobs.rb:36-40` reads `status: :current`.
- `job_application.rb:106-113` `fit_bands`/`unscored` scopes.
- counter_culture `ai_job_application_summary_status.rb:7` → `jobs.ai_job_application_summaries_count` (`db/schema.rb:907`, version `2026_06_22_182504`).
- FE: `JobApplicationListContainer.tsx:220/226/235/236`, `JobApplicationNavItem.tsx:17-18/26-29`, `PlatoTab.tsx:42/46/127/129/130/187/...`, `JobApplicationActivity.tsx:79-91`, `bulkAiSummaryCount.ts:37-41/46`, TS `jobApplication.ts:1-9`.
- Websocket: `WebsocketJobChannelHandler.tsx:73-76/77-81`, `WebsocketGlobalChannelHandler.tsx:227/241/253/281`.
- No optimistic FE write (`useJobApplication.ts:229` setQueryData in `onSuccess` `:220`, not onMutate; grep of queryHooks for `aiJobApplicationSummaryStatus` empty).

## OMISSION
- `lib/tasks/recurring_tasks.rake:79` — `AiJobApplicationSummaryStatus.counter_culture_fix_counts # fixes Job.ai_job_application_summaries_count`. A recurring maintenance reader that re-computes the counter_culture count off this table. Not mentioned anywhere in the map (not in Part 9 readers, not in the Part 10 census). For a whole-codebase X1 slice this is a real (if minor) omission. Add to map: "Maintenance: `recurring_tasks.rake:79` `AiJobApplicationSummaryStatus.counter_culture_fix_counts` periodically re-derives `jobs.ai_job_application_summaries_count` from the status rows (reader / count-repair site)."

## Notes (not disputes)
- Map line 745 "no `dependent:` option — relies on the migration FK for delete behavior": accurate. Migration `:6` uses `foreign_key: true` (no `on_delete`), so default RESTRICT, not cascade. Statement as written is correct.
- State-transition table (5.3 / Part 9): every value, writer, precondition, and resting/advancing actor verified against code. All AGREE.
- Desync windows #1-#8 (lines 778-785): each verified. #7 (`current` pointing at stale summary — `update_summary_status_record` has no `!stale?` guard) confirmed against `:69-80`. #4 stuck-`regenerating` no-credit confirmed against `:15` status-only write + `textract_result.rb:77/82`.

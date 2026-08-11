# X1 Adversarial Review — Pass 5

**Slice:** X1 — `AiJobApplicationSummaryStatus` table, whole-codebase reads + writes + state transitions + desync windows.
**Method:** Re-read all code from scratch; exhaustive grep of `app/` `lib/` for `AiJobApplicationSummaryStatus` / `ai_job_application_summary_status`; opened every reader/writer/serializer/frontend consumer the map cites; verified schema + migration line numbers.

## Census of EVERY Ruby reference (exhaustive grep, confirms map completeness)

Writers (4 total):
1. `find_or_create_ai_job_application_summary_status.rb:15` — `@status_record.update_columns(status: 'regenerating')` (status-only, bypasses counter_culture)
2. `find_or_create_ai_job_application_summary_status.rb:37` — create-path `@status_record.save` (sets `none` OR `current`+denormalized copy; fires counter_culture)
3. `textract_result.rb:104-107` — `set_initial_summary_pending` `update_columns(ai_job_application_summary_id:, status: 'initial_summary_pending')` (bypasses counter_culture)
4. `ai_job_application_summary.rb:74-80` — `update_summary_status_record` `.update(ai_job_application_summary_id: id, status: 'current', score_percentage:, headline:, integrated_role_analysis:)` (fires counter_culture); registered `after_commit ... on: :update` (`:30`)

Readers (Ruby): `queue_bulk_ai_summary_jobs.rb:36-40` (`status: :current`), `job_application.rb:106-113` (`fit_bands`/`unscored` scopes), serializers (`shallow_job_application_serializer.rb:23-24`, `job_application_serializer.rb:40-41`, `ai_job_application_summary_status_serializer.rb:4-10`), controller preloads (`job_applications_controller.rb:27,38,56`), counter_culture (`ai_job_application_summary_status.rb:7`).

No additional readers/writers exist beyond what the map documents. The map's X1 coverage is complete.

## Verdicts

All map claims for X1 verified AGREE against literal code. See structured output for the per-claim table. Highlights confirmed verbatim:
- Enum `{none:0, initial_summary_pending:1, current:2, regenerating:3}` _prefix:true (`ai_job_application_summary_status.rb:9-14`).
- No `regenerating` boolean column; columns per `db/schema.rb:168-179`.
- counter_culture with `column_names` mapping `status IN (2,3)` → `jobs.ai_job_application_summaries_count`; backing column present `db/schema.rb:907`; schema version `2026_06_22_182504` (`:13`).
- Regenerating-flip guarded on `summary&.status_succeeded?` (`:14`), status-only write keeps old denormalized data (`:15`), broadcasts `ai_summary_status_change` (`:16-20`).
- Create-path current guarded on `status_succeeded? && !stale?` (`:27`); none at `:34`; `context.fail!` on save fail (`:37-38`); RecordNotUnique rescue (`:43-44`).
- `set_initial_summary_pending` guard `:101-102`, write `:104-107`.
- `update_summary_status_record` guard `:69`, no-row early-return `:72`, write `:74-80`, re-points `ai_job_application_summary_id` unconditionally (`:75`), `ai_summary_succeeded` broadcast `:93-97`.
- All frontend consumers (NavItem `:17-18,26-29`, Container `:220,226,235,236`, PlatoTab `:41-46,127,129,130,50,52,151,154,210,218`, Activity `:79-91`, bulkAiSummaryCount `:37-41,46`, TS interface `:1-9`, websocket handlers) verified.
- No-optimistic-UI: `useJobApplication.ts:185` list key, `:229` setQueryData in `onSuccess` (block `:220`), no queryHook writes status via onMutate.

## Omissions (map could be more complete, not wrong)

1. **`update_summary_status_record` is `on: :update` only** (`ai_job_application_summary.rb:30`). The Part 9 "Lifecycle ownership" and the 5.3 writer table attribute the success-path `current` write but do not state that the callback is registered `on: [:update]`, so it NEVER fires on a summary CREATE. In practice harmless (the pipeline reaches `succeeded` via `.update`), but it is the literal trigger condition and belongs in the writer's precondition. Not a dispute (no path creates an already-succeeded summary), just an unstated registration detail.

2. **TS interface file path imprecision.** Map writes `jobApplication.ts:4` / `jobApplication.ts:1-9`; the actual file is `app/javascript/shared/types/jobApplication.ts`. Line numbers correct; full path omitted.

3. **counter_culture is conditional via BOTH a proc AND column_names** (`ai_job_application_summary_status.rb:7`). The map describes the `status IN (2,3)` `column_names` clause but does not mention the `column_name: proc { |model| (model.status_current? || model.status_regenerating?) ? '...' : nil }` half. Both halves are present in the literal; the map's behavioral summary (counts current+regenerating) is correct, but the proc is an undocumented part of the literal definition.

## clean = false (due to omissions above; every verdict is AGREE)

# Plato AI QA touchups: websocket event split, status polling, broadcast payloads, backfill ordering, db pool

Branch: `qa-refinements` → `develop` · 4 commits · 17 files (+162 / −48) · no migrations, no env var changes

## Realtime AI summary updates (websockets)

- Split the JobChannel `ai_summary_status_change` event by terminality in `AiJobApplicationSummary#broadcast_status_change`: `terminal_ai_summary_status_change` fires for `succeeded`, `failed`, and the initialization boundary (`pending`/`textract_processing` → `extracting`, detected by the new `generation_started_after_commit?`); every other transition fires `nonterminal_ai_summary_status_change`. A `retrying → extracting` re-entry is deliberately nonterminal.
- Both broadcast payloads (`AiJobApplicationSummary`, `AiJobApplicationSummaryStatus`) now include `status`.
- `WebsocketJobChannelHandler.tsx` handles the split: terminal events invalidate `aiJobApplicationSummary`, `jobApplication`, and `jobApplicationsForStage` queries; nonterminal events skip the stage-list invalidation. The `connected`/`disconnected`/`received` `window.logger` calls are re-enabled (logger is disabled in production via settings).
- `WebsocketContext.tsx` (ats): the ActionCable consumer is memoized with a `useState` lazy initializer. Previously `createConsumer` ran on every render of `WebsocketProvider`; the new consumer identity flowed into `WebsocketJobChannelHandler`'s `useCallback` dependency on `Websocket.subscriptions`, whose effect then unsubscribed and resubscribed — tearing down and reopening the `/cable` socket on every provider re-render (every window-focus `useGetMe` refetch, among others).

## Polling fallback for AI summary status

- `useAiJobApplicationSummary`: `refetchInterval` of 25s while the cached summary status is non-terminal; `false` once `succeeded`/`failed`.
- `useInfiniteJobApplicationsForStage`: `refetchInterval` of 30s while any cached row has `aiJobApplicationSummaryStatus.status` of `initial_summary_pending`/`regenerating` or `bulkAiSummaryProcessing: true`; `false` otherwise. (react-query 3.13.10 takes `refetchInterval` as `number | false` only, so both derive the value from the query's own cached data each render.)

## Hiring stage automation query efficiency

- New `HiringStage#kept_hiring_stage_message_automations` association (`kept`, ordered by `id`, preloadable).
- `Api::V1::HiringStageSerializer#hiring_stage_automation` reads that association instead of re-querying `hiring_stage_message_automations.kept` per stage.
- `Api::V1::JobApplicationsController#show` eager-loads it via `includes(job: { hiring_stages: :kept_hiring_stage_message_automations })`.

## Textract backfill: newest-first for the per-org task

- `TextractBackfillHelpers.per_org_eligible` orders `created_at: :desc` (was `:asc`).
- `textract_backfill_for_org` selects ids with `eligible_job_applications.limit(limit).pluck(:id, :created_at).map(&:first)` and enqueues with the existing staggered `wait:`. This replaces `find_each`, which silently discards declared ordering and batches by `id` ascending — so with a limit the task previously processed the oldest applications first. `created_at` rides along in the pluck because the relation carries `.distinct` (Postgres requires the `ORDER BY` column in the select list).
- Locals renamed per the variable naming convention: `relation`/`eligible` → `eligible_job_applications` in `bulk_app_ids`, `per_org_eligible`, and both per-org tasks. The all-orgs `textract_backfill` selection behavior is unchanged (`order(:id)`).

## Database connection pool

- `config/database.yml`: `pool: 12` (was `ENV.fetch("RAILS_MAX_THREADS") { 5 }`, resolving to 5 in production). Sidekiq's production concurrency is 10, so worker threads 6–10 starved for connections during job floods, raising `could not obtain a connection from the pool within 5 seconds`. The pool is a lazy ceiling — actual open connections stay bounded by thread counts (~56 worst case across 4 web + 2 worker dynos, against the standard-tier 120 limit). 12 covers the worker's 10 threads and the web process's 5 Puma + 4 ActionCable threads.

## Error logging

- `Rails.logger.error` added for scoring run failures (`ScoreJobApplication`) and non-200 API responses in `AiProviders::Openai`, `AiProviders::Gemini`, and `AiProviders::Anthropic` (previously `ap`-only, invisible in log drains).
- `TextractResult#update_summary_status_record`: `update_columns` → `update` on the status record.

## Tests

- `spec/models/ai_job_application_summary_spec.rb`: broadcast expectations updated for the `status` payload key and the terminality split; new tests for the `textract_processing → extracting` terminal boundary and the `retrying → extracting` nonterminal re-entry.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

# operational-concerns -- Round 2

## Verified

### Logging
- Service: `Rails.logger.error` + `ap` on API failure, JSON parse failure, and update failure -- context includes TextractResult ID and error message
- Job: `Rails.logger.error` + `ap` on CustomErrorStructuredExtraction (before re-raise), StandardError, and exhaustion
- Backfill: `ap` for progress (start, every 100 records, completion summary with processed/failed/total counts), `Rails.logger.error` + `ap` for per-record failures

### Error handling
- Service errors are caught and re-raised as `CustomErrorStructuredExtraction` (not `CustomErrorAiSummary`) -- ensures extraction errors don't trigger AI summary retry logic
- Job catches `CustomErrorStructuredExtraction` (re-raises for retry_on) and `StandardError` (logs and swallows) -- non-retryable errors don't crash the worker
- Exhaustion block logs and moves on -- extraction is supplementary, not critical
- Backfill: per-record `rescue StandardError` prevents cascade failure

### Performance
- Extraction runs asynchronously via Sidekiq `perform_later` -- no synchronous AI calls in the request/callback chain
- GIN index on `textsearch_vector` for search performance
- Backfill: `find_each(batch_size: 100)` for memory efficiency, `sleep 0.2` for OpenAI rate limiting
- Trigger-based tsvector update -- no application-level overhead for keeping search index in sync

### Deployment
- Data migration enqueues backfill job (does not iterate inline) -- deploy is not blocked by backfill
- Migrations are additive (new columns, new index, new trigger) -- no destructive changes, backward compatible
- `unless column_exists?` / `unless index_exists?` guards in tsvector migration prevent errors if reference migration was already applied

## Findings

No issues found.

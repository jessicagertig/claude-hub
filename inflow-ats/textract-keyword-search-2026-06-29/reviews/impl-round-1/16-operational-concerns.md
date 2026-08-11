# operational-concerns -- Round 1

## Findings

No issues found.

## Verified

### Logging
- **Service**: Logs errors with `Rails.logger.error` and `ap` for: update failure, API error (CustomErrorAiSummary), JSON parse error. Each log message includes the TextractResult ID for debugging.
- **Extraction job**: Logs with `ap` and `Rails.logger.error` for: retry (CustomErrorStructuredExtraction), non-retryable error (StandardError), exhaustion (includes TextractResult ID and error message).
- **Backfill job**: Logs with `ap` for: start, total count, progress every 100 records, per-record failures (with ID and error message), completion summary (processed/failed/total). Also logs per-record failures with `Rails.logger.error`.

### Error handling
- **Service**: Guards return early for missing record, no text, no organization -- no exception for expected conditions. API errors caught as CustomErrorAiSummary and re-raised as CustomErrorStructuredExtraction for retry isolation. JSON parse errors caught and re-raised as CustomErrorStructuredExtraction.
- **Extraction job**: `retry_on CustomErrorStructuredExtraction, wait: 5.minutes, attempts: 3` with exhaustion block that logs and stops. `rescue CustomErrorStructuredExtraction => e` + `raise` passes retryable errors to the retry mechanism. `rescue StandardError => e` catches non-retryable errors, logs, and stops without retry.
- **Backfill job**: Per-record `rescue StandardError => e` catches all errors (including CustomErrorStructuredExtraction) and continues. Correct for a backfill -- one record's failure should not stop processing.

### Performance
- **GIN index**: The `textsearch_vector` column has a GIN index, enabling efficient full-text search queries.
- **Postgres trigger**: `tsvector_update_trigger()` is a built-in C function -- minimal overhead per insert/update.
- **Backfill rate limiting**: `sleep 0.2` between records = max 5 records/second. With `find_each(batch_size: 100)`, records are loaded in batches of 100 from the database but processed sequentially with the sleep. This prevents overwhelming the OpenAI API.
- **No N+1 in service**: The service loads `textract_result.job_application`, then `job_application.job`, then `job.organization`. These are `belongs_to` associations that execute individual queries. Since the service processes one record at a time, this is acceptable -- no N+1 concern.
- **Column nullable**: All new columns are nullable with no defaults. Adding nullable columns to an existing table is a non-locking operation in PostgreSQL (no table rewrite needed).
- **Migration safety**: All three schema migrations are non-blocking: `add_column` with nullable columns, `add_index` using GIN, and `create_trigger`. The data migration only enqueues a job.

### Monitoring
- The backfill job logs progress every 100 records and a final summary. This provides visibility into backfill progress.
- Per-record failures in the backfill are logged with the specific TextractResult ID, enabling targeted re-investigation.
- The extraction job's exhaustion block logs the specific TextractResult ID that exhausted retries.

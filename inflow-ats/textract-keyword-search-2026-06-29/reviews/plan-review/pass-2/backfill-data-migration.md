# Pass 2 — backfill-data-migration

## Pass 1 corrections
None needed. Pass 1 found 0 findings.

## Fresh scrutiny

### Backfill job has no retry_on
- `BackfillStructuredExtractionJob` has no `retry_on` declaration
- If the job itself crashes (not individual records), Sidekiq's default retry behavior handles it
- The IS NULL scope means re-running (whether via Sidekiq retry or manual enqueue) picks up where it left off
- Individual record failures are caught by `rescue StandardError` inside `find_each`
- **Acceptable** — the per-record rescue + resumable scope is the right pattern for a bulk operation

### Service errors in backfill context
- Service raises `CustomErrorStructuredExtraction` on API/parse failure
- `CustomErrorStructuredExtraction < StandardError`
- Backfill's `rescue StandardError` in the `find_each` block catches it
- Error is logged and iteration continues to next record
- **Correct** — no unhandled errors escape the find_each block

### Count accuracy during backfill
- `total = textract_results_scope.count` is computed before iteration
- New records processed by the real-time path during backfill won't be in the original scope (they'll have `structured_extraction` populated)
- Records that fail during backfill still have `structured_extraction: nil` and would be included in a re-count
- The `total` is for logging only — it doesn't affect correctness
- **Acceptable**

### Data migration timing in deploy pipeline
- Schema migrations (steps 2.1-2.3) run in `db:migrate`
- Data migration (step 7.2) runs in `data:migrate` (or `data:migrate:up`)
- The data migration depends on the `structured_extraction` column existing (created in step 2.1) and the service class existing
- In a deploy, schema migrations run before data migrations. Code is deployed before migrations run.
- The `BackfillStructuredExtractionJob` class must exist when the data migration fires `perform_later`
- Since code deploys before migrations: the job class will exist when the data migration enqueues it. Correct.

### Backfill does not re-trigger callbacks
- Verified in Pass 1: `textract_result.update(structured_extraction:, structured_extraction_text:)` does NOT trigger `saved_change_to_textract_job_result_text?`
- Neither `queue_ai_summary_job` nor `queue_structured_extraction_job` fires during backfill
- **Re-confirmed** — no duplicate job enqueuing during backfill

### Backfill volume and timing
- Plan Risk #2: "10,000 records would take ~33 minutes" with sleep 0.2
- Each record also makes a GPT-4o-mini API call (latency varies, typically 1-3 seconds)
- Actual time per record: ~1.2-3.2 seconds (API call + 0.2s sleep)
- 10,000 records: ~3.3-8.9 hours, not 33 minutes
- The plan's 33-minute estimate only accounts for sleep time, not API latency
- **Not a finding** — the estimate is conservative in the wrong direction but the approach (async background job) handles any duration. The job runs until complete.

## Completeness sweep

All spec requirements for backfill verified present:
- Scoping (succeeded + null extraction + non-empty text): step 7.1
- Rate limiting (find_each + sleep 0.2): step 7.1
- Resumability (IS NULL guard): step 7.1
- Uses same service: step 7.1
- Per-record error handling: step 7.1
- Data migration enqueues job: step 7.2
- IrreversibleMigration on down: step 7.2

## Findings

0 BLOCKER, 0 HIGH, 0 MED, 0 LOW

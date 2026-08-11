# Backfill Data Migration

## Verdict: PASS

### Findings

None.

### Verification

- Data migration `EnqueueStructuredExtractionBackfill` only calls `BackfillStructuredExtractionJob.perform_later` — does not iterate records or call GPT-4o-mini inline. Does not block deploys.
- `down` raises `ActiveRecord::IrreversibleMigration` — matches reference backfill pattern (`db/data/20260106200000_backfill_textract_tsvector.rb`).
- Backfill job scope matches spec exactly:
  - `textract_job_status: :succeeded` — only succeeded records
  - `structured_extraction: nil` — only unprocessed records
  - `where.not(textract_job_result_text: [nil, ''])` — skips records with empty OCR text
- Uses `find_each(batch_size: 100)` for memory efficiency
- `sleep 0.2` between records for OpenAI rate limiting
- Per-record `rescue StandardError` — logs error with `textract_result.id` and continues to next record
- Uses the same `ExtractStructuredResumeData` service as the real-time path — no separate extraction implementation
- Resumable: the `structured_extraction: nil` scope guard means re-running picks up records that failed or were not yet processed on a prior run
- Progress logging: `ap` output every 100 records plus final summary (processed/failed/total)
- Expected deviation from reference backfill: reference uses raw SQL `UPDATE ... SET textsearch_vector = to_tsvector(...)`, but new backfill MUST call the service because it needs the GPT-4o-mini extraction step. The tsvector update happens automatically via the Postgres trigger when `structured_extraction_text` is written by the service.

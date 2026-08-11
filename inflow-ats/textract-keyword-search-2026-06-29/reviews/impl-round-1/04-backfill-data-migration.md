# backfill-data-migration -- Round 1

## Findings

No issues found.

## Verified

- **Scoping**: `TextractResult.where(textract_job_status: :succeeded, structured_extraction: nil).where.not(textract_job_result_text: [nil, ''])` -- matches spec exactly. Filters to succeeded status, NULL structured_extraction (not yet processed), and non-empty text (prevents wasting API calls on records with empty OCR text).

- **Rate limiting**: `sleep 0.2` between records per spec. With `find_each(batch_size: 100)` for memory efficiency.

- **Resumability**: The `structured_extraction: nil` scope means re-running the job picks up records that failed or were not yet processed. Successfully processed records have non-nil `structured_extraction` and are skipped.

- **Uses same service**: `ExtractStructuredResumeData.new(textract_result_id: textract_result.id).extract` -- same service as the real-time path. No separate extraction implementation.

- **Per-record error handling**: `rescue StandardError => e` inside the `find_each` block catches any error (including `CustomErrorStructuredExtraction` which is a subclass of StandardError), logs with `Rails.logger.error` and `ap`, increments `failed` counter, and continues to next record. This is correct for a backfill -- one record's failure should not stop the entire job.

- **Data migration**: `EnqueueStructuredExtractionBackfill` at `db/data/20260630050055_enqueue_structured_extraction_backfill.rb` only calls `BackfillStructuredExtractionJob.perform_later` in `up`. Does not iterate records or call GPT-4o-mini inline, avoiding deploy blocking. `down` raises `ActiveRecord::IrreversibleMigration` per reference pattern.

- **Expected deviation from reference**: The reference backfill (`backfill_textract_tsvector.rb`) uses raw SQL `UPDATE ... SET textsearch_vector = to_tsvector(...)`. The new backfill CANNOT use raw SQL because it needs the GPT-4o-mini extraction step. The tsvector update happens automatically via the Postgres trigger when `structured_extraction_text` is written by the service. This is a correct and expected deviation per spec.

- **Migration ordering**: Data migration timestamp (050055) is after schema migrations (050052, 050053) and trigger migration (050054), ensuring the columns, index, and trigger exist before backfill runs.

- **Progress logging**: Reports progress every 100 records and final summary (processed/failed/total) via `ap`.

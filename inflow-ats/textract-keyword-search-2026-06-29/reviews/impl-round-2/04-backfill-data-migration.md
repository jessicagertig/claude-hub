# backfill-data-migration -- Round 2

## Verified

- Scoping: `TextractResult.where(textract_job_status: :succeeded, structured_extraction: nil).where.not(textract_job_result_text: [nil, ''])` -- matches spec exactly (succeeded + no extraction yet + has text)
- Rate limiting: `find_each(batch_size: 100)` + `sleep 0.2` per record
- Resumability: `structured_extraction: nil` scope means re-running picks up unprocessed or failed records
- Same service: `ExtractStructuredResumeData.new(textract_result_id: textract_result.id).extract` -- identical to real-time path
- Per-record error handling: `rescue StandardError => e` inside `find_each` block, logs and continues
- Progress logging: every 100 records + final summary (processed/failed/total)
- Data migration: `BackfillStructuredExtractionJob.perform_later` -- enqueues job, does not iterate inline. `def down` raises `ActiveRecord::IrreversibleMigration`
- Expected deviation from reference: reference uses raw SQL `UPDATE`, implementation uses service (needs GPT-4o-mini call) -- spec-approved

## Findings

No issues found.

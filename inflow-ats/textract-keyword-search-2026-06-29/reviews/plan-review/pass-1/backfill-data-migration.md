# Pass 1 — backfill-data-migration

## Fact Check

### Scoping (plan step 7.1)
- Plan: `textract_job_status: :succeeded`, `structured_extraction: nil`, `.where.not(textract_job_result_text: [nil, ''])`
- Spec: "textract_job_status = succeeded AND structured_extraction IS NULL AND textract_job_result_text IS NOT NULL AND textract_job_result_text != ''"
- The `:succeeded` symbol is correctly translated by Rails enum to integer 2 (confirmed enum definition: `succeeded: 2`)
- Empty string check prevents wasting API calls on records with empty OCR text
- **VERIFIED** -- matches spec exactly

### Rate limiting (plan step 7.1)
- `find_each(batch_size: 100)` for memory efficiency
- `sleep 0.2` per record -- at 10,000 records, ~33 minutes. Runs as background job
- **VERIFIED** -- matches spec

### Resumability (plan step 7.1)
- `structured_extraction: nil` scope ensures re-running picks up records that failed or were not yet processed
- Successfully processed records have `structured_extraction` populated, so they are excluded
- **VERIFIED**

### Uses same service (plan step 7.1)
- `ExtractStructuredResumeData.new(textract_result_id: textract_result.id).extract`
- Same service as the real-time path (plan step 4.1)
- **VERIFIED** -- no separate extraction implementation

### Per-record error handling (plan step 7.1)
- `rescue StandardError => e` inside `find_each` block
- Logs error with `textract_result.id` and continues to next record
- `CustomErrorStructuredExtraction` (from service re-raise of `CustomErrorAiSummary`) is a `StandardError` subclass -- caught here
- Backfill does NOT retry individual records -- logs and moves on. Re-running the backfill picks up failures via the `IS NULL` guard
- **VERIFIED**

### No callback re-triggering during backfill
- Service updates `structured_extraction` and `structured_extraction_text`, NOT `textract_job_result_text`
- `queue_structured_extraction_job` guard: `saved_change_to_textract_job_result_text?` is FALSE -- returns early
- `queue_ai_summary_job` guard: `saved_change_to_textract_job_result_text?` is FALSE -- returns early
- No duplicate jobs enqueued during backfill
- **VERIFIED**

### Data migration (plan step 7.2)
- `def up`: `BackfillStructuredExtractionJob.perform_later` -- only enqueues, does not iterate
- `def down`: `raise ActiveRecord::IrreversibleMigration` -- matches reference backfill pattern
- Inherits `ActiveRecord::Migration[6.1]` -- matches reference
- Does NOT block deploys (job runs asynchronously)
- **VERIFIED**

### Reference comparison
- Reference backfill (`20260106200000_backfill_textract_tsvector.rb`): raw SQL `UPDATE ... SET textsearch_vector = to_tsvector(...)` with `WHERE textract_job_result_text IS NOT NULL AND textsearch_vector IS NULL`
- Plan: service call per record (needs GPT-4o-mini extraction step)
- **EXPECTED DEVIATION** documented in spec and plan. The tsvector update happens automatically via the trigger when `structured_extraction_text` is written

## Completeness

| Spec requirement | Plan step | Status |
|-----------------|-----------|--------|
| Scope: succeeded + null extraction + non-empty text | 7.1 | Present |
| Rate limiting: find_each + sleep 0.2 | 7.1 | Present |
| Resumability: IS NULL guard | 7.1 | Present |
| Uses same service as real-time path | 7.1 | Present |
| Per-record error handling: rescue + continue | 7.1 | Present |
| Data migration enqueues job (not inline) | 7.2 | Present |
| Down: IrreversibleMigration | 7.2 | Present |

## Findings

0 BLOCKER, 0 HIGH, 0 MED, 0 LOW

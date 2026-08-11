# Data Integrity & Security

## Verdict: PASS

### Findings

None.

### Verification

- New columns are nullable -- no NOT NULL constraint issues with existing records
- No data loss risk -- new columns add data, don't modify or remove existing columns
- Trigger only writes to `textsearch_vector` based on `structured_extraction_text` -- does not modify any other column
- The `update` in the service writes only `structured_extraction` and `structured_extraction_text` -- does not modify `textract_job_result_text` or `textract_job_status`
- Backfill scoping: `textract_job_status: :succeeded` AND `structured_extraction: nil` AND text present -- does not touch non-succeeded records or already-processed records
- Per-record error handling in backfill -- a single record failure does not abort the entire backfill
- No raw SQL in app code (only in migration trigger definitions) -- all data access through ActiveRecord
- AiApiRequest creation does not include sensitive data -- `prompt_text` is the messages array (resume text sent to API), `response_body` is the structured extraction result; both are already stored on TextractResult and AiJobApplicationSummary respectively
- No new endpoints, controllers, or serializers -- no new attack surface
- The `call_type: 'keyword_extraction'` is a distinct string -- does not conflict with existing `'extraction'` call type in the summary pipeline

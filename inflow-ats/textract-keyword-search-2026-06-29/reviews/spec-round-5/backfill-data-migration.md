# Backfill Data Migration — Round 5

## Findings

No issues found.

## Verified

- **Scoping** (spec line 218): `textract_job_status = succeeded` AND `structured_extraction IS NULL` AND `textract_job_result_text IS NOT NULL AND != ''`. The `succeeded` status is enum value 2 (model line 11). The text presence check prevents wasting API calls on empty OCR text. The `IS NULL` guard provides resumability.
- **Data-migration-enqueues-job pattern** (spec line 216): Data migration only enqueues the backfill job, doesn't iterate records. Avoids blocking deploys. Novel in this codebase (existing data migrations iterate inline) but sound given API-call-per-record constraint.
- **Rate limiting** (spec line 220): `find_each(batch_size: 100)` with `sleep 0.2` — 5 requests/second = 300 RPM, well within GPT-4o-mini limits.
- **Per-record error handling** (spec line 222): Rescue API errors per record, log with `textract_result.id`, continue. The `IS NULL` guard means re-running picks up failed records.
- **Same service** (spec line 224): Calls `ExtractStructuredResumeData` — same as real-time path.
- **Expected deviation documented** (spec line 226): Reference uses raw SQL UPDATE; new backfill must call the service for GPT-4o-mini extraction. Tsvector update via trigger is automatic.

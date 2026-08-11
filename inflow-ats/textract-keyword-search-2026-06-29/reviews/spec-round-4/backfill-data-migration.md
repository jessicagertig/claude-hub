# Backfill Data Migration — Round 4

## Findings

No issues found.

## Verified

- **Scoping** (spec line 218): `textract_job_status = succeeded` AND `structured_extraction IS NULL` AND `textract_job_result_text IS NOT NULL AND != ''`. All three conditions verified necessary: status for correct records, IS NULL for idempotency/resumability, text presence to avoid wasting API calls on empty text.
- **Data-migration-enqueues-job** (spec line 216): Novel in codebase (checked `db/data/` — existing migrations iterate inline) but sound trade-off for API-call-per-record workload. Avoids blocking deploys. Acknowledged as LOW in Round 2.
- **Rate limiting** (spec line 220): `find_each(batch_size: 100)` with `sleep 0.2` per record = ~300 RPM. GPT-4o-mini rate limits are generous (thousands RPM for most tiers). Conservative but appropriate — avoids burst issues.
- **Per-record error handling** (spec line 222): Rescue API errors, log with `textract_result.id`, continue. IS NULL guard ensures re-run picks up failed records. Complete.
- **Same service** (spec line 224): Uses `ExtractStructuredResumeData` (same as real-time path). No separate implementation.
- **Expected deviation** (spec line 226): Documented — reference uses raw SQL UPDATE, new backfill uses service for GPT-4o-mini extraction. Tsvector update via trigger. Correctly documented as expected deviation.
- **Reference comparison**: Reference backfill (`20260106200000_backfill_textract_tsvector.rb`) uses `execute(<<-SQL)` with `UPDATE textract_results SET textsearch_vector = to_tsvector(...)`. New approach correctly deviates for API-call requirement.

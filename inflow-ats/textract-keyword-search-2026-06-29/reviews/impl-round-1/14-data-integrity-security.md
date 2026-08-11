# data-integrity-security -- Round 1

## Findings

No issues found.

## Verified

- **No direct database access**: No `psql`, no raw SQL reads or writes outside of migrations. The service writes via ActiveRecord `update`. The backfill reads via ActiveRecord `where`/`find_each`. Migration trigger uses `create_trigger` (fx gem API) and `execute` for DROP TRIGGER only. All compliant with database safety rules.

- **No .env modification**: Branch does not touch any `.env` files.

- **No DATABASE_URL setting**: No environment variable manipulation in any file.

- **Authorization**: The service runs in a background job context, not in a request/controller context. No Pundit policy needed. The extraction is triggered by `after_commit` on TextractResult, which only fires when a legitimate Textract success updates the record. No user-facing endpoint is added.

- **Data validation**: `TextractResult.update(structured_extraction:, structured_extraction_text:)` uses standard ActiveRecord validation. The return value is checked with if/else. On failure, the error is logged but not re-raised (the extraction is supplementary).

- **AiApiRequest integrity**: The `create_ai_api_request` method uses `AiApiRequest.create` (not `create!`). If it fails, no exception is raised and the extraction result is still saved on the TextractResult (the AiApiRequest is created AFTER the successful update). This means a transient AiApiRequest failure does not roll back the extraction.

- **No data leakage**: New columns are not exposed through any serializer, controller, or API endpoint. The `structured_extraction` jsonb could contain PII (name, email, phone from the resume), but it's stored in the same table as `textract_job_result_text` which already contains the raw resume text including all PII. No new exposure surface.

- **Polymorphic association safety**: `has_many :ai_api_requests, as: :requestable` uses the existing polymorphic pattern. The `ai_api_requests` table already has `requestable_type` and `requestable_id` columns. Adding TextractResult as a new `requestable_type` does not require a migration -- polymorphic associations are open to new types by design.

- **Backfill safety**: The backfill uses per-record `rescue StandardError` and continues on failure. It does not wrap multiple records in a transaction -- each record is processed independently. No risk of a failed record rolling back successful ones.

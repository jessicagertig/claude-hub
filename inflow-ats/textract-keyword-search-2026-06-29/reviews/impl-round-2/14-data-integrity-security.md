# data-integrity-security -- Round 2

## Verified

- **Authorization:** service accesses data via `textract_result.job_application.job.organization` -- follows the existing data access pattern. No new public endpoints added. No new controller actions. No serializer changes. The search method exists on the model but is not exposed via any API endpoint in this branch
- **Validation:** `@textract_result.update(...)` return value is checked with `if/else` -- failure path logs error. No bang methods in app code
- **Data consistency:** Postgres `tsvector_update_trigger()` maintains `textsearch_vector` in sync with `structured_extraction_text` at the database level -- no application-level synchronization needed, no risk of stale tsvector
- **Polymorphic association:** `has_many :ai_api_requests, as: :requestable` matches existing associations on `AiJobApplicationSummary` (line 6) and `AiJobCriteria` (line 5). `AiApiRequest` has `belongs_to :requestable, polymorphic: true` at line 5 -- compatible
- **AiApiRequest creation:** `call_type: 'keyword_extraction'` is distinct from the summary pipeline's `'extraction'` -- no collision in cost reporting
- **Backfill safety:** per-record `rescue StandardError` prevents one failure from stopping the entire backfill. `structured_extraction: nil` scope makes it resumable

## Findings

No issues found.

# backward-compatibility -- Round 1

## Findings

No issues found.

## Verified

- **Serializer exposure**: Grep of `app/serializers/` for `textract_result` returned zero results. No serializer references TextractResult columns. New columns (`structured_extraction`, `structured_extraction_text`, `textsearch_vector`) cannot leak to the frontend via serializers.

- **Controller exposure**: Grep of `app/controllers/` for `TextractResult` returned zero results. No controller directly queries or returns TextractResult data. The only code path that creates/updates TextractResult is `GetResumeTextFromTextract` (a backend service), which does not expose the record to API responses.

- **PgSearch::Model include**: `include PgSearch::Model` adds class methods (`pg_search_scope`, `with_pg_search_rank`, `with_pg_search_highlight`) and does not override any existing instance or class methods on TextractResult. No scope name collision -- `search_resume_text` and `search_resume_by_keyword` are new additions not conflicting with any existing method.

- **exclude_job_result method**: Grep of `app/` for `exclude_job_result` returned zero results -- the method is defined on TextractResult but never called anywhere. The new columns would be included by this method's `select(*)` approach (it only excludes `textract_job_result`), but since it's never called, there is no exposure risk.

- **Nullable columns**: All three new columns (`structured_extraction`, `structured_extraction_text`, `textsearch_vector`) are nullable with no defaults. Existing records will have NULL values in these columns until the backfill runs. The Postgres `tsvector_update_trigger()` built-in handles NULL `structured_extraction_text` gracefully by setting `textsearch_vector` to NULL -- no error on insert/update of existing records.

- **has_many :ai_api_requests**: Adding `has_many :ai_api_requests, as: :requestable` to TextractResult follows the existing pattern on `AiJobApplicationSummary` (line 6) and `AiJobCriteria` (line 5). This is a polymorphic association -- no migration needed since `ai_api_requests` already has `requestable_type` and `requestable_id` columns. No backward compatibility risk.

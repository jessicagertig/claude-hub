# backward-compatibility -- Round 2

## Verified

- New columns don't leak to frontend: no serializers reference `TextractResult` (`grep -rn 'TextractResult' app/serializers/` and `grep -rn 'textract_result' app/serializers/` both return empty). No controller returns TextractResult columns directly. New columns (`structured_extraction`, `structured_extraction_text`, `textsearch_vector`) are not exposed in any API response
- `include PgSearch::Model` does not conflict: the reference implementation already uses this include on TextractResult and it works. No existing scopes named `search_resume_text` on the branch before this change
- `search_resume_by_keyword` class method: no existing method with this name on TextractResult (new to this branch)
- Nullable tsvector column: Postgres `tsvector_update_trigger()` handles NULL `structured_extraction_text` gracefully by setting `textsearch_vector` to NULL -- no error
- `has_many :ai_api_requests, as: :requestable`: follows existing pattern on `AiJobApplicationSummary` and `AiJobCriteria`. No method name collision -- `ai_api_requests` is not already defined on TextractResult

## Findings

No issues found.

# spec-compliance -- Round 1

## Findings

- F1 [HIGH] `db/schema.rb` not committed with migrations. The spec requires 3 schema migrations + 1 data migration. All four are committed. But schema.rb, which is the canonical record of database state, was not committed alongside the migrations. Migrations ran locally (schema.rb on disk has the columns), but the committed schema.rb on the branch does not include `structured_extraction`, `structured_extraction_text`, `textsearch_vector`, the GIN index, or the trigger definition. Merging this branch without the schema.rb update would leave the repository's schema.rb out of sync with the migrations. **(Cross-referenced with source-accuracy F1.)**

## Verified

Every spec requirement was checked against the implementation:

| Spec requirement | Implementation | Status |
|---|---|---|
| `structured_extraction` jsonb column | Migration 20260630050052 | PRESENT |
| `structured_extraction_text` text column | Migration 20260630050052 | PRESENT |
| `textsearch_vector` tsvector + GIN index | Migration 20260630050053 | PRESENT |
| fx trigger with `structured_extraction_text` source | Migration 20260630050054 | PRESENT |
| `CustomErrorStructuredExtraction` error class | `app/errors/custom_error_structured_extraction.rb` | PRESENT, matches analog |
| Service: `ExtractStructuredResumeData#extract` | `app/services/extract_structured_resume_data.rb` | PRESENT |
| Service takes TextractResult ID (not object) | Constructor `initialize(textract_result_id:)` | CORRECT |
| Service uses existing prompt/schema class | Calls `ResumeStructuredData.messages`, `.model`, `.response_format` | CORRECT |
| Service includes `job_title` in extraction | `job_title = @textract_result.job_application.job&.title` | CORRECT |
| Service creates AiApiRequest with `call_type: 'keyword_extraction'` | `create_ai_api_request` method, line 97 | CORRECT |
| Service re-raises `CustomErrorAiSummary` as `CustomErrorStructuredExtraction` | `rescue CustomErrorAiSummary => e ... raise CustomErrorStructuredExtraction` | CORRECT |
| Service re-raises `JSON::ParserError` as `CustomErrorStructuredExtraction` | `rescue JSON::ParserError => e ... raise CustomErrorStructuredExtraction` | CORRECT |
| Flattening: all non-null scalars, array items, sub-fields; newline-separated; no JSON syntax; no labels | `flatten_structured_data` private method | CORRECT |
| `include PgSearch::Model` on TextractResult | Line 4 | CORRECT |
| `has_many :ai_api_requests, as: :requestable` | Line 8 | CORRECT |
| `pg_search_scope` matches reference (only `against:` changes) | Lines 20-38 | CORRECT |
| `search_resume_by_keyword` matches reference exactly | Lines 43-52 | CORRECT |
| `after_commit` callback with same guards | Lines 11, 184-188 | CORRECT |
| Background job with `retry_on CustomErrorStructuredExtraction, wait: 5.minutes, attempts: 3` | `extract_structured_resume_data_job.rb:6-9` | CORRECT |
| Exhaustion block: log and move on | Lines 7-9 (ap + Rails.logger.error) | CORRECT |
| Backfill job with `find_each(batch_size: 100)`, `sleep 0.2`, per-record rescue | `backfill_structured_extraction_job.rb:21-29` | CORRECT |
| Data migration enqueues backfill job (not inline) | `db/data/20260630050055_enqueue_structured_extraction_backfill.rb:5` | CORRECT |
| `fx` gem added to Gemfile | `gem 'fx', '~> 0.8.0'` at line 126 | CORRECT |
| `pg_search` already in Gemfile (no change) | Line 125, version 2.3.2 | CORRECT |
| AI summary pipeline unchanged | Not in diff | CORRECT |
| No frontend changes | Not in diff | CORRECT |
| No controller/serializer changes | Not in diff | CORRECT |
| Test coverage for all spec requirements | 3 new spec files (548 total lines) | PRESENT |

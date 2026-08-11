# spec-compliance -- Round 2

## Verified

Every spec requirement checked against the implementation:

| Spec requirement | Implementation | Status |
|---|---|---|
| `structured_extraction` jsonb column on `textract_results` | Migration `20260630050052` | PRESENT |
| `structured_extraction_text` text column | Same migration | PRESENT |
| `textsearch_vector` tsvector column + GIN index | Migration `20260630050053` | PRESENT |
| Postgres trigger auto-updates tsvector on `structured_extraction_text` change | Migration `20260630050054` with `tsvector_update_trigger()` | PRESENT |
| `fx` gem added | Gemfile line 126, Gemfile.lock | PRESENT |
| Service takes TextractResult ID (not object) | `initialize(textract_result_id:)` with `find_by` | PRESENT |
| Public method `extract` (not `call`) | `def extract` | PRESENT |
| Uses same prompt and schema as existing extraction | `ResumeStructuredData.messages`, `.model`, `.response_format` | PRESENT |
| Creates `AiApiRequest` with `call_type: 'keyword_extraction'` | `create_ai_api_request` method | PRESENT |
| `requestable: textract_result` (not ai_summary) | `requestable: @textract_result` | PRESENT |
| Re-raises `CustomErrorAiSummary` as `CustomErrorStructuredExtraction` | `rescue CustomErrorAiSummary => e` + `raise CustomErrorStructuredExtraction` | PRESENT |
| `include PgSearch::Model` on TextractResult | Line 4 | PRESENT |
| `pg_search_scope` matches reference (only `against:` changes) | Lines 20-38 | PRESENT |
| `search_resume_by_keyword` matches reference | Lines 43-51 | PRESENT |
| `has_many :ai_api_requests, as: :requestable` | Line 8 | PRESENT |
| `after_commit` callback with same guards as existing | Lines 11, 184-188 | PRESENT |
| Background job: `retry_on CustomErrorStructuredExtraction, wait: 5.minutes, attempts: 3` | Job lines 6-10 | PRESENT |
| Exhaustion: log and move on | Exhaustion block logs with `ap` + `Rails.logger.error` | PRESENT |
| Backfill: `find_each(batch_size: 100)`, `sleep 0.2`, per-record rescue | `backfill_structured_extraction_job.rb` lines 20-29 | PRESENT |
| Data migration enqueues backfill job (not inline) | `20260630050055` calls `perform_later` | PRESENT |
| Existing AI summary pipeline unchanged | `git diff develop -- generate.rb` returns empty | PRESENT |
| No frontend changes | No frontend files in diff | PRESENT |
| No controller/serializer changes | No controller/serializer files in diff | PRESENT |

## Findings

No issues found. Implementation matches spec completely.

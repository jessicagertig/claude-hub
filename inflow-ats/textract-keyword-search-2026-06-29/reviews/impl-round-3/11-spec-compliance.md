# Spec Compliance

## Verdict: PASS

### Findings

None.

### Verification

Every spec item checked against the committed implementation:

- `structured_extraction` jsonb column: nullable, no default
- `structured_extraction_text` text column: nullable, no default
- `textsearch_vector` tsvector + GIN index
- fx trigger with `sql_definition:` inline: uses `tsvector_update_trigger()` built-in with `'pg_catalog.simple'` and `'structured_extraction_text'`
- `CustomErrorStructuredExtraction`: matches `CustomErrorTextract` pattern exactly (attr_reader :param, default msg, super(msg))
- Service `ExtractStructuredResumeData#extract`: takes ID via keyword arg `textract_result_id:`, uses existing prompt class
- Service creates `AiApiRequest` with `call_type: 'keyword_extraction'`: distinct from summary pipeline's `'extraction'`
- Service re-raises `CustomErrorAiSummary` as `CustomErrorStructuredExtraction`
- Flattening algorithm: all non-null scalars, array-of-string items, array-of-object sub-fields; newline-separated; no JSON syntax; no field labels
- `include PgSearch::Model`: at top of class body, before associations
- `has_many :ai_api_requests, as: :requestable`: matches `AiJobApplicationSummary` and `AiJobCriteria` analogs
- `pg_search_scope` changes only `against:` from `:textract_job_result_text` to `:structured_extraction_text` (verified side-by-side with reference)
- `search_resume_by_keyword` matches reference character-for-character
- `after_commit :queue_structured_extraction_job, on: [:create, :update]` with guards `textract_job_result_text.present?` and `saved_change_to_textract_job_result_text?`
- Background job: `retry_on CustomErrorStructuredExtraction, wait: 5.minutes, attempts: 3` with exhaustion block (ap + Rails.logger.error)
- Backfill job: `find_each(batch_size: 100)`, `sleep 0.2`, per-record `rescue StandardError`
- Data migration: enqueues `BackfillStructuredExtractionJob.perform_later`, `raise ActiveRecord::IrreversibleMigration` in `down`
- `gem 'fx', '~> 0.8.0'` added to Gemfile
- Existing AI summary pipeline unchanged: `generate.rb` and `get_resume_text_from_textract.rb` both unmodified on branch
- No frontend changes
- No controller/serializer changes

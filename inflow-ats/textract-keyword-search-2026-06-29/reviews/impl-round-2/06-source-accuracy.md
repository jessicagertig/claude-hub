# source-accuracy -- Round 2

## Verified

- `TextractResult` model: exists at `app/models/textract_result.rb`, has `belongs_to :job_application`, `has_many :ai_job_application_summaries`, enum `textract_job_status`, `after_commit :queue_ai_summary_job`
- `ExtractStructuredResumeData` service: exists at `app/services/extract_structured_resume_data.rb`
- `ExtractStructuredResumeDataJob`: exists at `app/jobs/extract_structured_resume_data_job.rb`
- `BackfillStructuredExtractionJob`: exists at `app/jobs/backfill_structured_extraction_job.rb`
- `CustomErrorStructuredExtraction`: exists at `app/errors/custom_error_structured_extraction.rb`, matches `CustomErrorTextract` and `CustomErrorAiSummary` patterns
- `AiJobApplicationAction::Summary::Prompts::ResumeStructuredData`: exists, has `.messages(resume_text:, job_title:)`, `.model` (returns `'gpt-4o-mini'`), `.response_format` (returns `JSON_SCHEMA`)
- `AiClient`: has `.new(provider: 'openai')`, `.chat(messages:, model:, response_format:)`, `.calculate_cost`
- `AiApiRequest`: has `belongs_to :requestable, polymorphic: true` at `app/models/ai_api_request.rb:5`
- `has_many :ai_api_requests, as: :requestable`: matches analogs at `AiJobApplicationSummary` (line 6) and `AiJobCriteria` (line 5)
- `pg_search` 2.3.2: in Gemfile at line 125
- `fx` ~> 0.8.0: in Gemfile at line 126, resolved as `fx (0.8.0)` in Gemfile.lock
- `tsvector_update_trigger`: real Postgres built-in function, argument signature `(tsvector_column, dictionary, source_column)` -- correct
- No serializers reference TextractResult: `grep -rn 'TextractResult' app/serializers/` returns empty; `grep -rn 'textract_result' app/serializers/` also returns empty

## Findings

No issues found.

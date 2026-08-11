# source-accuracy -- Round 1

## Findings

- F1 [HIGH] `db/schema.rb` not committed. The branch has 3 schema migrations and 1 data migration committed, and the developer ran `rails db:migrate` locally (schema.rb on disk has the new columns, GIN index, and trigger), but schema.rb changes were never staged or committed. `git status db/schema.rb` shows `modified: db/schema.rb` (unstaged). `git show textract-text-to-ts-vector:db/schema.rb` confirms the committed schema.rb does NOT have `structured_extraction`, `structured_extraction_text`, or `textsearch_vector` columns. **Recommended fix:** stage and commit `db/schema.rb`.

## Verified

- **textract_results table**: Exists in `db/schema.rb` with original columns `textract_job_id`, `textract_job_status`, `textract_job_result`, `textract_job_result_text`, `job_application_id`, timestamps. New columns exist only in the working-tree schema.rb (see F1).
- **GetResumeTextFromTextract**: Exists at `app/services/get_resume_text_from_textract.rb` with `parse_resume_text` method (lines 8-49). Success path at line 31 calls `@textract_result.update(update_textract_params)`.
- **TextractResult model**: Has `after_commit :queue_ai_summary_job, on: [:create, :update]` at line 10 (original) and new `after_commit :queue_structured_extraction_job` at line 11.
- **pg_search gem**: Version 2.3.2 confirmed in Gemfile line 125 and Gemfile.lock. Compatible with Ruby 3.1 / Rails 6.1 / activerecord 6.1.7.7. Already used in 4 models (Candidate, Organization, Job, User).
- **fx gem**: ~> 0.8.0 in Gemfile, resolved to 0.8.0 in Gemfile.lock. Requires activerecord >= 6.0.0 and railties >= 6.0.0 -- compatible with Rails 6.1.
- **ResumeStructuredData**: Exists at `app/services/ai_job_application_action/summary/prompts/resume_structured_data.rb`. Has `.messages(resume_text:, job_title:)`, `.model` (returns 'gpt-4o-mini'), `.response_format` (returns JSON_SCHEMA). Schema has all 11 required fields matching the spec.
- **tsvector_update_trigger**: Built-in Postgres function. Signature: `tsvector_update_trigger(tsvector_column_name, dictionary, source_column_name)`. Implementation uses `('textsearch_vector', 'pg_catalog.simple', 'structured_extraction_text')` -- correct.
- **AiProviders::Openai**: Confirmed at `app/services/ai_providers/openai.rb`. Raises `CustomErrorAiSummary` on API error (line 23), Faraday::Error (line 35), JSON::ParserError (line 38). Returns `{ content:, input_tokens:, output_tokens:, model: }` hash.

# Source Accuracy

## Verdict: PASS

### Findings

None.

### Verification

- `textract_results` table confirmed in `db/schema.rb` on disk with new columns (`structured_extraction`, `structured_extraction_text`, `textsearch_vector`) from running migrations locally
- `GetResumeTextFromTextract` class exists at `app/services/get_resume_text_from_textract.rb` with `parse_resume_text` method at lines 24-37
- `TextractResult` model has `after_commit :queue_ai_summary_job, on: [:create, :update]` callback on develop
- `pg_search` gem version 2.3.2 confirmed in Gemfile (line 125) and Gemfile.lock — compatible with Ruby 3.1 / Rails 6.1 / activerecord 6.1.7.7. Already used in 4 models (`Candidate`, `Organization`, `Job`, `User`)
- `fx` gem at `~> 0.8.0` resolves to 0.8.0 in Gemfile.lock, requires activerecord >= 6.0.0 and railties >= 6.0.0, compatible with Rails 6.1
- `resume_structured_data.rb` exists at `app/services/ai_job_application_action/summary/prompts/resume_structured_data.rb` with `self.messages(resume_text:, job_title:)`, `self.model`, `self.response_format` class methods (lines 86, 100, 96)
- `tsvector_update_trigger` is a real Postgres built-in function — confirmed argument signature: `(tsvector_column_name, dictionary, source_column_name)`
- `AiApiRequest` model has `belongs_to :requestable, polymorphic: true` at line 5
- `AiJobApplicationSummary` (line 6) and `AiJobCriteria` (line 5) both have `has_many :ai_api_requests, as: :requestable` — confirms the polymorphic pattern
- `CustomErrorTextract` and `CustomErrorAiSummary` exist at the referenced paths with the exact pattern the new error class follows
- `AiClient.new(provider: 'openai')` and `AiClient.calculate_cost` confirmed in `generate.rb` analog (lines 43, 309)

# Implementation Plan — Textract Keyword Search

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Summary

Add keyword search over job application resumes using a tsvector + GIN index on cleaned, structured resume text. When Textract completes, a new background job calls GPT-4o-mini to extract structured data from the OCR text, stores it on `TextractResult`, flattens it into searchable plain text, and a Postgres trigger auto-updates the tsvector column. Backend only -- no frontend changes, no controller/serializer changes.

## Pattern Precedents

### 1. Service that calls an external AI API (AiClient pattern)

- **`app/services/ai_job_application_action/summary/generate.rb:43-58`** -- `AiClient.new(provider: 'openai')`, `ai_client.chat(messages:, model:, response_format:)`, parses `extraction_result[:content]` as JSON
- **`app/services/ai_providers/openai.rb:7-40`** -- returns `{ content:, input_tokens:, output_tokens:, model: }` hash; raises `CustomErrorAiSummary` on API failure, connection error, or parse error

### 2. Background job with retry_on + exhaustion block

- **`app/jobs/get_resume_text_from_textract_job.rb:6-8`** -- `retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3 do |job, _error| ... end`
- **`app/jobs/generate_ai_job_application_summary_job.rb:13-22`** -- `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3 do |job, error| ... end` with exhaustion block that marks summary as failed

### 3. after_commit callback that enqueues a job

- **`app/models/textract_result.rb:7`** -- `after_commit :queue_ai_summary_job, on: [:create, :update]`
- **`app/models/textract_result.rb:114-143`** -- `queue_ai_summary_job` guards on `textract_job_result_text.present?` and `saved_change_to_textract_job_result_text?`

### 4. AiApiRequest creation pattern

- **`app/services/ai_job_application_action/summary/generate.rb:296-313`** -- `create_ai_api_request(ai_summary:, call_type:, provider:, result:, messages:)` creates `AiApiRequest.create(organization:, requestable:, call_type:, provider:, model:, input_tokens:, output_tokens:, cost:, prompt_text:, response_body:)`
- **`app/models/ai_job_application_summary.rb:6`** -- `has_many :ai_api_requests, as: :requestable`
- **`app/models/ai_job_criteria.rb:5`** -- `has_many :ai_api_requests, as: :requestable`

### 5. Custom error class pattern

- **`app/errors/custom_error_textract.rb`** -- `class CustomErrorTextract < StandardError` with `attr_reader :param`, `def initialize(msg = 'Custom Error - Textract', param = '')`
- **`app/errors/custom_error_ai_summary.rb`** -- identical pattern with different default message

### 6. fx trigger migration

- **Reference: `inflow-ats.keyword-search-connect-version/db/migrate/20260106002844_create_trigger_tsvectorupdate.rb`** -- `create_trigger :tsvectorupdate, on: :textract_results`
- **Reference Gemfile line 162:** `gem "fx", "~> 0.8.0"`

### 7. tsvector column + GIN index migration

- **Reference: `inflow-ats.keyword-search-connect-version/db/migrate/20260106002106_add_textsearch_vector_to_textract_results.rb`** -- `add_column :textract_results, :textsearch_vector, :tsvector` + `add_index :textract_results, :textsearch_vector, using: "gin"`

### 8. pg_search_scope on TextractResult

- **Reference: `inflow-ats.keyword-search-connect-version/app/models/textract_result.rb:4,15-46`** -- `include PgSearch::Model`, `pg_search_scope :search_resume_text` with `against: :textract_job_result_text`, `tsvector_column: 'textsearch_vector'`, `dictionary: 'simple'`, `prefix: true`, highlight config, `ranked_by: ":tsearch"`, `search_resume_by_keyword` class method

### 9. Data migration pattern

- **Reference: `inflow-ats.keyword-search-connect-version/db/data/20260106200000_backfill_textract_tsvector.rb`** -- `ActiveRecord::Migration[6.1]`, `def up/down`, `raise ActiveRecord::IrreversibleMigration` in `down`
- **`db/data/20260408040801_create_organization_ai_credit_balances_for_existing_organizations.rb`** -- existing data migration in main branch

## Files to Create

| # | File | Purpose |
|---|------|---------|
| 1 | `app/errors/custom_error_structured_extraction.rb` | Custom error for extraction API failures |
| 2 | `app/services/extract_structured_resume_data.rb` | Service: GPT-4o-mini extraction + flatten + store |
| 3 | `app/jobs/extract_structured_resume_data_job.rb` | Background job: retry/exhaustion wrapper for service |
| 4 | `app/jobs/backfill_structured_extraction_job.rb` | One-time backfill job: iterates existing records |
| 5 | `db/migrate/TIMESTAMP_add_structured_extraction_columns_to_textract_results.rb` | Add `structured_extraction` (jsonb) + `structured_extraction_text` (text) |
| 6 | `db/migrate/TIMESTAMP_add_textsearch_vector_to_textract_results.rb` | Add `textsearch_vector` (tsvector) + GIN index |
| 7 | `db/migrate/TIMESTAMP_create_trigger_tsvectorupdate.rb` | fx trigger: auto-update tsvector on text change |
| 8 | `db/data/TIMESTAMP_enqueue_structured_extraction_backfill.rb` | Data migration: enqueues `BackfillStructuredExtractionJob` |
| 9 | `spec/services/extract_structured_resume_data_spec.rb` | Service unit tests |
| 10 | `spec/jobs/extract_structured_resume_data_job_spec.rb` | Job unit tests |
| 11 | `spec/models/textract_result_keyword_search_spec.rb` | pg_search + callback tests |

## Files to Modify

| # | File | Changes |
|---|------|---------|
| 1 | `Gemfile` | Add `gem "fx", "~> 0.8.0"` |
| 2 | `app/models/textract_result.rb` | Add `include PgSearch::Model`, `pg_search_scope`, `search_resume_by_keyword`, `has_many :ai_api_requests, as: :requestable`, new `after_commit` callback |

---

## Backend Changes

### 1. Gemfile — Add fx gem

**Cursor rules:** `cursor_rules/core_critical_rules.md`

- [ ] 1.1. Add `gem "fx", "~> 0.8.0"` to `Gemfile` (near the `pg_search` line at line 125)
- [ ] 1.2. Run `bundle install` to update `Gemfile.lock`

### 2. Migrations

**Cursor rules:** `cursor_rules/backend/migrations.md`

- [ ] 2.1. **Migration 1: Add structured extraction columns**

  Create `db/migrate/TIMESTAMP_add_structured_extraction_columns_to_textract_results.rb`:

  ```ruby
  class AddStructuredExtractionColumnsToTextractResults < ActiveRecord::Migration[6.1]
    def change
      add_column :textract_results, :structured_extraction, :jsonb
      add_column :textract_results, :structured_extraction_text, :text
    end
  end
  ```

  Both columns are nullable (no `null: false`, no `default`). No index needed on these -- the tsvector column handles search indexing.

- [ ] 2.2. **Migration 2: Add textsearch_vector column with GIN index**

  Create `db/migrate/TIMESTAMP_add_textsearch_vector_to_textract_results.rb`:

  Match the reference migration at `inflow-ats.keyword-search-connect-version/db/migrate/20260106002106_add_textsearch_vector_to_textract_results.rb` exactly:

  ```ruby
  class AddTextsearchVectorToTextractResults < ActiveRecord::Migration[6.1]
    def change
      add_column :textract_results, :textsearch_vector, :tsvector
      add_index :textract_results, :textsearch_vector, using: "gin"
    end
  end
  ```

- [ ] 2.3. **Migration 3: Create fx trigger**

  Create `db/migrate/TIMESTAMP_create_trigger_tsvectorupdate.rb`:

  Uses `sql_definition:` inline (not a separate SQL file) because `*.sql` is gitignored (line 43 of `.gitignore`). The reference branch originally used file-based SQL but that approach was removed.

  ```ruby
  class CreateTriggerTsvectorupdate < ActiveRecord::Migration[6.1]
    def change
      create_trigger :tsvectorupdate, on: :textract_results, sql_definition: <<-SQL
        CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON public.textract_results
        FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', 'structured_extraction_text')
      SQL
    end
  end
  ```

  This matches the reference trigger exactly, changing ONLY the last argument from `'textract_job_result_text'` to `'structured_extraction_text'`. Uses the built-in Postgres `tsvector_update_trigger()` function (NOT custom PL/pgSQL).

- [ ] 2.4. Run `rails db:migrate` to apply all three schema migrations

### 3. Custom Error Class

**Cursor rules:** `cursor_rules/backend/services.md` (error handling section)

- [ ] 3.1. Create `app/errors/custom_error_structured_extraction.rb`:

  Match the `custom_error_textract.rb` and `custom_error_ai_summary.rb` pattern exactly:

  ```ruby
  # frozen_string_literal: true

  class CustomErrorStructuredExtraction < StandardError
    attr_reader :param

    def initialize(msg = 'Custom Error - Structured Extraction', param = '')
      @param = param.to_s
      super(msg)
    end
  end
  ```

### 4. Extraction Service

**Cursor rules:** `cursor_rules/backend/services.md` (rules 1-6), `cursor_rules/core_critical_rules.md` (rules 8, 11, 12)

- [ ] 4.1. Create `app/services/extract_structured_resume_data.rb`

  Class: `ExtractStructuredResumeData` (no "Service" in name -- rule 1)

  **Constructor:** `def initialize(textract_result_id:)` -- takes ID, not object (rule 3: called from background job). Loads record with `TextractResult.find_by(id: textract_result_id)`.

  **Public method:** `def extract` -- descriptive name, not `call` (rule 2)

  **Method body outline:**

  ```
  def extract
    # Guard: return unless textract_result exists
    # Guard: return unless textract_result.textract_job_result_text.present?

    # Load organization for AiApiRequest
    organization = textract_result.job_application&.job&.organization
    # Guard: return unless organization (can't create AiApiRequest without it)

    # Build messages using existing prompt class
    job_title = textract_result.job_application.job&.title
    messages = AiJobApplicationAction::Summary::Prompts::ResumeStructuredData.messages(
      resume_text: textract_result.textract_job_result_text,
      job_title: job_title
    )

    # Call GPT-4o-mini via AiClient
    ai_client = AiClient.new(provider: 'openai')
    result = ai_client.chat(
      messages: messages,
      model: AiJobApplicationAction::Summary::Prompts::ResumeStructuredData.model,
      response_format: AiJobApplicationAction::Summary::Prompts::ResumeStructuredData.response_format
    )

    # Parse structured data
    structured_data = JSON.parse(result[:content])

    # Flatten to searchable text
    flattened_text = flatten_structured_data(structured_data)

    # Update TextractResult with both columns
    # (trigger auto-updates textsearch_vector when structured_extraction_text changes)
    if textract_result.update(
      structured_extraction: structured_data,
      structured_extraction_text: flattened_text
    )
      # Create AiApiRequest for cost auditing
      create_ai_api_request(organization: organization, result: result, messages: messages)
    else
      Rails.logger.error "Failed to update TextractResult #{textract_result.id}: #{textract_result.errors.full_messages.join(', ')}"
      ap "Failed to update TextractResult #{textract_result.id} with structured extraction"
      ap textract_result.errors.full_messages
    end
  rescue CustomErrorAiSummary => e
    # OpenAI provider raises CustomErrorAiSummary -- re-raise as
    # CustomErrorStructuredExtraction so the extraction job retries
    # independently of the AI summary pipeline
    Rails.logger.error "Structured extraction failed for TextractResult #{textract_result_id}: #{e.message}"
    ap "Structured extraction API error for TextractResult #{textract_result_id}"
    ap e
    raise CustomErrorStructuredExtraction, e.message
  rescue JSON::ParserError => e
    Rails.logger.error "Structured extraction JSON parse failed for TextractResult #{textract_result_id}: #{e.message}"
    ap "Structured extraction JSON parse error for TextractResult #{textract_result_id}"
    ap e
    raise CustomErrorStructuredExtraction, e.message
  end
  ```

  **IMPORTANT:** The `rescue CustomErrorAiSummary` block is critical. The OpenAI provider (`app/services/ai_providers/openai.rb:22-39`) raises `CustomErrorAiSummary` on API errors, connection errors, and JSON parse errors. The new service MUST catch `CustomErrorAiSummary` and re-raise as `CustomErrorStructuredExtraction` so the extraction job's `retry_on CustomErrorStructuredExtraction` works and the error does not accidentally trigger retry logic in the AI summary pipeline.

- [ ] 4.2. **Private method: `flatten_structured_data`**

  Converts structured extraction jsonb into plain text for tsvector indexing:

  ```
  def flatten_structured_data(structured_data)
    parts = []

    # Scalar fields (skip nulls)
    %w[name email phone location professional_summary stated_experience].each do |field|
      value = structured_data[field]
      parts << value if value.present?
    end

    # Array-of-string fields
    %w[skills certifications links].each do |field|
      values = structured_data[field]
      values&.each { |value| parts << value if value.present? }
    end

    # Work experience (array of objects)
    work_experiences = structured_data['work_experience']
    work_experiences&.each do |work_experience_entry|
      %w[company title start_date end_date description].each do |sub_field|
        value = work_experience_entry[sub_field]
        parts << value if value.present?
      end
    end

    # Education (array of objects)
    education_entries = structured_data['education']
    education_entries&.each do |education_entry|
      %w[institution degree field_of_study graduation_year].each do |sub_field|
        value = education_entry[sub_field]
        parts << value if value.present?
      end
    end

    parts.join("\n")
  end
  ```

  Rules from spec:
  - Include ALL non-null scalar fields
  - Include all items from array-of-string fields
  - Include all sub-fields from array-of-object fields
  - Skip null values (do not output "null" strings)
  - Separate each field/item with a newline
  - No JSON syntax (no braces, brackets, quotes, colons, commas)
  - No field labels (no "Name:" prefixes)

- [ ] 4.3. **Private method: `create_ai_api_request`**

  Match `AiJobApplicationAction::Summary::Generate#create_ai_api_request` (lines 296-313):

  ```
  def create_ai_api_request(organization:, result:, messages:)
    model = result[:model]
    input_tokens = result[:input_tokens] || 0
    output_tokens = result[:output_tokens] || 0

    AiApiRequest.create(
      organization: organization,
      requestable: textract_result,
      call_type: 'keyword_extraction',
      provider: 'openai',
      model: model,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      cost: AiClient.calculate_cost(model: model, input_tokens: input_tokens, output_tokens: output_tokens).to_f.round(6),
      prompt_text: messages.to_json,
      response_body: result[:content]
    )
  end
  ```

  Key differences from the analog:
  - `requestable: textract_result` (not `ai_summary`) -- `TextractResult` is the polymorphic `requestable`
  - `call_type: 'keyword_extraction'` (not `'extraction'`) -- distinct from the summary pipeline's call type

### 5. Background Job

**Cursor rules:** `cursor_rules/backend/background_jobs.md` (rules 0a, 1-5)

- [ ] 5.1. Create `app/jobs/extract_structured_resume_data_job.rb`

  Match the `GetResumeTextFromTextractJob` retry/exhaustion pattern:

  ```ruby
  # frozen_string_literal: true

  class ExtractStructuredResumeDataJob < ApplicationJob
    queue_as :default

    retry_on CustomErrorStructuredExtraction, wait: 5.minutes, attempts: 3 do |job, error|
      ap '[ExtractStructuredResumeDataJob] retries exhausted'
      ap error
      Rails.logger.error "ExtractStructuredResumeDataJob exhausted retries for TextractResult #{job.arguments.first}: #{error.message}"
    end

    def perform(textract_result_id)
      ExtractStructuredResumeData.new(textract_result_id: textract_result_id).extract
    rescue CustomErrorStructuredExtraction => e
      ap '[ExtractStructuredResumeDataJob] CustomErrorStructuredExtraction — retrying'
      ap e
      raise
    rescue StandardError => e
      Rails.logger.error "ExtractStructuredResumeDataJob failed for TextractResult #{textract_result_id}: #{e.message}"
      ap '[ExtractStructuredResumeDataJob] StandardError'
      ap e
    end
  end
  ```

  Pattern notes:
  - Pass ID, not object (rule 1)
  - Delegates to service (rule 3: jobs orchestrate, don't contain business logic)
  - `rescue CustomErrorStructuredExtraction => e` + `raise` re-raises so `retry_on` can catch it
  - `rescue StandardError => e` catches non-retryable errors, logs and moves on
  - Exhaustion block logs the failure -- extraction is supplementary, not critical
  - Uses `ap` + `Rails.logger.error` for logging (cursor_rules pattern)

### 6. Model Changes — TextractResult

**Cursor rules:** `cursor_rules/core_critical_rules.md`, `cursor_rules/backend/background_jobs.md` (rule 5)

- [ ] 6.1. Add `include PgSearch::Model` at the top of the class body (after `class TextractResult < ApplicationRecord`, before `belongs_to`)

  Match reference: `inflow-ats.keyword-search-connect-version/app/models/textract_result.rb:4`

- [ ] 6.2. Add `has_many :ai_api_requests, as: :requestable` association

  Match analogs: `app/models/ai_job_application_summary.rb:6`, `app/models/ai_job_criteria.rb:5`

- [ ] 6.3. Add `pg_search_scope :search_resume_text` -- match reference EXACTLY, changing ONLY `against:`

  ```ruby
  pg_search_scope :search_resume_text,
                  against: :structured_extraction_text,
                  using: {
                    tsearch: {
                      dictionary: 'simple',
                      tsvector_column: 'textsearch_vector',
                      prefix: true,
                      highlight: {
                        StartSel: '<span class="highlight">',
                        StopSel:  '</span>',
                        MaxFragments: 3,
                        MaxWords:    20,
                        MinWords:    7,
                        ShortWord:   3,
                        FragmentDelimiter: ' .... '
                      }
                    }
                  },
                  ranked_by: ":tsearch"
  ```

  The ONLY change from the reference is `against: :structured_extraction_text` (was `:textract_job_result_text`).

- [ ] 6.4. Add `search_resume_by_keyword` class method -- match reference EXACTLY

  ```ruby
  def self.search_resume_by_keyword(search_params, limit = 15)
    search_term = search_params[:search_term].presence
    return none unless search_term

    search_resume_text(search_term)
      .with_pg_search_rank
      .with_pg_search_highlight
      .order(Arel.sql('pg_search_rank DESC'))
      .limit(limit)
  end
  ```

- [ ] 6.5. Add new `after_commit` callback for extraction job

  Add alongside existing callback (line 7):

  ```ruby
  after_commit :queue_ai_summary_job, on: [:create, :update]
  after_commit :queue_structured_extraction_job, on: [:create, :update]
  ```

  Private method implementation:

  ```ruby
  def queue_structured_extraction_job
    return unless textract_job_result_text.present?
    return unless saved_change_to_textract_job_result_text?

    ExtractStructuredResumeDataJob.perform_later(id)
  end
  ```

  Key design decisions:
  - Same guards as `queue_ai_summary_job`: `textract_job_result_text.present?` and `saved_change_to_textract_job_result_text?`
  - Does NOT need the organization/validation/feature-gate checks that `queue_ai_summary_job` has -- extraction is unconditional (it serves search, not AI credit gating)
  - Fires independently of `queue_ai_summary_job` -- both callbacks run after the same commit
  - Failure of the extraction job does NOT affect the AI summary pipeline

### 7. Backfill Job

**Cursor rules:** `cursor_rules/backend/background_jobs.md`, `cursor_rules/backend/migrations.md` (data migrations section)

- [ ] 7.1. Create `app/jobs/backfill_structured_extraction_job.rb`

  ```ruby
  # frozen_string_literal: true

  class BackfillStructuredExtractionJob < ApplicationJob
    queue_as :default

    def perform
      ap '[BackfillStructuredExtractionJob] starting backfill'

      textract_results_scope = TextractResult.where(
        textract_job_status: :succeeded,
        structured_extraction: nil
      ).where.not(textract_job_result_text: [nil, ''])

      total = textract_results_scope.count
      ap "[BackfillStructuredExtractionJob] #{total} records to backfill"

      processed = 0
      failed = 0

      textract_results_scope.find_each(batch_size: 100) do |textract_result|
        ExtractStructuredResumeData.new(textract_result_id: textract_result.id).extract
        processed += 1
        ap "[BackfillStructuredExtractionJob] processed #{processed}/#{total}" if (processed % 100).zero?
        sleep 0.2
      rescue StandardError => e
        failed += 1
        Rails.logger.error "BackfillStructuredExtractionJob failed for TextractResult #{textract_result.id}: #{e.message}"
        ap "[BackfillStructuredExtractionJob] failed TextractResult #{textract_result.id}: #{e.message}"
      end

      ap "[BackfillStructuredExtractionJob] complete: #{processed} processed, #{failed} failed out of #{total}"
    end
  end
  ```

  Design decisions from spec:
  - Scope: `textract_job_status = succeeded` AND `structured_extraction IS NULL` AND `textract_job_result_text IS NOT NULL AND != ''`
  - Uses the same `ExtractStructuredResumeData` service as the real-time path
  - `find_each(batch_size: 100)` for memory efficiency
  - `sleep 0.2` between records for OpenAI rate limiting
  - Per-record `rescue StandardError` -- logs and continues to next record
  - The `IS NULL` scope on `structured_extraction` makes this resumable: re-running picks up records that failed or were not yet processed
  - Expected deviation from reference backfill: reference uses raw SQL `UPDATE`, but this MUST call the service because it needs the GPT-4o-mini extraction step

- [ ] 7.2. Create data migration `db/data/TIMESTAMP_enqueue_structured_extraction_backfill.rb`

  ```ruby
  # frozen_string_literal: true

  class EnqueueStructuredExtractionBackfill < ActiveRecord::Migration[6.1]
    def up
      BackfillStructuredExtractionJob.perform_later
    end

    def down
      raise ActiveRecord::IrreversibleMigration
    end
  end
  ```

  The data migration itself only enqueues the job -- does NOT iterate records or call GPT-4o-mini inline. This avoids blocking deploys.

---

## Test Plan

### 8. Service Tests

- [ ] 8.1. Create `spec/services/extract_structured_resume_data_spec.rb`

  Test cases:
  - **Happy path:** Given a TextractResult with `textract_job_result_text`, the service calls GPT-4o-mini (stubbed), stores `structured_extraction` as parsed JSON on the TextractResult, and stores `structured_extraction_text` as a flattened plain-text string
  - **Flattening correctness:** Given a structured extraction hash with all field types (scalars, arrays, nested objects), `structured_extraction_text` contains every non-null value separated by newlines, with no JSON syntax or field labels
  - **Null handling:** Null scalar values are omitted from flattened text (no "null" strings)
  - **AiApiRequest creation:** After successful extraction, an `AiApiRequest` record is created with `requestable: textract_result`, `call_type: 'keyword_extraction'`, `provider: 'openai'`, correct token counts and cost
  - **API failure:** When the AiClient raises `CustomErrorAiSummary`, the service re-raises as `CustomErrorStructuredExtraction`
  - **JSON parse failure:** When `result[:content]` is not valid JSON, the service raises `CustomErrorStructuredExtraction`
  - **Guard: missing textract_result:** Returns early without error when the TextractResult ID does not exist
  - **Guard: no text:** Returns early when `textract_job_result_text` is nil/blank
  - **Guard: no organization:** Returns early when the TextractResult's job_application has no organization
  - **Idempotency:** Calling the service twice on the same TextractResult overwrites `structured_extraction` and `structured_extraction_text` cleanly (no duplicates, no errors)

  Stub the AiClient to return a known result hash. Use `instance_double` or `allow(AiClient).to receive_message_chain(:new, :chat)`.

### 9. Job Tests

- [ ] 9.1. Create `spec/jobs/extract_structured_resume_data_job_spec.rb`

  Test cases:
  - **Delegates to service:** `perform(textract_result_id)` calls `ExtractStructuredResumeData.new(textract_result_id:).extract`
  - **Retry on CustomErrorStructuredExtraction:** When service raises `CustomErrorStructuredExtraction`, the job re-raises (allowing `retry_on` to catch it)
  - **StandardError does not retry:** When service raises `StandardError`, the job rescues, logs, and does not re-raise
  - **Exhaustion logging:** After 3 failed attempts, the exhaustion block logs the error (verify with `ap` and `Rails.logger.error`)

### 10. Model / Callback Tests

- [ ] 10.1. Create `spec/models/textract_result_keyword_search_spec.rb`

  Test cases:
  - **Callback fires on create with text:** Creating a TextractResult with `textract_job_result_text` enqueues `ExtractStructuredResumeDataJob`
  - **Callback does not fire without text:** Creating a TextractResult with `textract_job_result_text: nil` does NOT enqueue `ExtractStructuredResumeDataJob`
  - **Callback does not fire on non-text update:** Updating a TextractResult without changing `textract_job_result_text` does NOT enqueue `ExtractStructuredResumeDataJob`
  - **Callback fires on text update:** Updating `textract_job_result_text` enqueues `ExtractStructuredResumeDataJob`
  - **Both callbacks fire independently:** When text changes, BOTH `GenerateAiJobApplicationSummaryJob` and `ExtractStructuredResumeDataJob` are enqueued
  - **pg_search_scope works:** Given a TextractResult with `structured_extraction_text` containing "Ruby developer", `search_resume_by_keyword({search_term: 'Ruby'})` returns it with rank and highlight
  - **search_resume_by_keyword returns none for blank search:** `search_resume_by_keyword({search_term: ''})` and `search_resume_by_keyword({search_term: nil})` return `none`

  Use the same test setup pattern as `spec/models/textract_result_ai_trigger_spec.rb`: `include ActiveJob::TestHelper`, `around` block with `:test` queue adapter, `let` blocks for organization/job/job_application using existing helpers.

### 11. Existing Test Updates

- [ ] 11.1. Review `spec/models/textract_result_ai_trigger_spec.rb`

  The existing tests create/update TextractResult records, which will now also fire the new `queue_structured_extraction_job` callback. The tests should still pass because:
  - The new callback only enqueues a job (does not call AI inline)
  - The test queue adapter collects enqueued jobs without executing them
  - Tests that assert `have_enqueued_job(GenerateAiJobApplicationSummaryJob)` will still pass -- the new job being enqueued alongside does not interfere

  However, verify that no test uses `not_to have_enqueued_job` without specifying a class (which would fail if any job is enqueued). All existing tests specify the class (`GenerateAiJobApplicationSummaryJob`), so this should be fine.

---

## Structural Manifest (Spec vs. Plan Comparison)

| Spec item | Plan step | Status |
|-----------|-----------|--------|
| `structured_extraction` jsonb column | 2.1 | SAME |
| `structured_extraction_text` text column | 2.1 | SAME |
| `textsearch_vector` tsvector + GIN index | 2.2 | SAME |
| fx trigger with `sql_definition:` inline | 2.3 | SAME |
| `CustomErrorStructuredExtraction` | 3.1 | SAME |
| Service: `ExtractStructuredResumeData#extract` | 4.1-4.3 | SAME |
| Service takes TextractResult ID | 4.1 | SAME |
| Service uses existing prompt/schema class | 4.1 | SAME |
| Service creates AiApiRequest with `call_type: 'keyword_extraction'` | 4.3 | SAME |
| Service re-raises `CustomErrorAiSummary` as `CustomErrorStructuredExtraction` | 4.1 | SAME |
| Flattening algorithm (all fields, no JSON, no labels) | 4.2 | SAME |
| `include PgSearch::Model` on TextractResult | 6.1 | SAME |
| `has_many :ai_api_requests, as: :requestable` | 6.2 | SAME |
| `pg_search_scope` matches reference (only `against:` changes) | 6.3 | SAME |
| `search_resume_by_keyword` matches reference exactly | 6.4 | SAME |
| `after_commit` callback with same guards | 6.5 | SAME |
| Background job with `retry_on CustomErrorStructuredExtraction` | 5.1 | SAME |
| Exhaustion: log and move on | 5.1 | SAME |
| Backfill job with `find_each`, `sleep 0.2`, per-record rescue | 7.1 | SAME |
| Data migration enqueues backfill job (not inline iteration) | 7.2 | SAME |
| `fx` gem added to Gemfile | 1.1 | SAME |
| `pg_search` already in Gemfile (no change) | -- | SAME |
| Existing AI summary pipeline unchanged | -- | SAME |
| No frontend changes | -- | SAME |
| No controller/serializer changes | -- | SAME |

---

## Risks and Open Questions

### Risks

1. **`gpt-4o-mini` pricing key:** `AiClient::PRICING` has `'gpt-4o-mini-2024-07-18'` but the prompt class returns `'gpt-4o-mini'` as the model string. The OpenAI API returns the resolved model name (e.g., `'gpt-4o-mini-2024-07-18'`) in the response's `parsed['model']` field, and the `create_ai_api_request` method uses `result[:model]` (the API-returned name). So `calculate_cost` will match. This matches how the existing summary pipeline works -- no change needed.

2. **Backfill volume:** The backfill iterates all `succeeded` TextractResult records with text. With `sleep 0.2` per record, 10,000 records would take ~33 minutes. This runs as a background job and does not block deploys.

3. **fx gem `sql_definition:` support:** Verify that `fx` ~> 0.8.0 supports the `sql_definition:` keyword argument to `create_trigger`. The reference branch used file-based triggers; the inline approach is specified in the spec. If `fx` does not support `sql_definition:`, fall back to raw `execute` with the SQL string.

4. **Trigger on NULL text:** When `structured_extraction_text` is NULL (before extraction runs), the Postgres `tsvector_update_trigger()` built-in handles this gracefully by setting `textsearch_vector` to NULL. No special handling needed.

### Open Questions

None. The spec has been through 5 rounds of adversarial review with 0 remaining findings.

---

## Estimated Scope

| Area | Files | Effort |
|------|-------|--------|
| Migrations (3 schema + 1 data) | 4 new | Small |
| Gemfile | 1 modified | Trivial |
| Error class | 1 new | Trivial |
| Service | 1 new | Medium |
| Jobs (extraction + backfill) | 2 new | Small |
| Model changes | 1 modified | Small |
| Tests | 3 new, 1 reviewed | Medium |
| **Total** | **12 new + 2 modified** | **~4-6 hours** |

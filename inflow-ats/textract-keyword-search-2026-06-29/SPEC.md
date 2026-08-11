# Textract Keyword Search — Structured Data + tsvector

## Goal

Enable keyword search over job application resumes using a tsvector index on cleaned, structured resume text rather than raw Textract OCR output.

## Problem

Raw Textract text (`textract_job_result_text`) is messy — OCR artifacts, layout noise, inconsistent formatting. Indexing it directly produces poor search results. The structured data extraction (currently done during AI summary generation) already cleans this text via GPT-4o-mini. Move that extraction earlier — to Textract completion — and use the result as the search index source.

## Architecture

### New column: structured data on TextractResult

Add a jsonb column `structured_extraction` to `textract_results` to store the GPT-4o-mini structured extraction result. This is the same structured data currently extracted during AI summary generation (Call 1 of the 4-call pipeline in `AiJobApplicationAction::Summary::Generate#generate`), stored at the source instead.

### New column: flattened text

Add a text column `structured_extraction_text` to `textract_results` that flattens the structured jsonb into a single searchable string. This is the tsvector source.

### tsvector column + GIN index

Add a `textsearch_vector` tsvector column with a GIN index on `textract_results`. Postgres trigger auto-updates it when `structured_extraction_text` changes.

### New service: structured data extraction on Textract success

A service that calls GPT-4o-mini to extract structured data from `textract_job_result_text`. Called when Textract completes successfully. Stores the result in `structured_extraction`, then flattens it into `structured_extraction_text` (which triggers the tsvector update).

## Reference implementation

The `keyword-search-connect-version` worktree (`~/wrk/wrk-corp/inflow-ats.keyword-search-connect-version/`) has the existing GIN index, trigger, and pg_search setup. **This is the primary blueprint — match its patterns exactly, deviating only where the new structured-extraction source column requires it.**

Key files:

- `db/migrate/20260106002106_add_textsearch_vector_to_textract_results.rb` — tsvector column + GIN index
- `db/migrate/20260106002844_create_trigger_tsvectorupdate.rb` — fx trigger (`create_trigger :tsvectorupdate, on: :textract_results`)
- `db/data/20260106200000_backfill_textract_tsvector.rb` — backfill data migration (raw SQL UPDATE)
- `app/models/textract_result.rb` — `pg_search_scope :search_resume_text` with simple dictionary, prefix matching, highlight support, `search_resume_by_keyword` class method

### Reference trigger SQL

The trigger uses Postgres's built-in `tsvector_update_trigger()` function (NOT custom PL/pgSQL):

```sql
CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE ON public.textract_results
FOR EACH ROW EXECUTE FUNCTION tsvector_update_trigger('textsearch_vector', 'pg_catalog.simple', 'textract_job_result_text')
```

The new implementation changes ONLY the last argument to `'structured_extraction_text'`.

### Reference pg_search_scope

```ruby
pg_search_scope :search_resume_text,
                against: :textract_job_result_text,
                using: {
                  tsearch: {
                    dictionary: 'simple',
                    tsvector_column: 'textsearch_vector',
                    prefix: true,
                    highlight: {
                      StartSel: '<span class="highlight">',
                      StopSel:  '</span>',
                      MaxFragments: 3,
                      MaxWords: 20,
                      MinWords: 7,
                      ShortWord: 3,
                      FragmentDelimiter: ' .... '
                    }
                  }
                },
                ranked_by: ":tsearch"

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

The new implementation changes ONLY `against:` to `:structured_extraction_text`.

### Gems required

- `pg_search` (2.3.2) — **already in main Gemfile** (line 125). Version 2.3.2 is confirmed compatible with Ruby 3.1 / Rails 6.1 / activerecord 6.1.7.7. Already used in 4 models (`Candidate`, `Organization`, `Job`, `User`) with `include PgSearch::Model`. Use 2.3.2 as-is; any upgrade is a separate task.
- `fx` (~> 0.8.0) — **NOT in main Gemfile**. Needs adding. Version 0.8.0 requires activerecord >= 6.0.0, confirmed compatible with Rails 6.1.

## Existing extraction (to reuse)

The structured data extraction currently lives in the AI summary pipeline:

- **Prompt + schema:** `app/services/ai_job_application_action/summary/prompts/resume_structured_data.rb`
- **Call site:** `app/services/ai_job_application_action/summary/generate.rb:46-58` (Call 1 of 4)
- **Model:** `gpt-4o-mini`
- **Input:** `textract_job_result_text` + `job_title`

### Extraction schema fields

All required, nullable where noted:

- `name` (string|null)
- `email` (string|null)
- `phone` (string|null)
- `location` (string|null)
- `links` (array of strings)
- `professional_summary` (string|null)
- `stated_experience` (string|null)
- `work_experience` (array of objects: `{company, title, start_date, end_date, description}`)
- `education` (array of objects: `{institution, degree, field_of_study, graduation_year}`)
- `skills` (array of strings)
- `certifications` (array of strings)

The new service uses the SAME prompt and schema. It does NOT add `total_months_experience` or any fields from Calls 2-4 — those belong to the summary pipeline.

## Textract success handler (call site)

**File:** `app/services/get_resume_text_from_textract.rb`

**Method:** `parse_resume_text` (lines 24-37)

**Success moment:** Line 31 — `@textract_result.update(update_textract_params)` sets `textract_job_status: 'succeeded'` and `textract_job_result_text`.

**Existing callback:** `after_commit :queue_ai_summary_job, on: [:create, :update]` on TextractResult (line 7). Guards on `textract_job_result_text.present?` and `saved_change_to_textract_job_result_text?`.

**Integration point:** A new `after_commit` callback on TextractResult (alongside the existing `queue_ai_summary_job`) enqueues the extraction background job. Same guards: `textract_job_result_text.present?` and `saved_change_to_textract_job_result_text?`. Constraints:
- Failure of the extraction MUST NOT prevent the Textract success path from completing
- The existing `queue_ai_summary_job` callback MUST still fire normally
- The extraction needs `textract_job_result_text` as input, so it runs AFTER the update

## TextractResult model (current state)

**File:** `app/models/textract_result.rb`

**Columns:** `id`, `textract_job_id` (string), `textract_job_status` (integer enum), `textract_job_result` (jsonb), `textract_job_result_text` (text), `job_application_id` (bigint), timestamps

**Associations:** `belongs_to :job_application`, `has_many :ai_job_application_summaries`

**Enum:** `textract_job_status`: `not_started: 0`, `in_progress: 1`, `succeeded: 2`, `failed: 3`

**Callbacks:** `after_commit :queue_ai_summary_job, on: [:create, :update]`

## Changes

### Migrations

1. Add `structured_extraction` (jsonb) column to `textract_results`
2. Add `structured_extraction_text` (text) column to `textract_results`
3. Add `textsearch_vector` (tsvector) column to `textract_results` with GIN index — match reference migration exactly
4. Create fx trigger: on insert/update of `structured_extraction_text`, auto-set `textsearch_vector` via `tsvector_update_trigger()` built-in Postgres function. Use `sql_definition:` inline in the migration (not a separate SQL file) to avoid `.gitignore` conflict (`*.sql` is gitignored on line 43). The reference branch originally used a file-based approach with `db/triggers/tsvectorupdate_v01.sql` but that file was later removed when `.gitignore` negation patterns were stripped.

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

   This matches the reference trigger exactly, changing only the last argument from `'textract_job_result_text'` to `'structured_extraction_text'`.

### Service

New service class (e.g., `ExtractStructuredResumeData`) that:
- Public method: `extract` (not `call` — per `cursor_rules/backend/services.md` rule 2: descriptive names)
- Takes a `TextractResult` ID (not object) when called from a background job (per `cursor_rules/backend/services.md` rule 3: pass IDs from jobs, objects in request cycle)
- Calls GPT-4o-mini using the same prompt and schema as `resume_structured_data.rb`, passing `resume_text:` (required) and `job_title:` (optional, from `textract_result.job_application.job&.title`). Include `job_title` because the prompt is identical to the existing extraction — the structured data should match what the summary pipeline produces.
- Creates an `AiApiRequest` record for the GPT-4o-mini call to maintain cost auditing. Use `TextractResult` as the `requestable` (polymorphic). This requires adding `has_many :ai_api_requests, as: :requestable` to `TextractResult`. Match the existing pattern in `AiJobApplicationAction::Summary::Generate#create_ai_api_request` (generate.rb:296-313). Required fields: `organization` (from `textract_result.job_application.job&.organization` — guard: return early if organization is nil), `requestable` (the TextractResult), `call_type: 'keyword_extraction'` (distinct from the summary pipeline's `'extraction'`), `provider: 'openai'`, `model`, `input_tokens`, `output_tokens`, `cost` (via `AiClient.calculate_cost`), `prompt_text`, `response_body`.
- Stores the structured result in `structured_extraction`
- Flattens the structured data into `structured_extraction_text`
- The trigger handles tsvector update automatically

#### Flattening algorithm

Convert the structured extraction jsonb into a single searchable plain-text string for tsvector indexing. The algorithm:

1. Include ALL non-null scalar fields: `name`, `email`, `phone`, `location`, `professional_summary`, `stated_experience`
2. Include all items from array-of-string fields: `skills`, `certifications`, `links`
3. Include all sub-fields from array-of-object fields: for each `work_experience` entry, concatenate `company`, `title`, `start_date`, `end_date`, `description`; for each `education` entry, concatenate `institution`, `degree`, `field_of_study`, `graduation_year`
4. Skip null values (do not output "null" strings)
5. Separate each field/item with a newline
6. No JSON syntax in output (no braces, brackets, quotes, colons, commas)
7. No field labels in output (do not prefix with "Name:" or "Skills:" — the tsvector indexes words, not structure)

The result is a plain text block where every searchable word from the resume appears at least once.

### Call site

When Textract completes successfully, enqueue a background job for the extraction. The GPT-4o-mini call MUST NOT run synchronously in the callback chain or inline in `parse_resume_text` — the existing `queue_ai_summary_job` callback only enqueues a Sidekiq job (`GenerateAiJobApplicationSummaryJob.perform_later`), never calls AI directly.

Integration: add a new `after_commit` callback on `TextractResult` (alongside the existing `queue_ai_summary_job`) that enqueues the extraction job. Guard on `textract_job_result_text.present?` and `saved_change_to_textract_job_result_text?` — same guards as the existing callback.

**Background job** (e.g., `ExtractStructuredResumeDataJob`):
- Calls the extraction service with the `TextractResult` ID
- New custom error class `CustomErrorStructuredExtraction` (in `app/errors/custom_error_structured_extraction.rb`, matching existing pattern: `CustomErrorTextract`, `CustomErrorAiSummary`). The service raises this on API failure.
- `retry_on CustomErrorStructuredExtraction, wait: 5.minutes, attempts: 3` with exhaustion block — match `GetResumeTextFromTextractJob` pattern
- On exhaustion: log the failure and move on. Extraction is supplementary — a failed extraction means no search index for that resume, not a broken pipeline.
- Failure isolation: the extraction job runs independently of `GenerateAiJobApplicationSummaryJob`. If extraction fails, the AI summary pipeline is unaffected.

### Model

Add to `TextractResult`:
- `include PgSearch::Model`
- `pg_search_scope :search_resume_text` — matching the reference implementation exactly, changing only `against:` to `:structured_extraction_text`
- `search_resume_by_keyword` class method — matching the reference exactly
- `has_many :ai_api_requests, as: :requestable` — for cost auditing of the GPT-4o-mini extraction call (matches `AiJobApplicationSummary` and `AiJobCriteria` pattern)

### Backfill

Data migration that enqueues a one-time background job to backfill existing records. The data migration itself does NOT iterate records or call GPT-4o-mini — it only enqueues the backfill job. This avoids blocking deploys (the reference backfill runs instantly as a single SQL UPDATE, but the new backfill makes an API call per record which could take hours).

**Backfill job** scoping: iterate existing `textract_results` where `textract_job_status = succeeded` AND `structured_extraction IS NULL` AND `textract_job_result_text IS NOT NULL` AND `textract_job_result_text != ''`. The text presence check prevents wasting API calls on records with empty OCR text (a `succeeded` status does not guarantee non-empty text).

**Rate limiting:** Use `find_each(batch_size: 100)` with a per-record `sleep 0.2` between GPT-4o-mini calls to stay under OpenAI rate limits.

**Per-record error handling:** Rescue API errors per record, log the error with the `textract_result.id`, and continue to next record. The `IS NULL` guard ensures re-running the job picks up any records that failed on a prior run.

**Uses the same service as the real-time path** — calls `ExtractStructuredResumeData` (or whatever the service is named) for each record.

**Expected deviation from reference backfill:** The reference backfill uses raw SQL because it only needs to set a tsvector from existing text. The new backfill MUST call the service because it needs the GPT-4o-mini extraction step. The tsvector update happens automatically via the trigger when `structured_extraction_text` is written.

## Parallel redundancy

The existing structured data extraction in the AI summary pipeline (`AiJobApplicationAction::Summary::Generate#generate`, Call 1) continues to run unchanged. Both paths read `textract_job_result_text` — no write conflicts. New extraction stores on `TextractResult.structured_extraction`; existing stores on `AiJobApplicationSummary.structured_data`. Once the new Textract-level extraction is stable and backfilled, remove the duplicate call from the summary pipeline. No coordination needed — both can coexist.

## Test requirements

### Existing tests that may need updating

- `spec/models/textract_result_ai_trigger_spec.rb` — tests `queue_ai_summary_job` callback. If the new extraction is added as a separate `after_commit` callback, these tests may need to stub or account for the new callback firing alongside the existing one.
- `spec/jobs/get_resume_text_from_textract_job_spec.rb` — tests the job's `perform` method which calls `parse_resume_text`. If the call site integration affects `parse_resume_text`, this spec needs review.

### New tests needed

- **Service unit test:** extraction call returns structured data, `structured_extraction` is stored on TextractResult, flattening produces correct `structured_extraction_text`, API failure raises `CustomErrorStructuredExtraction` (so the job can retry)
- **Model test:** `pg_search_scope :search_resume_text` works with `structured_extraction_text`, `search_resume_by_keyword` returns ranked results with highlights
- **Job test:** `ExtractStructuredResumeDataJob` enqueues correctly, retry/exhaustion behavior works, exhaustion logs and moves on
- **Integration/callback test:** Textract success (creating/updating TextractResult with `textract_job_result_text`) enqueues the extraction job
- **Idempotency test:** calling the service twice on the same TextractResult overwrites `structured_extraction` and `structured_extraction_text` cleanly

## Out of scope

- Frontend keyword search UI
- Connect version search endpoints / controller / serializer
- Changes to the AI summary pipeline (runs in parallel until cutover)

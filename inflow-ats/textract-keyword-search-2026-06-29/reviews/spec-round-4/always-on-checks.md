# Always-On Checks — Round 4

## Source Accuracy

All file paths, class names, method names, column names, and gem versions verified against current source:

- `textract_results` table: schema.rb:1222 — columns match spec line 138 (textract_job_id string, textract_job_status integer default 0, textract_job_result jsonb, textract_job_result_text text, job_application_id bigint). No textsearch_vector/structured_extraction/structured_extraction_text yet — correctly identified as new.
- `GetResumeTextFromTextract`: exists at `app/services/get_resume_text_from_textract.rb` with `parse_resume_text` method (line 8). Success path at line 31: `if @textract_result.update(update_textract_params)`.
- `TextractResult`: `after_commit :queue_ai_summary_job, on: [:create, :update]` at line 7. Guards at lines 115-116. Associations: `belongs_to :job_application` (line 4), `has_many :ai_job_application_summaries` (line 5).
- `pg_search` 2.3.2: Gemfile line 125, Gemfile.lock line 364. Compatible with activerecord 6.1.7.7. Used in Candidate, Organization, Job, User.
- `fx` ~> 0.8.0: not in main Gemfile (correct). Reference Gemfile line 162, Gemfile.lock resolves 0.8.0. Compatible with Rails 6.1 (requires activerecord >= 6.0.0).
- `resume_structured_data.rb`: exists at referenced path. Schema matches spec lines 105-115 exactly — all 11 fields, all types, all required constraints. Model is `gpt-4o-mini` (line 84).
- `tsvector_update_trigger`: Postgres built-in. Argument signature `(tsvector_column, dictionary, source_column)` confirmed from reference schema.rb:1208.
- `AiApiRequest`: model at `app/models/ai_api_request.rb`. `belongs_to :requestable, polymorphic: true` (line 5). Schema columns: `organization_id` NOT NULL, `requestable_type`/`requestable_id` NOT NULL, `call_type`/`provider`/`model` NOT NULL, `input_tokens`, `output_tokens`, `cost`, `prompt_text`, `response_body`.
- `AiClient.calculate_cost`: exists at `app/services/ai_client.rb:35`.
- `CustomErrorTextract` / `CustomErrorAiSummary`: both in `app/errors/`, both `< StandardError` with `attr_reader :param`. Pattern for new `CustomErrorStructuredExtraction` is clear.
- `call_type` column: free-form string, not an enum. Existing values include `extraction`, `assessment`, `comparison`, `summary`, etc. Proposed `keyword_extraction` is distinct.

## Test Coverage

Test requirements section (lines 232-245) covers all necessary areas:
- Existing tests identified: `textract_result_ai_trigger_spec.rb`, `get_resume_text_from_textract_job_spec.rb`
- New tests: service unit (5 aspects including error raising), model (pg_search + search method), job (enqueue + retry/exhaustion), integration/callback, idempotency
- No gaps.

## Backward Compatibility

- No serializers, controllers, routes, views, or frontend code reference TextractResult — confirmed via prior rounds. New columns cannot leak.
- `include PgSearch::Model` safe — already on 4 models, no method name collisions on TextractResult.
- `has_many :ai_api_requests, as: :requestable` safe — read-side association, no schema change, matches AiJobApplicationSummary and AiJobCriteria pattern.
- New columns nullable, no defaults affecting existing records.
- `textsearch_vector` trigger handles NULL `structured_extraction_text` by setting vector to NULL.

## Full-Stack Analog Completeness

All in-scope layers covered:
- Migrations: 3 columns + 1 trigger (lines 150-166)
- Service: extraction + flattening + AiApiRequest (lines 168-191)
- Background job: with retry/exhaustion (lines 199-204)
- Model: PgSearch + search method + association (lines 206-212)
- Backfill: data migration + backfill job (lines 214-226)
- Error class: CustomErrorStructuredExtraction (line 201)
- Out-of-scope documented: controller, serializer, frontend, summary pipeline changes (lines 247-251)

## Analog Structural Matching

- Migration structure matches reference exactly (column type, GIN index)
- Trigger uses `fx` gem API (`create_trigger` with `sql_definition:`) — documented deviation from file-based
- Trigger SQL changes only third argument — verified
- `pg_search_scope` changes only `against:` — all 7 highlight keys, dictionary, prefix, ranked_by match
- `search_resume_by_keyword` signature and chain match exactly
- Backfill deviation documented (API call vs raw SQL)

## Findings

No issues found.

# Always-On Checks — Round 5

## Source Accuracy

All file paths, class names, method names, column names, and gem versions verified against source:

- `textract_results` table: `db/schema.rb:1222` — columns match spec line 138. No new columns yet (structured_extraction, structured_extraction_text, textsearch_vector are new additions).
- `GetResumeTextFromTextract`: `app/services/get_resume_text_from_textract.rb` with `parse_resume_text` at line 8. Success path at line 31: `if @textract_result.update(update_textract_params)`.
- `TextractResult`: `app/models/textract_result.rb`. `after_commit :queue_ai_summary_job, on: [:create, :update]` at line 7. Guards at lines 115-116. Associations at lines 4-5.
- `pg_search` 2.3.2: Gemfile line 125, Gemfile.lock line 364. Used in Candidate, Organization, Job, User.
- `fx`: Not in main Gemfile (confirmed). Reference has `~> 0.8.0` resolved to 0.8.0.
- `resume_structured_data.rb`: Exists at `app/services/ai_job_application_action/summary/prompts/resume_structured_data.rb`. Schema fields match spec exactly.
- `AiClient.calculate_cost`: Exists at `app/services/ai_client.rb:35`.
- `AiApiRequest`: `app/models/ai_api_request.rb`. `belongs_to :requestable, polymorphic: true` at line 5. Schema: `organization_id null: false`, `requestable_type null: false`, `requestable_id null: false`, `call_type null: false`, `provider null: false`, `model null: false`.
- Custom error classes: `app/errors/custom_error_textract.rb` and `app/errors/custom_error_ai_summary.rb` both exist, both `< StandardError`.
- `.gitignore` line 43: `*.sql` confirmed.

## Test Coverage

Test requirements section (lines 232-245) covers:
- 2 existing specs identified for potential updates
- 5 categories of new tests: service unit, model, job, integration/callback, idempotency
- Test description for service unit (line 241) correctly says "API failure raises `CustomErrorStructuredExtraction`" — consistent with spec line 201.

## Backward Compatibility

- No serializers reference TextractResult (grep confirmed zero hits in `app/serializers/`).
- No controllers reference textract_result (grep confirmed zero hits in `app/controllers/`).
- `include PgSearch::Model` safe — already on 4 models, no method name collisions.
- `has_many :ai_api_requests, as: :requestable` safe — read-side association, no schema change.
- New columns nullable — existing records unaffected.
- `tsvector_update_trigger()` handles NULL source gracefully (sets vector to NULL).

## Full-Stack Analog Completeness

All in-scope layers covered:
- Migrations: 3 columns + trigger (lines 150-166)
- Service: extraction + flattening + AiApiRequest (lines 170-191)
- Job: background processing + retry/exhaustion (lines 199-204)
- Error class: CustomErrorStructuredExtraction (line 201)
- Model: PgSearch + association (lines 208-212)
- Backfill: data migration + job (lines 214-226)
- Tests: existing + new (lines 232-245)
- Out-of-scope documented: controller, serializer, frontend, summary changes (lines 247-251)

## Findings

No issues found.

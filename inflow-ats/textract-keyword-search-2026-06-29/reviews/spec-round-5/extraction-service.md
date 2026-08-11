# Extraction Service — Round 5

## Findings

No issues found.

## Verified

- **Prompt/schema match**: Spec lines 96-115 list all 11 fields. Verified against actual `resume_structured_data.rb` JSON_SCHEMA (lines 22-82): name, email, phone, location (string|null); links, skills, certifications (array of strings); professional_summary, stated_experience (string|null); work_experience (array of objects: company, title, start_date, end_date, description — all string|null, all required); education (array of objects: institution, degree, field_of_study, graduation_year — all string|null, all required). All match exactly.
- **Model**: `gpt-4o-mini` at `resume_structured_data.rb:84` — matches spec line 98.
- **Messages method**: `messages(resume_text:, job_title: nil)` at line 86 — spec correctly notes `job_title` is optional and decides to include it (spec line 173).
- **Flattening algorithm** (spec lines 179-191): Complete for all 11 fields. 6 scalars in step 1, 3 string arrays in step 2, 2 object arrays with all sub-fields in step 3. Null handling (step 4), separator (step 5), no JSON syntax (step 6), no labels (step 7). Edge cases handled: empty arrays produce no output; all-null fields produce empty/minimal text (tsvector trigger handles NULL gracefully — sets vector to NULL).
- **AiApiRequest** (spec line 174): All required fields specified. `organization_id` is `null: false` on `ai_api_requests` (schema.rb). Navigation path `textract_result.job_application.job&.organization` verified valid through model associations. Nil guard specified. `call_type: 'keyword_extraction'` distinct from existing values. `AiClient.calculate_cost` confirmed at `ai_client.rb:35`.
- **CustomErrorStructuredExtraction** (spec line 201): Matches existing pattern — `CustomErrorTextract < StandardError` (3-line file in `app/errors/`). File path `app/errors/custom_error_structured_extraction.rb` consistent.
- **Service naming**: `ExtractStructuredResumeData` with method `extract` — consistent with cursor_rules (no 'service' in filename, descriptive method name). Takes ID from job context.
- **Test description** (spec line 241): "API failure raises `CustomErrorStructuredExtraction`" — consistent with spec line 201 "The service raises this on API failure." No contradiction.

# Extraction Service — Round 4

## Findings

No issues found.

## Verified

- **Prompt/schema match**: Spec lines 96-115 describe the extraction schema. Verified against `resume_structured_data.rb`: all 11 fields match (name, email, phone, location, links, professional_summary, stated_experience, work_experience with 5 sub-fields, education with 4 sub-fields, skills, certifications). All `required` in JSON schema. Types match (`[string null]` for scalars, `array` for lists). Model is `gpt-4o-mini` (line 84 of prompt file).
- **`job_title` parameter**: Spec line 173 explicitly includes it. The prompt's `messages` method accepts `job_title: nil` as optional kwarg (line 86). Rationale given (match summary pipeline output).
- **Service method name**: `extract` (spec line 171). Not `call` — matches cursor_rules/backend/services.md rule 2.
- **Parameter type**: TextractResult ID (spec line 172). Matches cursor_rules rule 3 (IDs from jobs).
- **AiApiRequest creation** (spec line 174): All required fields specified: `organization` (with navigation path `textract_result.job_application.job&.organization` and nil guard), `requestable` (TextractResult), `call_type: 'keyword_extraction'` (distinct from summary pipeline's `'extraction'`), `provider: 'openai'`, `model`, `input_tokens`, `output_tokens`, `cost` (via `AiClient.calculate_cost` — confirmed at ai_client.rb:35), `prompt_text`, `response_body`. Verified against `ai_api_requests` schema (schema.rb:114-127): `organization_id` NOT NULL, `requestable_type`/`requestable_id` NOT NULL, `call_type` NOT NULL, `provider` NOT NULL, `model` NOT NULL. All covered.
- **Flattening algorithm** (spec lines 179-191): Complete for all 11 schema fields. 7 rules: include non-null scalars (6 fields), include string arrays (3 fields), include object array sub-fields (2 compound types with all sub-fields enumerated), skip nulls, newline separator, no JSON syntax, no labels. Edge cases handled: empty arrays produce nothing, all-null yields empty string → trigger sets tsvector to NULL.
- **Custom error class**: `CustomErrorStructuredExtraction` (spec line 201). File path `app/errors/custom_error_structured_extraction.rb` matches existing pattern (`CustomErrorTextract` at `app/errors/custom_error_textract.rb`, `CustomErrorAiSummary` at `app/errors/custom_error_ai_summary.rb` — both `< StandardError` with `attr_reader :param`).
- **Test description** (spec line 241): "API failure raises `CustomErrorStructuredExtraction` (so the job can retry)" — consistent with service behavior at spec line 201. Round 3 contradiction resolved.

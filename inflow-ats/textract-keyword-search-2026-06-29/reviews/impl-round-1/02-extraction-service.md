# extraction-service -- Round 1

## Findings

No issues found.

## Verified

- **Prompt and schema**: Service calls `AiJobApplicationAction::Summary::Prompts::ResumeStructuredData.messages(resume_text:, job_title:)`, `.model`, and `.response_format` -- identical to the existing Call 1 in `AiJobApplicationAction::Summary::Generate#generate` (lines 46-54). Uses `gpt-4o-mini` via the existing prompt class constant.

- **AiClient integration**: `AiClient.new(provider: 'openai')` followed by `ai_client.chat(messages:, model:, response_format:)` -- matches the analog pattern in generate.rb:43-54.

- **JSON parsing**: `JSON.parse(result[:content])` -- same pattern as generate.rb:58. Rescues `JSON::ParserError` and re-raises as `CustomErrorStructuredExtraction`.

- **Error re-raising**: The critical `rescue CustomErrorAiSummary => e` block correctly catches the error raised by `AiProviders::Openai` (verified: openai.rb raises `CustomErrorAiSummary` on API errors at line 23, connection errors at line 35, and parse errors at line 38) and re-raises as `CustomErrorStructuredExtraction`. This ensures the extraction job's `retry_on CustomErrorStructuredExtraction` works independently of the AI summary pipeline.

- **Storage**: Updates TextractResult with `structured_extraction: structured_data` (jsonb) and `structured_extraction_text: flattened_text` (text). The `update` return value is checked with if/else per cursor_rules rule 12.

- **Flattening algorithm**: Verified line by line against spec requirements:
  - Scalar fields: iterates `%w[name email phone location professional_summary stated_experience]`, skips nil/blank via `value.present?`
  - Array-of-string fields: iterates `%w[skills certifications links]`, each item checked with `value.present?`
  - Array-of-object fields: `work_experience` iterates `%w[company title start_date end_date description]`; `education` iterates `%w[institution degree field_of_study graduation_year]`
  - Join with `"\n"` -- newline separator per spec
  - No JSON syntax, no field labels -- correct

- **AiApiRequest creation**: `create_ai_api_request` method matches the analog at generate.rb:296-313. Key correct deviations: `requestable: @textract_result` (not ai_summary), `call_type: 'keyword_extraction'` (not 'extraction'). Uses `AiClient.calculate_cost` with `.to_f.round(6)` -- same pattern. Stores `prompt_text: messages.to_json` and `response_body: result[:content]`.

- **Guard clauses**: Three guards in correct order: (1) return unless @textract_result, (2) return unless textract_job_result_text.present?, (3) return unless organization. All use bare `return` per cursor_rules rule 8.

- **Idempotency**: `update` on the same record overwrites both columns cleanly. No uniqueness constraints that would prevent re-processing.

- **Constructor**: `def initialize(textract_result_id:)` takes ID (not object) per cursor_rules rule 3 (called from background job). Loads record with `find_by(id:)` which returns nil for missing records (no exception).

- **Public method name**: `extract` -- descriptive, not `call`, per cursor_rules rule 2.

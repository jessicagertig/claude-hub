# Extraction Service

## Verdict: PASS

### Findings

None.

### Verification

- Service uses the exact same prompt class: `AiJobApplicationAction::Summary::Prompts::ResumeStructuredData.messages(resume_text:, job_title:)`
- Same model: `ResumeStructuredData.model` (gpt-4o-mini)
- Same response format: `ResumeStructuredData.response_format`
- Same AiClient pattern: `AiClient.new(provider: 'openai')`, `ai_client.chat(messages:, model:, response_format:)` — matches `generate.rb:43-58`
- Stores structured data in `structured_extraction` (jsonb) on TextractResult
- Flattens into `structured_extraction_text` via `flatten_structured_data`:
  - Includes all non-null scalar fields: `name`, `email`, `phone`, `location`, `professional_summary`, `stated_experience`
  - Includes all items from array-of-string fields: `skills`, `certifications`, `links`
  - Includes all sub-fields from array-of-object fields: `work_experience` (`company`, `title`, `start_date`, `end_date`, `description`), `education` (`institution`, `degree`, `field_of_study`, `graduation_year`)
  - Uses newline separators (`parts.join("\n")`)
  - No JSON syntax in output (no braces, brackets, quotes, colons, commas)
  - No field labels (no "Name:" prefixes)
  - Skips null values via `value.present?`
- Error handling: catches `CustomErrorAiSummary` (raised by OpenAI provider at `ai_providers/openai.rb:22-39`) and re-raises as `CustomErrorStructuredExtraction` — isolates extraction errors from the AI summary pipeline
- Also catches `JSON::ParserError` and re-raises as `CustomErrorStructuredExtraction`
- Idempotent: `update` overwrites both columns cleanly — no duplicate records or errors on second call
- `AiApiRequest` creation with `requestable: @textract_result`, `call_type: 'keyword_extraction'` (distinct from summary pipeline's `'extraction'`), `provider: 'openai'` — matches `generate.rb:296-313` pattern
- Guard clauses: missing record (`return unless @textract_result`), missing text (`return unless ... .present?`), missing organization (`return unless organization`) — all bare returns per core_critical_rules.md Rule 8
- Uses `update` (not `update!`) and checks return value with `if`/`else` per Rules 11/12
- Uses `ap` for logging, not `pp` per Rule 3

# extraction-service -- Round 2

## Verified

- Prompt and schema: service calls `AiJobApplicationAction::Summary::Prompts::ResumeStructuredData.messages(resume_text:, job_title:)`, `.model`, `.response_format` -- identical to existing pipeline Call 1 at `generate.rb:46-54`
- AiClient usage: `AiClient.new(provider: 'openai')` + `ai_client.chat(messages:, model:, response_format:)` -- matches analog
- Storage: `structured_extraction` (jsonb) and `structured_extraction_text` (text) on TextractResult
- Flattening algorithm: all scalar fields (name, email, phone, location, professional_summary, stated_experience), array-of-string fields (skills, certifications, links), array-of-object fields (work_experience sub-fields, education sub-fields), newline-separated, no JSON syntax, no field labels -- matches spec exactly
- Error handling: `rescue CustomErrorAiSummary` re-raises as `CustomErrorStructuredExtraction`; `rescue JSON::ParserError` re-raises as `CustomErrorStructuredExtraction` -- extraction errors are isolated from the AI summary pipeline
- Guards: return unless textract_result exists, return unless text present, return unless organization exists -- all bare `return` (no truthy/falsy values per cursor_rules rule 8)
- AiApiRequest creation: `call_type: 'keyword_extraction'` (distinct from summary pipeline's `'extraction'`), `requestable: @textract_result`, cost via `AiClient.calculate_cost`, created inside `if @textract_result.update(...)` conditional -- matches analog at `generate.rb:296-313`
- `|| 0` for `input_tokens`/`output_tokens` matches the analog at `generate.rb:298-299` exactly
- Idempotency: `update` overwrites existing values cleanly

## Findings

No issues found.

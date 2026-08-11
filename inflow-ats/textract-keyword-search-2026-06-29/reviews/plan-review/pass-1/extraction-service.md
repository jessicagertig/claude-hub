# Pass 1 — extraction-service

## Fact Check

### Prompt and schema (plan step 4.1)
- Plan: `AiJobApplicationAction::Summary::Prompts::ResumeStructuredData.messages(resume_text:, job_title:)`
- Source: file exists at `app/services/ai_job_application_action/summary/prompts/resume_structured_data.rb`. Class methods: `.messages(resume_text:, job_title: nil)`, `.response_format`, `.model`. `MODEL = 'gpt-4o-mini'`
- Schema fields match spec: name, email, phone, location, links, professional_summary, stated_experience, work_experience (company/title/start_date/end_date/description), education (institution/degree/field_of_study/graduation_year), skills, certifications
- **VERIFIED**

### AiClient pattern (plan step 4.1)
- Plan: `AiClient.new(provider: 'openai')`, `ai_client.chat(messages:, model:, response_format:)`
- Source: matches `generate.rb:46-58` (Call 1 extraction). `openai.rb` returns `{ content:, input_tokens:, output_tokens:, model: }` hash
- **VERIFIED**

### Structured data storage (plan step 4.1)
- `textract_result.update(structured_extraction: structured_data, structured_extraction_text: flattened_text)`
- Uses non-bang `update` with if/else return check per cursor_rules rule 12
- **VERIFIED** -- compliant

### Flattening algorithm (plan step 4.2)
- Covers all spec fields: 6 scalar fields, 3 array-of-string fields, work_experience (5 sub-fields), education (4 sub-fields)
- Skips nulls via `value.present?`
- Joins with `"\n"` (newline separator)
- No JSON syntax, no field labels
- **VERIFIED** -- matches spec algorithm exactly

### Error handling (plan step 4.1)
- `rescue CustomErrorAiSummary => e` re-raises as `CustomErrorStructuredExtraction`
- Source: `openai.rb` raises `CustomErrorAiSummary` on API error (line 23), connection error (line 35), JSON parse error (line 39)
- Re-raise is critical: without it, the extraction job's `retry_on CustomErrorStructuredExtraction` would never trigger, and the error could accidentally match AI summary pipeline retry logic
- **VERIFIED** -- correct and critical

### JSON::ParserError rescue (plan step 4.1)
- The service does `JSON.parse(result[:content])` -- this is the LLM's output content, separate from the API envelope parsing done by `openai.rb`
- If the LLM returns invalid JSON in the content field, `JSON::ParserError` is raised at the service level
- Re-raised as `CustomErrorStructuredExtraction` for job retry
- **VERIFIED** -- handles a real failure mode

### AiApiRequest creation (plan step 4.3)
- `call_type: 'keyword_extraction'` -- distinct from existing values ('extraction', 'assessment', 'comparison', 'summary')
- `requestable: textract_result` -- polymorphic. `AiApiRequest` has `belongs_to :requestable, polymorphic: true`
- `has_many :ai_api_requests, as: :requestable` added to TextractResult (plan step 6.2) -- matches `AiJobApplicationSummary` (line 6) and `AiJobCriteria` (line 5)
- `AiClient.calculate_cost(model:, input_tokens:, output_tokens:)` confirmed at `ai_client.rb:35-36`
- `|| 0` for token counts: matches analog at `generate.rb:298-299` (exact same pattern). Pre-existing pattern, not a new violation
- **VERIFIED**

### Guard clauses (plan step 4.1)
- `return unless textract_result exists` -- bare return, per cursor_rules rule 8
- `return unless textract_result.textract_job_result_text.present?` -- bare return
- `return unless organization` -- bare return
- **VERIFIED** -- compliant

### Service naming and methods (plan step 4.1)
- Class: `ExtractStructuredResumeData` -- no "Service" suffix (cursor_rules/backend/services.md rule 1)
- File: `app/services/extract_structured_resume_data.rb` -- snake_case, no "service"
- Public method: `extract` -- descriptive, not `call` (rule 2)
- Constructor: `def initialize(textract_result_id:)` -- keyword arg, takes ID from job context (rule 3)
- **VERIFIED** -- fully compliant

### Idempotency
- `textract_result.update()` overwrites `structured_extraction` and `structured_extraction_text` with new values
- No uniqueness constraints on these columns
- Re-calling the service produces a fresh extraction and overwrites cleanly
- **VERIFIED**

## Completeness

| Spec requirement | Plan step | Status |
|-----------------|-----------|--------|
| GPT-4o-mini call using existing prompt/schema | 4.1 | Present |
| Stores structured_extraction (jsonb) | 4.1 | Present |
| Flattens to structured_extraction_text (text) | 4.2 | Present |
| Flattening: all fields, no JSON, no labels, newlines | 4.2 | Present |
| AiApiRequest with keyword_extraction call_type | 4.3 | Present |
| has_many :ai_api_requests, as: :requestable | 6.2 | Present |
| CustomErrorAiSummary re-raised as CustomErrorStructuredExtraction | 4.1 | Present |
| JSON::ParserError handled | 4.1 | Present |
| Guards: missing record, no text, no org | 4.1 | Present |
| Idempotent (overwrite on re-call) | implicit | Present |

## Findings

0 BLOCKER, 0 HIGH, 0 MED, 0 LOW

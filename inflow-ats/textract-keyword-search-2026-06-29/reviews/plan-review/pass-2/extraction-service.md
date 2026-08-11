# Pass 2 — extraction-service

## Pass 1 corrections
None needed. Pass 1 found 0 findings.

## Fresh scrutiny

### Safe navigation consistency
- Organization lookup: `textract_result.job_application&.job&.organization` — uses `&.` on `job_application`
- Job title lookup: `textract_result.job_application.job&.title` — does NOT use `&.` on `job_application`
- `belongs_to :job_application` is required (not optional), so `job_application` is guaranteed non-nil for persisted records
- The organization guard fires BEFORE the job_title line, so nil job_application would cause early return before reaching job_title
- Inconsistency is cosmetic, not functional. Implementation detail for the implementing agent.

### Service update triggers callbacks
- `textract_result.update(structured_extraction:, structured_extraction_text:)` fires `after_commit` callbacks
- `queue_ai_summary_job` guard: `saved_change_to_textract_job_result_text?` = FALSE (didn't change that column). Returns early. No duplicate AI summary job.
- `queue_structured_extraction_job` guard: `saved_change_to_textract_job_result_text?` = FALSE. Returns early. No infinite loop.
- Trigger auto-updates `textsearch_vector` via the Postgres trigger (database level, not Rails callback)
- **All side effects are correct**

### Error propagation chain
1. OpenAI API error → `openai.rb` raises `CustomErrorAiSummary`
2. Service catches `CustomErrorAiSummary` → re-raises as `CustomErrorStructuredExtraction`
3. Job catches `CustomErrorStructuredExtraction` → re-raises for `retry_on`
4. After 3 attempts → exhaustion block logs and stops

This chain is correct. Without step 2, the error would be `CustomErrorAiSummary`, and:
- The extraction job's `retry_on CustomErrorStructuredExtraction` would NOT match
- The AI summary job's `retry_on CustomErrorAiSummary` could potentially match if both jobs are running for the same record
- The re-raise in step 2 is critical for pipeline isolation

### JSON.parse placement
- `openai.rb` parses the API response envelope (HTTP response → hash with `content`, `input_tokens`, etc.)
- Service's `JSON.parse(result[:content])` parses the LLM's structured output (JSON string → Ruby hash)
- These are two different parse steps. The service's rescue of `JSON::ParserError` catches malformed LLM output, not malformed API responses.
- **Correct** — both parse steps are needed

### AiApiRequest conditional creation
- Plan creates AiApiRequest only if `textract_result.update()` succeeds (inside the `if` block)
- If the update fails, the API call still happened and cost was incurred, but no AiApiRequest is created
- Update failures on new nullable columns are extremely unlikely (no validations on `structured_extraction` or `structured_extraction_text`)
- Matches the general pattern — AiApiRequest records the successful operation, not just the API call
- **Acceptable design**

### Flattening edge cases
- Empty arrays (`skills: []`, `work_experience: []`): `values&.each` iterates zero times, adds nothing to `parts`. Correct.
- All-null structured data: every field is null → `parts` is empty → `parts.join("\n")` returns `""`. An empty string stored in `structured_extraction_text` means the tsvector trigger sets `textsearch_vector` to an empty tsvector (not NULL). This is fine — no search results for empty text.
- Mixed null/present values in objects: `work_experience_entry[sub_field]` returns nil for missing keys → `value.present?` is false → skipped. Correct.

## Completeness sweep

All spec requirements for the service verified present in plan:
- GPT-4o-mini call via existing prompt class: step 4.1
- Structured data storage: step 4.1
- Flattening with all field types: step 4.2
- AiApiRequest creation: step 4.3
- Error handling (re-raise chain): step 4.1
- Guard clauses: step 4.1
- Idempotency: implicit (update overwrites)

## Findings

0 BLOCKER, 0 HIGH, 0 MED, 0 LOW

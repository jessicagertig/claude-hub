# Layer 2 — Code Correctness: ExtractStructuredResumeData

**File reviewed:** `app/services/extract_structured_resume_data.rb`
**Related files read:** `app/services/ai_providers/openai.rb`, `app/services/ai_client.rb`, `app/services/ai_job_application_action/summary/prompts/resume_structured_data.rb`, `app/models/ai_api_request.rb`

---

## Findings

```
FINDING-ID: L2-SVC-1
SEVERITY: MED
FILE: app/services/extract_structured_resume_data.rb
LINE: 29
BUG: JSON.parse(nil) raises TypeError, not JSON::ParserError.
If the OpenAI API returns a 200 response but choices[0].message.content is nil,
result[:content] is nil. JSON.parse(nil) raises TypeError ("no implicit conversion
of nil into String"). The rescue on line 48 only catches JSON::ParserError.
TypeError would propagate uncaught from the service.

The job's rescue StandardError (line 18 of the job) DOES catch TypeError, so
the error would be swallowed and logged at the job level — not retried. The
extraction would silently fail without a retry attempt.

Likelihood: Low. OpenAI's response_format: json_schema guarantees content is
present on 200 responses. This would only occur on an API contract violation.

Fix: Either add `rescue TypeError` alongside JSON::ParserError, or guard with
`raise CustomErrorStructuredExtraction, 'nil content from API' unless result[:content]`
before JSON.parse.
```

---

## Checks that passed

1. **Null safety (line 13 vs 16):** Line 13 uses `job_application&.job&.organization` with safe navigation throughout. Line 16 uses `job_application.job&.title` without `&.` on `job_application`. This is safe: `belongs_to :job_application` is required by default in Rails 5+, and line 13's success guarantees both `job_application` and `job` are non-nil (if either were nil, `organization` would be nil and line 14 would return early).

2. **Error handling — update failure (line 33-42):** If `update` returns false, the service logs and uses `ap`. No error is raised. The extraction silently fails. This is acceptable: the service is supplementary and the job does not retry on update failures.

3. **Error handling — AiApiRequest.create failure (line 94):** Uses `create` (not `create!`), so validation failures return a false-y record without raising. The TextractResult update has already succeeded, so extraction data is preserved even if the cost record fails. Acceptable for an auditing record.

4. **Flattening — integer values (line 80):** `graduation_year` is defined as `type: [string, null]` in the JSON schema, so the API always returns a string. `present?` on strings works correctly. No integer edge case.

5. **Flattening — deeply nested nulls (lines 70-84):** `structured_data['work_experience']` uses `&.each` (safe nil navigation). Individual sub-field values checked with `value.present?` which handles nil correctly.

6. **Thread safety:** No shared mutable state. `@textract_result` and `@textract_result_id` are set once in the constructor. `AiClient` creates a new instance per call. No class-level mutable state.

7. **Memory:** No unbounded growth. `parts` array is bounded by the number of fields in the structured extraction schema. Resume text size is bounded by OCR output (typically < 50KB).

8. **Idempotency:** Calling `extract` twice calls the API twice (wasting one API call + creating a duplicate AiApiRequest), but the TextractResult columns are overwritten cleanly. No uniqueness constraints violated. The duplicate AiApiRequest is a minor cost concern, not a correctness bug.

9. **calculate_cost with unknown model:** If `result[:model]` is not in `PRICING`, `calculate_cost` returns `nil`. `nil.to_f` returns `0.0`. Cost is recorded as 0. Not a bug — just a gap in cost tracking for new model versions. Matches existing behavior.

---

**VERDICT: 1 MED finding (L2-SVC-1)**

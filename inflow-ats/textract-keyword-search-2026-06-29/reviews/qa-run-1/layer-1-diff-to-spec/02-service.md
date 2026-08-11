# Layer 1 — Diff-to-Spec Review: Service (ExtractStructuredResumeData)

**Focus area:** Service implementation, flattening algorithm, AiApiRequest creation
**Files reviewed:** `app/services/extract_structured_resume_data.rb`
**Analog files compared:** `app/services/ai_job_application_action/summary/generate.rb:46-58,296-313`, `app/services/ai_job_application_action/summary/prompts/resume_structured_data.rb`, `app/services/ai_providers/openai.rb`

## Verification Checklist

| # | Spec requirement | Code location | Status |
|---|---|---|---|
| 1 | Class name `ExtractStructuredResumeData` (no "Service") | Line 3 | PASS |
| 2 | Constructor takes `textract_result_id:`, loads via `find_by` | Lines 4-6 | PASS |
| 3 | Public method `extract` (not `call`) | Line 9 | PASS |
| 4 | Guard: returns unless textract_result | Line 10 | PASS |
| 5 | Guard: returns unless text present | Line 11 | PASS |
| 6 | Guard: returns unless organization | Lines 13-14 | PASS |
| 7 | Uses existing prompt class `.messages`, `.model`, `.response_format` | Lines 17-26 | PASS |
| 8 | Includes `job_title` from `job_application.job&.title` | Line 16 | PASS |
| 9 | `AiClient.new(provider: 'openai')` + `.chat` | Lines 22-27 | PASS |
| 10 | Parses `result[:content]` as JSON | Line 29 | PASS |
| 11 | Calls `flatten_structured_data` (private) | Line 31 | PASS |
| 12 | Updates both `structured_extraction` and `structured_extraction_text` | Lines 33-36 | PASS |
| 13 | Creates AiApiRequest on successful update | Line 37 | PASS |
| 14 | Rescues `CustomErrorAiSummary` → re-raises `CustomErrorStructuredExtraction` | Lines 43-47 | PASS |
| 15 | Rescues `JSON::ParserError` → re-raises `CustomErrorStructuredExtraction` | Lines 48-52 | PASS |
| 16 | Logs via `Rails.logger.error` + `ap` on failures | Lines 39-41, 44-46, 49-51 | PASS |

## Flattening Algorithm Verification

Spec section "Flattening algorithm" specifies 7 rules. Verified against `flatten_structured_data` (lines 57-86):

| Rule | Verification | Status |
|---|---|---|
| Include ALL non-null scalar fields | `name`, `email`, `phone`, `location`, `professional_summary`, `stated_experience` — all 6 present | PASS |
| Include array-of-string fields | `skills`, `certifications`, `links` — all 3 present | PASS |
| Include work_experience sub-fields | `company`, `title`, `start_date`, `end_date`, `description` — all 5 | PASS |
| Include education sub-fields | `institution`, `degree`, `field_of_study`, `graduation_year` — all 4 | PASS |
| Skip null values | `value.present?` guard on every append | PASS |
| Separate with newlines | `parts.join("\n")` | PASS |
| No JSON syntax, no field labels | No braces/brackets/quotes/colons added; no "Name:" prefixes | PASS |

Cross-checked all 11 top-level fields from JSON schema (`resume_structured_data.rb:78`) against flattening — all covered.

## AiApiRequest Analog Comparison

Compared `create_ai_api_request` (lines 89-106) against analog at `generate.rb:296-313`:

| Field | New service | Analog | Match? |
|---|---|---|---|
| `organization:` | local var | `@organization` instance var | SAME (same value) |
| `requestable:` | `@textract_result` | `ai_summary` | EXPECTED DEVIATION (spec: TextractResult) |
| `call_type:` | `'keyword_extraction'` | parameterized | EXPECTED DEVIATION (spec: distinct type) |
| `provider:` | `'openai'` hardcoded | parameterized | SAME (always openai for extraction) |
| `model:` | `result[:model]` | `result[:model]` | SAME |
| `input_tokens:` | `result[:input_tokens] \|\| 0` | `result[:input_tokens] \|\| 0` | SAME |
| `output_tokens:` | `result[:output_tokens] \|\| 0` | `result[:output_tokens] \|\| 0` | SAME |
| `cost:` | `AiClient.calculate_cost(...).to_f.round(6)` | identical | SAME |
| `prompt_text:` | `messages.to_json` | `messages.to_json` | SAME |
| `response_body:` | `result[:content]` | `result[:content]` | SAME |

## VERDICT: CLEAN — 0 findings

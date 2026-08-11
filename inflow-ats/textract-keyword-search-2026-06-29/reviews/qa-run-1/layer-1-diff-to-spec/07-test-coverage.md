# Layer 1 — Test Coverage Review

**Focus:** Test files in the diff vs. SPEC test requirements section
**Files reviewed:**
- `spec/services/extract_structured_resume_data_spec.rb` (344 lines)
- `spec/jobs/extract_structured_resume_data_job_spec.rb` (66 lines)
- `spec/models/textract_result_keyword_search_spec.rb` (151 lines)
- `spec/models/textract_result_ai_trigger_spec.rb` (existing — reviewed for interference)

---

## Checklist

### Service unit test (extract_structured_resume_data_spec.rb)

| Spec requirement | Present | Lines |
|---|---|---|
| Happy path: stores `structured_extraction` and `structured_extraction_text` | YES | 85-103 |
| Flattening correctness: all field types, no JSON syntax, no labels | YES | 116-153 |
| Null handling: null values omitted from flattened text | YES | 191-200 |
| AiApiRequest creation: `requestable: textract_result`, `call_type: 'keyword_extraction'` | YES | 213-226 |
| API failure: `CustomErrorAiSummary` re-raised as `CustomErrorStructuredExtraction` | YES | 239-245 |
| JSON parse failure: raises `CustomErrorStructuredExtraction` | YES | 267-271 |
| Guard: missing textract_result — returns early | YES | 275-279 |
| Guard: no text — returns early | YES | 292-296 |
| Guard: no organization — returns early | YES | 309-321 |
| Idempotency: second call overwrites cleanly | YES | 334-341 |

### Job test (extract_structured_resume_data_job_spec.rb)

| Spec requirement | Present | Lines |
|---|---|---|
| Delegates to service | YES | 16-22 |
| Retry on `CustomErrorStructuredExtraction` — re-raises | YES | 24-33 |
| StandardError does not retry — rescues and logs | YES | 35-43 |
| Exhaustion logging: verify `ap` and `Rails.logger.error` after 3 failures | **NO** | — |

### Model/callback test (textract_result_keyword_search_spec.rb)

| Spec requirement | Present | Lines |
|---|---|---|
| Callback fires on create with text | YES | 24-34 |
| Callback does NOT fire without text | YES | 37-47 |
| Callback does NOT fire on non-text update | YES | 50-72 |
| Callback fires on text update | YES | 75-91 |
| Both callbacks fire independently | YES | 94-113 |
| `pg_search_scope` works (search returns matching results) | YES | 128-131 |
| `search_resume_by_keyword` returns none for blank search | YES | 139-149 |

### Existing test updates

| Spec requirement | Verified |
|---|---|
| `textract_result_ai_trigger_spec.rb` — no class-less `not_to have_enqueued_job` | YES — all 5 occurrences specify `GenerateAiJobApplicationSummaryJob` |

### Stub accuracy (Known Failure Pattern #7)

| Stub | Production match |
|---|---|
| `AiClient.new(provider: 'openai')` | Matches `AiClient#initialize(provider:)` signature |
| `ai_client_instance.chat` return shape `{ content:, model:, input_tokens:, output_tokens: }` | Matches `AiProviders::Openai#chat` return shape (lines 26-31) |
| `CustomErrorAiSummary` raised on API failure | Matches `AiProviders::Openai` (lines 23, 35, 39) |
| `AiClient.calculate_cost` returns BigDecimal | Production returns float; service calls `.to_f.round(6)` so the type difference is harmless |

---

## Findings

```
FINDING-ID: L1-TST-1
SEVERITY: HIGH
FILE: spec/jobs/extract_structured_resume_data_job_spec.rb
SPEC SECTION: Test requirements → Job test → Exhaustion logging
DEVIATION: The spec requires "Exhaustion logging: After 3 failed attempts, the exhaustion block
logs the error (verify with `ap` and `Rails.logger.error`)". The job spec tests retry_on
re-enqueue behavior but has NO test case that verifies the exhaustion block fires after all
retries are exhausted. The exhaustion block (job lines 6-9) calls `ap` and `Rails.logger.error`
but this is untested.

NOTE: Neither analog job spec (get_resume_text_from_textract_job_spec.rb,
generate_ai_job_application_summary_job_spec.rb) tests exhaustion either, so this is a
codebase-wide gap. However, the SPEC explicitly requires it for this feature.
```

---

## VERDICT: 1 HIGH finding

L1-TST-1: Missing exhaustion block test in job spec (spec explicitly requires it).

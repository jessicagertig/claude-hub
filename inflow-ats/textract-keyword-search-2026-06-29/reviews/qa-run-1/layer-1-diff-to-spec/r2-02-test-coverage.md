# Layer 1 Round 2 — Test Coverage Review

**Focus:** Verify L1-TST-1 fix + fresh pass on all spec test requirements

---

## L1-TST-1 Fix Verification

The exhaustion test has been added at lines 66-76 of `spec/jobs/extract_structured_resume_data_job_spec.rb`:
- Uses `perform_enqueued_jobs(only: described_class)` to trigger the full retry cycle
- Expects `Rails.logger.error` with the exact exhaustion message string
- Stubs service to always raise `CustomErrorStructuredExtraction`

**L1-TST-1: RESOLVED**

---

## Full Checklist

### Service tests — `spec/services/extract_structured_resume_data_spec.rb` (344 lines)

| Spec requirement | Present | Lines |
|---|---|---|
| Happy path: stores `structured_extraction` as parsed JSON | YES | 85-90 |
| Happy path: stores `structured_extraction_text` as flattened text | YES | 92-103 |
| Flattening correctness: all field types, no JSON syntax, no labels | YES | 116-153 |
| Null handling: null values omitted from flattened text | YES | 191-200 |
| AiApiRequest creation: correct attributes | YES | 213-226 |
| API failure: `CustomErrorAiSummary` → `CustomErrorStructuredExtraction` | YES | 239-244 |
| JSON parse failure: raises `CustomErrorStructuredExtraction` | YES | 267-271 |
| Guard: missing textract_result — returns early | YES | 275-278 |
| Guard: no text — returns early | YES | 292-296 |
| Guard: no organization — returns early | YES | 309-321 |
| Idempotency: second call overwrites cleanly | YES | 334-341 |

**10/10 required + 1 bonus (idempotency) = all present**

### Job tests — `spec/jobs/extract_structured_resume_data_job_spec.rb` (79 lines)

| Spec requirement | Present | Lines |
|---|---|---|
| Delegates to service | YES | 16-22 |
| Retry on `CustomErrorStructuredExtraction` — re-raises | YES | 24-32, 57-64 |
| StandardError does not retry — rescues | YES | 35-43 |
| Exhaustion logging: `ap` + `Rails.logger.error` | YES | 66-76 |

**4/4 required = all present**

### Model/callback tests — `spec/models/textract_result_keyword_search_spec.rb` (151 lines)

| Spec requirement | Present | Lines |
|---|---|---|
| Callback fires on create with text | YES | 24-34 |
| Callback does NOT fire without text | YES | 37-47 |
| Callback does NOT fire on non-text update | YES | 50-72 |
| Callback fires on text update | YES | 75-91 |
| Both callbacks fire independently | YES | 94-113 |
| pg_search_scope works (search returns matching results) | YES | 128-136 |
| search_resume_by_keyword returns none for blank search | YES | 139-149 |

**7/7 required = all present**

### Existing test safety

`spec/models/textract_result_ai_trigger_spec.rb`: All `not_to have_enqueued_job` calls specify `GenerateAiJobApplicationSummaryJob` — no interference from new callback.

---

**VERDICT: CLEAN — 0 findings**

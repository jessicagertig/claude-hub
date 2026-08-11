# Test Coverage (Impl)

## Verdict: PASS

### Findings

None. (Round 2's LOW for missing exhaustion block test is not re-flagged.)

### Verification

561 lines of test code across 3 spec files covering all spec-required test cases:

**Service spec** (`spec/services/extract_structured_resume_data_spec.rb`, 344 lines):
- Happy path: `structured_extraction` stored as parsed JSON on TextractResult
- Flattening correctness: every field type verified line-by-line (scalars, arrays-of-strings, arrays-of-objects sub-fields), no JSON syntax, no field labels
- Null handling: null values omitted from flattened text (no "null" strings)
- AiApiRequest creation: all attributes verified (`requestable`, `call_type`, `provider`, `model`, `input_tokens`, `output_tokens`, `organization`)
- API failure: `CustomErrorAiSummary` re-raised as `CustomErrorStructuredExtraction`
- JSON parse failure: invalid JSON raises `CustomErrorStructuredExtraction`
- Guard: missing textract_result (returns early, no error)
- Guard: no text (returns early, AiClient not called)
- Guard: no organization (returns early, AiClient not called)
- Idempotency: second call overwrites cleanly

**Job spec** (`spec/jobs/extract_structured_resume_data_job_spec.rb`, 66 lines):
- Delegation to service verified
- `CustomErrorStructuredExtraction` re-raised for `retry_on`
- `StandardError` rescued without re-raise
- `retry_on` behavioral test: `perform_now` triggers `CustomErrorStructuredExtraction`, asserts `have_enqueued_job(described_class)` -- would fail if `retry_on` were removed (ghost test BLOCKER from Round 1 properly fixed)

**Model spec** (`spec/models/textract_result_keyword_search_spec.rb`, 151 lines):
- Callback on create with text: enqueues `ExtractStructuredResumeDataJob`
- Callback on create without text: does NOT enqueue
- Non-text update (touch): does NOT enqueue
- Non-text update (status change): does NOT enqueue
- Text update: enqueues with correct TextractResult ID
- Both callbacks fire independently: both `GenerateAiJobApplicationSummaryJob` and `ExtractStructuredResumeDataJob` enqueued
- `search_resume_by_keyword` returns results matching search term
- `search_resume_by_keyword` supports prefix matching
- `search_resume_by_keyword` returns `none` for blank/nil search terms

**Test isolation:**
- `organization.update_settings(auto_generate_ai_summaries_enabled: false)` disables existing AI summary callback
- Both-callbacks test enables AI summaries and stubs `ValidateAiSummaryGeneration`
- All tests use `:test` queue adapter via `around` block -- jobs collected, not executed
- No ghost tests: every assertion tests a meaningful behavioral condition

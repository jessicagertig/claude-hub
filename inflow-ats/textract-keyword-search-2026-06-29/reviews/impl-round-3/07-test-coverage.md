# Test Coverage

## Verdict: PASS

### Findings

None. (Round 2 LOW for missing exhaustion block test is not re-flagged — exhaustion is log-only behavior, and testing it requires simulating 3 consecutive failures, which is complex relative to the value.)

### Verification

- Spec requires tests: Yes, explicitly in the "Test requirements" section of SPEC.md
- 3 new spec files with 561 lines of test code and 23 test cases total
- **Service spec** (`spec/services/extract_structured_resume_data_spec.rb`): 344 lines, 10 test cases
  - Happy path: stores `structured_extraction` as parsed JSON, stores `structured_extraction_text` as flattened plain text
  - Flattening correctness: all field types (scalars, arrays, nested objects) present, separated by newlines, no JSON syntax or labels
  - Null handling: null scalar values omitted from flattened text, no "null" strings
  - AiApiRequest creation: correct `requestable`, `call_type: 'keyword_extraction'`, `provider: 'openai'`, token counts, organization
  - API failure: `CustomErrorAiSummary` re-raised as `CustomErrorStructuredExtraction`
  - JSON parse failure: raises `CustomErrorStructuredExtraction`
  - Guard: missing textract_result (returns early without error)
  - Guard: no text (returns early, AiClient not called)
  - Guard: no organization (returns early, AiClient not called)
  - Idempotency: second call overwrites cleanly, no duplicates or errors
- **Job spec** (`spec/jobs/extract_structured_resume_data_job_spec.rb`): 66 lines, 4 test cases
  - Delegates to `ExtractStructuredResumeData` service
  - Re-raises `CustomErrorStructuredExtraction` for `retry_on` to catch
  - Rescues `StandardError` without re-raising
  - `retry_on` behavioral assertion: `perform_now` with error triggers `have_enqueued_job(described_class)` — genuine behavioral test (Round 1 ghost test fix confirmed)
- **Model spec** (`spec/models/textract_result_keyword_search_spec.rb`): 151 lines, 9 test cases
  - Callback fires on create with text
  - Callback does not fire on create without text
  - Callback does not fire on non-text update (touch, status change) — 2 cases
  - Callback fires on text update, with correct job argument
  - Both `GenerateAiJobApplicationSummaryJob` and `ExtractStructuredResumeDataJob` enqueue independently
  - `search_resume_by_keyword` returns results matching search term
  - Prefix matching works
  - Blank/nil search term returns `none` — 2 cases
- Existing tests in `spec/models/textract_result_ai_trigger_spec.rb` are not broken — the new callback only enqueues a job, and existing tests specify job class in their assertions

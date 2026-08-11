# test-coverage -- Round 1

## Findings

- F1 [BLOCKER] `spec/jobs/extract_structured_resume_data_job_spec.rb:44-49` -- Ghost test. The `describe 'retry_on exhaustion'` block claims to test retry_on configuration but its only assertion is `expect(described_class.instance_method(:perform)).to be_a(UnboundMethod)`, which is trivially true for ANY class that defines `perform`. The test also assigns `described_class.rescue_handlers` to `retry_config` but never asserts on it. This test passes regardless of whether `retry_on` is configured, whether it targets `CustomErrorStructuredExtraction`, whether `attempts: 3` is set, or whether an exhaustion block exists. Ghost tests produce false coverage and are worse than no test. **Recommended fix:** Either test the actual retry_on configuration (e.g., verify that raising `CustomErrorStructuredExtraction` triggers retry behavior using `perform_enqueued_jobs` and counting attempts), or remove the test entirely and document that retry_on exhaustion is verified by observing the class-level declaration.

## Verified

### Service tests (`spec/services/extract_structured_resume_data_spec.rb`)
- Happy path: stores `structured_extraction` and `structured_extraction_text` -- covered
- Flattening correctness: verifies all field types appear as separate lines, no JSON syntax, no labels -- covered
- Null handling: verifies null values omitted, no "null" strings -- covered
- AiApiRequest creation: verifies requestable, call_type, provider, model, token counts -- covered
- API failure: CustomErrorAiSummary -> CustomErrorStructuredExtraction -- covered
- JSON parse failure: raises CustomErrorStructuredExtraction -- covered
- Guard: missing textract_result -- covered (returns early, no error)
- Guard: no text -- covered (no AiClient call)
- Guard: no organization -- covered (stubbed nil org, no AiClient call)
- Idempotency: two calls, second overwrites cleanly -- covered

### Job tests (`spec/jobs/extract_structured_resume_data_job_spec.rb`)
- Delegates to service -- covered
- CustomErrorStructuredExtraction re-raises for retry -- covered
- StandardError rescued, not re-raised -- covered
- Retry_on exhaustion -- **GHOST TEST** (see F1)

### Model tests (`spec/models/textract_result_keyword_search_spec.rb`)
- Callback on create with text -- covered
- Callback not fired without text -- covered
- Callback not fired on non-text update (touch, status change) -- covered
- Callback fires on text update -- covered
- Both callbacks fire independently -- covered (stubs ValidateAiSummaryGeneration correctly)
- pg_search_scope works with structured_extraction_text -- covered
- Prefix matching -- covered
- Blank search returns none (empty string and nil) -- covered

### Existing tests
- `spec/models/textract_result_ai_trigger_spec.rb` exists and tests `queue_ai_summary_job`. The new callback only enqueues a job, so existing tests should pass. Existing tests specify `GenerateAiJobApplicationSummaryJob` in their assertions (not bare `have_enqueued_job`), so the additional enqueued job does not interfere.

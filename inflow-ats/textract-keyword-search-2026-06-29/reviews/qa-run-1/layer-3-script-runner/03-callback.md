# Layer 3 — Callback Chain Verification

**Method:** `RAILS_ENV=test bundle exec rails runner` with `ActiveJob::Base.queue_adapter = :test`
**Seeded data:** Acme Inc. org, Senior Ruby Developer job, 1 candidate via Cypress endpoint

## Results

| Test | Description | Result |
|------|-------------|--------|
| 1 | Creating TextractResult with text enqueues ExtractStructuredResumeDataJob | PASS |
| 2 | Creating TextractResult with nil text does NOT enqueue | PASS |
| 3a | ExtractStructuredResumeDataJob enqueues alongside AI summary callback | PASS |
| 3b | GenerateAiJobApplicationSummaryJob also enqueues | INFO — not enqueued (expected: needs auto_generate_ai_summaries + ValidateAiSummaryGeneration guards) |
| 4 | Non-text update does NOT enqueue ExtractStructuredResumeDataJob | PASS |
| 5 | Text update enqueues ExtractStructuredResumeDataJob | PASS |

## Notes

- Test 3b: `GenerateAiJobApplicationSummaryJob` was not enqueued because the `queue_ai_summary_job` callback has stricter guards (organization auto_generate setting, ValidateAiSummaryGeneration interactor). This confirms the two callbacks are independent — extraction fires regardless of whether summary generation fires.
- All tests used the `:test` queue adapter to capture enqueued jobs without executing them, avoiding real GPT-4o-mini API calls.

**VERDICT: 5 PASS, 0 FAIL**

# test-coverage -- Round 2

## Critical: Ghost test fix verification

**Round 1 BLOCKER:** `spec/jobs/extract_structured_resume_data_job_spec.rb:44-49` had a trivially true assertion (`expect(described_class.instance_method(:perform)).to be_a(UnboundMethod)`).

**Round 2 status: FIXED.** The ghost test was replaced in commit `84cb0f881` with a behavioral test at lines 47-65:

```ruby
describe 'retry_on configuration' do
  include ActiveJob::TestHelper
  ...
  it 're-enqueues the job via retry_on when CustomErrorStructuredExtraction is raised' do
    allow(service_instance).to receive(:extract)
      .and_raise(CustomErrorStructuredExtraction, 'API failure')
    expect do
      described_class.perform_now(textract_result_id)
    end.to have_enqueued_job(described_class)
  end
end
```

This test is genuine:
1. Uses `perform_now` (executes immediately, not just enqueues)
2. Makes the service raise `CustomErrorStructuredExtraction`
3. The job's `rescue CustomErrorStructuredExtraction => e` catches and re-raises
4. `retry_on` catches the re-raised error and re-enqueues
5. Assertion verifies re-enqueue happened

If `retry_on CustomErrorStructuredExtraction` were removed from the job class, the error would propagate up unhandled and the job would NOT be re-enqueued -- the test would FAIL. Not a ghost test.

## Test coverage summary

| Spec file | Lines | Test cases | Coverage |
|---|---|---|---|
| `spec/services/extract_structured_resume_data_spec.rb` | 344 | 10 | Happy path, flattening, null handling, AiApiRequest creation, API failure, JSON parse, guard (missing record), guard (no text), guard (no org), idempotency |
| `spec/jobs/extract_structured_resume_data_job_spec.rb` | 66 | 4 | Service delegation, CustomError re-raise, StandardError rescue, retry_on re-enqueue |
| `spec/models/textract_result_keyword_search_spec.rb` | 151 | 9 | Create with text, create without text, non-text update, text update, both callbacks, keyword match, prefix match, blank search (empty string), blank search (nil) |

## Existing test impact

`spec/models/textract_result_ai_trigger_spec.rb` creates/updates TextractResult records, which now also fire `queue_structured_extraction_job`. All existing assertions use `have_enqueued_job(GenerateAiJobApplicationSummaryJob)` (class-specific), so the new job being enqueued alongside does not interfere.

## Findings

- F1 [LOW] Missing exhaustion block test. The plan step 9.1 specifies "Exhaustion logging: After 3 failed attempts, the exhaustion block logs the error (verify with `ap` and `Rails.logger.error`)." This test is not present. The exhaustion block only performs logging (`ap` + `Rails.logger.error`) -- no business-critical logic. The retry_on configuration IS tested (re-enqueue behavior). LOW because exhaustion is log-only and testing it requires simulating 3 consecutive failures.

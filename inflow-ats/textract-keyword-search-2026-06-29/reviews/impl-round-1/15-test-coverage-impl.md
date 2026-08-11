# test-coverage-impl -- Round 1

## Findings

- F1 [BLOCKER] `spec/jobs/extract_structured_resume_data_job_spec.rb:44-49` -- Ghost test: `describe 'retry_on exhaustion'` does not test retry_on configuration. The assertion `expect(described_class.instance_method(:perform)).to be_a(UnboundMethod)` is trivially true for any class defining `perform`. The variable `retry_config = described_class.rescue_handlers` is assigned but never asserted on. This test produces false coverage: it appears to verify retry_on exhaustion behavior but passes regardless of whether retry_on is configured, what error class it targets, or whether an exhaustion block exists. **(Cross-referenced with test-coverage F1.)**

## Verified

### Convention compliance

- **Test helper**: All three spec files use `require 'rails_helper'` -- correct
- **ActiveJob::TestHelper**: Model and service specs include `ActiveJob::TestHelper` and use `around` block to set `:test` queue adapter -- matches the pattern in `spec/models/textract_result_ai_trigger_spec.rb`
- **Test data setup**: Uses `create_credit_test_organization`, `create_credit_test_job`, `create_credit_test_job_application` helpers -- matches existing test patterns
- **AI summary callback isolation**: Model spec sets `auto_generate_ai_summaries_enabled: false` in `before` block to prevent the existing AI summary callback from interfering -- correct isolation
- **Stub pattern**: Service spec stubs AiClient with `instance_double(AiClient)` and `allow(AiClient).to receive(:new).and_return(ai_client_instance)` -- clean, no real API calls
- **Job spec**: Uses `instance_double(ExtractStructuredResumeData)` to stub the service -- correct isolation
- **Bang methods in tests**: Uses `create!`, `update!` in test setup -- acceptable per cursor_rules rule 11 exception for RSpec specs

### Test quality assessment

- **Service spec (344 lines)**: Comprehensive. Covers happy path, flattening, null handling, AiApiRequest creation, API failure, JSON parse failure, all three guard clauses, and idempotency. Each test creates its own TextractResult with appropriate attributes. The flattening test checks each individual line and verifies no JSON syntax.

- **Job spec (53 lines)**: Adequate for delegation, error re-raising, and StandardError rescue. The retry_on exhaustion test is a ghost test (see F1).

- **Model spec (151 lines)**: Thorough callback testing with create, no-text create, non-text update, text update, and dual-callback independence. pg_search tests verify search works, prefix matching works, and blank search returns none. Uses `clear_enqueued_jobs` between test phases to isolate callback assertions.

### Missing test cases (not findings, informational)

- No test for the backfill job's iteration logic (find_each, sleep, per-record rescue, progress logging). Backfill jobs are typically not unit-tested because they are one-shot operations. The service it delegates to IS tested.
- No database-level test for the Postgres trigger (verifying textsearch_vector auto-updates when structured_extraction_text changes). The pg_search test implicitly covers this by setting structured_extraction_text and verifying search works.

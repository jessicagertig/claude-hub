# test-coverage-impl -- Round 2

## Verified

### Ghost test fix -- CONFIRMED REAL

See `07-test-coverage.md` for detailed analysis. The Round 1 BLOCKER ghost test has been replaced with a genuine behavioral test that verifies `retry_on` re-enqueues the job.

### No ghost tests in current suite

Every test assertion was traced to a falsifiable condition:

- Service spec: all assertions would fail if the corresponding code were removed (e.g., `structured_extraction` not stored, `CustomErrorStructuredExtraction` not raised, AiApiRequest not created)
- Job spec: `have_received(:extract)` fails without delegation; `raise_error` fails without re-raise; `not_to raise_error` fails if StandardError is re-raised; `have_enqueued_job` fails without `retry_on`
- Model spec: `have_enqueued_job(ExtractStructuredResumeDataJob)` fails without callback; `not_to have_enqueued_job` fails if guards are removed; `include(textract_result)` for search tests fails without working pg_search + trigger

### Convention compliance

- All specs use `include ActiveJob::TestHelper` and `around` block for queue adapter -- matches `textract_result_ai_trigger_spec.rb` pattern
- All specs use existing test helpers (`create_credit_test_organization`, etc.)
- Test files follow naming convention: `spec/<layer>/<class_name>_spec.rb`
- Service spec at `spec/services/` (not `spec/services/ai_job_application_action/...`) -- correct since `ExtractStructuredResumeData` is a top-level service

### Existing test compatibility

`textract_result_ai_trigger_spec.rb` creates/updates TextractResult records, which now also fire `queue_structured_extraction_job`. All assertions use class-specific `have_enqueued_job(GenerateAiJobApplicationSummaryJob)` -- not affected by additional jobs being enqueued.

## Findings

- F1 [LOW] Same as `07-test-coverage.md` F1 -- missing exhaustion block test specified in plan step 9.1. Log-only behavior, LOW severity.

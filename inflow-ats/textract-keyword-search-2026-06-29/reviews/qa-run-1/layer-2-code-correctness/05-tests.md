# Layer 2 — Test Code Correctness Review

**Files reviewed:**
- `spec/services/extract_structured_resume_data_spec.rb` (344 lines)
- `spec/jobs/extract_structured_resume_data_job_spec.rb` (78 lines)
- `spec/models/textract_result_keyword_search_spec.rb` (151 lines)

**Production code cross-referenced:**
- `app/services/extract_structured_resume_data.rb`
- `app/jobs/extract_structured_resume_data_job.rb`
- `app/models/textract_result.rb`

**Test helpers verified:**
- `spec/support/ai_credits_test_helpers.rb` — `create_credit_test_organization`, `create_credit_test_job`, `create_credit_test_job_application`

**Framework internals checked:**
- `activejob-6.1.7.7/lib/active_job/exceptions.rb` — `retry_on` / `executions_for` / exhaustion block invocation
- `activejob-6.1.7.7/lib/active_job/test_helper.rb` — `perform_enqueued_jobs` behavior with `:test` adapter
- `activejob-6.1.7.7/lib/active_job/queue_adapters/test_adapter.rb` — `perform_enqueued_at_jobs` and time filtering

---

## Ghost test check

All tests execute the code path they claim to test. No stubs that short-circuit the code under test. No expectations that trivially pass regardless of implementation.

Specific verification of the exhaustion test (line 66-76 of job spec): `perform_enqueued_jobs(only: described_class)` sets `perform_enqueued_jobs = true` AND `perform_enqueued_at_jobs = true` on the test adapter. When the job raises `CustomErrorStructuredExtraction`, the `rescue` in `perform` re-raises, `retry_on`'s `rescue_from` catches it, `executions_for` increments and checks against `attempts: 3`. On attempts 1-2 (`executions < 3`), `retry_job` calls `enqueue_at` — test adapter immediately re-executes (since `perform_enqueued_at_jobs = true` and no `at:` filter set). On attempt 3 (`executions == 3`, `3 < 3` is false), exhaustion block fires, calling `Rails.logger.error`. The `expect(Rails.logger).to receive(:error).with(...)` correctly captures this. NOT a ghost test.

## Stub accuracy

| Stub | Production match | Verdict |
|------|------------------|---------|
| `AiClient.new(provider: 'openai')` | Matches service line 22 | OK |
| `ai_client_instance.chat` returns `{ content:, model:, input_tokens:, output_tokens: }` | Matches `AiProviders::Openai#chat` return shape | OK |
| `AiClient.calculate_cost` returns `BigDecimal` | Service calls `.to_f.round(6)` on result — type mismatch harmless | OK |
| `CustomErrorAiSummary` raised by AiClient | Matches `AiProviders::Openai` rescue/raise pattern | OK |
| `ExtractStructuredResumeData.new(textract_result_id:)` in job spec | Matches service constructor signature | OK |
| `ValidateAiSummaryGeneration.call` in model spec | Returns double with `success?: true, textract_result: nil, textract_pending: false` — sufficient for `queue_ai_summary_job` to proceed | OK |

## Test isolation

- All 3 specs use `around` blocks to save/restore `ActiveJob::Base.queue_adapter`. No adapter leak.
- `let!` used correctly for records that must exist before expectations. `let` (lazy) used for data structures.
- `clear_enqueued_jobs` called in `before` blocks for update-context tests (model spec lines 60, 85). Prevents create-time enqueued jobs from polluting update assertions.
- Service spec stubs are set at `before` block scope (not global). No cross-test pollution.

---

## Findings

```
FINDING-ID: L2-TST-1
SEVERITY: MED
FILE: spec/models/textract_result_keyword_search_spec.rb
LINE: 140-148
BUG: Blank-search-term tests use `expect(results).to eq(TextractResult.none)` but no
TextractResult records exist in this context (the `let!(:textract_result)` is scoped
to the sibling context). Both `TextractResult.none.to_a` and `TextractResult.all.to_a`
return `[]` when no records exist. If the guard clause (`return none unless search_term`)
were deleted, these tests would still pass because `search_resume_text('')` would either
raise (PgSearch raises on blank input) or return an empty relation. The assertion is
technically fragile — it passes even if `none` is replaced with `all` — but the guard
clause IS tested (the code returns before calling `search_resume_text`). Not a ghost
test, but a weaker assertion than ideal.
```

---

## VERDICT: 0 HIGH, 0 BLOCKER, 1 MED

No ghost tests. No stub mismatches. No isolation leaks. One MED for a fragile assertion pattern on blank-search tests.

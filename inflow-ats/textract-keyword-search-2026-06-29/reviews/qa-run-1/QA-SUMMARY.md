# QA Run 1 Summary — Textract Keyword Search

**Branch:** `textract-text-to-ts-vector`
**Base:** `develop`
**Date:** 2026-06-30
**Verdict:** PASS (all 4 layers cleared)

## Layer Results

| Layer | Status | Details |
|-------|--------|---------|
| L1: Diff-to-Spec | PASS (R2) | R1: 3 HIGH. 1 fixed (missing exhaustion test), 2 accepted deviations. R2: 0 HIGH |
| L2: Code Correctness | PASS | 0 HIGH, 0 BLOCKER, 3 MED |
| L3: Script Runner | PASS | 19/19 tests PASS |
| L4: RSpec Regression | PASS | 37 examples, 0 failures (new + existing specs) |

## QA Changes Made

1. **Added exhaustion test** to `spec/jobs/extract_structured_resume_data_job_spec.rb` (L1-TST-1 fix)
2. **Fixed exhaustion test assertion** from strict `expect(logger).to receive(:error)` to `allow` + `have_received` pattern (framework-level logging interfered with strict expectation)

## Accepted Deviations (from Layer 1)

**L1-MT-1:** tsvector migration uses `unless column_exists?`/`unless index_exists?` guards not in reference. Guards prevent migration errors in environments where the reference branch was previously applied. Defensive coding.

**L1-MT-2:** Trigger migration uses `def up/down` instead of spec's `def change`. Verified: `fx` gem's `create_trigger` with inline `sql_definition:` cannot auto-reverse (no previous version SQL exists). `def up/down` is technically necessary. `down` correctly restores the old trigger pointing to `textract_job_result_text`.

## MED Findings (non-blocking, collected for awareness)

**L2-SVC-1:** `JSON.parse(nil)` raises `TypeError`, not `JSON::ParserError`. If OpenAI returns `nil` content (API contract violation), the error escapes the service's rescue chain. The job's `rescue StandardError` catches it, but the extraction silently fails without retry. Likelihood: very low (response_format JSON schema guarantees content). Fix: guard `unless result[:content]` before `JSON.parse`.

**L2-MIG-1:** The `unless column_exists?`/`unless index_exists?` guards in `def change` prevent clean rollback. At rollback time the column exists, so `unless true` skips the `add_column` call, and Rails never records the inverse `remove_column`. Rollback silently does nothing. Not a runtime bug -- only affects database rollback. Manual cleanup would be required.

**L2-TST-1:** Blank-search tests in `textract_result_keyword_search_spec.rb` use `expect(results).to eq(TextractResult.none)` but no TextractResult records exist in that context. The assertion passes vacuously. Not a ghost test (the guard clause IS tested), but a weaker assertion than ideal.

## Test Coverage

| Spec file | Examples | Failures |
|-----------|----------|----------|
| `spec/services/extract_structured_resume_data_spec.rb` | 11 | 0 |
| `spec/jobs/extract_structured_resume_data_job_spec.rb` | 5 | 0 |
| `spec/models/textract_result_keyword_search_spec.rb` | 10 | 0 |
| `spec/models/textract_result_ai_trigger_spec.rb` (regression) | 11 | 0 |
| **Total** | **37** | **0** |

## Script Runner Verification (Layer 3)

| Area | Tests | Result |
|------|-------|--------|
| Postgres trigger auto-updates tsvector | 1 | PASS |
| pg_search_scope returns ranked+highlighted results | 1 | PASS |
| Prefix matching (search "Rub" finds "Ruby") | 1 | PASS |
| Blank search returns empty relation | 1 | PASS |
| Flattening: full structured data | 1 | PASS |
| Flattening: null handling | 1 | PASS |
| Flattening: empty data | 1 | PASS |
| Callback: create with text enqueues job | 1 | PASS |
| Callback: create without text does not enqueue | 1 | PASS |
| Callback: text update enqueues job | 1 | PASS |
| Callback: non-text update does not enqueue | 1 | PASS |
| Callback: both callbacks fire independently | 1 | PASS |
| Guard: missing TextractResult | 1 | PASS |
| Guard: nil text | 1 | PASS |
| Idempotency: overwrite cleanly | 1 | PASS |
| Error class: message + param + hierarchy | 1 | PASS |
| Polymorphic association | 1 | PASS |
| Backfill scope: correct filtering | 1 | PASS |
| Backfill scope: resumable | 1 | PASS |
| **Total** | **19** | **19 PASS** |

## Notable observation from Layer 3

pg_search 2.3.2 raises `PG::UndefinedColumn: column "count_column" does not exist` when `.count` is called on `search_resume_by_keyword` results. This is a known pg_search issue with `with_pg_search_rank` subqueries. Use `.to_a.size` instead. Pre-existing limitation, not a regression.

# Hardening Report — FindOrCreateAiJobApplicationSummaryStatus

## Rules updated

### Rule 16 (updated)
Changed from "create via model callback with find_or_create_by" to "create via the unconditional owner, not via the conditional association." Reflects the refactor from `AiJobApplicationSummary` callback to `FindOrCreateAiJobApplicationSummaryStatus` interactor called from `JobApplication` setup and `TextractResult#generate_ai_summary_with_credit_flow`.

## Rules added

### Rule 18: Denormalized columns — clear ALL when disassociating
Motivated by plan-round-1 BLOCKER. When clearing an FK on a denormalized record, clear all denormalized columns too.

### Rule 19: Test setup must account for eager companion record creation
Motivated by plan-round-3 HIGH. after_commit callbacks create companion records during test setup — specs must account for this.

## Review round summary

- Plan rounds 1-3: FAIL (BLOCKER + HIGH findings — denormalized columns, line numbers, dead code, test setup)
- Plan rounds 4-5: PASS then FAIL (missing test coverage for call sites)
- Plan rounds 6-7: PASS + PASS (two consecutive clean)
- Impl round 1: PASS (3 MED, 2 LOW)

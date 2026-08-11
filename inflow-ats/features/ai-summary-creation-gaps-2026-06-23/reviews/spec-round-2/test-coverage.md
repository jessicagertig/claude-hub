# test-coverage — Round 2

Re-verified the deterministic-timing test (W3), the per-mechanism-class site coverage (W5), and that the W3 timing test uses string keys.

## Findings
No new MED+ findings.

## Re-verified correct
- W3 deterministic timing test (Round-1 F1 fix): spy asserts `job_record.previous_changes` includes `'status'` (STRING) at enqueue time -> fails for before_update (previous_changes empty), passes for after_commit. The spec uses the STRING `'status'` (consistent with the Round-2 string-key fix). CONFIRMED non-ghost and key-consistent.
- W5 per-mechanism-class coverage (Round-1 F2 fix): direct record_failure unit test + one update_columns site + one .update site + C8 destroy site. CONFIRMED distinguishes routing.
- W1 C7 earlier-failed-TextractResult test cross-referenced; financial count pins; pipeline #19 (auto-gen ON/OFF per test); stub discipline (#7). CONFIRMED.
- Test homes all EXIST (source-accuracy R1); after_commit fires under use_transactional_fixtures=true (confirmed by existing textract_result_ai_trigger_spec). CONFIRMED.

## Amendments Applied (Round 2)
None.

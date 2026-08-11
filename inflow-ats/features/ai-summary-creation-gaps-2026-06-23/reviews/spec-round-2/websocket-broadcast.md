# websocket-broadcast contract (W4) — Round 2

Re-verified the union+map extension and the error_message-preserving conversion.

## Findings
No new MED+ findings.

## Re-verified correct
- PlatoGenerationStatus union (`:8-13`) + STATUS_TO_STEP (`:22-28`) both extended -> TS compiles. CONFIRMED (Round-1 F1 fix).
- generate.rb:175 -> `ai_summary&.update(status: :retrying, error_message: e&.message)` preserves error_message, matches analogs score:129/integrate:59. CONFIRMED (Round-1 F2 fix).
- Only generate.rb:175 needs conversion (score:129/integrate:59 already `.update`; extract_criteria:146 is AiJobCriteria, excluded). All awaiting_job_criteria writers are `.update`. CONFIRMED complete.
- Detail-view-only invalidation (no list storm); inversion of `ai_job_application_summary_spec.rb:57-62`. CONFIRMED.

## Amendments Applied (Round 2)
None.

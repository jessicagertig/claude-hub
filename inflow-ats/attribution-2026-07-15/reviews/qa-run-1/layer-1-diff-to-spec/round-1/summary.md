# QA Run 1 — Layer 1 (Diff-to-Spec) — Round 1 Summary

**Date:** 2026-07-16 ~01:05 CT
**Diff reviewed:** 62dd55867..8dcc2f06f on `attribution-work-qa` (clean tree, committed code == working tree)
**Team:** 15 agents (qa_team_size 15), 8 coverage areas, every spec requirement assigned to >=2 agents.
**Dispatch note (deadline measure, logged per orchestrator instruction):** agents were dispatched in parallel rather than strictly sequentially — Layer 1 is read-only static analysis with no shared server/DB state, and sequential dispatch of 15 agents would have jeopardized the 10:00 AM ceiling. Breadth was NOT reduced (full 15 agents).

## Result: 2 HIGH findings -> FAIL -> fix loop

| Agent | Area | Findings |
|---|---|---|
| 1, 2 | Data layer (migrations, schema, user.rb) | 0, 0 |
| 3, 4 | Registrations controller + spec | 0, 0 |
| 5, 6 | Organizations + confirmations + specs | 0, 0 |
| 7, 8 | Omniauth chain + specs | 0, 0 |
| 9, 10 | Frontend capture + payloads | 1, 2 |
| 11, 12 | Frontend SSO + events | 0, 0 |
| 13, 14 | Cross-cutting constraints | 0, 0 |
| 15 | Full-diff traceability sweep | 0 |

## Consolidated findings (deduplicated)

### l1-r1-F1 (agents 9 + 10, independent empirical reproduction)
`sanitizeTrackingParams` (app/javascript/shared/lib/utils.js) silently drops `utm_*` params whose key contains malformed percent-encoding. The occurrence-order key scan decodes keys with native `decodeURIComponent` (raw-key fallback on throw) while `queryString.parse` decodes keys with `decode-uri-component` (lenient best-effort). When the decoders disagree (keys mixing valid and malformed percent sequences, e.g. `?utm_x%C2=1`, `utm_%C3%A9%`), the scan key never matches the parse output, the `parsedParams[key] !== undefined` membership filter fails, and the param is dropped from `utmData` — violating SPEC §5.1's "every other param whose name starts with utm_". Not an approved deviation (absent from REVIEW-ANGLES.md). Note: IMPL-REVIEW-COMPLETE.md recorded this as LOW #3 ("degenerate input only"), but Layer 1 has no LOW — spec-implementation mismatch is HIGH by rule, and the acceptability call belongs to Jessica, not a reviewer.

### l1-r1-F2 (agent 10)
§9.6 Jest coverage gap: no test pins the per-value sanitization rules (255-char truncation, first-of-repeated-array) for values inside `utmData`. An implementation that skipped `sanitizeTrackingValue` for `utmData` values would pass all 8 existing tests.

## Disagreement note
Agent 14 (cross-cutting, 2nd pass) asserted the key scan "exactly mirrors query-string v6.1.0's own key handling" — source-inspection only. Agents 9 and 10 each reproduced the divergence empirically by executing the helper against the installed libraries. Empirical reproduction supersedes source inspection; F1 stands.

## Gate
FAIL — fix loop per prompt: FAILURE-REPORT.md written, fix agent dispatched, restart from Layer 1 in qa-run-2.

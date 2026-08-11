# Layer 1 (Diff-to-Spec) — qa-run-4, Round 1 Summary

**Date:** 2026-07-17 | **HEAD:** fc3f047f9 (attribution-work-qa, clean tree) | **Diff:** 62dd55867..fc3f047f9
**Team:** 15 agents, dispatched sequentially, full rigor. Every spec requirement covered by >=2 agents; agent 14 built the complete 22-file reverse mapping table, agent 15 the complete forward coverage table.

## Result: 1 consolidated finding -> FAIL -> fix loop

### l1-run4-001 (HIGH) — SPEC.md 5.1 rule 2 lags the sanctioned surrogate-safe truncation

- Found independently by agent 8 (empirically, 20-assertion execution against the repo's node_modules) and agent 14 (reverse mapping: the only 3 untraceable lines in the entire 1057-line diff). Corroborated by agent 15.
- sanitizeTrackingValue in app/javascript/shared/lib/utils.js drops a trailing lone high surrogate after .slice(0, 255) — the sanctioned qa-run-2 l2-B1 HIGH fix (commit fa51c91a5, adversarially delta-reviewed in the prior run; reverting it would reintroduce the signup-POST 400). SPEC.md 5.1 rule 2 still reads bare "Truncate string values to 255 characters."
- **Resolution direction: amend the spec text, not the code.** The spec is the Layer 1 authority and must record the approved semantics with provenance, updating ALL truncation references in the same amendment (5.1 rule 2, 7.1, 11 note 4) per the stale-references failure pattern.

## Clean areas (14/15 agents, 0 findings)

| Agent | Area | Result |
|---|---|---|
| 1 | Migrations + schema (3, D6) | 0 findings; analog manifest vs 20260622182504 migration SAME |
| 2 | Registrations controller (4.1-4.3) | 0 findings; permit form matches questions_controller analog exactly |
| 3 | Backend second pass (4.1-4.4, nil-chain, 7.5 write-site enumeration) | 0 findings; all 5 write sites are creation paths |
| 4 | Org controller + authorization (4.4, 6, 7.6) | 0 findings; routes/policies/serializers 0-byte diffs |
| 5 | Omniauth chain (4.5-4.7) | 0 findings; signature verbatim; post-block byte-identical to base |
| 6 | Omniauth second pass + D9 call-site completeness | 0 findings; 4 files reference from_omniauth, all keyword-form; session key-type chain traced to actionpack/omniauth definitions |
| 7 | sanitizeTrackingParams (5.1) | 0 findings; both v6.1.0 order facts re-verified in library source; 6 adversarial decoder traces agree |
| 8 | Sanitizer second pass + wire contract + 5.3 | **1 finding (l1-r1-a8-F1 -> l1-run4-001)**; wire contract verified by execution end-to-end |
| 9 | AuthForm + GoogleSSOButton (5.2, 5.3) | 0 findings; all 49 changed lines trace |
| 10 | useSession + SignupForm (5.4, 5.5) + 5.2 name-trace | 0 findings; four fields identical at every hop |
| 11 | Funnel events (5.6-5.9, 7.8) | 0 findings; exactly 7 trackEvent additions = 6 fixed names |
| 12 | D19 + events second pass + 10 absences | 0 findings; Auth.tsx/confirmations controller byte-identical to base; sole browser identify remains AppAuthRouter.tsx:168 |
| 13 | Test requirements (9 items 1-5, rule 26/31) | 0 findings; all required scenarios present, falsifiable; queue-adapter around blocks in all 5 files |
| 14 | Reverse mapping sweep (entire diff) | **1 finding (l1-r1-a14-F1 -> l1-run4-001)**; all other hunks trace |
| 15 | Forward completeness sweep (2-11) | 0 findings; spec_coverage.missing empty; 12/13 analog rows structurally matched |

## Settled rulings respected

No agent re-flagged M1-M4 or the 9 LOW dispositions. The decode-uri-component key scan (fix 299cf9465) was examined by 4 agents and judged traceable — 5.1 declares the key-scan mechanism plan-level.

## Gate

Any finding -> fix loop. FAILURE-REPORT.md written; fix agent to amend SPEC.md; restart from Layer 1 in qa-run-5.

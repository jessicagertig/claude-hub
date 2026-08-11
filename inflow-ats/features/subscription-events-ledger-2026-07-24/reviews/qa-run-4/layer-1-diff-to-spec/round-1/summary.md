# QA run 4 — Layer 1 (diff-to-spec) — Round 1 summary

**Diff reviewed:** `a0d59115d..549039a0c` on `attribution-work-qa` (committed; includes all three prior fix commits)
**Agents:** 10, sequential, slices per harness-profile.md
**Result:** 10 HIGH filed → 9 to the fix loop (r4-l1-a9-005 consolidated into r4-l1-a9-002) → restart in qa-run-5

| Agent | Slice | Findings |
|---|---|---|
| 1 | trial_started writer chain | 0 |
| 2 | invoice.paid conversion insertion | 0 — 549039a0c fix audited, both repaired examples falsifiable |
| 3 | subscription.deleted cancellation insertion | 1 HIGH (a3-001) |
| 4 | migration + enum + uniqueness invariant | 0 — r3-l1-a4-001 fix verified |
| 5 | CreateSubscriptionEvent changes | 1 HIGH (a5-001) |
| 6 | fan-out + PostHog payload | 2 HIGH (a6-001, a6-002) |
| 7 | Discord enqueue moves + Slack untouched | 1 HIGH (a7-001) |
| 8 | webhook delicacy audit (D11) | 0 — 34/0; all three fix commits spec-file-only |
| 9 | tests-vs-spec EXHAUSTIVE mechanism matrix (55 rows) | 5 HIGH (a9-001..005); confirmed all round-4 priors |
| 10 | reverse traceability | 0 — all hunks traced; branch shape = feature + 3 spec-only fixes |

All 10 findings are test-falsifiability gaps in the four new spec files. App code is clean in every slice for the fourth consecutive full-layer audit. Agent 9's 55-row mechanism matrix (agent-9.json) is the class-closing artifact: 38 pinned, the rest are exactly this round's findings (plus one immaterial `.to_i` row not filed).

See consolidated.json for per-finding fixes. FAILURE-REPORT.md carries the fix work order.

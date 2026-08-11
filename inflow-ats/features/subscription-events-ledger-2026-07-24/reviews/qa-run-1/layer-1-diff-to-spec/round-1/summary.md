# QA run 1 — Layer 1 (diff-to-spec) — Round 1 summary

**Diff reviewed:** `a0d59115d..89286fba8` on `attribution-work-qa` (committed code)
**Agents:** 10, sequential, slices per harness-profile.md
**Result:** 1 HIGH → fix loop (restart in qa-run-2)

| Agent | Slice | Findings |
|---|---|---|
| 1 | trial_started writer chain (org callback) | 0 |
| 2 | invoice.paid conversion insertion | 1 HIGH (l1-a2-001) |
| 3 | subscription.deleted cancellation insertion | 0 |
| 4 | migration + enum + uniqueness invariant | 0 |
| 5 | CreateSubscriptionEvent changes | 0 |
| 6 | fan-out + PostHog payload | 0 |
| 7 | Discord enqueue moves + Slack untouched | 0 |
| 8 | webhook delicacy audit (D11) | 0 — 34 insertions / 0 deletions, every line classified as one of the two sanctioned hunks |
| 9 | tests-vs-spec (§9) | 0 |
| 10 | reverse traceability | 0 — every hunk in all 11 diff files traced to a SPEC section |

## Finding

**l1-a2-001 (HIGH):** `spec/jobs/stripe_webhook_handler_subscription_events_spec.rb:131-140` — the ledger-failure isolation example (raising `CreateSubscriptionEvent.call`) asserts only two of the three §9.1-enumerated existing behaviors (org period-end update, `stripe_update_default_payment_method`); the `reset_ai_credits` assertion is missing. The success-path example (lines 121-128) covers all three. Fix: mirror the success-path `reset_ai_credits` assertion into the failure-path example (~3 lines, spec file only).

## Notes (not findings)

- Agent 3 neutral observation: the ledger-failure-isolation test exists for the invoice.paid insertion only, not subscription.deleted — §9.1's parenthetical enumerates invoice.paid behaviors, so the tests satisfy the spec as written.
- Agent 2 nuance: the webhook duplicate-delivery test falls inside the interactor's 5-minute dedupe window; conversion-uniqueness is isolated instead by the interactor spec's cross-type examples, which defeat the dedupe.

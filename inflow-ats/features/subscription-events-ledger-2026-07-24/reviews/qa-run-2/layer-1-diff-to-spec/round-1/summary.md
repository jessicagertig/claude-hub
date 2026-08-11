# QA run 2 — Layer 1 (diff-to-spec) — Round 1 summary

**Diff reviewed:** `a0d59115d..7574df408` on `attribution-work-qa` (committed code; includes the run-1 fix commit)
**Agents:** 10, sequential, slices per harness-profile.md
**Result:** 1 HIGH → fix loop (restart in qa-run-3)

| Agent | Slice | Findings |
|---|---|---|
| 1 | trial_started writer chain | 0 |
| 2 | invoice.paid conversion insertion | 0 — run-1 fix (7574df408) audited: exactly +3 lines, non-vacuous, mirrors success-path shape |
| 3 | subscription.deleted cancellation insertion | 1 HIGH (r2-l1-a3-001) |
| 4 | migration + enum + uniqueness invariant | 0 |
| 5 | CreateSubscriptionEvent changes | 0 |
| 6 | fan-out + PostHog payload | 0 |
| 7 | Discord enqueue moves + Slack untouched | 0 |
| 8 | webhook delicacy audit (D11) | 0 — 34/0 across the two sanctioned hunks; fix commit touched only the spec file |
| 9 | tests-vs-spec | 0 new; VALIDATED r2-l1-a3-001; systematic stub sweep found no other instance |
| 10 | reverse traceability | 0 — all 17 hunks across 11 files traced; fix commit clean |

## Finding

**r2-l1-a3-001 (HIGH):** `spec/jobs/stripe_webhook_handler_subscription_events_spec.rb:161` — the subscription.deleted example stubs `sync_with_stripe` (`allow(organization).to receive(:sync_with_stripe)`) but never asserts it with `have_received`. Deleting the branch's `organization&.sync_with_stripe if stripe_subscription_id == organization&.stripe_subscription_id` line would pass the suite. §9.1's load-bearing existing-behavior clause covers both insertions; this is the only one of the deleted branch's four existing effects with no assertion. Same class as run 1's l1-a2-001. Fix: one `have_received(:sync_with_stripe)` assertion line.

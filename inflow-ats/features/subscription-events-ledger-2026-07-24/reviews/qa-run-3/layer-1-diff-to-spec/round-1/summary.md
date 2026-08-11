# QA run 3 — Layer 1 (diff-to-spec) — Round 1 summary

**Diff reviewed:** `a0d59115d..e850c74fe` on `attribution-work-qa` (committed; includes both prior fix commits)
**Agents:** 10, sequential, slices per harness-profile.md
**Result:** 2 HIGH → fix loop (restart in qa-run-4)

| Agent | Slice | Findings |
|---|---|---|
| 1 | trial_started writer chain | 0 |
| 2 | invoice.paid conversion insertion | 0 — both fix commits audited clean |
| 3 | subscription.deleted cancellation insertion | 0 — e850c74fe verified incl. fixture-condition trace + live run |
| 4 | migration + enum + uniqueness invariant | 1 HIGH (r3-l1-a4-001) |
| 5 | CreateSubscriptionEvent changes | 0 — interactor uniqueness examples confirmed dedupe-independent |
| 6 | fan-out + PostHog payload | 0 |
| 7 | Discord enqueue moves + Slack untouched | 0 |
| 8 | webhook delicacy audit (D11) | 0 — 34/0, two sanctioned hunks; both fixes spec-file-only |
| 9 | tests-vs-spec | 1 HIGH (r3-l1-a9-001); VALIDATED r3-l1-a4-001 |
| 10 | reverse traceability | 0 — all 17 hunks traced |

## Findings (both in spec/jobs/stripe_webhook_handler_subscription_events_spec.rb)

**r3-l1-a4-001 (HIGH):** the duplicate-delivery example (~line 111) runs both deliveries inside the interactor's 5-minute dedupe window with byte-identical `event_params` — deleting `conversion_duplicate_exists?` AND the partial index still passes (the dedupe blocks row 2). In production the dedupe does not enforce §3 for redeliveries >5 minutes apart. Fix: backdate the first row's `created_at` past 5 minutes between deliveries so the invariant is the enforcing mechanism.

**r3-l1-a9-001 (HIGH):** the ledger-failure isolation example — `not_to raise_error` is satisfied by the invoice.paid branch's pre-existing outer `rescue StandardError` tier even if the insertion's own rescue is deleted; the three existing-behavior assertions precede the insertion point; and the raising `CreateSubscriptionEvent` stub is never asserted (`have_received(:call)` missing), so deleting the ENTIRE insertion also passes. Fix: assert `have_received(:call)` + a `Rails.logger` spy pinning the insertion's ledger-specific error message.

## Note

App code clean for the third consecutive full-layer pass; all HIGHs across runs 1-3 are test-falsifiability defects in this one spec file. Agent 9's secondary note (insertion 2 has no failure-isolation example at all) remains a non-finding per §9.1's parenthetical scope; recorded for the MED/notes ledger.

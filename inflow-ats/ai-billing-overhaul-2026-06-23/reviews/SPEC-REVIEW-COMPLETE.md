# Spec Review Complete: Custom AI Credit Subscription Upgrade/Downgrade

## Final verdict: PASS

Two consecutive PASS rounds (Rounds 4 and 5) with 0 BLOCKER, 0 HIGH, 0 MED findings and 0 amendments.

## Review history

| Round | Verdict | Findings | Amendments |
|-------|---------|----------|------------|
| 1 | FAIL | 2 HIGH (C1, P1), 2 MED (S1, D1) | 4 |
| 2 | FAIL | 1 MED (S3) | 1 |
| 3 | FAIL | 1 MED (S4) | 1 |
| 4 | PASS | 0 | 0 |
| 5 | PASS | 0 | 0 |

## All findings and their resolutions

### C1 (HIGH, Round 1): `fail_with_record_invalid` unavailable to `ApplyAiCreditUpgrade`
**Problem:** The `fail_with_record_invalid` helper is a private method defined locally in `ApplyAiCreditPurchase`, not a shared concern. The new `ApplyAiCreditUpgrade` interactor called it but never defined it, causing a runtime `NoMethodError`.
**Fix:** Added a local `fail_with_record_invalid` private method definition to `ApplyAiCreditUpgrade`, matching the analog's pattern with an updated log prefix.

### P1 (HIGH, Round 1): Removing `redirectToStripe` breaks top-up checkout flow
**Problem:** The spec said to remove `redirectToStripe` from `AiCreditSubscription.tsx`, but the function is also called by `purchaseTopUpCheckoutSession` for the top-up checkout flow.
**Fix:** Changed to "Keep `redirectToStripe` function" with explanation that it is still used by the top-up flow.

### S1 (MED, Round 1): `newMonthlyPrice` derived from prorated line item
**Problem:** The modal's `newMonthlyPrice` was derived from the invoice preview's positive line item amount, which is a prorated charge for remaining time, not the actual monthly price.
**Fix:** Changed `newMonthlyPrice` source to `tier.priceDollars` (the actual monthly price from the tier data).

### D1 (MED, Round 1): `downgrade_detected?` does not recognize AI credit lookup keys
**Problem:** The spec claimed `handle_subscription_schedule_downgrade` would detect AI credit downgrades and fire Discord/engagement notifications. The `downgrade_detected?` method only recognizes ATS plan tiers.
**Fix:** Updated the spec and sequence diagram to accurately state that `downgrade_detected?` returns `false` for AI credit lookup keys, and that adding AI credit recognition is out of scope.

### S3 (MED, Round 2): `isDowngrade` param inconsistency between frontend and backend
**Problem:** The frontend sent `isDowngrade` to the backend, but the spec also said the backend determines upgrade/downgrade from lookup keys. A malicious client could bypass downgrade scheduling.
**Fix:** Removed `isDowngrade` from `CommitSubscriptionChangeParams`. Backend computes upgrade/downgrade server-side only.

### S4 (MED, Round 3): Controller lacks mechanism to obtain `new_lookup_key`
**Problem:** After removing `isDowngrade`, the controller needed `new_lookup_key` to compare credit amounts, but only had the Stripe price ID.
**Fix:** Added step 3 to `commit_subscription_change`: `Stripe::Price.retrieve(determine_price_id)` to obtain `new_lookup_key`.

## Verification methodology

- Source code verification performed against the billing-bonanza worktree (read-only)
- Real Stripe invoice example (`stripe-invoice-subscription-update-example.json`) used to verify invoice structure claims
- All 8 review angles from REVIEW-ANGLES.md checked in every round
- All 15 always-on checks verified in every round
- All 6 approved decisions cross-checked against spec for contradictions (none found)
- Known failure patterns #1-21 from pipeline CLAUDE.md applied throughout
- 4 parallel source code verification forks used in Round 1 to verify controller, webhook handler, models/interactors, and frontend code

## Files

- Spec: `/Users/jessica/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/SPEC.md`
- Reviews: `/Users/jessica/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/reviews/spec-round-{1..5}/`
- Plain English Summary: `/Users/jessica/claude-hub/inflow-ats/ai-billing-overhaul-2026-06-23/reviews/plain-english-summary.md`

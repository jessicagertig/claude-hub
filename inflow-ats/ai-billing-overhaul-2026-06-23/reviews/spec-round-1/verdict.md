# Round 1 Verdict: FAIL

## Findings summary

| ID | Severity | Angle | Description |
|----|----------|-------|-------------|
| C1 | HIGH | Credit granting correctness | `fail_with_record_invalid` is private to `ApplyAiCreditPurchase` — not available to `ApplyAiCreditUpgrade`. Runtime `NoMethodError` on any save/update failure. |
| P1 | HIGH | Portal flow removal | Removing `redirectToStripe` breaks `purchaseTopUpCheckoutSession` — the function is also used by the top-up checkout flow. |
| S1 | MED | Stripe API contract | `newMonthlyPrice` is derived from the prorated invoice line item amount, not the actual monthly price. Users would see a prorated amount labeled as their future monthly price. |
| D1 | MED | Downgrade scheduling | `downgrade_detected?` only recognizes ATS plan tiers (`free/starter/growth/scale/enterprise`), not AI credit subscription lookup keys. Discord/engagement notifications will NOT fire for AI credit downgrades. Spec falsely claims they will. |

## Amendments applied

4 amendments applied to SPEC.md:
1. C1: Added `fail_with_record_invalid` private method definition to `ApplyAiCreditUpgrade` section
2. P1: Changed "Remove `redirectToStripe` function" to "Keep `redirectToStripe` function" with explanation
3. S1: Changed `newMonthlyPrice` source from invoice line item to `tier.priceDollars`
4. D1: Corrected the downgrade sequence diagram and interactor description to note that `downgrade_detected?` does not recognize AI credit lookup keys

## Next round

Round 2 will re-read the amended spec and verify all amendments are correct and introduce no new issues.

# Angle 2: Webhook Event Routing — Round 5

## Deep verification

- Checked event ordering: `customer.subscription.updated` fires before `invoice.paid`. The `customer.subscription.updated` handler updates `subscription_credits_per_period` to the new plan's value BEFORE `ApplyAiCreditUpgrade` runs. `ApplyAiCreditUpgrade` correctly does NOT use `subscription_credits_per_period` — it computes the difference from invoice line items. PASS.
- Checked failed payment edge case: if `invoice.paid` never fires, the purchase row has new plan data but no credits were granted. This is pre-existing behavior, not introduced by this feature. Not a spec issue. PASS.
- `billing_reason` routing remains correct: `subscription_update` -> `ApplyAiCreditUpgrade`, everything else -> `ApplyAiCreditPurchase`. PASS.

No new findings. PASS.

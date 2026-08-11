# Angle 3: Credit Granting Correctness — Round 4

## Deep sweep

- Idempotency verified: both `ApplyAiCreditUpgrade` and `ApplyAiCreditPurchase` check `stripe_invoice_id == invoice.id`
- Payment-info stamp happens unconditionally before the branch — correct for all invoice types
- `stripe_amount: invoice.amount_paid` is NET amount for upgrade invoices, full amount for renewals — both are the actual charge, stored correctly
- `stripe_invoice_item_id: invoice.lines.data.first&.id` — first line item for both types — correct

No new findings. PASS.

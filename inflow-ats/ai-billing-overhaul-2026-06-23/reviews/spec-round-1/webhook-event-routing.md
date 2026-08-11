# Angle 2: Webhook Event Routing — Round 1

## Checks performed

1. Verified `handle_subscription_credit_pack_invoice_paid` current code (lines 472-490 confirmed)
2. Verified `billing_reason` check placement — AFTER purchase lookup and payment-info stamp, BEFORE `ApplyAiCreditPurchase.call`
3. Verified guard ordering (known failure pattern #8) — no guards between method entry and the credit-pack handler call that would reject upgrade invoices
4. Verified `invoice.paid` routing dispatch chain (lines 222-306)
5. Verified metadata checks on real invoice example (top-level `metadata: {}` — no board listing IDs, no `organization_ai_credit_purchase_id`)
6. Verified `billing_reason: 'subscription_update'` confirmed in real invoice example
7. Verified lookup key routing: subscription update invoices go through the same lookup-key check as renewals

## Findings

No MED, HIGH, or BLOCKER findings.

### W1: Guard ordering is safe — PASS

The `invoice.paid` routing chain checks metadata keys first (lines 236, 249, 267), then retrieves the subscription and checks the lookup key (lines 280-284). The `subscription_update` invoice has empty top-level `metadata` (confirmed by real invoice example), so it passes through all metadata guards. The lookup key check at line 283 routes to `handle_subscription_credit_pack_invoice_paid` for AI credit subscription prices. The `CustomStripeSubscriptionMissingError` guard at line 286 is in the `else` branch (non-credit-pack subscriptions). No guard blocks upgrade invoices. PASS.

### W2: `billing_reason` branching placement — PASS

The spec correctly places the `billing_reason` check after the payment-info stamp (which applies to all invoice types) and before the `ApplyAiCreditPurchase.call` dispatch. The existing code at line 489 calls `ApplyAiCreditPurchase.call` — the spec replaces that single line with a conditional that routes to either `ApplyAiCreditUpgrade.call` or `ApplyAiCreditPurchase.call`. PASS.

### W3: No other `billing_reason` values for credit-pack subscription invoices — PASS

For subscription invoices, Stripe sets `billing_reason` to one of: `subscription_create`, `subscription_cycle`, `subscription_update`, `subscription_threshold`, `manual`. The spec handles `subscription_update` (upgrade) and routes everything else to `ApplyAiCreditPurchase` (existing behavior). This is correct — `subscription_threshold` and `manual` are not used for credit-pack subscriptions. PASS.

## Verdict

0 findings. PASS for this angle.

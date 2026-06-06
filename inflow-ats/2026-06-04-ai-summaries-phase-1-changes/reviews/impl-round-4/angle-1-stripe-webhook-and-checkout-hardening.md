# Angle 1: Stripe Webhook and Checkout Hardening -- Round 4

## Fresh adversarial focus areas

1. **Invoice.paid top-up: metadata key correctness.** The `purchase_top_up` controller sets `invoice_data.metadata` with keys `organization_id`, `stripe_price_lookup_key`, `ai_credit_pack_top_up`. The webhook handler reads these same keys. Verified match.

2. **Top-up one-off idempotency.** `apply_one_off_from_invoice` checks `OrganizationAiCreditPurchase.find_by(stripe_invoice_id: invoice.id, kind: :one_off)`. If found, returns without creating. Duplicate `invoice.paid` webhooks are safe.

3. **Checkout subscription idempotency.** `checkout.session.completed` calls `OrganizationAiCreditPurchase.find_by(stripe_checkout_session_id: object.id)`. If not found, logs error. If found, sets `stripe_subscription_id` via `update_columns`. Duplicate webhooks: second call finds the purchase, sets the same subscription_id again (idempotent).

4. **Guard ordering in invoice.paid.** Verified execution order:
   - `ai_credit_pack_top_up` metadata check -> return
   - `board_wwr_listing_id` metadata check -> return
   - `board_what_jobs_listing_id` metadata check -> return
   - `raise CustomStripeSubscriptionMissingError` if no subscription
   
   All side branches return before the guard. Correct.

5. **`handle_credit_pack_invoice_paid` when `existing` is nil.** Method does nothing -- no error, no crash, no side effects. This is acceptable: if no purchase record exists, the subscription wasn't created via our checkout flow.

## Findings

**No findings.**

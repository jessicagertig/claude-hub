# Implementation Angle: Data Integrity and Security -- Round 3

## Reviewed for

- Data loss risks
- Authorization bypass
- Stripe payment integrity
- Race conditions
- Input validation

## Observations

### Stripe payment flow integrity
- Top-up credits only granted via `invoice.paid` (not `checkout.session.completed`) -- payment confirmation required before credit grant
- `invoice_creation: { enabled: true }` ensures Stripe creates an invoice for `payment` mode checkout
- Idempotency: `apply_one_off_from_invoice` checks for existing `stripe_invoice_id` before creating
- `handle_credit_pack_invoice_paid` has idempotency check via `metadata->>'stripe_invoice_id'`
- Subscription checkout creates pre-active record immediately, preventing duplicate checkout sessions

### Authorization
- `checkout` and `purchase_top_up` use `BillingPolicy` (money-charging actions)
- `show` and `prices` use model-specific policies
- Admin-only gate on `AccountPlatoAiContainer` plus `memberPathNames` removal

### Validation relaxation
- Only relaxes for subscription records with `stripe_checkout_session_id` present but `stripe_subscription_id` blank -- a narrow window between checkout and webhook callback
- `amount_cents_paid` and `currency` populated on first `invoice.paid`

### Data migration
- Settings key rename is safe: only touches the specific key, doesn't rewrite other settings

## Findings

**No findings.**

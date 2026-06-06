# Always-On A2: Test Coverage -- Round 4

## Re-verified

All test requirements from Round 3 re-confirmed. Additional focus areas:

### Invoice-based one-off path coverage
- `apply_ai_credit_purchase_spec.rb` has dedicated `describe '.call -- one_off via invoice (top-up)'` block
- Tests: creates purchase with `stripe_invoice_id`, creates ledger row, increments balance, idempotent on duplicate `stripe_invoice_id`
- Invoice spec does NOT stub `Stripe::Checkout::Session.list_line_items` (confirms Round 1 fix holds)

### Pre-checkout validation coverage
- `organization_ai_credit_purchase_spec.rb` has `describe 'validations -- subscription (pre-checkout, checkout_session_id only)'`
- Tests: valid without `stripe_subscription_id`, does not require period dates, does not require `amount_cents_paid`, does not require `currency`

### Stripe webhook spec coverage
- `checkout.session.completed` test: creates purchase, sends event, verifies `stripe_subscription_id` is set on purchase
- `invoice.paid` top-up test: sends event with metadata, verifies balance increases by 100 (matching `ai_credit_pack_top_up_small` pack)
- Idempotency test updated to use invoice path

## Findings

**No findings.**

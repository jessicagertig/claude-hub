# Data Integrity & Security — Round 1

## Findings

- F1 [HIGH] `app/jobs/stripe_webhook_handler_job.rb:212` / The `invoice.paid` top-up handler passes a Stripe invoice object to `ApplyAiCreditPurchase.call(session: object, kind: :one_off)`. The interactor treats this as a checkout session and calls `Stripe::Checkout::Session.list_line_items(session.id)`, which will fail in production with a Stripe API error because invoice IDs are not valid checkout session IDs. This means top-up credit purchases via the new invoice.paid path will silently fail -- users pay but never receive credits. This is a data integrity issue: payment is collected but credits are not granted.

All other data integrity checks pass:
- Pundit authorization is correctly applied on all controller actions
- Validation relaxation for pre-checkout state is safe (defers amount/currency to invoice.paid)
- Stripe metadata keys are consistent between controller and webhook handler
- Idempotency guards (existing purchase found by checkout_session_id) are preserved

# data-integrity-security — Round 5

## Findings

- F1 [MED] `app/models/organization_ai_credit_purchase.rb:53` / Relaxed `stripe_checkout_session_id` validation for one-offs allows purchase records with no session linkage / With the validation `if: -> { one_off? && stripe_invoice_id.blank? }`, a one-off purchase can be created with just a `stripe_invoice_id` and no `stripe_checkout_session_id`. This means the idempotency key for one-off purchases is now ambiguous: some are keyed on `stripe_checkout_session_id`, others on `stripe_invoice_id`. If the same purchase is somehow processed by both paths (session-based and invoice-based), two separate purchase records could be created for the same payment. The spec's original design used `stripe_checkout_session_id` as the sole unique lookup key for one-offs.

- F2 [MED] `app/jobs/stripe_webhook_handler_job.rb:211-220` / Top-up `invoice.paid` branch looks up org but doesn't use it / Line 213 does `org = Organization.find_by(id: object.metadata['organization_id'])` and checks `if org && lookup_key`, but then calls `ApplyAiCreditPurchase.call(invoice: object, kind: :one_off)` without passing `org`. Inside the interactor, `apply_one_off_from_invoice` does the org lookup AGAIN from the same metadata. The `org` variable in the webhook handler is wasted -- it's only used as a guard but the interactor does its own guard. This is not a data integrity issue but is confusing.

No authorization issues found. Policies correctly gate show, checkout, top_up, cancel, and prices. Admin-only gate on Plato AI container. `BillingPolicy` correctly used for payment actions.

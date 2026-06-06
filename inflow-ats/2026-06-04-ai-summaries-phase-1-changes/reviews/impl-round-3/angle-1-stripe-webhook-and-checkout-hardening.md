# Angle 1: Stripe Webhook and Checkout Hardening -- Round 3

## Files reviewed

- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb`
- `app/jobs/stripe_webhook_handler_job.rb`
- `app/interactors/apply_ai_credit_purchase.rb`
- `app/models/organization_ai_credit_purchase.rb`
- `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`
- `spec/interactors/apply_ai_credit_purchase_spec.rb`

## Round 1 defects (resolved)

- H1 (invoice.paid type mismatch) -- FIXED. New `apply_one_off_from_invoice` method extracts lookup_key from invoice metadata instead of calling `Stripe::Checkout::Session.list_line_items`. Spec updated to use invoice path, no longer stubs `list_line_items` with invoice ID.
- MED (checkout sets subscription_status: :active) -- ADDRESSED. Checkout now sets `amount_cents_paid: 0` and omits `subscription_status`.
- MED (update_columns comment) -- ADDRESSED. Comment added explaining why `update_columns` is used.

## Findings

**No new findings.**

The Stripe flow is now correct:
1. `checkout` creates `OrganizationAiCreditPurchase` with `stripe_checkout_session_id` only
2. `checkout.session.completed` links `stripe_subscription_id` via `update_columns`
3. `invoice.paid` top-up branch uses `apply_one_off_from_invoice` with invoice metadata
4. `invoice.paid` subscription branch goes to `handle_credit_pack_invoice_paid` which updates `amount_cents_paid`/`currency`
5. All metadata branches (`ai_credit_pack_top_up`, `board_wwr_listing_id`, `board_what_jobs_listing_id`) are above the `CustomStripeSubscriptionMissingError` guard with explicit `return`
6. `handle_credit_pack_invoice_paid` `else` branch removed
7. Validation relaxation correct for pre-checkout state

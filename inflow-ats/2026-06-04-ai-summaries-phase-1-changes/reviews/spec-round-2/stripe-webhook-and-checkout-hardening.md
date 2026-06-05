# angle-1: stripe-webhook-and-checkout-hardening — Round 2

Round 1 BLOCKER and HIGH findings (CustomStripeSubscriptionMissingError guard, validation relaxation) were amended. Verifying the amendments and checking for residual issues.

## Finding 1

**[HIGH]** `handle_credit_pack_invoice_paid` does not populate `amount_cents_paid` or `currency` on the purchase

**Where:** `app/jobs/stripe_webhook_handler_job.rb` lines 453-458; SPEC.md Note #9B-5 amendment

**What:** The Round 1 amendment correctly relaxes `amount_cents_paid` and `currency` validations so the purchase can be created at checkout without payment data. The amendment states: "They will be set when `invoice.paid` arrives and `handle_credit_pack_invoice_paid` updates the purchase." However, the existing `handle_credit_pack_invoice_paid` `if existing` branch (lines 453-458) only updates `subscription_current_period_start/end`, `subscription_status`, and `stripe_invoice_id` — it does NOT set `amount_cents_paid` or `currency`. With the `else` branch removed, these fields are never populated.

**Evidence:** Current `existing.update(...)` call at lines 453-457:
```ruby
updated = existing.update(
  subscription_current_period_start: ...,
  subscription_current_period_end: ...,
  subscription_status: ...,
  stripe_invoice_id: invoice.id
)
```
No `amount_cents_paid` or `currency` in this update.

**Fix:** Add to Note #9B-5 or the `handle_credit_pack_invoice_paid` section: on the first `invoice.paid` for a subscription (when `existing.amount_cents_paid.nil?`), also set `amount_cents_paid: invoice.amount_paid` and `currency: invoice.currency` in the `existing.update(...)` call. This mirrors what the removed `apply_subscription` creation logic did (line 109-110 of `apply_ai_credit_purchase.rb`).

## No other findings

- Round 1 BLOCKER (guard placement) amendment is correct and complete
- Round 1 F3 (dead code removal of `apply_top_up_checkout`) amendment is correct
- The `invoice_creation` metadata structure correctly mirrors `board_wwr_listings_controller.rb`

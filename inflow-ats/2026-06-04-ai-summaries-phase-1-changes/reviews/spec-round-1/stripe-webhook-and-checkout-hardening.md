# angle-1: stripe-webhook-and-checkout-hardening — Round 1

## Finding 1

**[BLOCKER]** `invoice.paid` handler — `CustomStripeSubscriptionMissingError` guard blocks new branch

**Where:** `app/jobs/stripe_webhook_handler_job.rb` line 204; SPEC.md Note #4

**What:** The spec says to add the `ai_credit_pack_top_up` metadata branch to the `invoice.paid` handler, placed "before the existing `board_wwr_listing_id` / `board_what_jobs_listing_id` branches." But line 204 of the handler is `raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?`, which fires BEFORE any metadata branches. An organization that purchases only a top-up credit pack (no base plan subscription) will have `stripe_subscription_id.nil?` be true, causing the handler to raise before the top-up metadata check is reached.

**Evidence:** `stripe_webhook_handler_job.rb` lines 203-206:
```ruby
begin
  raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?

  if object.metadata&.[]('board_wwr_listing_id').present?
```

The new `ai_credit_pack_top_up` branch needs to be placed BEFORE the `CustomStripeSubscriptionMissingError` guard, or the guard needs to be repositioned after the non-subscription invoice branches (top-up, wwr listing, what jobs listing).

**Fix:** Amend Note #4 to explicitly state: "Place the `ai_credit_pack_top_up` branch BEFORE the `raise CustomStripeSubscriptionMissingError` guard at line 204. The guard should only fire for invoices that are neither top-up credit packs nor job listings."

## Finding 2

**[HIGH]** `OrganizationAiCreditPurchase` validation relaxation incomplete — `amount_cents_paid` and `currency` still required at checkout

**Where:** `app/models/organization_ai_credit_purchase.rb` lines 15-16; SPEC.md Note #9B-5

**What:** The spec relaxes validations for `stripe_subscription_id` and `subscription_current_period_start/end` so subscription records can be created at checkout before payment. But `validates :amount_cents_paid, presence: true` and `validates :currency, presence: true` are unconditional (lines 15-16). At checkout time, no payment has been collected, so `amount_cents_paid` and `currency` are unknown. The purchase row will fail validation.

**Evidence:** Lines 15-16 of `organization_ai_credit_purchase.rb`:
```ruby
validates :amount_cents_paid, presence: true, numericality: { greater_than_or_equal_to: 0 }
validates :currency, presence: true
```

**Fix:** Add conditional validation for `amount_cents_paid` and `currency` in Note #9B-5's validation relaxation section. For example: make them required only when `stripe_subscription_id.present?` (i.e., after the subscription is linked and payment is confirmed), or set them to 0/default at checkout time and update them when `invoice.paid` arrives.

## Finding 3

**[MED]** `OrganizationAiCreditBalance#apply_top_up_checkout` becomes dead code

**Where:** `app/models/organization_ai_credit_balance.rb` lines 35-43

**What:** The `checkout.session.completed` `mode == 'payment'` branch (line 58-62 of `stripe_webhook_handler_job.rb`) is the sole caller of `apply_top_up_checkout`. When this branch is removed per Note #4, `apply_top_up_checkout` becomes dead code. The spec does not mention removing it.

**Evidence:**
```
grep -rn 'apply_top_up_checkout' → only two files:
- organization_ai_credit_balance.rb (definition)
- stripe_webhook_handler_job.rb (sole caller, in the branch being removed)
```

**Fix:** Add to Note #4 or Note #27 (model cleanups): remove `apply_top_up_checkout` from `OrganizationAiCreditBalance`.

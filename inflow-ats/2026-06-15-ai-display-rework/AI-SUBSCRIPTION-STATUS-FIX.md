# AI Subscription Status Fix

**Date:** 2026-06-16
**Issue:** `OrganizationAiCreditPurchase.subscription_status` never gets set to `active` after checkout

## Root cause

Three gaps in the webhook/checkout flow:

1. **`checkout.session.completed`** — sets `stripe_subscription_id` on the purchase but not `subscription_status`
2. **`customer.subscription.updated`** — only updates the organization, not the AI purchase record
3. **`customer.subscription.deleted`** — same, only touches the organization

AI subscription webhook events get routed to the organization instead of `OrganizationAiCreditPurchase`.

## Fix (3 parts)

### 1. `stripe_webhook_handler_job.rb` — checkout.session.completed (line 64)

Set status to active when the checkout completes:
```ruby
purchase.update_columns(
  stripe_subscription_id: object.subscription,
  subscription_status: 'active'
)
```

### 2. `stripe_webhook_handler_job.rb` — customer.subscription.updated (line 111)

Check if this subscription belongs to an AI purchase first. If so, update the purchase and skip the organization update:
```ruby
ai_purchase = OrganizationAiCreditPurchase.find_by(stripe_subscription_id: object.id)
if ai_purchase
  ai_purchase.update(
    subscription_status: object.status,
    subscription_current_period_start: Time.at(object.current_period_start).to_datetime,
    subscription_current_period_end: Time.at(object.current_period_end).to_datetime
  )
  return
end
```

Same pattern for `customer.subscription.deleted`.

### 3. `OrganizationAiCreditPurchase#sync_ai_subscription_with_stripe`

Safety net method — retrieves the Stripe subscription by `stripe_subscription_id` and updates local record. Called from the `show` action so stale records self-heal on page load.

### Also fix org 3 data

The existing purchase (id=1) needs `subscription_status` set to match Stripe's actual status for that subscription.

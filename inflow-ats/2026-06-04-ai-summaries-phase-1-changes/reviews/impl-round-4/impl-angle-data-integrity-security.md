# Implementation Angle: Data Integrity and Security -- Round 4

## Fresh adversarial focus

1. **Race condition: checkout creates purchase, webhook arrives before response.** The `checkout` action creates the `OrganizationAiCreditPurchase` record AFTER creating the Stripe checkout session. If the `checkout.session.completed` webhook fires between `Stripe::Checkout::Session.create` and `purchase.save`, the webhook handler would find no purchase and log an error. The purchase would then be created by the controller, and the next `invoice.paid` webhook would fail because `stripe_subscription_id` was never set (the `checkout.session.completed` handler already returned without setting it). 

   However, in practice, `checkout.session.completed` fires only after the customer completes the checkout flow in their browser, which takes at minimum several seconds. The controller response is synchronous and fast (milliseconds). This race is theoretically possible but practically impossible. And even if it happened, it would be detectable via the error log, and the subscription would need manual intervention (set `stripe_subscription_id` manually). Not a production concern.

   **Severity: Informational only.** Not blocking.

2. **`update_columns` bypass.** `purchase.update_columns(stripe_subscription_id: object.subscription)` skips validations. At this point, `stripe_subscription_id` is being set for the first time. The validation `presence: true, if: -> { subscription? && stripe_checkout_session_id.blank? }` would pass after this update (subscription_id is now present). But `subscription_current_period_start/end` validations (required when `stripe_subscription_id.present?`) would fail because those fields aren't set yet. Hence `update_columns` is the correct choice -- the comment in the code explains this. Correct.

3. **Authorization on `prices` endpoint.** Uses `OrganizationAiCreditPurchasePolicy#show?` which requires `is_org_user?`. This means any org member can see prices, which is appropriate -- prices are not sensitive. Correct.

## Findings

**No findings.**

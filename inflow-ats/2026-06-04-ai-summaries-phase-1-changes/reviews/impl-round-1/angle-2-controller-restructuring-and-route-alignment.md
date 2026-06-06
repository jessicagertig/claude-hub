# Controller Restructuring and Route Alignment — Round 1

## Findings

- F1 [MED] `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:52-53` / In `#checkout`, the purchase is created with `subscription_status: :active` and `amount_cents_paid: 0`. Setting `subscription_status: :active` immediately is premature -- the user has not completed checkout yet and may abandon the Stripe checkout page. The spec says "subscription_status: nil" for the pre-checkout record. However, this does not block because the status is a display hint, and the `checkout.session.completed` webhook will fire to confirm anyway. If the user abandons checkout, the purchase row stays with status `:active` but no `stripe_subscription_id`, which is misleading but not data-destructive.

No blocking issues found.

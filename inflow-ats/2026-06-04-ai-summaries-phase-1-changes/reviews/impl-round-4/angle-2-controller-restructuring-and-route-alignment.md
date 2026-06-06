# Angle 2: Controller Restructuring and Route Alignment -- Round 4

## Fresh adversarial focus areas

1. **Route resource type.** `resource :ai_credits` (singular) and `resource :ai_credit_purchases` (singular) -- both use `resource` not `resources`. This means paths like `/ai_credits` (not `/ai_credits/:id`) and `/ai_credit_purchases` (not `/ai_credit_purchases/:id`). This is correct per spec: these are org-scoped singletons.

2. **Params key alignment.** Controller uses `params.require(:organization_ai_credit_purchase).permit(:stripe_price_lookup_key)`. Frontend hooks send `{ organizationAiCreditPurchase: { stripePriceLookupKey } }`. Rails auto-converts camelCase to snake_case via the middleware. Match confirmed.

3. **Authorization consistency.**
   - `show` -> `OrganizationAiCreditPurchasePolicy#show?` (any org user)
   - `checkout` -> `BillingPolicy#create_subscription?` (admin)
   - `purchase_top_up` -> `BillingPolicy#checkout?` (admin)
   - `cancel` -> `BillingPolicy#cancel_subscription?` (admin)
   - `prices` -> `OrganizationAiCreditPurchasePolicy#show?` (any org user)
   
   This matches the spec's authorization table.

4. **Deleted controllers.** Both `ai_credits_controller.rb` and `ai_credit_subscriptions_controller.rb` confirmed deleted.

## Findings

**No findings.**

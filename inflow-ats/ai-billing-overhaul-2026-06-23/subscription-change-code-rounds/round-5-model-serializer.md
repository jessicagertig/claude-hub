# Round 5 — MODEL + SERIALIZER segment

Reviewer: model-serializer. Segment: `app/models/organization_ai_credit_purchase.rb` (`#stripe_subscription`, enums, subscription lookup) + `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb`, audited against the analog `Organization` methods + render shapes in `subscription-change-analog-trace.md`.

## Files traced

- `app/models/organization_ai_credit_purchase.rb` (OURS) ← → `app/models/organization.rb:469-483` (ANALOG, in-worktree, verified)
- `app/serializers/api/v1/organization_ai_credit_purchase_serializer.rb` (OURS)
- `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` (consumer — confirms which model/serializer methods are on the subscription-change SCREEN path)
- `db/schema.rb:965-990` (organization_ai_credit_purchases columns — confirms serializer attrs + enum columns exist)

Chain: `AiCreditSubscription.tsx` → `customer_subscription` (controller `:420`) → `OrganizationAiCreditPurchase#stripe_subscription` (`:260`) → `Stripe::Subscription.retrieve` (STRIPE terminal, raw live object rendered, no serializer).

## Structural comparison vs analog

1. **`OrganizationAiCreditPurchase#stripe_subscription` (`:260-264`) vs `Organization#stripe_subscription` (`organization.rb:474-478`)** — EXACT structural match. Same `return if stripe_subscription_id.nil?` guard, same `Stripe::Subscription.retrieve({ id: stripe_subscription_id, expand: ['items.data.price.tiers'] })`. Resolves the live Stripe object that the SCREEN consumes. The only difference is the receiver (`purchase.stripe_subscription_id` vs `organization.stripe_subscription_id`) — SANCTIONED #1.

2. **Serializer is OFF the subscription-change SCREEN path.** The analog `customer_subscription` (`billing_controller.rb:614`) renders the RAW live Stripe object with NO serializer. OURS `customer_subscription` (`:430`) likewise renders `organization_ai_credit_purchase.stripe_subscription` (raw live object) — `OrganizationAiCreditPurchaseSerializer` is NOT invoked on this path. The serializer is used only by `#show` (W3, out-of-flow), `purchase_top_up`, and `cancel`. Therefore the serializer's attribute set has no bearing on the audited flow and the analog's render shape (live-Stripe fields `items.data[0].price`, `status`, `plan.id`, `items.data[0].id`) is satisfied by `stripe_subscription`, not the serializer.

3. **Local-column display-gating symptom is NOT present in the model/serializer layer.** The render gate in `customer_subscription` is `organization_ai_credit_purchase.nil? || organization_ai_credit_purchase.stripe_subscription_id.nil?` (`:426`) — matching the analog's `stripe_subscription_id.nil?` gate. The `find_by(subscription_status: [:active, :past_due])` row scoping (`:423`) is the live-subscription-endpoint scoping covered by SANCTIONED #4. The model exposes no method that gates the display on a local status column.

4. **Enums** (`kind`, `subscription_status` with `_prefix: true`) and the `subscription_credits_per_period` / `subscription_current_period_*` / `subscription_canceled_at` columns — operate on the purchase row's own columns rather than the analog's org columns. SANCTIONED #2 (operates on the `OrganizationAiCreditPurchase` record). The `subscription` kind-enum scope + the `subscription_status` enum back the SANCTIONED #4 scoped lookup.

5. **`AI_CREDIT_AMOUNTS_BY_LOOKUP_KEY` + `ai_credit_subscription_plan_lookup_key?` / `ai_credit_allocation_for_lookup_key` / `ai_credit_top_up_lookup_key?`** — `ai_credit_*` descriptor naming + local lookup_key→credits table. SANCTIONED #5 (naming) and W4 (local credits table). The model is internally consistent with the current (post-rename) names.

## Out-of-segment observation (NOT a model/serializer deviation, NOT flagged as a finding)

`OrganizationAiCreditPurchasesController#checkout` (`:19`, `:31`) calls `OrganizationAiCreditPurchase.subscription_key?` and `.credit_amount_for_key` — the OLD pre-rename names. The model defines only `ai_credit_subscription_plan_lookup_key?` / `ai_credit_allocation_for_lookup_key`, so those calls would raise `NoMethodError`. This is a stale-reference bug in the `#checkout` action (subscribe-CREATION path), which is a DIFFERENT flow from the subscription-CHANGE flow under audit and lives in the controller layer, not the model/serializer. Noted for the controller-segment reviewer; not a deviation from the analog within my segment.

## Verdict

Zero in-segment deviations from the analog (beyond those already covered by SANCTIONED #1/#2/#4/#5 and W4). The model's `stripe_subscription` is an exact structural match to the analog `Organization#stripe_subscription`; the serializer is off the audited SCREEN path; no local-column display-gating exists in this layer.

deviation_count: 0
